import { describe, expect, it } from "bun:test";

import {
  buildReviewHistory,
  dedupePullRequests,
  parseArguments,
  parseJsonLines,
  pullRequestRefFromSearchItem,
  resolveWindowStart,
  truncateDiffHunk,
  type PullRequestActivity,
} from "./gather-review-history.ts";
import { z } from "zod";

const pullRequest = {
  repository: "mainframecomputer/async",
  number: 12,
  title: "Tighten authentication",
  url: "https://github.com/mainframecomputer/async/pull/12",
  authoredByReviewer: false,
};

const activity: PullRequestActivity = {
  pullRequest,
  reviews: [
    {
      id: 1,
      body: "Please fix the authorization gap.",
      state: "CHANGES_REQUESTED",
      submitted_at: "2026-01-03T00:00:00Z",
      html_url: "https://github.com/mainframecomputer/async/pull/12#pullrequestreview-1",
    },
    {
      id: 2,
      body: "",
      state: "COMMENTED",
      submitted_at: "2026-01-03T01:00:00Z",
      html_url: "https://github.com/mainframecomputer/async/pull/12#pullrequestreview-2",
    },
    {
      id: 3,
      body: "",
      state: "APPROVED",
      submitted_at: "2026-01-03T02:00:00Z",
      html_url: "https://github.com/mainframecomputer/async/pull/12#pullrequestreview-3",
    },
    {
      id: 4,
      body: "Draft thoughts, not submitted.",
      state: "PENDING",
      html_url: "https://github.com/mainframecomputer/async/pull/12#pullrequestreview-4",
    },
  ],
  inlineComments: [
    {
      id: 10,
      body: "This trusts an unverified organization id.",
      created_at: "2026-01-01T00:00:00Z",
      html_url: "https://github.com/mainframecomputer/async/pull/12#discussion_r10",
      path: "src/auth.ts",
      line: 42,
      diff_hunk: "@@ -40,1 +40,3 @@",
    },
  ],
  issueComments: [
    {
      id: 20,
      body: "The threat model needs one more pass.",
      created_at: "2026-01-02T00:00:00Z",
      html_url: "https://github.com/mainframecomputer/async/pull/12#issuecomment-20",
    },
  ],
};

const buildOptions = {
  reviewer: "octocat",
  scope: "all visible repositories",
  generatedAt: "2026-01-04T00:00:00Z",
  windowStart: "2025-01-04T00:00:00.000Z",
  limitations: [],
};

describe("parseArguments", () => {
  it("defaults to the authenticated reviewer, all repositories, and full window", () => {
    expect(parseArguments(["history.json"])).toEqual({
      outputPath: "history.json",
      reviewer: undefined,
      repos: [],
      since: undefined,
    });
  });

  it("accepts reviewer, repeated repos, and a since date in any order", () => {
    expect(
      parseArguments([
        "--since", "2025-06-01",
        "--repo", "acme/tools",
        "history.json",
        "--reviewer", "hubot",
        "--repo", "acme/web",
      ]),
    ).toEqual({
      outputPath: "history.json",
      reviewer: "hubot",
      repos: ["acme/tools", "acme/web"],
      since: "2025-06-01",
    });
  });

  it("rejects a malformed repo", () => {
    expect(() => parseArguments(["history.json", "--repo", "acme"])).toThrow(
      "--repo",
    );
  });

  it("rejects unsupported arguments", () => {
    expect(() => parseArguments(["history.json", "hubot"])).toThrow("Usage:");
    expect(() => parseArguments(["history.json", "--reviewer"])).toThrow("Usage:");
    expect(() => parseArguments(["--reviewer", "hubot"])).toThrow("Usage:");
  });

  it("rejects an unparseable since date", () => {
    expect(() => parseArguments(["history.json", "--since", "not-a-date"])).toThrow(
      "--since",
    );
  });
});

