import type {
  ExtensionAPI,
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
  type SelectItem,
  SelectList,
  Text,
  type TUI,
} from "@earendil-works/pi-tui";

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

const BARE_REVIEW_AS_COMMAND = /^\/skill:review-as\s*$/;
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
  private filteredUsers: GitHubRepositoryUser[];
  private selectedIndex = 0;
  private selectList: SelectList;

  constructor(
    private readonly repositoryUsers: RepositoryUsers,
    private readonly tui: TUI,
    private readonly theme: Theme,
    private readonly keybindings: KeybindingsManager,
    private readonly done: (login: string | null) => void,
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
      label: `@${user.login}`,
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
    } else if (this.keybindings.matches(data, "tui.select.confirm")) {
      const selectedUser = this.filteredUsers[this.selectedIndex];
      if (selectedUser) {
        this.done(selectedUser.login);
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
            `Review as someone in ${this.repositoryUsers.repository}`,
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
          "dim",
          "Type to search · ↑↓ navigate · enter select · esc cancel",
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

async function chooseRepositoryUser(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
): Promise<string | null> {
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

  return ctx.ui.custom<string | null>(
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

export default function reviewAsExtension(pi: ExtensionAPI): void {
  pi.on("input", async (event, ctx) => {
    if (
      event.source === "extension" ||
      ctx.mode !== "tui" ||
      !BARE_REVIEW_AS_COMMAND.test(event.text)
    ) {
      return { action: "continue" };
    }

    const login = await chooseRepositoryUser(pi, ctx);
    if (!login) {
      return { action: "handled" };
    }

    return {
      action: "transform",
      text: `${event.text.trim()} ${login}`,
    };
  });
}
