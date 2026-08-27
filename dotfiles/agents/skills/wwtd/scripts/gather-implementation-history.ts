#!/usr/bin/env bun
// WWTD implementation evidence gatherer. Collects one GitHub user's authored
// pull requests, the files and commits in those PRs, and their direct commits
// on requested paths from the trailing 30 days (or a narrower --since window).
//
// It gathers and validates facts but never decides what the person would do.
//
// Usage: bun gather-implementation-history.ts <output-json-path>
//          [--author <github-login>]  default: authenticated user
//          [--repo <owner/name>]      repeatable; default: all visible repositories
//          [--path <repo-path>]       repeatable; requires at least one --repo
//          [--since <ISO-8601 date>]  narrow the window

import { execFile } from "node:child_process";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import process from "node:process";
import { promisify } from "node:util";

import { z } from "zod";

const execFileAsync = promisify(execFile);
const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024 * 1024;
const IMPLEMENTATION_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const SEARCH_RESULT_CAP = 1000;
const SEARCH_PAGE_SIZE = 100;
const MIN_SEARCH_SLICE_MS = 60 * 60 * 1000;
const FETCH_CONCURRENCY = 8;

const githubUserSchema = z.object({
  login: z.string().min(1),
});

const searchItemSchema = z.object({
  number: z.number().int().positive(),
  title: z.string(),
  body: z.string().nullable(),
  html_url: z.string().url(),
  repository_url: z.string().url(),
  state: z.enum(["open", "closed"]),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

const searchPageSchema = z.object({
  total_count: z.number().int().nonnegative(),
  incomplete_results: z.boolean(),
  items: z.array(searchItemSchema),
});

const pullRequestDetailsSchema = z.object({
  body: z.string().nullable(),
  draft: z.boolean(),
  merged_at: z.string().datetime().nullable(),
  additions: z.number().int().nonnegative(),
  deletions: z.number().int().nonnegative(),
  changed_files: z.number().int().nonnegative(),
  base: z.object({ ref: z.string() }),
  head: z.object({ ref: z.string() }),
});

const pullRequestFileSchema = z.object({
  filename: z.string().min(1),
  status: z.string().min(1),
  additions: z.number().int().nonnegative(),
  deletions: z.number().int().nonnegative(),
  changes: z.number().int().nonnegative(),
  previous_filename: z.string().min(1).optional(),
});

const commitIdentitySchema = z.object({
  name: z.string(),
  email: z.string(),
  date: z.string().datetime(),
}).nullable();

const restCommitSchema = z.object({
  sha: z.string().min(7),
  html_url: z.string().url(),
  author: githubUserSchema.nullable(),
  committer: githubUserSchema.nullable(),
  commit: z.object({
    message: z.string(),
    author: commitIdentitySchema,
    committer: commitIdentitySchema,
  }),
});

const authoredPullRequestRefSchema = z.object({
  repository: z.string().regex(/^[^/]+\/[^/]+$/),
  number: z.number().int().positive(),
  title: z.string(),
  body: z.string(),
  url: z.string().url(),
  state: z.enum(["open", "closed"]),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});

export type AuthoredPullRequestRef = z.infer<typeof authoredPullRequestRefSchema>;

type PullRequestDetails = z.infer<typeof pullRequestDetailsSchema>;
type RestPullRequestFile = z.infer<typeof pullRequestFileSchema>;
type RestCommit = z.infer<typeof restCommitSchema>;

const implementationFileSchema = z.object({
  path: z.string(),
  previousPath: z.string().optional(),
  status: z.string(),
  additions: z.number().int().nonnegative(),
  deletions: z.number().int().nonnegative(),
  changes: z.number().int().nonnegative(),
});

const implementationCommitSchema = z.object({
  sha: z.string(),
  message: z.string(),
  authoredAt: z.string().datetime().nullable(),
  committedAt: z.string().datetime().nullable(),
  authorLogin: z.string().nullable(),
  committerLogin: z.string().nullable(),
  url: z.string().url(),
});

const pullRequestImplementationSchema = z.object({
  repository: z.string(),
  number: z.number().int().positive(),
  title: z.string(),
  body: z.string(),
  url: z.string().url(),
  state: z.enum(["open", "closed"]),
  draft: z.boolean().nullable(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
  mergedAt: z.string().datetime().nullable(),
  baseRef: z.string().nullable(),
  headRef: z.string().nullable(),
  additions: z.number().int().nonnegative().nullable(),
  deletions: z.number().int().nonnegative().nullable(),
  changedFiles: z.number().int().nonnegative().nullable(),
  detailsComplete: z.boolean(),
  filesComplete: z.boolean(),
  commitsComplete: z.boolean(),
  files: z.array(implementationFileSchema),
  commits: z.array(implementationCommitSchema),
});

export type PullRequestImplementation = z.infer<
  typeof pullRequestImplementationSchema
>;

const directCommitSchema = implementationCommitSchema.extend({
  repository: z.string(),
  matchingPaths: z.array(z.string().min(1)).min(1),
});

export type DirectCommit = z.infer<typeof directCommitSchema>;

const implementationHistorySchema = z.object({
  schemaVersion: z.literal(1),
  generatedAt: z.string().datetime(),
  author: z.string(),
  coverage: z.object({
    scope: z.string(),
    windowStart: z.string().datetime(),
    windowEnd: z.string().datetime(),
    targetPaths: z.array(z.string()),
    pullRequestsFound: z.number().int().nonnegative(),
    pullRequestsWithCompleteDetails: z.number().int().nonnegative(),
    pullRequestsWithCompleteFiles: z.number().int().nonnegative(),
    pullRequestsWithCompleteCommits: z.number().int().nonnegative(),
    repositories: z.number().int().nonnegative(),
    pullRequestFiles: z.number().int().nonnegative(),
    pullRequestCommits: z.number().int().nonnegative(),
    directCommits: z.number().int().nonnegative(),
    limitations: z.array(z.string()),
  }),
  pullRequests: z.array(pullRequestImplementationSchema),
  directCommits: z.array(directCommitSchema),
});

export type ImplementationHistory = z.infer<typeof implementationHistorySchema>;

export type PullRequestEvidence = {
  ref: AuthoredPullRequestRef;
  details: PullRequestDetails | null;
  detailsComplete: boolean;
  files: RestPullRequestFile[];
  filesComplete: boolean;
  commits: RestCommit[];
  commitsComplete: boolean;
};

export type CliArguments = {
  outputPath: string;
  author: string | undefined;
  repos: string[];
  paths: string[];
  since: string | undefined;
};

export function parseArguments(args: string[]): CliArguments {
  const usage =
    "Usage: bun gather-implementation-history.ts <output-json-path> [--author <github-login>] [--repo <owner/name> ...] [--path <repo-path> ...] [--since <ISO-8601 date>]";
  const positional: string[] = [];
  const repos: string[] = [];
  const paths: string[] = [];
  let author: string | undefined;
  let since: string | undefined;

  for (let index = 0; index < args.length; index++) {
    const argument = args[index];
    if (
      argument === "--author" ||
      argument === "--repo" ||
      argument === "--path" ||
      argument === "--since"
    ) {
      const value = args[index + 1];
      if (value === undefined || value === "" || value.startsWith("--")) {
        throw new Error(usage);
      }
      if (argument === "--author") {
        author = value;
      } else if (argument === "--repo") {
        repos.push(value);
      } else if (argument === "--path") {
        paths.push(value);
      } else {
        since = value;
      }
      index++;
      continue;
    }
    if (argument.startsWith("--")) {
      throw new Error(usage);
    }
    positional.push(argument);
  }

  if (positional.length !== 1) {
    throw new Error(usage);
  }
  if (since !== undefined && Number.isNaN(new Date(since).getTime())) {
    throw new Error(`--since must be an ISO-8601 date, got: ${since}`);
  }
  for (const repo of repos) {
    if (!/^[^/\s]+\/[^/\s]+$/.test(repo)) {
      throw new Error(`--repo must be owner/name, got: ${repo}`);
    }
  }
  for (const path of paths) {
    if (path.trim() === "" || path.startsWith("/") || path.includes("\0")) {
      throw new Error(`--path must be a repository-relative path, got: ${path}`);
    }
  }
  if (paths.length > 0 && repos.length === 0) {
    throw new Error("--path requires at least one --repo");
  }

  return {
    outputPath: positional[0],
    author,
    repos: [...new Set(repos)],
    paths: [...new Set(paths)],
    since,
  };
}

export function resolveWindowStart(
  generatedAt: string,
  since: string | undefined,
): string {
  const windowStart = new Date(generatedAt).getTime() - IMPLEMENTATION_WINDOW_MS;
  const sinceMs =
    since === undefined ? Number.NEGATIVE_INFINITY : new Date(since).getTime();
  return new Date(Math.max(windowStart, sinceMs)).toISOString();
}

async function runGh(args: string[]): Promise<string> {
  try {
    const { stdout } = await execFileAsync("gh", args, {
      encoding: "utf8",
      maxBuffer: MAX_COMMAND_OUTPUT_BYTES,
    });
    return stdout;
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`gh ${args.join(" ")} failed: ${error.message}`, {
        cause: error,
      });
    }
    throw error;
  }
}

function isRetryable(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /HTTP (403|429|5\d\d)|rate limit|timed? ?out|ECONNRESET|EAI_AGAIN/i.test(
    message,
  );
}

async function withRetry<T>(operation: () => Promise<T>): Promise<T> {
  const delaysMs = [2_000, 15_000, 60_000];
  for (let attempt = 0; ; attempt++) {
    try {
      return await operation();
    } catch (error) {
      if (attempt >= delaysMs.length || !isRetryable(error)) {
        throw error;
      }
      console.error(
        `Retrying after transient GitHub error (attempt ${attempt + 1}): ${
          error instanceof Error ? error.message.split("\n")[0] : error
        }`,
      );
      const jitterMs = Math.floor(Math.random() * 2_000);
      await new Promise((resolve) =>
        setTimeout(resolve, delaysMs[attempt] + jitterMs),
      );
    }
  }
}

export function parseJsonLines<T>(raw: string, schema: z.ZodType<T>): T[] {
  const trimmed = raw.trim();
  if (trimmed === "") {
    return [];
  }

  return trimmed.split("\n").map((line, index) => {
    let value: unknown;
    try {
      value = JSON.parse(line);
    } catch (error) {
      throw new Error(`Invalid JSON from gh on line ${index + 1}`, {
        cause: error,
      });
    }
    return schema.parse(value);
  });
}

export function authoredPullRequestRefFromSearchItem(
  item: z.infer<typeof searchItemSchema>,
): AuthoredPullRequestRef {
  const prefix = "https://api.github.com/repos/";
  if (!item.repository_url.startsWith(prefix)) {
    throw new Error(
      `Unexpected repository URL: ${item.repository_url} — only GitHub.com is supported, not GitHub Enterprise hosts`,
    );
  }
  return authoredPullRequestRefSchema.parse({
    repository: item.repository_url.slice(prefix.length),
    number: item.number,
    title: item.title,
    body: item.body ?? "",
    url: item.html_url,
    state: item.state,
    createdAt: item.created_at,
    updatedAt: item.updated_at,
  });
}

export function dedupePullRequests(
  refs: AuthoredPullRequestRef[],
): AuthoredPullRequestRef[] {
  const byKey = new Map<string, AuthoredPullRequestRef>();
  for (const ref of refs) {
    byKey.set(`${ref.repository}#${ref.number}`, ref);
  }
  return [...byKey.values()];
}

function searchTimestamp(ms: number): string {
  return `${new Date(ms).toISOString().slice(0, 19)}+00:00`;
}

async function searchPage(
  query: string,
  page: number,
  limitations: string[],
): Promise<z.infer<typeof searchPageSchema>> {
  const fetchPage = async () => {
    const raw = await withRetry(() =>
      runGh([
        "api",
        "-X",
        "GET",
        "search/issues",
        "-f",
        `q=${query}`,
        "-F",
        "advanced_search=true",
        "-f",
        "sort=created",
        "-f",
        "order=desc",
        "-F",
        `per_page=${SEARCH_PAGE_SIZE}`,
        "-F",
        `page=${page}`,
      ]),
    );
    return searchPageSchema.parse(JSON.parse(raw));
  };

  let result = await fetchPage();
  if (result.incomplete_results) {
    result = await fetchPage();
    if (result.incomplete_results) {
      limitations.push(
        `GitHub reported incomplete search results for "${query}" (page ${page}); some pull requests may be missing.`,
      );
    }
  }
  return result;
}

async function searchSlice(
  baseQuery: string,
  startMs: number,
  endMs: number,
  limitations: string[],
): Promise<AuthoredPullRequestRef[]> {
  const query = `${baseQuery} created:${searchTimestamp(startMs)}..${searchTimestamp(endMs)}`;
  const first = await searchPage(query, 1, limitations);

  if (
    first.total_count > SEARCH_RESULT_CAP &&
    endMs - startMs >= 2 * MIN_SEARCH_SLICE_MS
  ) {
    const midMs = startMs + Math.floor((endMs - startMs) / 2);
    const left = await searchSlice(baseQuery, startMs, midMs, limitations);
    const right = await searchSlice(
      baseQuery,
      midMs + 1_000,
      endMs,
      limitations,
    );
    return [...left, ...right];
  }

  if (first.total_count > SEARCH_RESULT_CAP) {
    limitations.push(
      `Search "${query}" matched ${first.total_count} pull requests; only the ${SEARCH_RESULT_CAP} GitHub returns were scanned.`,
    );
  }

  const refs = first.items.map(authoredPullRequestRefFromSearchItem);
  const reachable = Math.min(first.total_count, SEARCH_RESULT_CAP);
  const pageCount = Math.ceil(reachable / SEARCH_PAGE_SIZE);
  for (let page = 2; page <= pageCount; page++) {
    const result = await searchPage(query, page, limitations);
    refs.push(...result.items.map(authoredPullRequestRefFromSearchItem));
  }
  return refs;
}

async function discoverAuthoredPullRequests(
  author: string,
  repos: string[],
  windowStartMs: number,
  windowEndMs: number,
  limitations: string[],
): Promise<AuthoredPullRequestRef[]> {
  const repoQualifiers =
    repos.length === 0 ? [""] : repos.map((repo) => ` repo:${repo}`);
  const refs: AuthoredPullRequestRef[] = [];
  for (const repoQualifier of repoQualifiers) {
    console.error(`Searching authored pull requests (${author}${repoQualifier})…`);
    refs.push(
      ...(await searchSlice(
        `type:pr author:${author}${repoQualifier}`,
        windowStartMs,
        windowEndMs,
        limitations,
      )),
    );
  }
  return dedupePullRequests(refs);
}

type EndpointResult<T> = {
  value: T;
  complete: boolean;
};

async function fetchEndpoint<T>(
  label: string,
  endpoint: string,
  fallback: T,
  parse: (raw: string) => T,
  limitations: string[],
): Promise<EndpointResult<T>> {
  try {
    const raw = await withRetry(() => runGh(["api", endpoint]));
    return { value: parse(raw), complete: true };
  } catch (error) {
    limitations.push(
      `Could not fetch ${label}: ${
        error instanceof Error ? error.message.split("\n")[0] : error
      }`,
    );
    return { value: fallback, complete: false };
  }
}

async function fetchPaginatedEndpoint<T>(
  label: string,
  endpoint: string,
  schema: z.ZodType<T>,
  limitations: string[],
): Promise<EndpointResult<T[]>> {
  try {
    const raw = await withRetry(() =>
      runGh(["api", "--paginate", endpoint, "--jq", ".[]"]),
    );
    return {
      value: parseJsonLines(raw, schema),
      complete: true,
    };
  } catch (error) {
    limitations.push(
      `Could not fetch ${label}: ${
        error instanceof Error ? error.message.split("\n")[0] : error
      }`,
    );
    return { value: [], complete: false };
  }
}

async function fetchPullRequestEvidence(
  ref: AuthoredPullRequestRef,
  limitations: string[],
): Promise<PullRequestEvidence> {
  const prefix = `${ref.repository}#${ref.number}`;
  const details = await fetchEndpoint(
    `details for ${prefix}`,
    `repos/${ref.repository}/pulls/${ref.number}`,
    null,
    (raw) => pullRequestDetailsSchema.parse(JSON.parse(raw)),
    limitations,
  );
  const files = await fetchPaginatedEndpoint(
    `files for ${prefix}`,
    `repos/${ref.repository}/pulls/${ref.number}/files?per_page=100`,
    pullRequestFileSchema,
    limitations,
  );
  const commits = await fetchPaginatedEndpoint(
    `commits for ${prefix}`,
    `repos/${ref.repository}/pulls/${ref.number}/commits?per_page=100`,
    restCommitSchema,
    limitations,
  );

  if (files.value.length >= 3000) {
    files.complete = false;
    limitations.push(
      `GitHub caps pull request file responses at 3000 files; ${prefix} may have additional files.`,
    );
  }

  return {
    ref,
    details: details.value,
    detailsComplete: details.complete,
    files: files.value,
    filesComplete: files.complete,
    commits: commits.value,
    commitsComplete: commits.complete,
  };
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  operation: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let nextIndex = 0;
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, async () => {
      for (;;) {
        const index = nextIndex++;
        if (index >= items.length) {
          return;
        }
        results[index] = await operation(items[index]);
      }
    }),
  );
  return results;
}

