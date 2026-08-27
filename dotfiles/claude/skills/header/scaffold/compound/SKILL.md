---
name: compound
description: Capture session learnings as discoverable memory artifacts in this repo, so future sessions stop repeating the same mistakes. Run at session end, or right after something notable breaks or works.
---

# Compound

Turn what this session learned into committed memory the next session can find.
This is the compounding flywheel: every pitfall captured here is one a future
agent won't re-hit. It lives in the repo (not a personal scratch dir) so it
travels to every machine and teammate.

## When to run

1. **Session end** — as the last step before handing off.
2. **Mid-session** — right after something breaks unexpectedly, a workaround is
   found, the user corrects you, or an approach works notably well.

## Process

### 1. Review the session

Scan for at most a few learnings, by category (filename prefix):

- `feedback_` — a user correction or stated preference.
- `pattern_` — an approach that worked and should be repeated.
- `pitfall_` — something that broke, failed, or wasted time.
- `domain_` — a project fact discovered during the work.

Most sessions yield 0–2. **Do not force it.** Nothing notable → skip to step 4
and record a no-learnings review. The review itself is the work product.

### 2. De-duplicate

Scan `MEMORY.md` for an existing entry on the same topic. If one exists, update
that file instead of creating a near-duplicate.

### 3. Write the memory file(s)

Location: `.claude/memory/` (committed). Filename: `{prefix}_{slug}.md` (lowercase,
underscores). 3–8 line body. Format:

```markdown
---
name: Short imperative name
description: One line for the MEMORY.md index
type: feedback | pattern | pitfall | domain
date: YYYY-MM-DD
---

The learning, stated plainly.

**Context:** when/why it matters.
**Apply when:** the specific condition a future session should recall this under.
```

### 4. Update the index

Add one line to the right section of `.claude/memory/MEMORY.md`:

```
- [{prefix}_{slug}.md]({prefix}_{slug}.md) — one-line actionable description
```

### 5. Mark complete

If the optional /compound commit gate is enabled in
`scripts/pre-commit-gate.sh`, drop the per-commit marker so the next commit is
unblocked:

```bash
touch .claude/.compound_ran
```

Print one line: `Compound: captured N learning(s) — <slugs>`, or
`Compound: reviewed, nothing notable to capture`.

## Rules

- **Max ~3 learnings per session.** Be selective, not exhaustive.
- **Descriptions are actionable** — start with a verb or "Never/Always".
- **Keep `MEMORY.md` scannable** — consolidate related entries before it sprawls.

## Do not capture

- Task status / progress (belongs in your tracker).
- Implementation detail (belongs in code comments or design docs).
- Obvious things already in `CLAUDE.md` / `AGENTS.md`.
- One-off debugging steps that won't recur.
