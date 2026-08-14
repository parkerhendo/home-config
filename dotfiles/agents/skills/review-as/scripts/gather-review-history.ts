#!/usr/bin/env bun
// review-as evidence gatherer. Collects one GitHub user's review activity —
// review submissions, inline review comments, and PR discussion comments —
// from the trailing 365 days (or a narrower --since window), scoped to the
// given repositories or, without --repo, to every repository the
// authenticated gh CLI can see. PRs authored by the reviewer are included
// and every item is marked with onOwnPullRequest: agents author many PRs
// now, so a person's comments on their own PRs are often genuine review.
//
// It never judges: distilling the profile and simulating reviews is the
// agent's job.
//
// Usage: bun gather-review-history.ts <output-json-path>
//          [--reviewer <github-login>]   default: the authenticated user
//          [--repo <owner/name>]         repeatable; default: all visible repositories
//          [--since <ISO-8601 date>]     narrow the window
//
// Every gh/JSON boundary is validated with Zod. Requires an authenticated
// gh CLI; run via `bun run gather`, which installs dependencies first.

import { execFile } from "node:child_process";
import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import process from "node:process";
import { promisify } from "node:util";

import { z } from "zod";

const execFileAsync = promisify(execFile);
const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024 * 1024;
const REVIEW_WINDOW_MS = 365 * 24 * 60 * 60 * 1000;
const SEARCH_RESULT_CAP = 1000;
const SEARCH_PAGE_SIZE = 100;
const MIN_SEARCH_SLICE_MS = 60 * 60 * 1000;
const FETCH_CONCURRENCY = 8;
const DIFF_HUNK_MAX_LINES = 12;

const githubUserSchema = z.object({
  login: z.string().min(1),
});

const searchItemSchema = z.object({
  number: z.number().int().positive(),
  title: z.string(),
  html_url: z.string().url(),
  repository_url: z.string().url(),
  user: githubUserSchema.nullable(),
  pull_request: z.object({}).loose(),
});

const searchPageSchema = z.object({
  total_count: z.number().int().nonnegative(),
  incomplete_results: z.boolean(),
  items: z.array(searchItemSchema),
});

const reviewStateSchema = z.enum([
  "APPROVED",
  "CHANGES_REQUESTED",
  "COMMENTED",
  "DISMISSED",
  "PENDING",
]);

const restReviewSchema = z.object({
  id: z.number().int(),
  body: z.string().nullable(),
  state: reviewStateSchema,
  // Pending (draft) reviews carry a null submitted_at or omit the field.
  submitted_at: z.string().datetime().nullish(),
  html_url: z.string().url(),
});

const inlineCommentSchema = z.object({
  id: z.number().int(),
  body: z.string(),
  created_at: z.string().datetime(),
  html_url: z.string().url(),
  path: z.string(),
  line: z.number().int().nullable(),
  diff_hunk: z.string().nullable(),
  in_reply_to_id: z.number().int().optional(),
});

const issueCommentSchema = z.object({
  id: z.number().int(),
  body: z.string(),
  created_at: z.string().datetime(),
  html_url: z.string().url(),
});

const pullRequestRefSchema = z.object({
  repository: z.string().regex(/^[^/]+\/[^/]+$/),
  number: z.number().int().positive(),
  title: z.string(),
  url: z.string().url(),
  authoredByReviewer: z.boolean(),
});

export type PullRequestRef = z.infer<typeof pullRequestRefSchema>;

const reviewHistoryItemSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("review_submission"),
    repository: z.string(),
    pullRequestNumber: z.number().int().positive(),
    pullRequestTitle: z.string(),
    onOwnPullRequest: z.boolean(),
    body: z.string(),
    createdAt: z.string().datetime(),
    url: z.string().url(),
    state: reviewStateSchema.exclude(["PENDING"]),
  }),
  z.object({
    kind: z.literal("inline_review_comment"),
    repository: z.string(),
    pullRequestNumber: z.number().int().positive(),
    pullRequestTitle: z.string(),
    onOwnPullRequest: z.boolean(),
    body: z.string(),
    createdAt: z.string().datetime(),
    url: z.string().url(),
    path: z.string(),
    line: z.number().int().nullable(),
    diffHunk: z.string(),
    isReply: z.boolean(),
  }),
  z.object({
    kind: z.literal("pull_request_comment"),
    repository: z.string(),
    pullRequestNumber: z.number().int().positive(),
    pullRequestTitle: z.string(),
    onOwnPullRequest: z.boolean(),
    body: z.string(),
    createdAt: z.string().datetime(),
    url: z.string().url(),
  }),
]);