export function normalizeImplementationCommit(
  commit: RestCommit,
): z.infer<typeof implementationCommitSchema> {
  return implementationCommitSchema.parse({
    sha: commit.sha,
    message: commit.commit.message,
    authoredAt: commit.commit.author?.date ?? null,
    committedAt: commit.commit.committer?.date ?? null,
    authorLogin: commit.author?.login ?? null,
    committerLogin: commit.committer?.login ?? null,
    url: commit.html_url,
  });
}

export function normalizePullRequestEvidence(
  evidence: PullRequestEvidence,
): PullRequestImplementation {
  const { ref, details } = evidence;
  return pullRequestImplementationSchema.parse({
    ...ref,
    body: details?.body ?? ref.body,
    draft: details?.draft ?? null,
    mergedAt: details?.merged_at ?? null,
    baseRef: details?.base.ref ?? null,
    headRef: details?.head.ref ?? null,
    additions: details?.additions ?? null,
    deletions: details?.deletions ?? null,
    changedFiles: details?.changed_files ?? null,
    detailsComplete: evidence.detailsComplete,
    filesComplete: evidence.filesComplete,
    commitsComplete: evidence.commitsComplete,
    files: evidence.files.map((file) => ({
      path: file.filename,
      ...(file.previous_filename === undefined
        ? {}
        : { previousPath: file.previous_filename }),
      status: file.status,
      additions: file.additions,
      deletions: file.deletions,
      changes: file.changes,
    })),
    commits: evidence.commits.map(normalizeImplementationCommit),
  });
}

