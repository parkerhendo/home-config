# Session wrap-up & compound — the pinned flow

Loaded on demand when `/header wrapup` or `/header compound` is invoked (the trigger + summary live in SKILL.md).

> **Beta — Header's compounding-memory motion, run natively.** Header *does* the
> capture instead of recommending you go install a separate `/compound` skill.
> The canonical process is `scaffold/compound/SKILL.md`; this section is that
> process, executed by the skill. No audit runs in this flow.

**What each is for.**
- **`/header compound`** — *capture only*. Run it anytime: mid-session right after
  something breaks, a workaround lands, the user corrects you, or an approach
  works notably well; or at the end. Straight to capture, no recap.
- **`/header wrapup`** — the **session-end ritual**: a 2–4 line recap of what the
  session actually did, then the same capture. (This is the seed of the fuller
  "coach" retro; today it is recap + capture.)

Both write to the repo's committed `.claude/memory/`, so a captured pitfall is
one a *future* session — yours or a teammate's — won't re-hit. This is the
compounding flywheel, adjacent to Header's own recommendation ledger.

### The flow (pinned)

1. **(`wrapup` only) Recap.** From your own session context, render 2–4 plain-
   language lines: what the user set out to do, what actually shipped/changed,
   and any notable rough patch. Then continue to capture.

2. **Review the session for learnings.** Source is your own conversation context
   — you lived this session. *(Run in a fresh session with no relevant context?
   Fall back to the repo's most recent transcript under
   `~/.claude/projects/<repo-key>/`.)* Pull **at most 3**, each in exactly one
   category (the filename prefix):
   - `feedback_` — a user correction or stated preference.
   - `pattern_` — an approach that worked and should be repeated.
   - `pitfall_` — something that broke, failed, or wasted time.
   - `domain_` — a project fact discovered during the work.
   Most sessions yield **0–2. Do not force it.** Nothing notable → print
   `Compound: reviewed, nothing notable to capture` and stop. The review itself
   is the work product. **Do not capture:** task status/progress, implementation
   detail (→ code comments), anything already in `CLAUDE.md`/`AGENTS.md`, or
   one-off debugging that won't recur.

3. **Locate / seed the store.** Memory lives in `.claude/memory/` (committed). If
   `.claude/memory/MEMORY.md` doesn't exist, seed it first (via Bash) with this
   skeleton — it mirrors `scaffold/compound/MEMORY.md`:
   ```
   # Memory Index

   Committed, compounding memory for this repo. Future sessions read this first.
   Each entry is one file under `.claude/memory/`; `/header compound` adds them.

   ## Feedback
   ## Patterns
   ## Pitfalls
   ## Domain
   ```

4. **De-duplicate.** Read the existing `.claude/memory/MEMORY.md` + entry files.
   A learning on the same topic as an existing entry → **update that file**, don't
   create a near-duplicate.

5. **Draft (don't write yet).** For each kept learning, draft a file at
   `.claude/memory/{prefix}_{slug}.md` (`{slug}` = kebab-case of the topic, e.g.
   `pitfall_git-from-repo-root.md`), 3–8 line body, in this **pinned** format:
   ```markdown
   ---
   name: <short imperative name>
   description: <one actionable line — starts with a verb or Never/Always; becomes the MEMORY.md index line>
   type: feedback | pattern | pitfall | domain
   date: <YYYY-MM-DD, from `date +%F`>
   ---

   <the learning, stated plainly>

   **Context:** <when/why it matters — cite the moment it came from>
   **Apply when:** <the specific condition a future session should recall this under>
   ```

6. **Draft-then-ask** *(locked: always ask before writing — a `header-config`
   "just write, don't ask" opt-in comes later)*. Show a compact summary — one
   bullet per draft, `{prefix}_{slug} — description` — then the line *"These live
   in `.claude/memory/` (committed → teammates read them next session)."* Then
   exactly **one** `AskUserQuestion`:
   - **Question:** "Capture these N learning(s) to `.claude/memory/`?"
   - **Options** (single-select; mark the **team** option *Recommended* when the
     repo has a git remote, else the just-me option):
     1. **Write + stage (team)** — write the files, `git add` them (committed
        memory travels to teammates).
     2. **Write, uncommitted (just me)** — write the files, no `git add`.
     3. **Show me the full files first** — render the full drafts, then re-ask.
     4. **Skip** — don't write; print `Compound: reviewed, chose not to capture`.
   "Skip" ≠ "wrong" — the user may want them local-only, or not now.

7. **Write + index** (Bash — the skill's only write path). For each confirmed
   file: write it, then add its line `- [{prefix}_{slug}.md]({prefix}_{slug}.md) —
   <description>` under the matching `## Section` in `.claude/memory/MEMORY.md`. If
   the user chose **team**, `git add` the written files — do **not** commit unless
   they ask. Close with one line: `Compound: captured N learning(s) — <slugs>`.

### When the audit sends you here

The `compound-memory` rail (when `absent`) points at this flow: the audit
recommends running `/header wrapup` at session end rather than installing a
separate skill. If the user takes it, seed `.claude/memory/MEMORY.md` (step 3) so
the store is ready for the first capture.