export type ReviewHistoryItem = z.infer<typeof reviewHistoryItemSchema>;

const reviewHistorySchema = z.object({
  schemaVersion: z.literal(2),
  generatedAt: z.string().datetime(),
  reviewer: z.string(),
  coverage: z.object({
    scope: z.string(),
    windowStart: z.string().datetime(),
    windowEnd: z.string().datetime(),
    pullRequestsScanned: z.number().int().nonnegative(),
    pullRequestsAuthoredByReviewer: z.number().int().nonnegative(),
    repositories: z.number().int().nonnegative(),
    reviewSubmissions: z.number().int().nonnegative(),
    inlineReviewComments: z.number().int().nonnegative(),
    pullRequestComments: z.number().int().nonnegative(),
    limitations: z.array(z.string()),
  }),
  items: z.array(reviewHistoryItemSchema),
});

export type ReviewHistory = z.infer<typeof reviewHistorySchema>;

export type PullRequestActivity = {
  pullRequest: PullRequestRef;
  reviews: z.infer<typeof restReviewSchema>[];
  inlineComments: z.infer<typeof inlineCommentSchema>[];
  issueComments: z.infer<typeof issueCommentSchema>[];
};

export type CliArguments = {
  outputPath: string;
  reviewer: string | undefined;
  repos: string[];
  since: string | undefined;
};