async function fetchDirectCommitsForPath(
  repository: string,
  path: string,
  author: string,
  windowStart: string,
  windowEnd: string,
  limitations: string[],
): Promise<DirectCommit[]> {
  const query = new URLSearchParams({
    path,
    author,
    since: windowStart,
    until: windowEnd,
    per_page: "100",
  });
  const result = await fetchPaginatedEndpoint(
    `commits by ${author} on ${repository}:${path}`,
    `repos/${repository}/commits?${query.toString()}`,
    restCommitSchema,
    limitations,
  );
  return result.value.map((commit) =>
    directCommitSchema.parse({
      ...normalizeImplementationCommit(commit),
      repository,
      matchingPaths: [path],
    }),
  );
}

export function mergeDirectCommits(commits: DirectCommit[]): DirectCommit[] {
  const byKey = new Map<string, DirectCommit>();
  for (const commit of commits) {
    const key = `${commit.repository}:${commit.sha}`;
    const existing = byKey.get(key);
    if (existing === undefined) {
      byKey.set(key, structuredClone(commit));
      continue;
    }
    existing.matchingPaths = [
      ...new Set([...existing.matchingPaths, ...commit.matchingPaths]),
    ].sort();
  }
  return [...byKey.values()].sort(
    (left, right) =>
      (right.authoredAt ?? right.committedAt ?? "").localeCompare(
        left.authoredAt ?? left.committedAt ?? "",
      ) || left.url.localeCompare(right.url),
  );
}

