import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  KeybindingsManager,
  Theme,
} from "@earendil-works/pi-coding-agent";
import { BorderedLoader, DynamicBorder } from "@earendil-works/pi-coding-agent";
import {
  type Component,
  type Focusable,
  fuzzyFilter,
  Input,
  Key,
  matchesKey,
  type SelectItem,
  SelectList,
  Text,
  type TUI,
} from "@earendil-works/pi-tui";
import { promises as fs } from "node:fs";
import path from "node:path";

type GitHubRepositoryUser = {
  login: string;
  description: string;
};

type RepositoryUsers = {
  repository: string;
  source: "collaborators" | "contributors";
  users: GitHubRepositoryUser[];
};

type Result<T> = { ok: true; value: T } | { ok: false; error: string };

const REVIEW_AS_SKILL_NAME = "review-as";
const REVIEW_AS_ANCHOR_TYPE = "review-as-anchor";
const GH_TIMEOUT_MS = 30_000;
const MAX_VISIBLE_USERS = 12;

function commandError(
  action: string,
  result: { stderr: string; stdout: string; code: number },
): string {
  const details =
    result.stderr.trim() || result.stdout.trim() || `exit code ${result.code}`;
  return `${action}: ${details}`;
}

function parseRepository(output: string): Result<string> {
  try {
    const value = JSON.parse(output) as { nameWithOwner?: unknown };
    if (
      typeof value.nameWithOwner !== "string" ||
      !/^[^/\s]+\/[^/\s]+$/.test(value.nameWithOwner)
    ) {
      return { ok: false, error: "gh returned an unexpected repository" };
    }
    return { ok: true, value: value.nameWithOwner };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return { ok: false, error: `failed to parse repository: ${details}` };
  }
}

function parseRepositoryUsers(
  output: string,
  source: RepositoryUsers["source"],
): Result<GitHubRepositoryUser[]> {
  const usersByLogin = new Map<string, GitHubRepositoryUser>();

  for (const line of output.split("\n").filter(Boolean)) {
    let value: unknown;
    try {
      value = JSON.parse(line);
    } catch (error) {
      const details = error instanceof Error ? error.message : String(error);
      return { ok: false, error: `failed to parse GitHub users: ${details}` };
    }

    if (value === null || typeof value !== "object" || Array.isArray(value)) {
      return { ok: false, error: "gh returned an unexpected GitHub user" };
    }

    const user = value as Record<string, unknown>;
    if (typeof user.login !== "string" || typeof user.type !== "string") {
      return { ok: false, error: "gh returned an unexpected GitHub user" };
    }
    if (user.type !== "User") {
      continue;
    }

    let description = "repository collaborator";
    if (source === "collaborators" && typeof user.role_name === "string") {
      description = `repository collaborator · ${user.role_name.replaceAll("_", " ")}`;
    } else if (
      source === "contributors" &&
      typeof user.contributions === "number"
    ) {
      const contributionLabel =
        user.contributions === 1 ? "contribution" : "contributions";
      description = `${user.contributions} ${contributionLabel}`;
    }

    usersByLogin.set(user.login.toLowerCase(), {
      login: user.login,
      description,
    });
  }

  return {
    ok: true,
    value: [...usersByLogin.values()].sort((left, right) =>
      left.login.localeCompare(right.login),
    ),
  };
}

async function loadRepositoryUsers(
  pi: ExtensionAPI,
  cwd: string,
  signal: AbortSignal,
): Promise<Result<RepositoryUsers>> {
  const repositoryResult = await pi.exec(
    "gh",
    ["repo", "view", "--json", "nameWithOwner"],
    { cwd, signal, timeout: GH_TIMEOUT_MS },
  );
  if (repositoryResult.code !== 0) {
    return {
      ok: false,
      error: commandError(
        "failed to resolve the GitHub repository",
        repositoryResult,
      ),
    };
  }

  const parsedRepository = parseRepository(repositoryResult.stdout);
  if (!parsedRepository.ok) {
    return parsedRepository;
  }
  const repository = parsedRepository.value;

  const collaboratorsResult = await pi.exec(
    "gh",
    [
      "api",
      "--paginate",
      `repos/${repository}/collaborators?affiliation=all&per_page=100`,
      "--jq",
      ".[] | {login, type, role_name}",
    ],
    { cwd, signal, timeout: GH_TIMEOUT_MS },
  );
  if (collaboratorsResult.code === 0) {
    const users = parseRepositoryUsers(
      collaboratorsResult.stdout,
      "collaborators",
    );
    if (!users.ok) {
      return users;
    }
    return {
      ok: true,
      value: { repository, source: "collaborators", users: users.value },
    };
  }

  const contributorsResult = await pi.exec(
    "gh",
    [
      "api",
      "--paginate",
      `repos/${repository}/contributors?anon=0&per_page=100`,
      "--jq",
      ".[] | {login, type, contributions}",
    ],
    { cwd, signal, timeout: GH_TIMEOUT_MS },
  );
  if (contributorsResult.code !== 0) {
    return {
      ok: false,
      error: commandError(
        "failed to list repository users",
        contributorsResult,
      ),
    };
  }

  const users = parseRepositoryUsers(contributorsResult.stdout, "contributors");
  if (!users.ok) {
    return users;
  }
  return {
    ok: true,
    value: { repository, source: "contributors", users: users.value },
  };
}

