---
name: calldiff
description: Diff call stacks across git commits for agentic code review (22 languages). Run `npx calldiff --help` for usage details.
---

Always invoke calldiff through `npx calldiff`. Do not look for or invoke an installed `calldiff` binary. If npm rejects the repository's package-manager requirement, retry with `npx --force calldiff`.

# calldiff diff

Diff call stacks between two git trees

## Arguments

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `from` | `string` | no | Before ref (default: HEAD) |
| `to` | `string` | no | After ref (default: working tree) |
| `paths` | `array` | no | Limit to these path prefixes |

## Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--entry` | `unknown` |  |  |
| `--file` | `unknown` |  |  |
| `--maxDepth` | `number` | `12` | Max call-tree depth |
| `--locs` | `boolean` | `false` | Show call-site source locations (file:line) |
| `--from` | `string` |  | Left / "before" tree |
| `--to` | `string` |  | Right / "after" tree |

## Examples

```sh
# HEAD vs working tree
npx calldiff diff

# One ref vs working tree
npx calldiff diff main

# Two commits / branches
npx calldiff diff abc123 def456

# Force entrypoints
npx calldiff diff main feature --entry createAgentSession

# File as entrypoint (all exports in that file)
npx calldiff diff main feature --file src/routes.ts
```

> Semantics match git diff: no refs → HEAD vs worktree; one ref → that vs worktree; two refs → compare those trees.

---

# calldiff reach

Find all call paths from an entrypoint to a target symbol

## Arguments

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `ref` | `string` | no | Git ref (default: working tree) |
| `paths` | `array` | no | Limit to these path prefixes |

## Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--entry` | `unknown` |  |  |
| `--file` | `unknown` |  |  |
| `--to` | `string` |  | Target symbol to reach (functionName or ClassName.method) |
| `--maxDepth` | `number` | `12` | Max call-tree depth |
| `--locs` | `boolean` | `false` | Show call-site source locations (file:line) |

## Examples

```sh
# Paths in the working tree
npx calldiff reach --entry runCheckout --to sendEmail

# Paths at a commit, limited to a directory
npx calldiff reach HEAD examples/checkout --entry runCheckout --to sendEmail

# Paths from every export in a file
npx calldiff reach --file packages/api/src/flow.ts --to notify
```

---

# calldiff tree

View a call tree (no diff) for one or more entrypoints

## Arguments

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `ref` | `string` | no | Git ref (default: working tree) |
| `paths` | `array` | no | Limit to these path prefixes |

## Options

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--entry` | `unknown` |  |  |
| `--file` | `unknown` |  |  |
| `--maxDepth` | `number` | `12` | Max call-tree depth |
| `--locs` | `boolean` | `false` | Show call-site source locations (file:line) |

## Examples

```sh
# Tree from working tree
npx calldiff tree --entry createAgentSession

# Tree from a commit
npx calldiff tree HEAD --entry PiService.createAgentSession

# Tree for every export in a file
npx calldiff tree --file packages/api/src/routes.ts
```