export function buildImplementationHistory(
  pullRequests: PullRequestImplementation[],
  directCommits: DirectCommit[],
  options: {
    author: string;
    scope: string;
    generatedAt: string;
    windowStart: string;
    targetPaths: string[];
    limitations: string[];
  },
): ImplementationHistory {
  const sortedPullRequests = [...pullRequests].sort(
    (left, right) =>
      right.createdAt.localeCompare(left.createdAt) ||
      left.url.localeCompare(right.url),
  );
  const mergedDirectCommits = mergeDirectCommits(directCommits);
  const repositories = new Set([
    ...sortedPullRequests.map((pullRequest) => pullRequest.repository),
    ...mergedDirectCommits.map((commit) => commit.repository),
  ]);

  return implementationHistorySchema.parse({
    schemaVersion: 1,
    generatedAt: options.generatedAt,
    author: options.author,
    coverage: {
      scope: options.scope,
      windowStart: options.windowStart,
      windowEnd: options.generatedAt,
      targetPaths: options.targetPaths,
      pullRequestsFound: sortedPullRequests.length,
      pullRequestsWithCompleteDetails: sortedPullRequests.filter(
        (pullRequest) => pullRequest.detailsComplete,
      ).length,
      pullRequestsWithCompleteFiles: sortedPullRequests.filter(
        (pullRequest) => pullRequest.filesComplete,
      ).length,
      pullRequestsWithCompleteCommits: sortedPullRequests.filter(
        (pullRequest) => pullRequest.commitsComplete,
      ).length,
      repositories: repositories.size,
      pullRequestFiles: sortedPullRequests.reduce(
        (total, pullRequest) => total + pullRequest.files.length,
        0,
      ),
      pullRequestCommits: sortedPullRequests.reduce(
        (total, pullRequest) => total + pullRequest.commits.length,
        0,
      ),
      directCommits: mergedDirectCommits.length,
      limitations: options.limitations,
    },
    pullRequests: sortedPullRequests,
    directCommits: mergedDirectCommits,
  });
}