class GitHubUserPicker implements Component, Focusable {
  private readonly input = new Input();
  private readonly selectedLogins = new Set<string>();
  private filteredUsers: GitHubRepositoryUser[];
  private selectedIndex = 0;
  private selectList: SelectList;

  constructor(
    private readonly repositoryUsers: RepositoryUsers,
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly done: (logins: string[] | null) => void,
  ) {
    this.filteredUsers = repositoryUsers.users;
    this.selectList = this.createSelectList();
  }

  get focused(): boolean {
    return this.input.focused;
  }

  set focused(value: boolean) {
    this.input.focused = value;
  }

  private createSelectList(): SelectList {
    const items: SelectItem[] = this.filteredUsers.map((user) => ({
      value: user.login,
      label: `${this.selectedLogins.has(user.login) ? "[x]" : "[ ]"} @${user.login}`,
      description: user.description,
    }));

    const selectList = new SelectList(
      items,
      Math.min(Math.max(items.length, 1), MAX_VISIBLE_USERS),
      {
        selectedPrefix: (text) => this.theme.fg("accent", text),
        selectedText: (text) => this.theme.fg("accent", text),
        description: (text) => this.theme.fg("muted", text),
        scrollInfo: (text) => this.theme.fg("dim", text),
        noMatch: () => this.theme.fg("warning", "  No matching GitHub users"),
      },
    );
    selectList.setSelectedIndex(this.selectedIndex);
    return selectList;
  }

  private updateFilter(): void {
    this.filteredUsers = fuzzyFilter(
      this.repositoryUsers.users,
      this.input.getValue(),
      (user) => user.login,
    );
    this.selectedIndex = 0;
    this.selectList = this.createSelectList();
  }

  handleInput(data: string): void {
    if (this.keybindings.matches(data, "tui.select.up")) {
      if (this.filteredUsers.length > 0) {
        this.selectedIndex =
          this.selectedIndex === 0
            ? this.filteredUsers.length - 1
            : this.selectedIndex - 1;
        this.selectList.setSelectedIndex(this.selectedIndex);
      }
    } else if (this.keybindings.matches(data, "tui.select.down")) {
      if (this.filteredUsers.length > 0) {
        this.selectedIndex =
          this.selectedIndex === this.filteredUsers.length - 1
            ? 0
            : this.selectedIndex + 1;
        this.selectList.setSelectedIndex(this.selectedIndex);
      }
    } else if (matchesKey(data, Key.space)) {
      const selectedUser = this.filteredUsers[this.selectedIndex];
      if (selectedUser) {
        if (this.selectedLogins.has(selectedUser.login)) {
          this.selectedLogins.delete(selectedUser.login);
        } else {
          this.selectedLogins.add(selectedUser.login);
        }
        this.selectList = this.createSelectList();
      }
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      if (this.selectedLogins.size > 0) {
        this.done([...this.selectedLogins]);
      } else {
        const selectedUser = this.filteredUsers[this.selectedIndex];
        if (selectedUser) {
          this.done([selectedUser.login]);
        }
      }
    } else if (this.keybindings.matches(data, "tui.select.cancel")) {
      this.done(null);
    } else {
      this.input.handleInput(data);
      this.updateFilter();
    }

    this.tui.requestRender();
  }

  render(width: number): string[] {
    const sourceLabel =
      this.repositoryUsers.source === "collaborators"
        ? "repository collaborators"
        : "repository contributors";
    const components: Component[] = [
      new DynamicBorder((text: string) => this.theme.fg("accent", text)),
      new Text(
        this.theme.fg(
          "accent",
          this.theme.bold(
            `Review as people in ${this.repositoryUsers.repository}`,
          ),
        ),
        1,
        0,
      ),
      new Text(this.theme.fg("muted", `Search ${sourceLabel}:`), 1, 0),
      this.input,
      this.selectList,
      new Text(
        this.theme.fg(
          "muted",
          `${this.selectedLogins.size} reviewer${this.selectedLogins.size === 1 ? "" : "s"} selected`,
        ),
        1,
        0,
      ),
      new Text(
        this.theme.fg(
          "dim",
          "Type to search · ↑↓ navigate · space toggle · enter review · esc cancel",
        ),
        1,
        0,
      ),
      new DynamicBorder((text: string) => this.theme.fg("accent", text)),
    ];

    return components.flatMap((component) => component.render(width));
  }

  invalidate(): void {
    this.input.invalidate();
    this.selectList.invalidate();
  }
}

