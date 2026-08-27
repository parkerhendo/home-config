---
name: header
version: 0.41.1
description: "Audit and optimize the AI coding agent's own setup — CLAUDE.md, model choice, dependencies, settings — for prompt-config debt and supply-chain risk, enriched by the latest agentic-coding briefing for your stack. '/header wrapup' (or 'compound') captures the session's learnings into committed .claude/memory/. Public access needs no auth; an API key unlocks custom, codebase-tuned briefings."
when_to_use: "Use to audit and improve the agent's own setup. Triggers: audit, audit my setup or harness, optimize codebase, reduce token cost, supply-chain risk, dependency or model upgrade, CLAUDE.md or prompt debt, add guardrails / a pre-commit gate / test ratchet, compounding memory / capture learnings, latest best practices, what's new in agents/MCP/coding tools. Runs on /header or /header-audit. '/header wrapup' (or 'compound') at session end reviews the session and writes its pitfalls/learnings into committed .claude/memory/ — triggers: wrap up, capture learnings, what did we learn, note the pitfalls, remember this for next time. Pass a topic name/UUID/briefing URL to swap the enrichment topic. '/header fable-5' (or 'adopt' / 'opus-4.8') renders the engine-adoption card — a grounded 'should you move your harness to this model?' answer that hands off to header-experiment mine --adopt."
argument-hint: "[topic-name-or-uuid-or-briefing-url]"
allowed-tools: Bash, AskUserQuestion
---

*The `when_to_use`, `argument-hint`, and `allowed-tools` frontmatter fields are honored by Claude Code; other harnesses ignore them safely.*

*Deep / rarely-hit material lives in `reference/*.md` next to this file (loaded on demand, not every run). When a section points at **`reference/X.md`**, read it then — `cat "$(dirname "$HEADER_BIN")/../reference/X.md"` — only when that path actually fires.*

# Header — audit & optimize the coding agent

