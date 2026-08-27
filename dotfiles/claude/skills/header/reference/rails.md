# Header reference — rails

*Loaded on demand by the Header skill; not part of the always-loaded SKILL.md.*

## Determinism rails (guardrails) — beta

The rest of the audit is **reductive** — it removes prompt-config debt. This is the **constructive** half: it adds *guardrails* that make an AI-written codebase reliable. Driven by `<AUDIT> rails`; surfaced in Step 4 as `[Apply with review] (opinionated)`. Unlike everything else in the skill, these are **conviction, not measurement** — you can't cheaply A/B "should you have a test ratchet" (its value is tail-risk it *prevents*). So present them honestly as Header's house guardrails, not as a proven finding. This is the one part of the audit where we say: take our word for it — it's how we build Header itself.

### Why guardrails (the pitch — lead with this)

A non-deterministic agent **forgets to run things**. Every "always run the tests before committing" line in `CLAUDE.md` is not a rule — it's a *bet that the model complies this turn*, and the odds decay exactly when you need them most (deep in a long session, attention on the bug). No amount of `**IMPORTANT: ALWAYS**` moves that probability to 1; it just costs more tokens to assert harder.

> **A CLAUDE.md instruction lives in the model's *attention* — stochastic, decaying with context. A guardrail lives in the harness's *control flow* — deterministic, constant. Prose asks; a guardrail enforces.**

Promoting a rule from prose to a guardrail is the **one move that's strictly better on both axes Header cares about**: **cheaper** (it leaves the prompt — stops being paid for every turn) *and* **more reliable** (enforced, can't be skipped). So the Header story is **delete *or promote***: dead cargo-cult prose → delete it; prose that encodes a real procedural requirement → promote it to a rail.

**The example to show the user** (prose → guardrail):

```markdown
## Before committing            ← CLAUDE.md: loaded every turn, obeyed *probably*
- Always run black and flake8; fix what they flag.
- Always run the full suite and make sure it passes.
- Never commit with failing or skipped tests.
```

On turn 47 the agent commits without running `black` (the rule is buried), and "make sure it passes" gets satisfied by *deleting the failing test* — prose can't defend against its own misreading. The same rules as `scripts/pre-commit-gate.sh` run deterministically every commit, **block** on failure (the agent is stopped, not reminded), the **ratchet** catches the delete-the-test hack, and the block message says exactly what to run next so the agent self-corrects in-loop. The CLAUDE.md section collapses to one line.

### The three rails (v1)

| Rail | Enforces | When `absent` |
|---|---|---|
| `precommit-gate` | format + lint + test pass before every commit | recommend installing it (bundles the ratchet by default) |
| `test-ratchet` | the agent can't green the suite by deleting / skipping the failing test | if a gate exists but has no ratchet, recommend inserting the block; a fresh `precommit-gate` already includes it |
| `compound-memory` | session learnings get captured (committed `.claude/memory/`) so they stop recurring | recommend the native **`/header wrapup`** capture ritual + seed the index — Header runs the compounding flywheel itself (see "Session wrap-up & compound"), no separate skill to install |

### Delivery: let the user choose (explain the tradeoff)

Both wirings exec the **same** `scripts/pre-commit-gate.sh`, so "both" is one implementation behind two triggers — not double work. They propagate in *opposite* directions, so explain it and let the user pick:

| | Auto-propagates to team on clone | Gates humans + all harnesses | Gates the agent in-loop |
|---|:---:|:---:|:---:|
| **git-native** (`.githooks/` + `git config core.hooksPath .githooks`) | ✗ — each dev runs the `git config` once (a committed `.git/hooks/` is *not* cloned-and-activated) | ✓ | partial |
| **Claude Code PreToolUse** (committed `.claude/settings.json`) | ✓ — every teammate's agent picks it up on clone (modulo Claude Code's hook-trust prompt) | ✗ — Claude Code only | ✓ |
| **both** | ✓ | ✓ | ✓ |

Rule of thumb: solo repo or all-Claude-Code team → PreToolUse alone. Mixed human/agent commits, or multiple harnesses (Codex etc.) → both. Pass the choice to `rail <name> --delivery <git|pretooluse|both>`.

### Not the security risk the audit warns about

The audit flags opaque hooks as the biggest unguarded execution surface (`HOOK` lines). A rail is the **opposite**: committed and reviewable, from this documented template, calling one in-repo script the user can read, with agent-actionable messages. Say this when you recommend it. And note: after the rail is installed, the next `<AUDIT> harness` will list it as a `HOOK` — that's the rail you just added, **not** a new finding; don't re-flag it.

### Install flow

1. Run `<AUDIT> rails`. For each `RAIL absent` (skip `n/a`), check the ledger (`rail-precommit-gate` / `rail-test-ratchet` / `rail-compound-memory`) and drop anything `dismissed`.
2. Present the surviving rails as `[Apply with review] (opinionated)` with the pitch above — comprehensive: offer the full set of missing rails, not just one.
3. On a yes, present the **delivery chooser** (git-native / PreToolUse / both) for gate-based rails, using the `RAIL-ENV git-remote` / `claude` context to recommend a default.
4. Print the artifact: `<AUDIT> rail <name> --ecosystem <RAIL-ENV ecosystem> --delivery <choice>`. **Write the files** it describes (the gate script `chmod +x`, the wiring). For `compound-memory` the only file to seed is `.claude/memory/MEMORY.md` — capture itself runs natively via `/header wrapup` (see "Session wrap-up & compound"); the printer also offers a standalone `/compound` skill for repos whose sessions don't use Header. Stack-adaptation is automatic from `--ecosystem`; if it's `unknown`, fill in the `TODO` checks block from the detected tooling before writing.
5. Record dispositions in the ledger (`applied` / `dismissed` / `snoozed`). On a commit, append the `Header-Audit-Finding: <key>` trailer.