async function chooseRepositoryUsers(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
): Promise<string[] | null> {
  const repositoryUsers = await ctx.ui.custom<Result<RepositoryUsers> | null>(
    (tui, theme, _keybindings, done) => {
      const loader = new BorderedLoader(tui, theme, "Loading GitHub users…");
      loader.onAbort = () => done(null);

      loadRepositoryUsers(pi, ctx.cwd, loader.signal)
        .then((result) => {
          if (!loader.signal.aborted) {
            done(result);
          }
        })
        .catch((error) => {
          if (!loader.signal.aborted) {
            const details =
              error instanceof Error ? error.message : String(error);
            done({ ok: false, error: details });
          }
        });

      return loader;
    },
  );

  if (!repositoryUsers) {
    return null;
  }
  if (!repositoryUsers.ok) {
    ctx.ui.notify(`/skill:review-as: ${repositoryUsers.error}`, "error");
    return null;
  }
  if (repositoryUsers.value.users.length === 0) {
    ctx.ui.notify(
      `/skill:review-as: no GitHub users found for ${repositoryUsers.value.repository}`,
      "info",
    );
    return null;
  }

  return ctx.ui.custom<string[] | null>(
    (tui, theme, keybindings, done) =>
      new GitHubUserPicker(
        repositoryUsers.value,
        tui,
        theme,
        keybindings,
        done,
      ),
  );
}

function normalizeSkillCommandName(name: string): string {
  return name.startsWith("skill:") ? name.slice("skill:".length) : name;
}

function resolveMaybeRelativePath(filePath: string, cwd: string): string {
  return path.isAbsolute(filePath) ? filePath : path.resolve(cwd, filePath);
}

function stripFrontmatter(content: string): string {
  return content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, "").trim();
}

async function buildReviewAsSkillPrompt(
  pi: ExtensionAPI,
  cwd: string,
  args: string,
): Promise<Result<string>> {
  const skillCommand = pi
    .getCommands()
    .find(
      (command) =>
        command.source === "skill" &&
        normalizeSkillCommandName(command.name) === REVIEW_AS_SKILL_NAME,
    );
  if (!skillCommand) {
    return { ok: false, error: "review-as skill is not available" };
  }

  const skillPath = resolveMaybeRelativePath(skillCommand.sourceInfo.path, cwd);
  const skillBaseDir = path.dirname(skillPath);

  try {
    const content = await fs.readFile(skillPath, "utf8");
    const body = stripFrontmatter(content);
    if (!body) {
      return { ok: false, error: "review-as skill has no instructions" };
    }

    const skillBlock = `<skill name="${REVIEW_AS_SKILL_NAME}" location="${skillPath}">\nReferences are relative to ${skillBaseDir}.\n\n${body}\n</skill>`;
    return {
      ok: true,
      value: args ? `${skillBlock}\n\n${args}` : skillBlock,
    };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return { ok: false, error: `failed to load review-as skill: ${details}` };
  }
}

async function startReviewAsThread(
  pi: ExtensionAPI,
  ctx: ExtensionCommandContext,
): Promise<Result<boolean>> {
  // A new session has no leaf to branch from. The non-context anchor keeps the
  // review prompt in its own empty branch, matching /review.
  if (!ctx.sessionManager.getLeafId()) {
    pi.appendEntry(REVIEW_AS_ANCHOR_TYPE, {
      createdAt: new Date().toISOString(),
    });
  }

  const firstUserMessage = ctx.sessionManager
    .getEntries()
    .find((entry) => entry.type === "message" && entry.message.role === "user");
  if (!firstUserMessage) {
    return { ok: true, value: true };
  }

  try {
    const result = await ctx.navigateTree(firstUserMessage.id, {
      summarize: false,
      label: "review-as",
    });
    if (result.cancelled) {
      return { ok: true, value: false };
    }
    ctx.ui.setEditorText("");
    return { ok: true, value: true };
  } catch (error) {
    const details = error instanceof Error ? error.message : String(error);
    return {
      ok: false,
      error: `failed to start review-as thread: ${details}`,
    };
  }
}

export default function reviewAsExtension(pi: ExtensionAPI): void {
  pi.registerCommand("skill:review-as", {
    description:
      "Review code as selected GitHub users in an empty session branch",
    handler: async (args, ctx) => {
      let skillArgs = args.trim();
      if (!skillArgs && ctx.mode === "tui") {
        const logins = await chooseRepositoryUsers(pi, ctx);
        if (!logins || logins.length === 0) {
          return;
        }
        skillArgs = logins.join(" ");
      }

      const skillPrompt = await buildReviewAsSkillPrompt(
        pi,
        ctx.cwd,
        skillArgs,
      );
      if (!skillPrompt.ok) {
        ctx.ui.notify(`/skill:review-as: ${skillPrompt.error}`, "error");
        return;
      }

      const thread = await startReviewAsThread(pi, ctx);
      if (!thread.ok) {
        ctx.ui.notify(`/skill:review-as: ${thread.error}`, "error");
        return;
      }
      if (!thread.value) {
        ctx.ui.notify("Review-as cancelled", "info");
        return;
      }

      pi.sendUserMessage(skillPrompt.value);
    },
  });
}