[Header](https://joinheader.com) is an optimization layer for AI coding agents. Every invocation of this skill runs a **local audit** of your agent harness — `CLAUDE.md`, model choice, dependencies, settings — for prompt-config debt and supply-chain gaps, and **enriches the recommendations** with the latest agentic-coding briefing for the resolved topic. **The audit is always 100% local** — no code, no file contents, no diffs ever leave the machine. Enrichment is your choice: **generic** briefings come from Header's public API (no auth, nothing project-derived egresses); **custom** briefings tune the feed to your stack, which sends a one-line stack summary (e.g. *"Python/FastAPI + React"*) — nothing else — to build the topic (API key; the skill can set up a free anonymous one).

> This skill uses `curl`, so it runs in any agent with shell access (Claude Code, Cursor, Aider, OpenAI Codex CLI, Goose, etc.). Claude Code users may substitute `WebFetch` for the read-only GETs if they prefer.

## Preamble (run first)

Run this block before anything else. **Claude Code substitutes `{SKILL_DIR}`** with the absolute path of the directory containing this `SKILL.md` (the skill's base directory, provided on invocation). Other agents: replace `{SKILL_DIR}` with the path of the folder you loaded this file from. If you cannot determine it, leave the token — the fallback paths handle it.

```bash
# --- Header skill preamble - run before anything else ---
_HC=""
for _d in "{SKILL_DIR}" "$HOME/.claude/skills/header" \
          ".claude/skills/header" "$HOME/.codex/skills/header" \
          ".agents/skills/header"; do
  [ -x "$_d/bin/header-config" ] && { _HC="$_d/bin/header-config"; break; }
done
# Self-heal: a Codex / npx GitHub-download install can copy bin/* without the
# executable bit, so the -x test above misses an otherwise-complete install. If a
# header-config exists but isn't executable, repair the bin dir best-effort.
if [ -z "$_HC" ]; then
  for _d in "{SKILL_DIR}" "$HOME/.claude/skills/header" \
            ".claude/skills/header" "$HOME/.codex/skills/header" \
            ".agents/skills/header"; do
    if [ -f "$_d/bin/header-config" ] && [ ! -x "$_d/bin/header-config" ]; then
      chmod +x "$_d/bin/"* 2>/dev/null || true
      [ -f "$_d/test/run.sh" ] && chmod +x "$_d/test/run.sh" 2>/dev/null || true
      [ -x "$_d/bin/header-config" ] && { _HC="$_d/bin/header-config"; echo "HEADER_SELFHEAL: chmod +x $_d/bin"; break; }
    fi
  done
fi
if [ -z "$_HC" ]; then
  echo "HEADER_INSTALL: missing"
  echo "HEADER_NOTICE: full install required — run: npx skills add Header-inc/Header-skill -g  (or)  curl -fsSL https://raw.githubusercontent.com/Header-inc/Header-skill/main/install.sh | sh"
else
  echo "HEADER_INSTALL: ok"
  echo "HEADER_BIN: $_HC"
  _HH="${HEADER_HOME:-$HOME/.header}"
  mkdir -p "$_HH" 2>/dev/null || true
  # Codex's filesystem sandbox (workspace-write) often excludes ~/.header, so
  # ledger/last-run/config writes fail silently. Probe once and tell the user the
  # remedy instead of letting persistence degrade invisibly. Normal shells: ok.
  if ( : > "$_HH/.writable-probe" ) 2>/dev/null; then
    rm -f "$_HH/.writable-probe" 2>/dev/null || true
    echo "HEADER_STATE: ok"
  else
    echo "HEADER_STATE: readonly"
    echo "HEADER_NOTICE: $_HH is not writable (Codex sandbox?) — ledger, config and run markers won't persist. Fix: add $_HH to the sandbox's writable roots, or set HEADER_HOME to a writable path (e.g. export HEADER_HOME=\"\$PWD/.header\")."
  fi
  if [ -n "${CI:-}" ] || [ -n "${HEADER_NONINTERACTIVE:-}" ]; then
    echo "INTERACTIVE: no"
  else
    echo "INTERACTIVE: yes"
  fi
  _HR="$(dirname "$_HC")/header-repo"
  _TEAM_CFG="$("$_HC" team-path 2>/dev/null || true)"
  _TEAM_TOPIC="$("$_HC" team-get default_topic 2>/dev/null || true)"
  _TEAM_LANG="$("$_HC" team-get language 2>/dev/null || true)"
  _TEAM_STALE="$("$_HC" team-get staleness_days 2>/dev/null || true)"
  echo "TEAM_CONFIG: ${_TEAM_CFG:-none}"
  echo "TEAM_TOPIC: $_TEAM_TOPIC"
  echo "DEFAULT_TOPIC: ${HEADER_DEFAULT_TOPIC:-$("$_HC" get default_topic)}"
  echo "REPO_TOPIC: $("$_HR" get 2>/dev/null || true)"
  echo "LANGUAGE: ${HEADER_LANGUAGE:-${_TEAM_LANG:-$("$_HC" get language)}}"
  echo "STALENESS_DAYS: ${HEADER_STALENESS_DAYS:-${_TEAM_STALE:-$("$_HC" get staleness_days)}}"
  echo "WELCOME_SEEN: $([ -f "$_HH/.welcome-seen" ] && echo yes || echo no)"
  echo "LANGUAGE_PROMPTED: $([ -f "$_HH/.language-prompted" ] && echo yes || echo no)"
  echo "SIGNUP_STATE: $(cat "$_HH/.signup-state" 2>/dev/null || echo unset)"
  echo "TELEMETRY_PROMPTED: $([ -f "$_HH/.telemetry-prompted" ] && echo yes || echo no)"
  echo "TOPIC_OFFERED: $("$_HR" flag topic-offered 2>/dev/null || echo no)"
  echo "SCHEDULE_OFFERED: $("$_HR" flag schedule-offered 2>/dev/null || echo no)"
  echo "TEAM_CONFIG_OFFERED: $("$_HR" flag team-config-offered 2>/dev/null || echo no)"
  echo "AUTOTUNE_OFFERED: $([ -f "$_HH/.autotune-offered" ] && echo yes || echo no)"
  if [ -n "${HEADER_API_KEY:-}" ] || { [ -f "$_HH/credentials" ] && grep -q '^HEADER_API_KEY=' "$_HH/credentials" 2>/dev/null; }; then
    echo "HAS_KEY: yes"
  else
    echo "HAS_KEY: no"
  fi
  _HA="$(dirname "$_HC")/header-auth"
  echo "ACCOUNT: $([ -x "$_HA" ] && "$_HA" state 2>/dev/null || echo none)"
  echo "AUTO_REGISTER: $("$_HC" get auto_register)"
  _EM="$("$_HR" enrich-mode 2>/dev/null || true)"
  [ -n "$_EM" ] || _EM="$("$_HC" get enrich_mode 2>/dev/null || true)"
  echo "ENRICH_MODE: ${_EM:-unset}"
  echo "CLAIM_NUDGED: $([ -f "$_HH/.claim-nudged" ] && echo yes || echo no)"
  _UPD="$("$(dirname "$_HC")/header-update-check" 2>/dev/null || true)"
  case "$_UPD" in UPDATE_*) echo "UPDATE_CHECK: $_UPD" ;; esac
fi
# --- end preamble ---
```

If `HEADER_INSTALL: missing` was echoed, print the `HEADER_NOTICE` line to the user and **stop**. The audit requires `bin/header-audit`; there is no fallback flow. Tell them to re-run after the install completes. (If the preamble echoed `HEADER_SELFHEAL:` it repaired exec bits an installer stripped — e.g. a Codex/`npx skills` GitHub download — and resolved the install automatically; no action needed.)

If `HEADER_STATE: readonly` was echoed, surface the accompanying `HEADER_NOTICE` once and **continue** — the audit still runs. Only local persistence degrades: the recommendation ledger, personal config, onboarding markers, and update snoozes won't be saved. This is common under Codex's `workspace-write` sandbox, which usually excludes `~/.header`; the remedy is to add `~/.header` to the sandbox's writable roots or point `HEADER_HOME` at a writable path.

If `HEADER_INSTALL: ok`, use the echoed values for the rest of the session:

| Echoed line | Use |
|---|---|
| `HEADER_BIN` | Absolute path to `bin/header-config`. Re-substitute it in any later bash call that needs the config CLI — each `Bash` invocation is a fresh shell. |
| `TEAM_CONFIG` | Path to the committed `<repo>/.header/config` (the team layer), or `none`. A path means this repo ships shared Header settings — see `reference/custom-briefings.md` (Team config). |
| `TEAM_TOPIC` | Topic UUID pinned by the committed team config, or empty. When non-empty **and** a key is available it sits above `DEFAULT_TOPIC` but below a personal `REPO_TOPIC` binding in topic resolution. |
| `DEFAULT_TOPIC` | Personal/global topic UUID — env var → `~/.header/config` → empty. Used when no argument, personal binding, or team topic applies. |
| `REPO_TOPIC` | Topic UUID this repository is **personally** bound to (via `header-repo`), or empty. When non-empty **and** a key is available, it wins over `TEAM_TOPIC` and `DEFAULT_TOPIC`. |
| `LANGUAGE` | Render user-facing output in this language. Resolves env → team config → personal config → `English`. |
| `STALENESS_DAYS` | Threshold for the briefing-age check. Resolves env → team config → personal config → `7`. |
| `INTERACTIVE` | `no` → scheduled / non-interactive run: skip every prompt. `yes` → all prompts are eligible. |
| `WELCOME_SEEN` | `no` (with `INTERACTIVE: yes`) → show the first-run welcome before the audit. |
| `LANGUAGE_PROMPTED` | `no` (with `INTERACTIVE: yes` and `LANGUAGE: English`) → show the first-run language prompt. |
| `SIGNUP_STATE` / `HAS_KEY` | Drive the post-audit custom-topic offer — see `reference/topics.md`. |
| `ENRICH_MODE` | `custom` / `generic` / `unset` for this repo (per-repo `header-repo enrich-mode` › global `enrich_mode` default). `unset` (with `INTERACTIVE: yes`, `HAS_KEY: no`, `AUTO_REGISTER` ≠ `false`) → ask the generic-vs-custom enrichment choice — see "Default flow". `generic` → public topics, never register. `custom` → use the repo's bound topic (register/key already resolved). |
| `ACCOUNT` | `none` / `anonymous-unclaimed` / `anonymous-claimed` / `full` (from `header-auth state`). `none` + `HAS_KEY: no` → the enrichment choice may register an anonymous account (new user) or save a pasted key (existing user). Drives the `/header account` view and the claim nudge. |
| `AUTO_REGISTER` | `true` / `false` (config `auto_register`, default `true`). `false` → never offer custom / never register; generic public-topic behavior only. |
| `CLAIM_NUDGED` | `yes` / `no`. `no` (with `ACCOUNT: anonymous-unclaimed`, `INTERACTIVE: yes`, and 3+ applied recs) → make the one-time claim-your-account nudge — see "Claim your account (nudge)". |
| `TELEMETRY_PROMPTED` | `no` (with `INTERACTIVE: yes`, after the post-audit flow resolves) → ask telemetry consent once. |
| `TOPIC_OFFERED` | **Per-repo** flag. `no` (with `INTERACTIVE: yes` and empty `REPO_TOPIC`) → offer to create a custom topic for *this* repo after the audit. Once per repo. |
| `SCHEDULE_OFFERED` | **Per-repo** flag. `no` (with a bound `REPO_TOPIC` not yet on a schedule, `INTERACTIVE: yes`) → make the schedule offer for *this* repo's topic. Once per repo. |
| `TEAM_CONFIG_OFFERED` | **Per-repo** flag. `no` (with `TEAM_CONFIG: none`, a team-shareable topic just created or bound, `INTERACTIVE: yes`) → offer to write and commit `.header/config`. Once per repo. |
| `AUTOTUNE_OFFERED` | Global. `no` (with a key, a custom goal, and 3+ applied recs, `INTERACTIVE: yes`) → make the one-time goal auto-tuning offer. |
| `UPDATE_CHECK` | `UPDATE_AVAILABLE old new` or `UPDATE_REQUIRED old min` → run the update flow (see "Staying up to date"). Absent when up to date, snoozed, or disabled. |

The echoed `DEFAULT_TOPIC` / `LANGUAGE` / `STALENESS_DAYS` already fold in **env var > `~/.header/config` > built-in default** — use them directly rather than re-reading env vars or the config file later.

## Staying up to date

If the preamble emitted an `UPDATE_CHECK` line, **read `reference/update.md` now and follow it** — before onboarding and before the audit (an out-of-date skill may not work against the API). In brief: `UPDATE_REQUIRED` warns plainly (offer the update when interactive; never block a scheduled run); `UPDATE_AVAILABLE` asks once when interactive, honoring `auto_update` and an escalating snooze. No `UPDATE_CHECK` line → skip this section and do not load the reference.

## First-run onboarding

Runs **only with `INTERACTIVE: yes`**, and only after the update check above is resolved. If `WELCOME_SEEN: no` or `LANGUAGE_PROMPTED: no`, **read `reference/onboarding.md` and follow it** (a one-time welcome line, then a one-time output-language choice, each persisted via a marker so it never re-fires). Both markers already seen, or `INTERACTIVE: no` → skip this section and do not load the reference — print nothing, ask nothing.

## Configuration

Configuration resolves in this order, highest priority first: **environment variable › committed team config (`<repo>/.header/config`) › personal config (`~/.header/config`) › built-in default**. None are required to run.

| Variable | Default | Description |
|---|---|---|
| `HEADER_API_KEY` | — | API key (`hdr_sk_...`) for authenticated workflows (custom topics, on-demand generation). |
| `HEADER_LANGUAGE` _(Beta)_ | `English` | Language for output rendering. API content stays English; the agent translates the presentation. |
| `HEADER_DEFAULT_TOPIC` | *(unset → built-in pair)* | A single topic UUID used when no argument, repo binding, or team topic applies. **Unset (the default): both public topics are fetched & merged — `1991163f-…` Self Improving Agent + `bf25c29e-…` Agentic Coding.** Setting it (or `~/.header/config default_topic`) replaces the pair with your one topic. |
| `HEADER_STALENESS_DAYS` | `7` | Maximum briefing age in days before the audit flags the enrichment briefing as stale. |
| `HEADER_TEAM_DIR` | git toplevel, else `$PWD` | Directory whose `.header/config` is read as the team layer. Override mainly for testing. |

## Default flow: audit + enrichment

Every invocation runs this flow. The audit is local and read-only; the briefing is fetched from Header for enrichment.

> **Mode routing:** the audit always runs. A short word at the end of the invocation switches **what gets shown**, not what gets done: `summary` → render only the briefing's `summary` field, no audit output; `sources` → only `source_articles`, no audit output; `add-source <url>` → see `reference/custom-briefings.md` (Add a source); `since-last` → see `reference/custom-briefings.md` (Since-last); `cost` → see `reference/cost.md`. Some arguments are special-cased to a *different* flow, not a display mode:
- `fable-5` (also `fable5`, `claude-fable-5`), `opus-4.8` (also `opus-4-8`), or `adopt` → render the **engine-adoption card** (see `reference/engine-adoption.md`), a self-contained "should you move your harness to this model?" answer — not a topic; bare `adopt` renders the newest snapshot (Fable 5).
- `wrapup` (also `wrap-up`, `wrap`) or `compound` → run the **session wrap-up / compound** flow (see "Session wrap-up & compound (`/header wrapup`, `/header compound`)"): review the session and capture its learnings/pitfalls into committed `.claude/memory/`. This does **not** run the audit — it's the session-end capture ritual. `wrapup` adds a short session recap first; `compound` is capture-only.
- `account` → print this device's Header account status and **stop** (no audit): run `header-auth status` (next to the preamble's `HEADER_BIN`) and relay it — account type, trial, the claim URL to convert an anonymous trial to a full account, and the `header-config set auto_register false` opt-out. This is the manage/claim/delete view for the silently-created account.

Anything else (a topic name/UUID/briefing URL, or no argument) runs the full audit-led flow below.

### First-run enrichment choice

**Fires only when** `ENRICH_MODE: unset` **and** `INTERACTIVE: yes` **and** `HAS_KEY: no` **and** `AUTO_REGISTER` ≠ `false` **and** `REPO_TOPIC`/`TEAM_TOPIC` are empty **and** `SIGNUP_STATE` isn't `public-only`. Otherwise skip this — `ENRICH_MODE: generic` (or no key / opted out) uses the standard Step 0 resolution below; `ENRICH_MODE: custom` resolves the repo's bound topic.

This is the front door for a new repo: ask **generic vs. codebase-tuned** enrichment once, and on custom set up a zero-friction account (anonymous trial for a new user, or the existing user's key) + a repo topic. Because the custom option names the detected stack and the new briefing can't enrich the run that creates it, this branch **runs Step 3 (the audit) first, presents the audit recommendations, and defers the briefing-derived recommendations to a background pass.** **Flow → `reference/topics.md` ("First-run enrichment choice").** Resolve it before continuing; `ENRICH_MODE: generic` falls through to Step 0, `custom` proceeds with the bound topic.

### Step 0 — Resolve the topic

The topic determines which briefing is pulled in for enrichment. Fallback chain (first match wins):

> **Engine-adoption short-circuit:** if the argument is `fable-5` / `fable5` / `claude-fable-5` / `opus-4.8` / `opus-4-8` / `adopt` (or a `<model>-adoption` keyword), this is **not a topic** — render the **engine-adoption card** (see that section) and skip Steps 1–4. The card reads a bundled snapshot + the user's detected engine, not a briefing.

1. **Explicit argument** — if the user passed an identifier:
   - URL containing `/briefings/<uuid>` → extract the UUID, treat as a **briefing ID**, skip Step 1, go straight to Step 2 with `/api/v2/public/briefings/<uuid>`.
   - URL containing `/topics/<uuid>` or a bare UUID → use as the **topic ID** and proceed to Step 1.
   - Anything else → search `/api/v2/topics/public/catalog` for a case-insensitive substring match on `name`. One match → use its `id`; multiple → ask to disambiguate; none → fall through.
2. **Personal binding for this repo** — if `REPO_TOPIC` is non-empty **and** `HAS_KEY: yes`, use it (it wins over `TEAM_TOPIC`). Bound topics are private — use the authenticated endpoints, and run the session-start freshness check (see `reference/custom-briefings.md` (Bound repos)). If `REPO_TOPIC` is set but no key is available, skip and fall through. A `404` means the topic was deleted server-side — offer `header-repo clear` and fall through.
3. **Team topic for this repo** — `TEAM_TOPIC` non-empty (a committed `.header/config`).
   - **With a key** (`HAS_KEY: yes`) → use the authenticated endpoints (same freshness check). On `404`, tell the user to fix `.header/config` (never auto-edit a committed file) and fall through.
   - **Without a key** (`HAS_KEY: no`) → **probe the public endpoint before giving up**: `"<TOPIC>" latest --topic <TEAM_TOPIC> --public`. A team topic whose owner published it is readable with no auth — the common open-source case, where a repo commits `.header/config` so every contributor gets its briefing. Exit `0` → use it, reading the briefing through Step 2's no-key path (`/api/v2/public/briefings/<id>`). Exit `4` (`404` → the topic is private) → *only then* tell the user this repo pins a **private** team topic that needs an API key (offer to sign up), and fall through. **Never announce that a key is required before the public probe has actually failed** — a published team topic needs none.
4. **Resolved default topic** — `DEFAULT_TOPIC` if non-empty. This is an explicit override (env `HEADER_DEFAULT_TOPIC` or `~/.header/config`): a **single** topic that **replaces** the built-in pair below.
5. **Built-in public default — BOTH hardcoded topics (no auth).** When nothing above resolves, always enrich from **both** public topics:
   - `1991163f-be9c-4df2-a33c-046a4d1357e1` — **Self Improving Agent**
   - `bf25c29e-de97-46f2-9c46-47e4e9d75e40` — **Agentic Coding**

   Run Steps 1–2 for **each** id, then **merge** the two briefings for enrichment (see "Merging the default briefings" under Step 2). This is the default for every no-argument, no-key run. (A single topic resolved in 1–4 is unchanged: one briefing, no merge.)

**Claude Code only:** the explicit argument is delivered as `$ARGUMENTS` when invoked via `/header <topic>`. Other harnesses: extract the topic identifier from the user's message text.

### Step 1 — Get the latest briefing ID

*Skip if Step 0 resolved a briefing ID directly.* `<TOPIC>` is `header-topic`, next to `HEADER_BIN`. When Step 0 resolved the **built-in two-topic default**, run this **once per topic id** and keep both `BRIEFING_ID`s.

```bash
"<TOPIC>" latest --topic <topic_id> --public   # prints BRIEFING_ID / GENERATED_AT (+ TOPIC_NAME / GOAL_ID)
```

(For a bound/custom topic with a key, drop `--public` — that's the freshness check in `reference/custom-briefings.md`.)

### Step 2 — Fetch the full briefing

With a key (bound/custom topic): `"<TOPIC>" get <BRIEFING_ID>` returns the briefing as markdown. Public (no key), read the `summary` field from the JSON:

```bash
curl -sS --retry 1 -w "\n%{http_code}" \
  https://joinheader.com/api/v2/public/briefings/<BRIEFING_ID>
```

**The content lives in `summary`** — a markdown doc whose "Key Insights" / bolded developments you cross-reference in Step 4; also pull `source_articles` (title + url). (`key_developments` is typically empty; don't depend on it.)

**Staleness:** compare `GENERATED_AT` (from Step 1) to today. If older than `${HEADER_STALENESS_DAYS:-7}` days, prepend a one-line warning to the audit output. With an API key, suggest re-triggering via `"<TOPIC>" generate <goal_id>`.

**Merging the default briefings (two-topic default only).** When you fetched both public topics, pull `summary` / `source_articles` / `generated_at` from each, then combine: read both `summary` markdowns for developments and concatenate `source_articles`, then **de-duplicate** near-identical items (same headline, or same source URL), keeping one. When the origin matters, label a surfaced item with its topic (*Self Improving Agent* / *Agentic Coding*). Apply the staleness check **per briefing** — warn if **either** is older than `${HEADER_STALENESS_DAYS:-7}` days, naming which. For the `summary` / `sources` output modes on the two-topic default, show **both** (each labeled by topic). A single resolved topic (Steps 1–4) is unchanged: one briefing, no merge.

### Step 3 — Run the audit

Local, read-only — nothing leaves the machine. Run **all nine** scans. `<AUDIT>` is `header-audit`, in the same `bin/` dir as the preamble's `HEADER_BIN`.

```bash
<AUDIT> harness          # CLAUDE.md / AGENTS.md (+ @imports) / settings / hooks / skills / commands / subagents / MCP / Bash posture / model staleness / stale refs
<AUDIT> drift            # INVARIANT COVERAGE: a value pipeline in the SOURCE + whether anything round-trips it; lenient schemas that silently drop unknown keys
<AUDIT> silence          # THE SILENCE AXIS: config vars read but declared nowhere; exception handlers with empty bodies
<AUDIT> deps             # ecosystems / tool versions / install-cooldown gate
<AUDIT> cost             # spend-by-model from your real transcripts → top model-routing candidate
<AUDIT> waste            # usage accounting from the same transcripts: unused MCP servers / skills, tool error rates, compaction pressure, skill context tax
<AUDIT> rails            # determinism guardrails present|absent (pre-commit gate / test ratchet / compounding memory) — opinionated, additive
<AUDIT> retro            # behavioral mining of your own sessions: edit-thrash, gotcha volume, git-workflow tells, ranked capability nudges (worktree / guardrail / compound) — the coach lead
<AUDIT> grade            # TWO setup grades over the 5 axes: 📦 project (checked-in config, the headline) + 💻 local harness (your machine) — composites harness+deps+rails, partitioned by scope; static-config, deterministic
```

**Briefing-supplied patterns (run before `harness`).** The 8 prompt-debt patterns are built in, but the briefing can ship new ones without a skill release. If the fetched briefing names additional cargo-cult / debt phrases (a `debt_patterns` field, or patterns called out in the `summary`), write them to `${HEADER_HOME:-$HOME/.header}/patterns.tsv` *before* running `harness` — one `id<TAB>regex<TAB>why` per line — and the scan picks them up as `HIT`s with your ids. **Proven rows:** when the briefing carries cross-customer evidence for a pattern (a measured effect from the proven-changes library), write a 6-field row instead — `id<TAB>regex<TAB>why<TAB>effect<TAB>n_repos<TAB>ci` — and `harness` re-emits the evidence as a `PROVEN` line (a proven row may reuse a built-in id to attach evidence to it; the scan de-duplicates by id, first wins). Keep regexes conservative (`grep -iE`); malformed lines (not exactly 3 or 6 tab fields, or a non-integer `n_repos`) are skipped. This is how the distribution wedge feeds new hypotheses — and proven library results — into the deterministic scanner.

Capture the scans' output. Every line type it can emit — fields, disposition (`[Apply now]` / `[Apply with review]` / `[Experiment]`), grouping rules, and grade semantics — is documented in **`reference/audit-output.md`**: **read that file before curating findings in Step 4.** Two contracts to honor even before reading it: lines that can become recommendations end with a **`key=<canonical-key>`** field — use it verbatim as the recommendation-ledger key, never invent one (see "Recommendation ledger") — and a `SCAN-DEGRADED` row means that scan could not fully read its input, so its counts are an undercount: say so, and never present a degraded scan as a clean one.

### Step 4 — Cross-reference and present

The audit's findings + the briefing's items become a ranked list — but the **front door is the coach, not the config audit.** Render the default `/header` output as a **coach lead** (this subsection), then the existing scorecard + config recommendations as the **audit tail** below. The session-review feedback was unambiguous: what lands is *behavioral* (what happened, what to learn, what to do differently); what falls flat is config-artifact accounting (line counts, gates, dollar tables). So lead behavioral, demote config.

#### Coach lead — render first, in this fixed order

Built from `<AUDIT> retro` (+ your own session context). Heading: `## 🧭 Header — <repo basename>`. `RETRO-HARNESS` says these read **Claude Code** transcripts — if the preamble's active harness isn't `claude` (e.g. Codex), say the behavioral read is *historical Claude sessions*, not your current harness (Codex coverage ships with the Codex install).

**Proportional to signal — the #1 rule.** A thin window (few sessions, no `RETRO-CAP` fired, clean fails) gets a **short** lead: 2–3 lines total, then hand straight to the audit. **Don't narrate emptiness** — a quiet log earns a quiet lead, not paragraphs explaining why there's little to say. Length tracks signal; when in doubt, cut.

1. **Position — wrapup or setup.** *Wrapup*: substantial work already happened in *this* session (it's in your context) → open with what this session did, and close the lead by offering `/header compound` to capture its learnings. *Setup*: a fresh session → open with the week's pattern from the transcripts. A session with prior tool use is a wrapup. (If `<AUDIT> retro` returned only a `NOTE` — no transcripts for this repo yet — skip the week read; do the session-context parts and say machine-wide history is available via `retro --all-projects`.)

2. **This week, in one read** — open with **one** hook line (never a section): `🧭 <archetype> · <RETRO-PEAK> · <RETRO-SHIP> commits` (archetype = burst vs marathon from the session mix). Then 2–4 plain lines: sessions (`RETRO-WINDOW`), what shipped (`RETRO-SHIP` commits / LOC), what the work was about. No token counts here.

3. **⚠️ Gotchas & pitfalls** — `RETRO-DRIFT` first when present (it is the highest-precision behavioral finding the scan produces, and it is *counted, not inferred*): "`<fileA>` changed <n> times without `<fileB>`, which it otherwise moves with <pct>% of the time" — an invariant the repo never wrote down, and the commits that broke it. Name the two files and the count; the fix is a check that fails when one moves without the other (if `ROUNDTRIP absent` also fired, they are the same bug — surface it **once**, in the ranked list, not twice). Then `RETRO-FAILS` volume + the *actual* failing moments (your own session context for a wrapup; the recent transcript otherwise). Each: what bit, the one-line fix; if the learning is durable, note `/header wrapup` would capture it. `RETRO-FAILS` 0 errors → "clean week," don't invent gotchas to fill the section. `RETRO-CORRECTION` (user redirects) are the strongest `feedback_` candidates — name them and offer `/header wrapup` to capture them. `RETRO-GAP` (fixes claimed with no test run) is its own pitfall — name it and suggest asking for proof or the `precommit-gate` rail (`key=cap-verify`).

4. **🎯 Best practices for you — ranked by `RETRO-CAP`** (emission order = order of demonstrated need; render only the caps that fired). `worktree` → recommend git worktrees, citing the branch-juggling count. `guardrail` → recommend `<AUDIT> rail precommit-gate`, citing the failed-call count (if `RAIL precommit-gate` is already present, **affirm** it, don't re-pitch). `compound` → recommend `/header wrapup` + seeding `.claude/memory/`, citing the gotcha count + absent memory. All `[Apply with review]`; use each `key=cap-<name>` verbatim in the ledger. A weak cap (low count) → rank it low and **say it's weak**; never hard-sell — that anti-upsell discipline is exactly what the Fable-5 card got wrong. Also `RETRO-PLAN`: a low plan-mode rate → nudge plan-first for multi-file / migration work — `RETRO-CORR`, when present, quantifies it (planned vs unplanned error rate).

5. **🧪 Bigger experiments** *(opt-in depth)* — one or two `[Experiment]` items (model routing from `ROUTE-CANDIDATE`, engine adoption), framed "want me to prove it?" Below the practices, never above.

**One register, for everyone.** Plain language, lead with outcomes, no jargon dump. Keep the depth available (counts, ledger keys, experiment specs) but never let it crowd the lead — a line a non-engineer follows *and* an engineer trusts. Don't fork by audience; just be clear.

#### Audit tail — the config scorecard, demoted (still rendered)

After the coach lead, render the **spend + two scorecards (📦 project, 💻 local) + `[Apply now]` / `[Apply with review]` config findings** exactly as the contract below specifies (its heading stays `## 📊 Header audit`). It is the *tail*, not the lead. The RETRO-CAP rail practices already live in the coach lead (step 4) — **don't re-surface them here.** Keep it tight (the ranked-list cap applies). The headline **setup grade** (`header-audit grade`'s `GRADE` line — the **📦 project** grade) answers "how's my setup?" for the repo's checked-in config; the **💻 local harness** grade (`GRADE-LOCAL`) sits beside it for your machine. Spend sits directly below the heading, where the "open with the money" rule applies (not at the top of the report).

**Recent activity (diff-aware):** glance at recently-touched files (`git log --name-only --pretty=format: -15 2>/dev/null | sort -u`) and recent commit subjects (`git log --oneline -15 2>/dev/null`) to **weight audit recommendations** toward areas the user just changed. This is for the audit tail only — the **coach lead's "what shipped" comes from `RETRO-SHIP`** (a windowed count); don't narrate raw commit subjects from this glance up in the coach lead.

**Open with the money — but only spend that matches this repo and harness.** Before leading with any `SPEND` row, run the **scope + harness sanity check**: *does this spend source match the current repo and the current agent harness?* Read it off the markers `<AUDIT> cost` emits:

- **`COST-SCOPE repo`** + `COST-INPUT` → the spend is this repo's own transcripts. Safe to lead with and to turn into a ranked recommendation. (The default; nothing else aggregates silently.)
- **`COST-SCOPE global`** (only ever from an explicit `--all-projects`) → machine-wide spend across *all* projects. Present it as **background context only** — "across all your projects you've spent ~$X" — **never** as a ranked recommendation for *this* repo. Don't promote its `ROUTE-CANDIDATE` to an `[Experiment]`.
- **`COST-HARNESS codex …`** with a **`COST-NOTE harness-mismatch`** → the priced transcripts are *historical Claude Code* usage; the active harness is Codex, so this spend does **not** measure your current engine. Do **not** surface `ROUTE-CANDIDATE` as a model-routing `[Experiment]`. Say instead: *"No Codex cost data available; run a Codex 5.x paired experiment if you want to test model choice."* If you do mention the figures, label them explicitly as historical Claude Code usage only.

When the source *does* match (repo-scoped, harness `claude`), *lead* the scorecard with where the tokens actually go — "this period you spent ~$X; N% of it on `<top model>`" — using the `SPEND-TOTAL` / `SPEND` lines (always surface `header-cost`'s price-source + freshness line and the billing-mode note; see `reference/cost.md`). Then turn the `ROUTE-CANDIDATE` (the costliest model) into the headline **model-routing `[Experiment]`**: "route the low-stakes share of this spend to a cheaper tier — prove it before trusting the saving." This is the on-thesis hypothesis (model migration is the moat's first learning); it's a *candidate to prove*, never a projected saving — drive it with `header-experiment new --kind model-swap` (see `reference/experiments.md`). If `cost` returned only a `NOTE` (no usage history for this repo yet), skip the spend lead and say so in one line — mention `--all-projects` is available for machine-wide spend.

Build the unified list by combining:

- **Audit findings** — every `HIT` (prompt-debt pattern, built-in *or* briefing-supplied; when the pattern id carries a `PROVEN` line, cite the library evidence and skip the local experiment), `FILE` size signal (heavy always-loaded `CLAUDE.md`/`AGENTS.md` — **sum `FILE` + `IMPORT`ed files**, since @imports are loaded every turn too; `NESTED` (subdir CLAUDE.md/AGENTS.md) and `ONDEMAND` (slash-command / subagent bodies) are **not** always-loaded — never add them to the per-turn sum; trim them on their own merits, and read their cheap per-turn cost off the `CONTEXT-TAX registry` row instead), `MODEL` mismatch / `MODEL-STALE` (pinned to a superseded tier → model-migration `[Experiment]`), `MODEL-UPGRADE` (a newer model shipped above the current one, e.g. Fable 5 above Opus 4.8 → offer the **engine-adoption card** (`/header fable-5`, or `/header opus-4.8` for the same-price move) and `header-experiment mine --adopt` to prove it — opportunity, not debt), `SECURITY` posture, `HOOK` (arbitrary shell on agent events — the biggest unguarded execution + supply-chain surface; treat an unexpected/opaque hook command as a security finding), `SKILL` (installed skills are a supply-chain surface — note any carrying `has-bin yes`, à la `/cso`), `STALE-REF` (a referenced path/script or @import that no longer exists), and `GATE absent` from `header-audit`.
- **Consistency findings** — `STALE-REF` lines are the deterministic half: surface each as `[Apply with review]` (fix the reference or delete the dead instruction). The other half is yours to judge — while reading `CLAUDE.md`/`AGENTS.md`, flag **mutually contradictory instructions** the greps can't catch (e.g. "use tabs" *and* "use spaces" for the same files; "always delegate to a subagent" *and* "never spawn subagents"; a rule that names a flag/command the tool no longer has). High-signal, low-risk — usually `[Apply now]` / `[Apply with review]`.
- **Briefing-derived recommendations** — developments in the briefing's `summary` (markdown) that touch the project's stack/tooling (read package manifests, lockfiles, language version files, build/test/CI configs, container/infra definitions, agent/skill definitions, `CLAUDE.md`, README), or that name a pattern the project doesn't yet use (or uses a now-legacy version of). The bias is toward **deletion** and toward changes the briefing endorses on the model currently configured. For a `MODEL-STALE` hit, cross-reference the briefing for the *current* recommended tier — the bin flags that it's stale; the briefing names what to move to.
- **Waste findings** — the highest-trust deterministic wins in the audit, because each is *measured from the user's own sessions* (see "`header-audit waste`"). `MCP-UNUSED` and repo-scope `SKILL-UNUSED` → `[Apply with review]` removals, stating the evidence window ("0 calls across N session files"); an unused MCP server's tool schemas are paid for on **every turn**, so this routinely outweighs any single prompt-debt `HIT`. `ERROR-RATE` rows are investigate-hypotheses (what keeps failing, and why). A non-zero `COMPACTIONS` count alongside a heavy always-loaded `FILE`+`IMPORT` sum is the strongest practical argument for the trim recommendations — name the connection. (The always-loaded `CONTEXT-TAX` rows now come from `harness`, not `waste` — see the scorecard contract for their placement.) Ledger keys are emitted on the rows themselves (`key=waste-mcp-<server>`, `key=waste-skill-<name>`).
- **Determinism-rail findings** — the absent `RAIL` rows (`<AUDIT> rails`, skip `n/a`) become **one** `[Apply with review] (opinionated — Header house guardrail, not measured on your repo)` recommendation, not one per rail: "add the determinism rails — *gate + ratchet + compound*." List the specific keys (`rail-precommit-gate` / `rail-test-ratchet` / `rail-compound-memory`) inside that single entry. Conviction, not an A/B; the new hook/file *is* the diff. (It'll show as a `HOOK` next `harness` scan — that's the rail you added, don't re-flag. See `reference/rails.md`.)
- **Invariant-coverage findings (`<AUDIT> drift`)** — the one axis that grades whether the machinery covers what the *architecture* depends on, rather than whether machinery exists. A repo with no pipeline emits a `NOTE` and nothing else — say nothing. When rows are present:
  - **`ROUNDTRIP absent`** → its **own** `[Apply with review]`, ranked **above** the generic rails entry, and **never folded into** the "add the determinism rails" bundle. A repo can have a gate, a ratchet, and a green suite while silently dropping a field on every release — machinery present, invariant uncovered; that is the distinction this finding exists to draw. Cite the `PIPELINE` rows as evidence ("a field must survive <n> hops; nothing asserts that it does"), and get the artifact from `<AUDIT> rail roundtrip-invariant --ecosystem <eco>` — it prints a stack-adapted round-trip test plus the strict-parsing companion fix. Key: `rail-roundtrip-invariant`.
  - **`SCHEMA-LAX`** → `[Apply now]`, one per file: strict mode is a one-line config change and the diff is the whole effect. This is *why the drift is invisible* — a config authored with a field nobody wired still parses clean, so it looks complete. Pair it with the round-trip entry: the test says *that* something drifted, strict parsing says *what*. Keys: `strict-schema-<file>`.
  - A `RETRO-DRIFT` pair whose files sit in the same pipeline is the **same finding** as `ROUNDTRIP absent`. Surface it **once** — here, using the co-change counts as the evidence — never as two recommendations.
- **Inert machinery (`RAIL-INERT`)** — **rank this at or near the top whenever it fires.** A rail that is *present and cannot fail* is worse than an absent one: it earns credit, it runs on every commit, and it enforces nothing, so the whole team believes they're covered. Say exactly that, name the line (`pytest -q || true`), and make it `[Apply now]` — deleting `|| true` is a one-token diff whose effect is the whole finding. Group `TOOL npm too-old` (the `deps` scan's cooldown gate that is present and silently ignored) into the same entry when both fire: it is the same defect in the supply-chain axis. Keys `inert-<name>`.
- **Silence findings (`<AUDIT> silence`)** — fold `ENV-UNDECLARED` + `SWALLOW` + `SCHEMA-LAX` into **one** entry ("what fails quietly here") rather than scattering them; three related rows in one recommendation land, three separate entries dilute. `ENV-UNDECLARED` is `[Apply now]` (declare the var); `SWALLOW` is `[Apply with review]` (log, re-raise, or return an explicit fallback). A repo with no declaration discipline emits a `NOTE` — say nothing.
- **Known issues** — themes from learnings/post-mortems/runbooks/architecture-decision-records/incident reports + a quick `TODO`/`FIXME`/`HACK` density scan. A recommendation that addresses a known issue jumps the queue.

When a `MODEL` is known, cross-reference its model card / release notes before declaring a prompt-debt `HIT` actionable — confirm the pattern is *still* debt on that model. Prefer briefing sources for the cross-reference; fall back to the web.

**Present** the scorecard, then the ranked recommendation list. The shape below is a **contract, not an illustration** — same blocks, same axes, same order, every run, on every model (placeholders in `<angle brackets>`; everything else verbatim):

```markdown
## 📊 Header audit — <repo basename>

💰 **Spend** (this repo, last <COST-INPUT file count> transcripts — API-rate equivalent): **~$<SPEND-TOTAL usd> / <calls> calls**
- `<model>` — $<usd> (<share>%) ← costliest
- `<model>` — $<usd> (<share>%)

<header-cost's price-source + freshness line>. <billing-mode note: API → real dollars; subscription → usage-limit headroom, the % is identical; unknown → say so>.

### 📦 Project setup — **`<GRADE letter>`**

<one clause: the heaviest project `GRADE-AXIS` deduction, e.g. "supply-chain gate + rails absent"; or "clean, current config" at A/A+>. *Grades the repo's checked-in agent config — reproducible on any machine.*

| Axis | State |
|---|---|
| Model | <repo-pinned `<MODEL>` + the MODEL-UPGRADE / MODEL-STALE note when one fired; or "not pinned — graded under your local harness"> |
| Always-loaded context | <project FILE+IMPORT sum> tokens across <n> files; **repo-scope** skills frontmatter +<`CONTEXT-TAX skills repo` est_tokens> tokens (<count> skills); **repo-scope** command/subagent registry +<`CONTEXT-TAX registry repo` est_tokens> tokens (<count> on-demand files) — the registry tax is the *only* per-turn cost of those files; their bodies (`ONDEMAND`) load on invocation, so never fold them into this sum |
| Security | Bash (repo settings): <allowlist / denylist / bypass / no explicit policy>; hooks: <n configured / none> |
| Deps | <ECOSYSTEM names>; gates: <per non-n/a GATE: name present/absent> |
| Rails | <per non-n/a RAIL: name ✓ present / ✗ absent> |

### 💻 Your local harness — **`<GRADE-LOCAL letter>`**

<one clause: the heaviest `GRADE-AXIS-LOCAL` deduction; or collapse the whole section to one line when clean — see rules>. *Grades your machine (`~/.claude`, the model you run, tool versions) — never moves the project grade.*

| Axis | State |
|---|---|
| Model | <the model you actually run (`~/.claude` / transcript) + the MODEL-STALE note if any; or "—"> |
| Always-loaded context | <`~/.claude/CLAUDE.md` tokens; **user-scope** skills frontmatter +<`CONTEXT-TAX skills user` est_tokens> tokens (<count> skills); **user-scope** command/subagent registry +<`CONTEXT-TAX registry user` est_tokens> tokens> |
| Security | Bash (`~/.claude/settings.json`): <allowlist / denylist / bypass / none> |
| Deps | <package-tool versions: the `TOOL too-old` note, or "current"> |
| Rails | n/a — determinism rails are a repo property |
```

Hard rules:

- **Two grades, explicitly scoped** — the audit grades two distinct things and **must keep them separate**:
  - **📦 Project setup** = the repo's **checked-in** agent config (`CLAUDE.md`, `AGENTS.md`, committed `.claude/settings.json`, `.claude/commands|agents`, `.mcp.json`, editor rules, `.npmrc` gate, determinism rails). Reproducible on any machine, reviewable in a PR. Its `GRADE` letter is **the headline** — the one howsmyaicoding.com shows as "Setup grade B+".
  - **💻 Your local harness** = **your machine**, not committed (`~/.claude/CLAUDE.md` & settings, the `settings.local.json` override, the model *you* run, package-tool versions). Its `GRADE-LOCAL` letter is machine-dependent by design and **never moves the project grade**.
  - Route fixes by scope: a 📦 project finding → commit/PR; a 💻 local finding → fix your machine. Never imply a local issue is the repo's fault (or vice-versa).
- **Grade letters** — show the **letter only** from `GRADE <letter> <score> 100` (project) and `GRADE-LOCAL <letter> <score> 100` (local). **Drop the numeric `<score>`/100.** **Never** model-assign or recompute either letter — both are deterministic by design. Follow each with one short clause naming the heaviest `GRADE-AXIS` / `GRADE-AXIS-LOCAL` deduction. The breakdown rows are the *why* — surface them only if the user asks "why that grade?". Omit a grade section only if its `GRADE`/`GRADE-LOCAL` row is absent.
- **Collapse a clean local harness** — if `GRADE-LOCAL` is `A`/`A+` **and** every `GRADE-AXIS-LOCAL` deduction is `0`, replace the entire `### 💻 Your local harness` section (heading + table) with a single line: `💻 **Your local harness: <letter>** — no local overrides detected.` Render the full local table only when something there actually deducts. (The 📦 project table always shows all five axes.)
- **Spend block** — only when the scope + harness sanity check above passes (`COST-SCOPE repo` + `COST-HARNESS claude`). Otherwise replace the entire block with the single line that check prescribes (background-only global figure, harness-mismatch wording, or the no-data note) — never render the breakdown.
- **The table is fixed** — exactly these five axes, this order, as a GitHub-flavored markdown table (not a box-drawing table, not prose, not a different row set). An axis with nothing to report reads `—`. **Each cell is one short clause** — no paragraphs; detail belongs in the ranked list, not in the row.
- **Skip `n/a` rows** (gates, rails) everywhere, per the scan contracts.
- A due staleness warning is one line *above* the scorecard heading, nothing more.

Then the recommendations — each entry in exactly this shape, ranked by expected effect (the spend-led model-routing `[Experiment]` leads when the sanity check passed). **Keep the list to ~5 substantive items:** fold related findings into one (all absent rails → one; two weak/low-urgency experiments → **one parked line**, not separate entries). Each entry is **two lines max**:

```markdown
### Ranked recommendations

1. **[<Apply now | Apply with review | Experiment>] <imperative title>** — `<ledger-key>`
   **Where:** <file/manifest + line>. **Why:** <one sentence — the audit line or briefing item, link the source_articles URL>. <**Est:** <concrete expected effect> — OMIT this field entirely when there's no real estimate; never pad with "est."/"directional".>
```

`<ledger-key>` is the finding's emitted `key=` (see "Recommendation ledger") — showing it on every entry is how the user refers to an item and how the next run recognizes it. Sort findings into three buckets — the audit is not just a hypothesis generator, it's also a hypothesis *filter*:

- **`[Apply now]`** — strictly deterministic, low-risk: supply-chain gate, security patches, obvious bug fixes, doc typos. On the user's yes, make the edit (show a diff first; for the gate, write/append the `<AUDIT> gate ...` snippet to `.npmrc`). No verification beyond the diff.
- **`[Apply with review]`** — small-magnitude changes whose effect is observable from the diff alone: deletions of cargo-cult phrases (`as an AI language model`, `take a deep breath`, role puffery), trimming redundant role/persona boilerplate, doc cleanups, minor lint-style edits in CLAUDE.md / AGENTS.md. The user is the verifier — show the diff, get approval, apply. Optionally, run **one sanity replicate** (`header-experiment new --kind ... && header-experiment run <id> --k 1`) to confirm tests still pass; skip the full bootstrap A/B — the diff is the proof.
- **`[Experiment]`** _(beta)_ — only when the payoff is BOTH non-deterministic AND has enough magnitude to justify the experiment's own spend. Model swaps, subagent delegation toggles, fast-mode-instruction toggles, mandatory-skill rules, major framework migrations, behavior rewrites. If the user says "let's test that", **scaffold the spec from the finding payload** with `header-experiment new --kind ...` (see `reference/experiments.md`) — don't make the user retype what the audit already told us. The standard ledger dispositions apply per finding: `dismissed` if they reject this specific experiment, `wanted` if they want this one but aren't running it locally right now, `snoozed` for "not now."

**The dividing line between `[Apply with review]` and `[Experiment]` is a *ratio*, not a threshold.** What matters is **experiment cost vs. proven payoff** — and both sides are levers:

- **Magnitude lever** (the "is the change big enough?" side). Use the rough estimator from `header-audit harness` — each `FILE` row prints `<bytes>` and `<est_tokens>`. If the affected lines are **<~5% of the file's bytes** AND the diff is a faithful preview of the effect (a CLAUDE.md deletion: yes, the diff IS the change; a model swap or "always route X through subagent Y" rule: no — diff is one line, effect lives outside it), default to `[Apply with review]`.
- **Experiment-cost lever** (the "can we run it cheaply?" side). Even a tiny-magnitude question is fair game for `[Experiment]` if you make the experiment small:
  - **Cheaper model adapter.** For prefix-only experiments (CLAUDE.md edits, AGENTS.md tweaks), the agent's model isn't what's being tested — the prefix effect transfers across models. Run via Haiku: `--adapter "<wrapper that invokes claude --model claude-haiku-4-5 --print --output-format json>"`. Typically 5-10× cheaper than the user's default Opus.
  - **`--k 1`** when you want a sanity check, not a confidence interval. One replicate proves "this doesn't break," not "this is significantly better." Useful when paired with `[Apply with review]`.
  - **Narrower verify.** `pytest tests/v2/test_just_the_module.py -x -q` instead of the full suite — exercise only what the change can affect.
  - **Shorter task prompts.** A 10-turn focused task on a contained module gives the same statistical surface as a 76-turn coding marathon at ~7× less spend per replicate.

**Decision rule in one sentence:** if the change is small AND the diff is faithful → `[Apply with review]` (don't even run an experiment). If the change is large OR the diff is opaque → `[Experiment]` is warranted; *then* spend on the cost-lever side until the ratio is defensible.

**Quotable principle (don't lose this):** *don't run a $60 experiment to prove a $0.10 effect*. Experiments cost real tokens on API rates or real usage-limit headroom on a Claude subscription — either way, they're not free. Both magnitude and experiment-cost are levers; spend on either side until the ratio works.

**If you re-classify mid-flight, say so.** A finding's disposition (`[Apply now]` / `[Apply with review]` / `[Experiment]`) is a claim to the user. If you announce one and then act under another — e.g. you flagged `[Experiment]`, then on a closer look decide the diff is faithful enough to just apply — **state the change and your reason before you act**, and let the user redirect. Silently applying under a disposition other than the one you announced reads as sleight of hand, even when the new call is correct. The common case: you scope a CLAUDE.md trim as `[Experiment]`, then realize it's small *and* diff-faithful → `[Apply with review]`. Say that out loud; don't just quietly apply it.

**The apply menu.** After presenting, ask which recommendations (if any) to implement — one question, asked **alone**:

- **Claude Code:** a single `AskUserQuestion` call containing exactly one question. Never attach a second question to this call — the custom-topic offer, schedule offer, telemetry consent, and language prompt are each their own later step, in their documented order.
  - `question`: "Which recommendations should I implement now?" · `header`: "Apply" · `multiSelect: true`.
  - Options, in rank order, one per recommendation, at most **3** (the tool caps options at 4 and the last slot is reserved): `label` = the recommendation's `<ledger-key>`; `description` = one line — its disposition tag plus what changes where. More than 3 recommendations → say in the question text that the rest can be named via "Other".
  - Final option, always present: `label` "Just the report" · `description` "Change nothing now — everything stays in the ledger and is recognized next run."
  - "Just the report" selected together with recommendations → treat as a mis-tap: apply nothing, re-ask in plain text.
- **Other harnesses:** the same options as a numbered list (no cap); the user replies with numbers (comma-separated for several), or `0` / "none" for just the report.

On selection, implement the chosen recommendations in rank order in the current project. **An unselected option is not a dismissal** — leave it `surfaced`; only an explicit rejection in the user's words earns `dismissed` (see the ledger dispositions below).

**Commit signature.** When you (or the user) commit a fix that came from a recommendation the audit just surfaced, append a trailer to the commit message so the change's provenance is visible in `git log` / `git blame`:

```
Header-Audit-Finding: <ledger-key> — https://joinheader.com
```

Use the same `<ledger-key>` you logged to the recommendation ledger (the emitted `key=` for audit-derived findings, e.g. `gate-npm`, `delete-step-by-step`, `rail-precommit-gate`). Multiple findings landed in one commit → emit multiple `Header-Audit-Finding:` lines, one per key. Skip the trailer when the user is making unrelated commits in the same session; this trailer is for changes that originated from a specific Header audit finding. If the user is committing manually rather than asking you to commit, show them the trailer line and let them decide whether to include it.

**Output format detection** — adjust depth from modifiers in the user's invocation:

| User says | Show |
|---|---|
| "summary", "tl;dr", "short" | Just the briefing `summary`. No audit output. |
| "sources", "links" | Just `source_articles` (title + url). No audit output. |
| _none of the above_ (default) | Full output: scorecard + audit + briefing-enriched recommendations. |

**Output language:** render all user-facing output in `${HEADER_LANGUAGE:-English}`. Translate prose, headings, rationale; keep proper nouns, code identifiers, and URLs verbatim. API content stays English on the wire.

**Caching within a session:** hold the `briefing_id`(s) + `generated_at`(s) + the audit output in conversation context (the two-topic default caches both). On re-invocation in the same session, reuse it unless the user says "refresh", "latest", "new", or "re-audit".

### Recommendation ledger

Record each recommendation's disposition so future runs adapt. Skip when `<HEADER_BIN> get ledger` is `false`. `<LEDGER>` is `header-ledger`, in the same `bin/` dir.

**While surfacing recommendations:**
- **Audit-derived finding → the key is already minted.** Every scan line that can become a recommendation carries a final `key=<canonical-key>` field (`gate-pip`, `rail-precommit-gate`, `delete-step-by-step`, `route-<model>`, `adopt-<model>`, `trim-<file>`, `waste-mcp-<server>`, `stale-ref-<ref>`, `bash-allowlist`, …). **Use it verbatim — never rename, shorten, or re-mint it.** A per-run model-minted key fragments the ledger: the same finding resurfaces under a new name, `status` can't see its history, and dedup silently fails.
- **No audit line (briefing-derived or consistency finding) → mint once, reuse forever.** Before minting, run `<LEDGER> list` and reuse the existing key if any row is the same recommendation in substance (match on meaning, not exact title). Only when none exists, mint `<verb>-<object>` (lowercase, hyphenated, ≤4 words, e.g. `add-agents-md`) and keep that spelling on every re-surfacing.
- `<LEDGER> status <key>` — if `dismissed`, drop it. If `applied`, prefer a follow-up framing over re-recommending.
- `<LEDGER> list --action applied --since-days 30` — recently-adopted keys to proactively follow up on.
- Record each one you surface:

```bash
<LEDGER> record surfaced "<key>" --title "<short title>" --briefing "<briefing_id>" --topic "<topic_id>" --source "<source_url>"
```

**After the user chooses:**

```bash
<LEDGER> record applied   "<key>"    # implemented (or asked you to implement)
<LEDGER> record dismissed "<key>"    # explicitly rejected
<LEDGER> record snoozed   "<key>"    # "not now"
<LEDGER> record wanted    "<key>"    # an [Experiment] the user wants (and isn't running locally via header-experiment)
```

**Reset (start fresh after a finding-shape change).** When a Header update introduces new finding keys or retires old ones (e.g. the `cap-*` / `RETRO-*` coach findings, or the STALE-REF precision pass that orphaned the old false-positive `stale-ref-*` entries), the ledger can carry stale rows. `<LEDGER> reset` **archives** the current `ledger.jsonl` to a timestamped `.bak-*` (never destroys) and starts fresh. Offer it once, optionally — the canonical keys are stable, so this is a cleanup, not a requirement (see "Register — before the audit" for the one-time post-update prompt).

All ledger writes are best-effort, local-only, and never block the audit. They land under `${HEADER_HOME:-$HOME/.header}` (`ledger.jsonl`, `.last-run`, `credentials`, onboarding markers). Under a restrictive filesystem sandbox — notably Codex `workspace-write`, which usually excludes `~/.header` — these writes silently no-op; the preamble's `HEADER_STATE: readonly` line flags this, and the fix is to make `${HEADER_HOME:-$HOME/.header}` writable (add it to the sandbox's writable roots) or set `HEADER_HOME` to a writable path.

### Usage logging (run last in the audit flow)

After the audit + recommendations are delivered, log one usage event. `<TELEMETRY>` is `header-telemetry`, in the same `bin/` dir:

```bash
<TELEMETRY> log skill_run --outcome "<success|error>" --path "audit" --recs-surfaced <N> --recs-applied <N>
date -u +%Y-%m-%dT%H:%M:%SZ > "${HEADER_HOME:-$HOME/.header}/.last-run" 2>/dev/null || true
```

Records nothing unless the user opted into telemetry; only sends usage metadata — never workspace content. Best-effort.

### Fallback

On the built-in two-topic default, if **one** topic 404s, proceed with the other (note the miss in one line). If **both** default topics 404 — or a single resolved default topic does — browse the public catalog and pick a relevant topic:

```bash
curl -sS -w "\n%{http_code}" https://joinheader.com/api/v2/topics/public/catalog
```

## After the audit: customize your topic (existing key)

For a user who **already has a key** (`HAS_KEY: yes`) but no `REPO_TOPIC`/`TEAM_TOPIC` yet: the "First-run enrichment choice" above doesn't fire for them (it gates on `HAS_KEY: no`), so make the offer here. In an interactive run, once per repo, offer to point the briefing at the user's stack (plus the chained bind / schedule / team-config offers). **Flow → `reference/topics.md`.** A **no-key** new repo is handled up front by the first-run choice instead — don't also offer here.

## Claim your account (nudge)

A **one-time** conversion nudge for an **unclaimed anonymous** account — only when `INTERACTIVE: yes`, `ACCOUNT: anonymous-unclaimed`, and `CLAIM_NUDGED: no` (skip for `full` / `anonymous-claimed` / `none`). `<AUTH>` is `header-auth`. Fire it at the **first** of these moments to occur, then `touch "${HEADER_HOME:-$HOME/.header}/.claim-nudged"` so it never repeats:

1. **First-run custom onboarding — at the briefing payoff** (best moment): right after the freshly-created briefing lands and you surface its stack-specific recs. If the briefing won't surface in-session (other harness, or the background poll timed out), do it at topic-creation instead. Wired in `reference/topics.md` (first-run flow, step 2).
2. **Later run — after 3+ applied recs:** `<LEDGER> list --action applied --since-days 90` has ≥3 entries.

Lead with what claiming **keeps**, framed around the briefing they just got (get the link from `"<AUTH>" claim-url` — the `/signup?code=…` URL; empty if already claimed):

> 🔒 Your briefings live in a free anonymous trial, not on your machine. **Claim your account** — ~30 seconds, just sign in, no card — to **keep this briefing and every future one, get back to them anytime, and read them in a clean web UI** instead of the terminal (your API key and topics come with you). Here's your link: `<claim_url>`. Totally optional — the CLI keeps working without it.

## Telemetry consent

Ask **once**, only when `INTERACTIVE: yes`, `TELEMETRY_PROMPTED: no`, and the post-audit flow has resolved (one of: `SIGNUP_STATE` is `done` or `public-only`, OR `TOPIC_OFFERED: yes` for this repo, OR `ENRICH_MODE` is `custom`/`generic` for this repo — the first-run choice was made).

> Help improve the Header skill? It can share **usage only** — which path ran, the outcome, and how many recommendations you applied. **Never** your code, file paths, repo names, or briefing content.
>
> 1. **Share usage** (recommended) — includes a random install id, not tied to your identity
> 2. **Anonymous only** — aggregate counts, no id
> 3. **No thanks**

```bash
<HEADER_BIN> set telemetry full        # "Share usage"   (or: anonymous / off)
touch "${HEADER_HOME:-$HOME/.header}/.telemetry-prompted"
```

Telemetry stays off until the user opts in here; they can change it any time with `header-config set telemetry off|anonymous|full`.

## What the audit scans

`bin/header-audit` is a deterministic, read-only scanner behind the flow above — one subcommand per axis: `harness` (prompt-config debt, model staleness, hooks, Bash posture, context tax) · `deps` (ecosystems + install-cooldown gate) · `cost` / `waste` / `retro` (transcript-mined: measured spend, pay-for-vs-use accounting, behavioral coaching) · `rails` (determinism guardrails + inert machinery) · `drift` (invariant coverage over a detected value pipeline) · `silence` (undeclared config vars, swallowed errors) · `grade` (the two composite setup grades).

The full line-type catalog — every emitted row, its fields, and how to read it — is **`reference/audit-output.md`** (load-on-demand; Step 4 sends you there before curating findings). Cross-cutting contracts: recommendation-capable lines pre-mint their ledger `key=`; `SCAN-DEGRADED` rows mark a scan that could not fully read its input (undercount, never a clean report); `likely-present` statuses are word-match evidence and carry their caveat.

### Record findings

Each finding becomes a ledger entry, as documented in the recommendation ledger above. Telemetry aggregates demand consent-gated — **never** sends code, paths, or line content; only counts and kinds.

## Cost analytics (`header-cost`) — beta

Direct `header-cost` usage — the audit-led spend path already lives in the flow above. **→ `reference/cost.md`.**

## Determinism rails (guardrails) — beta

The constructive *add-a-guardrail* axis (pre-commit gate / test ratchet). Detection runs in `<AUDIT> rails`; the pitch, delivery chooser, and install flow → **`reference/rails.md`.**

## Session wrap-up & compound (`/header wrapup`, `/header compound`)

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

### The flow

The pinned step-by-step flow — recap (`wrapup` only) → review for at most 3 learnings → locate/seed `.claude/memory/MEMORY.md` → de-duplicate → draft in the pinned format → **draft-then-ask** (one `AskUserQuestion`: team / just-me / show-first / skip) → write + index via Bash — is **`reference/wrapup.md`**. **Read that file when either command is invoked and follow it exactly**; never write to `.claude/memory/` without the ask step. When the audit's `compound-memory` rail is `absent`, it points here: recommend `/header wrapup` at session end (no separate skill), seeding the index per the reference.


## Engine-adoption card (`/header fable-5`)

`/header fable-5` / `/header opus-4.8` — the grounded "should you move to this model?" card. **→ `reference/engine-adoption.md`.**

## Experiments (`header-experiment`) — beta

The local A/B engine (`header-experiment`): mine tasks from git history, run model/effort sweeps, prove a change before trusting it. **Full CLI + flow → `reference/experiments.md`.**

## Browse public topics

**→ `reference/custom-briefings.md`.**

## Custom briefings (API key required)

Authenticated workflows: custom topics, sources, schedule, team config. **→ `reference/custom-briefings.md`.**

## Error handling (every Header API call)

Don't auto-retry blindly; inform the user before retrying.

| Condition | Action |
|---|---|
| Network failure / DNS / timeout | `--retry 1` handles transient blips. Second failure → tell the user the API is unreachable, stop. |
| HTTP `429` Too Many Requests | Read `Retry-After`. Wait that many seconds (or 30s if absent), retry once. If still 429, stop. |
| HTTP `4xx` (other) | Surface JSON `detail` or `error.message`. Don't retry. |
| HTTP `5xx` | Retry once after 5s. If it fails again, tell the user. |
| Empty body / malformed JSON | Tell the user; suggest the catalog fallback. |
| Briefing `status: FAILED` | Don't auto-retry. Suggest re-triggering via `POST /api/v2/goals/{goal_id}/briefings`. |

## Response Reference

API response shapes (BriefingResponse, etc.). **→ `reference/custom-briefings.md`.**