async function main(): Promise<void> {
  const {
    outputPath,
    author: requestedAuthor,
    repos,
    paths,
    since,
  } = parseArguments(process.argv.slice(2));

  await runGh(["auth", "status"]);
  const authorEndpoint =
    requestedAuthor === undefined
      ? "user"
      : `users/${encodeURIComponent(requestedAuthor)}`;
  const author = githubUserSchema.parse(
    JSON.parse(await runGh(["api", authorEndpoint])),
  ).login;

  const generatedAt = new Date().toISOString();
  const windowStart = resolveWindowStart(generatedAt, since);
  const limitations = [
    "GitHub only returns history visible to the authenticated user; deleted commits, deleted pull requests, and inaccessible repositories are absent.",
    "GitHub login attribution can omit commits authored with an email not linked to the account.",
    "Pull request ownership does not prove that the author wrote every commit or changed line in that pull request.",
  ];

  const refs = await discoverAuthoredPullRequests(
    author,
    repos,
    new Date(windowStart).getTime(),
    new Date(generatedAt).getTime(),
    limitations,
  );
  console.error(`Found ${refs.length} pull requests authored by ${author}.`);

  let fetched = 0;
  const evidence = await mapWithConcurrency(
    refs,
    FETCH_CONCURRENCY,
    async (ref) => {
      try {
        return await fetchPullRequestEvidence(ref, limitations);
      } finally {
        fetched++;
        if (fetched % 25 === 0 || fetched === refs.length) {
          console.error(
            `Fetched implementation evidence for ${fetched}/${refs.length} pull requests…`,
          );
        }
      }
    },
  );
  const pullRequests = evidence.map(normalizePullRequestEvidence);

  const directCommitGroups = await mapWithConcurrency(
    repos.flatMap((repository) =>
      paths.map((path) => ({ repository, path })),
    ),
    FETCH_CONCURRENCY,
    ({ repository, path }) =>
      fetchDirectCommitsForPath(
        repository,
        path,
        author,
        windowStart,
        generatedAt,
        limitations,
      ),
  );

  const history = buildImplementationHistory(
    pullRequests,
    directCommitGroups.flat(),
    {
      author,
      scope: repos.length === 0 ? "all visible repositories" : repos.join(", "),
      generatedAt,
      windowStart,
      targetPaths: paths,
      limitations,
    },
  );

  await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
  await rm(outputPath, { force: true });
  await writeFile(outputPath, `${JSON.stringify(history, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });

  process.stdout.write(
    `${JSON.stringify(
      {
        outputPath,
        author: history.author,
        coverage: history.coverage,
      },
      null,
      2,
    )}\n`,
  );
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}
