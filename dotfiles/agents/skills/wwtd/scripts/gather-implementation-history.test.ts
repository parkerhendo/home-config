import { describe, expect, it } from "bun:test";
import { z } from "zod";

import {
  authoredPullRequestRefFromSearchItem,
  buildImplementationHistory,
  dedupePullRequests,
  mergeDirectCommits,
  normalizePullRequestEvidence,
  parseArguments,
  parseJsonLines,
  resolveWindowStart,
  type DirectCommit,
  type PullRequestEvidence,
} from "./gather-implementation-history.ts";

const ref = {
  repository: "mainframecomputer/async",
  number: 42,
  title: "Add bounded retries",
  body: "Retry transient transport failures.",
  url: "https://github.com/mainframecomputer/async/pull/42",
  state: "closed" as const,
  createdAt: "2026-01-02T00:00:00Z",
  updatedAt: "2026-01-03T00:00:00Z",
};

const evidence: PullRequestEvidence = {
  ref,
  details: {
    body: "Retry transient transport failures without changing callers.",
    draft: false,
    merged_at: "2026-01-03T00:00:00Z",
    additions: 30,
    deletions: 4,
    changed_files: 2,
    base: { ref: "main" },
    head: { ref: "bounded-retries" },
  },
  detailsComplete: true,
  files: [
    {
      filename: "src/retry-policy.ts",
      status: "modified",
      additions: 20,
      deletions: 4,
      changes: 24,
    },
    {
      filename: "src/retry-policy.test.ts",
      previous_filename: "test/retry-policy.test.ts",
      status: "renamed",
      additions: 10,
      deletions: 0,
      changes: 10,
    },
  ],
  filesComplete: true,
  commits: [
    {
      sha: "abcdef0123456789",
      html_url:
        "https://github.com/mainframecomputer/async/commit/abcdef0123456789",
      author: { login: "octocat" },
      committer: { login: "octocat" },
      commit: {
        message: "Bound retries after transient failures",
        author: {
          name: "Octo Cat",
          email: "octocat@example.com",
          date: "2026-01-02T00:00:00Z",
        },
        committer: {
          name: "Octo Cat",
          email: "octocat@example.com",
          date: "2026-01-02T00:01:00Z",
        },
      },
    },
  ],
  commitsComplete: true,
};

const directCommit = (
  path: string,
  authoredAt = "2026-01-02T00:00:00Z",
): DirectCommit => ({
  repository: "mainframecomputer/async",
  sha: "abcdef0123456789",
  message: "Bound retries after transient failures",
  authoredAt,
  committedAt: "2026-01-02T00:01:00Z",
  authorLogin: "octocat",
  committerLogin: "octocat",
  url: "https://github.com/mainframecomputer/async/commit/abcdef0123456789",
  matchingPaths: [path],
});

const buildOptions = {
  author: "octocat",
  scope: "mainframecomputer/async",
  generatedAt: "2026-01-04T00:00:00Z",
  windowStart: "2025-01-04T00:00:00.000Z",
  targetPaths: ["src/retry-policy.ts"],
  limitations: [],
};

describe("parseArguments", () => {
  it("defaults to the authenticated author and all visible repositories", () => {
    expect(parseArguments(["history.json"])).toEqual({
      outputPath: "history.json",
      author: undefined,
      repos: [],
      paths: [],
      since: undefined,
    });
  });

  it("accepts and deduplicates repositories and paths", () => {
    expect(
      parseArguments([
        "--author",
        "octocat",
        "--repo",
        "acme/tools",
        "--path",
        "src/retry.ts",
        "history.json",
        "--repo",
        "acme/tools",
        "--path",
        "src/retry.ts",
        "--since",
        "2025-06-01",
      ]),
    ).toEqual({
      outputPath: "history.json",
      author: "octocat",
      repos: ["acme/tools"],
      paths: ["src/retry.ts"],
      since: "2025-06-01",
    });
  });

  it("requires a repository for direct path history", () => {
    expect(() =>
      parseArguments(["history.json", "--path", "src/retry.ts"]),
    ).toThrow("--path requires");
  });

  it("rejects malformed repositories, paths, dates, and arguments", () => {
    expect(() =>
      parseArguments(["history.json", "--repo", "acme"]),
    ).toThrow("--repo");
    expect(() =>
      parseArguments(["history.json", "--repo", "acme/tools", "--path", "/tmp/x"]),
    ).toThrow("--path");
    expect(() =>
      parseArguments(["history.json", "--since", "not-a-date"]),
    ).toThrow("--since");
    expect(() => parseArguments(["history.json", "--wat"])).toThrow("Usage:");
  });
});

describe("resolveWindowStart", () => {
  it("defaults to the trailing 30 days", () => {
    expect(resolveWindowStart("2026-01-04T00:00:00Z", undefined)).toBe(
      "2025-12-05T00:00:00.000Z",
    );
  });

  it("narrows but never widens the 30-day window", () => {
    expect(
      resolveWindowStart("2026-01-04T00:00:00Z", "2025-12-20T00:00:00Z"),
    ).toBe("2025-12-20T00:00:00.000Z");
    expect(
      resolveWindowStart("2026-01-04T00:00:00Z", "2025-01-01T00:00:00Z"),
    ).toBe("2025-12-05T00:00:00.000Z");
  });
});

describe("parseJsonLines", () => {
  it("parses one validated object per line", () => {
    const schema = z.object({ value: z.number() });

    expect(parseJsonLines('{"value":1}\n{"value":2}\n', schema)).toEqual([
      { value: 1 },
      { value: 2 },
    ]);
    expect(parseJsonLines("", schema)).toEqual([]);
  });
});

