# Global Pi Instructions

## Minimal Change Rule

Make only the smallest change needed for the stated objective.

- Re-read the file before editing. Don't edit from memory or an earlier diff.
- If the user removed something, leave it removed. Ask before reintroducing it.
- No opportunistic cleanup, reformatting, or renaming outside the change.
- When scope is unclear, ask.

## Git Safety Rule

**Do not run any `git` commands unless the user's most recent message contains the literal token `/git`.**

This applies to every form of git interaction, including but not limited to:

- `git add`, `git commit`, `git rm`, `git mv`
- `git checkout`, `git switch`, `git restore`, `git reset`, `git revert`
- `git branch`, `git tag`, `git stash`, `git rebase`, `git merge`, `git cherry-pick`
- `git push`, `git pull`, `git fetch`, `git clone`, `git remote`
- `git clean`, `git gc`, `git reflog expire`, `git filter-branch`, `git worktree`
- `gh pr create|merge|close|edit`, `gh issue create|edit|close`, and any other `gh` subcommand that mutates a repository
- Any wrapper, alias, script, or tool invocation whose purpose is to perform one of the above (e.g. `jj` against a colocated repo, `hub`, `lazygit`, `tig` actions, custom scripts that wrap git)

### Read-only git is fine

Inspection-only commands are always allowed, since they don't change state:

- `git status`, `git diff`, `git log`, `git show`, `git blame`
- `git branch --list`, `git tag --list`, `git remote -v`, `git config --get`
- `git rev-parse`, `git ls-files`, `git ls-tree`, `git for-each-ref`
- `gh pr view|list|diff`, `gh issue view|list`, `gh run view|list`, `gh api` for GETs

If you're unsure whether a command mutates state, treat it as mutating and skip it.

### How to handle a blocked request

If the user asks for work that would normally end in a git action (commit, push, PR, branch creation, etc.) and their message does **not** contain `/git`:

1. Do the non-git work (edit files, run tests, etc.) as normal.
2. At the end, surface the staged-but-uncommitted state and tell the user exactly which git commands you would run.
3. Ask them to re-issue with `/git` (or run the commands themselves) to authorize the git actions.

Do not "sneak" git through pre/post-commit hooks, `npm version`, release scripts, or tool extensions either — if the side effect is a git mutation, it needs `/git`.

### Autoresearch exception

Autoresearch's `log_experiment` tool intentionally performs `git add` / `git commit` / revert as part of its experiment bookkeeping. That is allowed without `/git` because it's a tool-internal mechanism, not a user-facing git workflow. Don't invoke raw `git` commands to substitute for or augment it.

### With `/git`

When `/git` is present, proceed normally and use good judgment: write clear commit messages, prefer small focused commits, don't force-push shared branches without confirming, etc.
