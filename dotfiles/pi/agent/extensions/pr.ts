import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";

type PullRequest = {
  number: number;
  title: string;
  url: string;
  headRefName: string;
  isDraft: boolean;
  updatedAt?: string;
};

type Result<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

const PR_TOKEN_PATTERN = /(^|[\s([{<])\/pr(?=$|[\s.,;:!?)}\]>])/g;
const MAX_PULL_REQUESTS = 100;
const GH_TIMEOUT_MS = 10_000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseJson(output: string): Result<unknown> {
  try {
    return { ok: true, value: JSON.parse(output) };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return { ok: false, error: `failed to parse gh output: ${details}` };
  }
}

function parsePullRequest(value: unknown): PullRequest | undefined {
  if (!isRecord(value)) {
    return undefined;
  }

  const number = value.number;
  const title = value.title;
  const url = value.url;

  if (
    typeof number !== "number" ||
    typeof title !== "string" ||
    typeof url !== "string"
  ) {
    return undefined;
  }

  const headRefName =
    typeof value.headRefName === "string" ? value.headRefName : "";
  const updatedAt =
    typeof value.updatedAt === "string" ? value.updatedAt : undefined;

  return {
    number,
    title,
    url,
    headRefName,
    isDraft: value.isDraft === true,
    updatedAt,
  };
}

function parsePullRequestList(output: string): Result<PullRequest[]> {
  const parsed = parseJson(output);
  if (!parsed.ok) {
    return parsed;
  }

  if (!Array.isArray(parsed.value)) {
    return { ok: false, error: "gh returned a non-array PR list" };
  }

  const pullRequests: PullRequest[] = [];
  for (const item of parsed.value) {
    const pullRequest = parsePullRequest(item);
    if (!pullRequest) {
      return { ok: false, error: "gh returned an unexpected PR shape" };
    }
    pullRequests.push(pullRequest);
  }

  return { ok: true, value: pullRequests };
}

function parseSinglePullRequest(output: string): Result<PullRequest> {
  const parsed = parseJson(output);
  if (!parsed.ok) {
    return parsed;
  }

  const pullRequest = parsePullRequest(parsed.value);
  if (!pullRequest) {
    return { ok: false, error: "gh returned an unexpected PR shape" };
  }

  return { ok: true, value: pullRequest };
}

function ghError(action: string, stderr: string, stdout: string, code: number): string {
  const details = stderr.trim() || stdout.trim() || `exit code ${code}`;
  return `${action}: ${details}`;
}

async function listAuthoredPullRequests(
  pi: ExtensionAPI,
  cwd: string,
): Promise<Result<PullRequest[]>> {
  const result = await pi.exec(
    "gh",
    [
      "pr",
      "list",
      "--author",
      "@me",
      "--state",
      "open",
      "--limit",
      String(MAX_PULL_REQUESTS),
      "--json",
      "number,title,url,headRefName,isDraft,updatedAt",
    ],
    { cwd, timeout: GH_TIMEOUT_MS },
  );

  if (result.code !== 0) {
    return {
      ok: false,
      error: ghError("failed to list your open PRs", result.stderr, result.stdout, result.code),
    };
  }

  return parsePullRequestList(result.stdout);
}

async function resolveCurrentBranchPullRequest(
  pi: ExtensionAPI,
  cwd: string,
): Promise<Result<PullRequest>> {
  const result = await pi.exec(
    "gh",
    [
      "pr",
      "view",
      "--json",
      "number,title,url,headRefName,isDraft,updatedAt",
    ],
    { cwd, timeout: GH_TIMEOUT_MS },
  );

  if (result.code !== 0) {
    return {
      ok: false,
      error: ghError(
        "failed to resolve a PR for the current branch",
        result.stderr,
        result.stdout,
        result.code,
      ),
    };
  }

  return parseSinglePullRequest(result.stdout);
}

function oneLine(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

function truncate(text: string, maxLength: number): string {
  if (text.length <= maxLength) {
    return text;
  }
  return `${text.slice(0, Math.max(0, maxLength - 1))}…`;
}

function formatPullRequestLabel(pullRequest: PullRequest): string {
  const draft = pullRequest.isDraft ? " [draft]" : "";
  const title = truncate(oneLine(pullRequest.title), 90);
  const branch = pullRequest.headRefName
    ? ` (${truncate(pullRequest.headRefName, 40)})`
    : "";
  return `#${pullRequest.number}${draft} ${title}${branch}`;
}

function replacePullRequestToken(text: string, url: string): string {
  PR_TOKEN_PATTERN.lastIndex = 0;
  return text.replace(PR_TOKEN_PATTERN, `$1${url}`);
}

function hasPullRequestToken(text: string): boolean {
  PR_TOKEN_PATTERN.lastIndex = 0;
  return PR_TOKEN_PATTERN.test(text);
}

async function selectAuthoredPullRequest(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
): Promise<PullRequest | undefined> {
  const listed = await listAuthoredPullRequests(pi, ctx.cwd);
  if (!listed.ok) {
    ctx.ui.notify(`/pr: ${listed.error}`, "error");
    return undefined;
  }

  if (listed.value.length === 0) {
    ctx.ui.notify("/pr: no open PRs authored by you in this repository", "info");
    return undefined;
  }

  const labels = listed.value.map(formatPullRequestLabel);
  const selected = await ctx.ui.select("Select an open PR you authored:", labels);
  if (!selected) {
    return undefined;
  }

  const index = labels.indexOf(selected);
  return listed.value[index];
}

async function resolveInlineToken(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  text: string,
): Promise<Result<string>> {
  const resolved = await resolveCurrentBranchPullRequest(pi, ctx.cwd);
  if (!resolved.ok) {
    return resolved;
  }

  return {
    ok: true,
    value: replacePullRequestToken(text, resolved.value.url),
  };
}

export default function (pi: ExtensionAPI): void {
  pi.registerCommand("pr", {
    description:
      "Select one of your open PRs, or use /pr inline for the current branch PR",
    handler: async (args, ctx) => {
      if (args.trim()) {
        const transformed = await resolveInlineToken(pi, ctx, `/pr ${args.trim()}`);
        if (!transformed.ok) {
          ctx.ui.notify(`/pr: ${transformed.error}`, "error");
          return;
        }
        if (!ctx.isIdle()) {
          ctx.ui.notify("Agent is busy. Use /pr inline in your next message.", "warning");
          return;
        }
        pi.sendUserMessage(transformed.value);
        return;
      }

      if (!ctx.hasUI) {
        ctx.ui.notify("/pr picker requires interactive mode", "error");
        return;
      }

      const pullRequest = await selectAuthoredPullRequest(pi, ctx);
      if (!pullRequest) {
        return;
      }

      ctx.ui.setEditorText(pullRequest.url);
      ctx.ui.notify(`Inserted ${formatPullRequestLabel(pullRequest)}`, "info");
    },
  });

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension" || !hasPullRequestToken(event.text)) {
      return { action: "continue" };
    }

    const transformed = await resolveInlineToken(pi, ctx, event.text);
    if (!transformed.ok) {
      ctx.ui.notify(`/pr: ${transformed.error}`, "error");
      return { action: "handled" };
    }

    return { action: "transform", text: transformed.value };
  });
}