describe("authoredPullRequestRefFromSearchItem", () => {
  it("normalizes a GitHub search result", () => {
    expect(
      authoredPullRequestRefFromSearchItem({
        number: 7,
        title: "Add retry",
        body: null,
        html_url: "https://github.com/acme/tools/pull/7",
        repository_url: "https://api.github.com/repos/acme/tools",
        state: "open",
        created_at: "2026-01-01T00:00:00Z",
        updated_at: "2026-01-02T00:00:00Z",
      }),
    ).toEqual({
      repository: "acme/tools",
      number: 7,
      title: "Add retry",
      body: "",
      url: "https://github.com/acme/tools/pull/7",
      state: "open",
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
    });
  });

  it("rejects GitHub Enterprise repository URLs", () => {
    expect(() =>
      authoredPullRequestRefFromSearchItem({
        number: 7,
        title: "Add retry",
        body: "",
        html_url: "https://github.example.com/acme/tools/pull/7",
        repository_url: "https://github.example.com/api/v3/repos/acme/tools",
        state: "open",
        created_at: "2026-01-01T00:00:00Z",
        updated_at: "2026-01-02T00:00:00Z",
      }),
    ).toThrow("GitHub.com");
  });
});

describe("dedupePullRequests", () => {
  it("drops duplicate repository and number pairs", () => {
    expect(dedupePullRequests([ref, { ...ref }, { ...ref, number: 43 }])).toEqual([
      ref,
      { ...ref, number: 43 },
    ]);
  });
});

describe("normalizePullRequestEvidence", () => {
  it("normalizes details, renamed files, and commit attribution", () => {
    const pullRequest = normalizePullRequestEvidence(evidence);

    expect(pullRequest).toMatchObject({
      repository: "mainframecomputer/async",
      number: 42,
      body: "Retry transient transport failures without changing callers.",
      mergedAt: "2026-01-03T00:00:00Z",
      changedFiles: 2,
      detailsComplete: true,
      filesComplete: true,
      commitsComplete: true,
    });
    expect(pullRequest.files[1]).toMatchObject({
      path: "src/retry-policy.test.ts",
      previousPath: "test/retry-policy.test.ts",
      status: "renamed",
    });
    expect(pullRequest.commits[0]).toMatchObject({
      sha: "abcdef0123456789",
      authorLogin: "octocat",
      authoredAt: "2026-01-02T00:00:00Z",
    });
  });

  it("marks unavailable endpoint data as incomplete", () => {
    const pullRequest = normalizePullRequestEvidence({
      ref,
      details: null,
      detailsComplete: false,
      files: [],
      filesComplete: false,
      commits: [],
      commitsComplete: false,
    });

    expect(pullRequest).toMatchObject({
      body: ref.body,
      draft: null,
      mergedAt: null,
      additions: null,
      detailsComplete: false,
      filesComplete: false,
      commitsComplete: false,
    });
  });
});

describe("mergeDirectCommits", () => {
  it("combines matching paths and orders commits newest-first", () => {
    const oldCommit = {
      ...directCommit("src/old.ts", "2025-12-01T00:00:00Z"),
      sha: "0123456789abcdef",
      url: "https://github.com/mainframecomputer/async/commit/0123456789abcdef",
    };
    const merged = mergeDirectCommits([
      directCommit("src/retry-policy.ts"),
      oldCommit,
      directCommit("src/retry-policy.test.ts"),
    ]);

    expect(merged).toHaveLength(2);
    expect(merged[0].matchingPaths).toEqual([
      "src/retry-policy.test.ts",
      "src/retry-policy.ts",
    ]);
    expect(merged[1].sha).toBe("0123456789abcdef");
  });
});

describe("buildImplementationHistory", () => {
  it("reports coverage and preserves limitations", () => {
    const pullRequest = normalizePullRequestEvidence(evidence);
    const history = buildImplementationHistory(
      [pullRequest],
      [directCommit("src/retry-policy.ts")],
      {
        ...buildOptions,
        limitations: ["One endpoint was incomplete."],
      },
    );

    expect(history.coverage).toEqual({
      scope: "mainframecomputer/async",
      windowStart: "2025-01-04T00:00:00.000Z",
      windowEnd: "2026-01-04T00:00:00Z",
      targetPaths: ["src/retry-policy.ts"],
      pullRequestsFound: 1,
      pullRequestsWithCompleteDetails: 1,
      pullRequestsWithCompleteFiles: 1,
      pullRequestsWithCompleteCommits: 1,
      repositories: 1,
      pullRequestFiles: 2,
      pullRequestCommits: 1,
      directCommits: 1,
      limitations: ["One endpoint was incomplete."],
    });
    expect(history.pullRequests[0].number).toBe(42);
    expect(history.directCommits[0].matchingPaths).toEqual([
      "src/retry-policy.ts",
    ]);
  });

  it("orders pull requests newest-first with deterministic ties", () => {
    const pullRequest = normalizePullRequestEvidence(evidence);
    const newer = {
      ...pullRequest,
      number: 43,
      createdAt: "2026-01-03T00:00:00Z",
      url: "https://github.com/mainframecomputer/async/pull/43",
    };
    const tiedLaterUrl = {
      ...pullRequest,
      number: 44,
      url: "https://github.com/mainframecomputer/async/pull/44",
    };

    const history = buildImplementationHistory(
      [tiedLaterUrl, pullRequest, newer],
      [],
      buildOptions,
    );

    expect(history.pullRequests.map((item) => item.number)).toEqual([43, 42, 44]);
  });
});