describe("resolveWindowStart", () => {
  it("defaults to the trailing 365 days", () => {
    expect(resolveWindowStart("2026-01-04T00:00:00Z", undefined)).toBe(
      "2025-01-04T00:00:00.000Z",
    );
  });

  it("narrows to --since when it is more recent than a year ago", () => {
    expect(resolveWindowStart("2026-01-04T00:00:00Z", "2025-11-01T00:00:00Z")).toBe(
      "2025-11-01T00:00:00.000Z",
    );
  });

  it("never widens beyond a year even when --since is older", () => {
    expect(resolveWindowStart("2026-01-04T00:00:00Z", "2020-01-01T00:00:00Z")).toBe(
      "2025-01-04T00:00:00.000Z",
    );
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

describe("pullRequestRefFromSearchItem", () => {
  it("derives the repository and marks the reviewer's own pull requests", () => {
    const item = {
      number: 7,
      title: "Add retry",
      html_url: "https://github.com/acme/tools/pull/7",
      repository_url: "https://api.github.com/repos/acme/tools",
      user: { login: "Hubot" },
      pull_request: {},
    };

    expect(pullRequestRefFromSearchItem(item, "octocat")).toEqual({
      repository: "acme/tools",
      number: 7,
      title: "Add retry",
      url: "https://github.com/acme/tools/pull/7",
      authoredByReviewer: false,
    });
    expect(pullRequestRefFromSearchItem(item, "hubot").authoredByReviewer).toBe(
      true,
    );
    expect(
      pullRequestRefFromSearchItem({ ...item, user: null }, "hubot")
        .authoredByReviewer,
    ).toBe(false);
  });
});

describe("dedupePullRequests", () => {
  it("drops duplicates found by both search qualifiers", () => {
    const other = { ...pullRequest, number: 13 };
    expect(dedupePullRequests([pullRequest, other, pullRequest])).toEqual([
      pullRequest,
      other,
    ]);
  });
});

describe("truncateDiffHunk", () => {
  it("keeps short hunks intact", () => {
    expect(truncateDiffHunk("@@ -1 +1 @@\n-a\n+b")).toBe("@@ -1 +1 @@\n-a\n+b");
  });

  it("keeps only the trailing lines of long hunks", () => {
    const lines = Array.from({ length: 40 }, (_, i) => `line ${i}`);
    const truncated = truncateDiffHunk(lines.join("\n"));

    expect(truncated.split("\n")[0]).toBe("… (hunk truncated)");
    expect(truncated.split("\n")).toHaveLength(13);
    expect(truncated.endsWith("line 39")).toBe(true);
  });
});

describe("buildReviewHistory", () => {
  it("normalizes and orders review activity newest-first", () => {
    const history = buildReviewHistory([activity], buildOptions);

    expect(history.coverage).toMatchObject({
      scope: "all visible repositories",
      windowStart: "2025-01-04T00:00:00.000Z",
      windowEnd: "2026-01-04T00:00:00Z",
      pullRequestsScanned: 1,
      pullRequestsAuthoredByReviewer: 0,
      repositories: 1,
      reviewSubmissions: 2,
      inlineReviewComments: 1,
      pullRequestComments: 1,
    });
    expect(history.items.map((item) => item.kind)).toEqual([
      "review_submission",
      "review_submission",
      "pull_request_comment",
      "inline_review_comment",
    ]);
    expect(history.items[0]).toMatchObject({
      repository: "mainframecomputer/async",
      pullRequestNumber: 12,
      onOwnPullRequest: false,
      state: "APPROVED",
    });
  });

  it("marks items on the reviewer's own pull requests", () => {
    const own = structuredClone(activity);
    own.pullRequest.authoredByReviewer = true;

    const history = buildReviewHistory([own], buildOptions);

    expect(history.coverage.pullRequestsAuthoredByReviewer).toBe(1);
    expect(history.items.every((item) => item.onOwnPullRequest)).toBe(true);
  });

  it("drops empty COMMENTED review wrappers but keeps empty approvals", () => {
    const history = buildReviewHistory([activity], buildOptions);
    const states = history.items
      .filter((item) => item.kind === "review_submission")
      .map((item) => item.state);

    expect(states).toEqual(["APPROVED", "CHANGES_REQUESTED"]);
  });

  it("excludes activity outside the window", () => {
    const stale = structuredClone(activity);
    stale.issueComments.push({
      ...stale.issueComments[0],
      id: 21,
      body: "Old feedback",
      created_at: "2025-01-03T23:59:59Z",
    });

    const history = buildReviewHistory([stale], buildOptions);

    expect(history.items.some((item) => item.body === "Old feedback")).toBe(false);
  });

  it("marks thread replies and truncates their hunks", () => {
    const withReply = structuredClone(activity);
    withReply.inlineComments.push({
      ...withReply.inlineComments[0],
      id: 11,
      body: "Still applies after the rebase.",
      in_reply_to_id: 10,
      diff_hunk: Array.from({ length: 40 }, (_, i) => `line ${i}`).join("\n"),
    });

    const history = buildReviewHistory([withReply], buildOptions);
    const reply = history.items.find(
      (item) => item.kind === "inline_review_comment" && item.isReply,
    );

    expect(reply).toBeDefined();
    if (reply?.kind === "inline_review_comment") {
      expect(reply.diffHunk.startsWith("… (hunk truncated)")).toBe(true);
    }
  });

  it("breaks createdAt ties by url so output is deterministic", () => {
    const tied = structuredClone(activity);
    tied.issueComments = [
      {
        id: 22,
        body: "B side of the tie.",
        created_at: "2026-01-02T00:00:00Z",
        html_url: "https://github.com/mainframecomputer/async/pull/12#issuecomment-22",
      },
      {
        id: 21,
        body: "A side of the tie.",
        created_at: "2026-01-02T00:00:00Z",
        html_url: "https://github.com/mainframecomputer/async/pull/12#issuecomment-21",
      },
    ];

    const urls = buildReviewHistory([tied], buildOptions)
      .items.filter((item) => item.kind === "pull_request_comment")
      .map((item) => item.url);

    expect(urls).toEqual([
      "https://github.com/mainframecomputer/async/pull/12#issuecomment-21",
      "https://github.com/mainframecomputer/async/pull/12#issuecomment-22",
    ]);
  });

  it("carries limitations through to coverage", () => {
    const history = buildReviewHistory([activity], {
      ...buildOptions,
      limitations: ["Could not fetch acme/tools#7: HTTP 403"],
    });

    expect(history.coverage.limitations).toContain(
      "Could not fetch acme/tools#7: HTTP 403",
    );
  });
});