export function parseArguments(args: string[]): CliArguments {
  const usage =
    "Usage: bun gather-review-history.ts <output-json-path> [--reviewer <github-login>] [--repo <owner/name> ...] [--since <ISO-8601 date>]";
  const positional: string[] = [];
  const repos: string[] = [];
  let reviewer: string | undefined;
  let since: string | undefined;

  for (let index = 0; index < args.length; index++) {
    const argument = args[index];
    if (argument === "--reviewer" || argument === "--since" || argument === "--repo") {
      const value = args[index + 1];
      if (value === undefined || value === "" || value.startsWith("--")) {
        throw new Error(usage);
      }
      if (argument === "--reviewer") {
        reviewer = value;
      } else if (argument === "--repo") {
        repos.push(value);
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

  return { outputPath: positional[0], reviewer, repos, since };
}

export function resolveWindowStart(
  generatedAt: string,
  since: string | undefined,
): string {
  const yearAgo = new Date(generatedAt).getTime() - REVIEW_WINDOW_MS;
  const sinceMs = since === undefined ? Number.NEGATIVE_INFINITY : new Date(since).getTime();
  return new Date(Math.max(yearAgo, sinceMs)).toISOString();
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
      await new Promise((resolve) => setTimeout(resolve, delaysMs[attempt] + jitterMs));
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

export function pullRequestRefFromSearchItem(
  item: z.infer<typeof searchItemSchema>,
  reviewer: string,
): PullRequestRef {
  const prefix = "https://api.github.com/repos/";
  if (!item.repository_url.startsWith(prefix)) {
    throw new Error(
      `Unexpected repository URL: ${item.repository_url} — only GitHub.com is supported, not GitHub Enterprise hosts`,
    );
  }
  return pullRequestRefSchema.parse({
    repository: item.repository_url.slice(prefix.length),
    number: item.number,
    title: item.title,
    url: item.html_url,
    authoredByReviewer:
      item.user?.login.toLowerCase() === reviewer.toLowerCase(),
  });
}

export function dedupePullRequests(refs: PullRequestRef[]): PullRequestRef[] {
  const byKey = new Map<string, PullRequestRef>();
  for (const ref of refs) {
    byKey.set(`${ref.repository}#${ref.number}`, ref);
  }
  return [...byKey.values()];
}

export function truncateDiffHunk(hunk: string): string {
  const lines = hunk.split("\n");
  if (lines.length <= DIFF_HUNK_MAX_LINES) {
    return hunk;
  }
  return ["… (hunk truncated)", ...lines.slice(-DIFF_HUNK_MAX_LINES)].join("\n");
}

function searchTimestamp(ms: number): string {
  return `${new Date(ms).toISOString().slice(0, 19)}+00:00`;
}

async function searchPage(query: string, page: number, limitations: string[]) {
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
        "sort=updated",
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
    // GitHub timed out the search and returned a partial page; one retry
    // usually completes it.
    result = await fetchPage();
    if (result.incomplete_results) {
      limitations.push(
        `GitHub reported incomplete search results for "${query}" (page ${page}); some pull requests may be missing.`,
      );
    }
  }
  return result;
}

// GitHub search returns at most 1000 results per query, so recursively split
// the updated-time window until every slice fits under the cap.
async function searchSlice(
  baseQuery: string,
  reviewer: string,
  startMs: number,
  endMs: number,
  limitations: string[],
): Promise<PullRequestRef[]> {
  const query = `${baseQuery} updated:${searchTimestamp(startMs)}..${searchTimestamp(endMs)}`;
  const first = await searchPage(query, 1, limitations);

  if (
    first.total_count > SEARCH_RESULT_CAP &&
    endMs - startMs >= 2 * MIN_SEARCH_SLICE_MS
  ) {
    const midMs = startMs + Math.floor((endMs - startMs) / 2);
    const left = await searchSlice(baseQuery, reviewer, startMs, midMs, limitations);
    const right = await searchSlice(
      baseQuery,
      reviewer,
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

  const toRef = (item: z.infer<typeof searchItemSchema>) =>
    pullRequestRefFromSearchItem(item, reviewer);
  const refs = first.items.map(toRef);
  const reachable = Math.min(first.total_count, SEARCH_RESULT_CAP);
  const pageCount = Math.ceil(reachable / SEARCH_PAGE_SIZE);
  for (let page = 2; page <= pageCount; page++) {
    const result = await searchPage(query, page, limitations);
    refs.push(...result.items.map(toRef));
  }
  return refs;
}

async function discoverPullRequests(
  reviewer: string,
  repos: string[],
  windowStartMs: number,
  windowEndMs: number,
  limitations: string[],
): Promise<PullRequestRef[]> {
  // Advanced search ANDs repeated repo: qualifiers together, so each repo
  // needs its own query; dedupe reconciles the overlap.
  const repoQualifiers =
    repos.length === 0 ? [""] : repos.map((repo) => ` repo:${repo}`);
  const refs: PullRequestRef[] = [];
  for (const qualifier of ["reviewed-by", "commenter"]) {
    for (const repoQualifier of repoQualifiers) {
      console.error(
        `Searching pull requests (${qualifier}:${reviewer}${repoQualifier})…`,
      );
      refs.push(
        ...(await searchSlice(
          `type:pr ${qualifier}:${reviewer}${repoQualifier}`,
          reviewer,
          windowStartMs,
          windowEndMs,
          limitations,
        )),
      );
    }
  }
  return dedupePullRequests(refs);
}

// Endpoints are fetched sequentially per PR — total concurrency stays at
// FETCH_CONCURRENCY requests — and a failed endpoint costs only its own
// category, recorded as a limitation, not the whole PR.
async function fetchPullRequestActivity(
  ref: PullRequestRef,
  reviewer: string,
  limitations: string[],
): Promise<PullRequestActivity> {
  const reviewerLiteral = JSON.stringify(reviewer);
  const byReviewer = `.[] | select((.user.login // "") == ${reviewerLiteral})`;
  const fetchEndpoint = async <T>(
    label: string,
    endpoint: string,
    schema: z.ZodType<T>,
  ): Promise<T[]> => {
    try {
      const raw = await withRetry(() =>
        runGh(["api", "--paginate", endpoint, "--jq", byReviewer]),
      );
      return parseJsonLines(raw, schema);
    } catch (error) {
      limitations.push(
        `Could not fetch ${label} for ${ref.repository}#${ref.number}: ${
          error instanceof Error ? error.message.split("\n")[0] : error
        }`,
      );
      return [];
    }
  };

  const reviews = await fetchEndpoint(
    "reviews",
    `repos/${ref.repository}/pulls/${ref.number}/reviews?per_page=100`,
    restReviewSchema,
  );
  const inlineComments = await fetchEndpoint(
    "inline comments",
    `repos/${ref.repository}/pulls/${ref.number}/comments?per_page=100`,
    inlineCommentSchema,
  );
  const issueComments = await fetchEndpoint(
    "discussion comments",
    `repos/${ref.repository}/issues/${ref.number}/comments?per_page=100`,
    issueCommentSchema,
  );

  return { pullRequest: ref, reviews, inlineComments, issueComments };
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

export function buildReviewHistory(
  activities: PullRequestActivity[],
  options: {
    reviewer: string;
    scope: string;
    generatedAt: string;
    windowStart: string;
    limitations: string[];
  },
): ReviewHistory {
  const windowStartMs = new Date(options.windowStart).getTime();
  const windowEndMs = new Date(options.generatedAt).getTime();
  const isWithinWindow = (createdAt: string): boolean => {
    const timestamp = new Date(createdAt).getTime();
    return timestamp >= windowStartMs && timestamp <= windowEndMs;
  };

  const items: ReviewHistoryItem[] = [];
  for (const activity of activities) {
    const { pullRequest } = activity;
    const base = {
      repository: pullRequest.repository,
      pullRequestNumber: pullRequest.number,
      pullRequestTitle: pullRequest.title,
      onOwnPullRequest: pullRequest.authoredByReviewer,
    };

    for (const review of activity.reviews) {
      const body = review.body ?? "";
      // A COMMENTED review with no body is just the wrapper GitHub creates
      // around inline comments, which are collected separately.
      if (
        review.state === "PENDING" ||
        review.submitted_at == null ||
        !isWithinWindow(review.submitted_at) ||
        (body.trim() === "" &&
          review.state !== "APPROVED" &&
          review.state !== "CHANGES_REQUESTED")
      ) {
        continue;
      }
      items.push({
        kind: "review_submission",
        ...base,
        body,
        createdAt: review.submitted_at,
        url: review.html_url,
        state: review.state,
      });
    }

    for (const comment of activity.inlineComments) {
      if (!isWithinWindow(comment.created_at)) {
        continue;
      }
      items.push({
        kind: "inline_review_comment",
        ...base,
        body: comment.body,
        createdAt: comment.created_at,
        url: comment.html_url,
        path: comment.path,
        line: comment.line,
        diffHunk: truncateDiffHunk(comment.diff_hunk ?? ""),
        isReply: comment.in_reply_to_id !== undefined,
      });
    }

    for (const comment of activity.issueComments) {
      if (!isWithinWindow(comment.created_at)) {
        continue;
      }
      items.push({
        kind: "pull_request_comment",
        ...base,
        body: comment.body,
        createdAt: comment.created_at,
        url: comment.html_url,
      });
    }
  }

  items.sort(
    (left, right) =>
      right.createdAt.localeCompare(left.createdAt) ||
      left.url.localeCompare(right.url),
  );

  const count = (kind: ReviewHistoryItem["kind"]): number =>
    items.filter((item) => item.kind === kind).length;

  return reviewHistorySchema.parse({
    schemaVersion: 2,
    generatedAt: options.generatedAt,
    reviewer: options.reviewer,
    coverage: {
      scope: options.scope,
      windowStart: options.windowStart,
      windowEnd: options.generatedAt,
      pullRequestsScanned: activities.length,
      pullRequestsAuthoredByReviewer: activities.filter(
        (activity) => activity.pullRequest.authoredByReviewer,
      ).length,
      repositories: new Set(
        activities.map((activity) => activity.pullRequest.repository),
      ).size,
      reviewSubmissions: count("review_submission"),
      inlineReviewComments: count("inline_review_comment"),
      pullRequestComments: count("pull_request_comment"),
      limitations: options.limitations,
    },
    items,
  });
}

async function main(): Promise<void> {
  const {
    outputPath,
    reviewer: requestedReviewer,
    repos,
    since,
  } = parseArguments(process.argv.slice(2));

  await runGh(["auth", "status"]);
  const reviewerEndpoint =
    requestedReviewer === undefined
      ? "user"
      : `users/${encodeURIComponent(requestedReviewer)}`;
  const reviewer = githubUserSchema.parse(
    JSON.parse(await runGh(["api", reviewerEndpoint])),
  ).login;

  const generatedAt = new Date().toISOString();
  const windowStart = resolveWindowStart(generatedAt, since);
  const limitations = [
    "GitHub only returns activity still visible to the authenticated user; deleted comments and inaccessible repositories are absent.",
  ];

  const pullRequests = await discoverPullRequests(
    reviewer,
    repos,
    new Date(windowStart).getTime(),
    new Date(generatedAt).getTime(),
    limitations,
  );
  console.error(
    `Found ${pullRequests.length} pull requests with review activity by ${reviewer}.`,
  );

  let fetched = 0;
  const activities = await mapWithConcurrency(
    pullRequests,
    FETCH_CONCURRENCY,
    async (ref) => {
      try {
        return await fetchPullRequestActivity(ref, reviewer, limitations);
      } finally {
        fetched++;
        if (fetched % 25 === 0 || fetched === pullRequests.length) {
          console.error(`Fetched activity for ${fetched}/${pullRequests.length} pull requests…`);
        }
      }
    },
  );

  const history = buildReviewHistory(activities, {
    reviewer,
    scope: repos.length === 0 ? "all visible repositories" : repos.join(", "),
    generatedAt,
    windowStart,
    limitations,
  });

  await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
  // Recreate rather than overwrite: mode only applies to newly created files.
  await rm(outputPath, { force: true });
  await writeFile(outputPath, `${JSON.stringify(history, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });

  process.stdout.write(
    `${JSON.stringify(
      {
        outputPath,
        reviewer: history.reviewer,
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
