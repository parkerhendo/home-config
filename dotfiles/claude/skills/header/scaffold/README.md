# Header scaffold — determinism rails

Templates the Header skill installs when the audit (`/header`) finds a missing
**determinism rail** — a guardrail that makes an AI-written codebase reliable by
*enforcing* a rule the agent would otherwise be merely *asked* to follow in
prose.

> **Prose asks. A guardrail enforces.** Every "always run the tests before
> committing" line in `CLAUDE.md` is a bet that a non-deterministic model
> complies — and you pay for it in context tokens every turn whether or not it
> works. Promoting that rule to a guardrail is strictly better on both axes:
> **cheaper** (it leaves the prompt) and **more reliable** (it can't be skipped).

These files are **data**, not run in place. `header-audit rail <name>` reads them,
adapts the stack-specific parts, and prints a ready-to-install artifact.

## The rails

| Rail | What it enforces | Template |
|---|---|---|
| `precommit-gate` | format + lint + test pass before every commit | `pre-commit-gate.sh` + `checks/<eco>.sh` (+ `ratchet.sh` by default) |
| `test-ratchet` | the agent can't green the suite by deleting / skipping the failing test | `ratchet.sh` |
| `compound-memory` | session learnings get captured so they stop recurring | `compound/` |

## Delivery: two trigger surfaces, one script

Both wirings exec the **same** `scripts/pre-commit-gate.sh`, so "both" is not
double work — it's one implementation behind two triggers.

| | Auto-propagates to team on clone | Gates humans + all harnesses | Gates the agent in-loop |
|---|:---:|:---:|:---:|
| **git-native** (`githook-pre-commit` → `.githooks/pre-commit` + `git config core.hooksPath .githooks`) | ✗ — each dev runs the `git config` once | ✓ | partial |
| **Claude Code** (`pretooluse.json` → committed `.claude/settings.json`) | ✓ — modulo Claude Code's hook-trust prompt | ✗ — Claude Code only | ✓ |
| **both** | ✓ | ✓ | ✓ |

Rule of thumb: solo repo or all-Claude-Code team → PreToolUse alone is enough.
Mixed human/agent commits or multiple harnesses → install both.

## Why adding a hook is not the security risk the audit warns about

The audit flags opaque hooks as the biggest unguarded execution surface. A rail
is the opposite: it's committed and reviewable, it comes from this documented
template, it calls one in-repo script you can read, and its messages are written
as agent remediation. (Note: after you install a rail, the next `header-audit
harness` scan will list it as a `HOOK` — that's expected; it's the rail you just
added, not a finding.)

## Files

- `pre-commit-gate.sh` — the shared gate. `#==CHECKS==` / `#==RATCHET==` /
  `#==COMPOUND==` sentinels are filled in by `header-audit rail`.
- `checks/{python,npm,go,cargo,bundler,unknown}.sh` — per-stack staged-file checks.
- `ratchet.sh` — the multi-language test ratchet.
- `githook-pre-commit` — git-native wiring (`HEADER_GATE_FORCE=1`).
- `pretooluse.json` — Claude Code `PreToolUse(Bash)` wiring.
- `compound/SKILL.md`, `compound/MEMORY.md` — the `/compound` skill + a seed index.
