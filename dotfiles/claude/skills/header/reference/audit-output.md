# What the audit scans — the line-type reference

Moved out of SKILL.md (0.41.0): this catalog is needed only when *interpreting* audit output, so it loads on demand — Step 4 of the audit flow says when to read it. `bin/header-audit` is a deterministic, read-only scanner; the flow calls it, and this file documents every line type it emits.


**Canonical ledger keys (`key=`).** Any line that can become a recommendation ends with a final tab field `key=<canonical-key>`, derived deterministically from the line's own fields — `gate-<eco>` on an absent `GATE`, `rail-<name>` on an absent `RAIL`, `delete-<pattern-id>` on a `HIT`, `trim-<file>` on `FILE`/`NESTED`/`ONDEMAND`, `migrate-`/`adopt-<model>` on `MODEL-STALE`/`MODEL-UPGRADE`, `route-<model>` on `ROUTE-CANDIDATE`, `waste-mcp-<server>`/`waste-skill-<name>` on the unused rows, `stale-ref-<ref>`, `bash-allowlist`, `hook-<event>-<cmd>`, `review-skill-<name>`, `error-rate-<tool>`, `skill-context-tax-<scope>` / `registry-context-tax-<scope>` (scope = `repo`|`user`). Evidence/context lines (`IMPORT`, `MODEL`, `SPEND`, `TOOL-USE`, `RAIL-ENV`, present/`n/a` `GATE` and `RAIL` rows, …) carry none. The flow uses an emitted key verbatim as the recommendation-ledger key — see "Recommendation ledger".

### `header-audit harness`

The premise — *"prompts are technical debt too"*: harness instructions are written for a model and a moment, and they rot silently (workarounds for weaknesses newer models fixed, format-nagging, role puffery, all loaded every turn). Output lines (tab-separated):

- `FILE <path> <bytes> <est_tokens>` — every always-loaded harness file found (`CLAUDE.md`, `AGENTS.md`, settings, MCP config, editor rules). `est_tokens` is `bytes/4`. Sum these — that cost is paid on **every turn**.
- `IMPORT <parent> <imported-path>` — an `@import` edge. Claude Code (and AGENTS.md) load an `@path` line's target inline, every turn, so the auditor follows imports and emits the imported file as its own `FILE` row. **Include imported files in the always-loaded sum** — the previous scan undercounted by ignoring them.
- `NESTED <path> <bytes> <est_tokens>` — a subdir `CLAUDE.md`/`AGENTS.md`. Loaded **on demand** when the agent works in that subtree, *not* every turn — so count it apart from the always-loaded total (it still rots; flag debt the same way).
- `ONDEMAND <path> <bytes> <est_tokens>` — a slash-command (`.claude/commands/*.md`) or subagent (`.claude/agents/*.md`). Its **body loads only when the command/agent is invoked**, never every turn — so it is **not** an always-loaded file: never add `<est_tokens>` to the per-turn sum (counting these bodies as always-loaded was a real over-count that could pin the grade to F on a repo with many commands/agents). It is still scanned for prompt-debt `HIT`s and reported for trimming. The genuine per-turn cost of these files is only their registry frontmatter — the `CONTEXT-TAX registry` row.
- `SKILL-TAX <name> <scope> <bytes> <est_tokens>` — one row per installed skill (scope `repo`|`user`); its frontmatter (name + description) is loaded each session, used or not. Names the heavy ones.
- `CONTEXT-TAX <kind> <scope> <count> <bytes> <est_tokens>` — the aggregate always-loaded **frontmatter tax** of on-demand things, split two ways so the two scorecards stay scope-clean: `kind` is `skills` or `registry` (slash-commands + subagents), `scope` is `repo` or `user`. Their **bodies** are on-demand (`ONDEMAND`) — this frontmatter is their *only* per-turn cost. **`repo` scope → the 📦 project context row; `user` scope → the 💻 local context row.** Emitted here in `harness` (static config — shows on a fresh clone, transcript-independent). **Never graded, never folded into the `FILE` per-turn sum.**
- `MODEL <value> <source>` — the model the harness runs, plus where it came from: `project` = pinned in committed `.claude/settings.json` (ships with the repo); `local` = a `settings.local.json` override or the most recent primary model in the user's transcripts (`~/.claude/projects`). So `MODEL` / `MODEL-STALE` / `MODEL-UPGRADE` fire even when nothing is pinned, and `grade` uses the source to put the model axis on the **project** grade (repo-pinned) or the **local** grade (what you run).
- `MODEL-STALE <value> <why>` — the model id names a **superseded tier** (Claude 3.x/2.x/instant; early Opus 4.0/4.1). Pure hypothesis-generation: cross-reference the briefing for the current recommended tier and surface a model-migration `[Experiment]`. Conservative by design — current ids aren't flagged.
- `MODEL-UPGRADE <value> <recommended> <why>` — a newer model has shipped above the current engine, **priced honestly**: pre-4.8 Opus tiers get the *same-price* move (Opus 4.5/4.6/4.7 → Opus 4.8); Opus 4.8 gets the tier above (→ Fable 5, **2× token price** — the `<why>` says so). An **opportunity, not debt** (distinct from `MODEL-STALE`): offer the **engine-adoption card** (`/header fable-5` / `/header opus-4.8`, matching the recommended model) for the grounded case + caveats, then `header-experiment mine --adopt` to prove it on the repo. Conservative — never fires on the top tier (Fable 5) or a superseded tier.
- `HIT <path> <lineno> <pattern_id> <excerpt>` — a known cargo-cult pattern (built-in or briefing-supplied). Run `<AUDIT> patterns` to list the ids and why each is debt.
- `PROVEN <pattern_id> <effect> <n_repos> <ci>` — cross-customer library evidence for a pattern (from a 6-field `patterns.tsv` row). When a `HIT`'s pattern id has a `PROVEN` line, **cite it with the finding** — "proven: median <effect> across <n_repos> repos (CI <ci>)" — and treat the deletion as `[Apply with review]` with the library as the evidence. Don't scaffold a local experiment to re-prove a change the library already measured at scale; that's the whole point of pooling.
- `STALE-REF <path> <lineno> <ref> <why>` — the harness names a path/script or `@import`s a file that **doesn't exist** (moved, renamed, deleted). High-trust, low-risk: fix the reference or delete the dead instruction — usually `[Apply with review]`. (Deterministic and conservative — only path-shaped backtick tokens and unresolved imports; documentation placeholders like `path/to/x` are skipped.)
- `HOOK <event> <command-excerpt> <file>` — a shell command wired to an agent event (`PreToolUse`, `Stop`, …) in Claude Code settings. The **biggest unguarded execution + supply-chain surface**, and one the Bash-posture check is blind to (a hook runs regardless of the Bash allow/deny list). Surface any unexpected or opaque hook command as a security finding; an attacker who can write settings owns the agent.
- `SKILL <name> <path> <has-bin> <scope>` — an installed skill (`scope` = `repo` or `user`). Skills carry their own instructions and, when `has-bin yes`, executable scripts — a supply-chain surface (cf. `/cso`'s skill-supply-chain scan). Header is itself a skill, so this is dogfood-credible. Flag skills you don't recognize, especially user-scope ones with bin scripts.
- `SECURITY bash <level> <file>` (+ `SECURITY-DETAIL allow|deny <pattern>`) — Bash-tool permission posture from Claude Code settings:
  - `bypass` → **no permission gating** (`defaultMode: bypassPermissions`). Highest risk; if the agent can reach any production asset, recommend a command allow-list.
  - `denylist` → blacklist, which is bypassable (an agent can script around a blocked command) — recommend an allow-list.
  - `allowlist` → whitelist-leaning; affirm it, suggest tightening only if gaps.
  - **no `SECURITY` line** → no explicit policy (interactive prompts only). Fine for local dev; recommend an allow-list anywhere the agent reaches production.

Curate the hits — don't surface them blindly. When `MODEL` is known, cross-reference its model card / release notes to confirm the pattern is **still** debt on that model.

**Briefing-supplied patterns.** Beyond the built-ins, `header-audit` appends extra patterns from `${HEADER_HOME:-$HOME/.header}/patterns.tsv` (override with `HEADER_PATTERNS_FILE`): `id<TAB>regex<TAB>why` rows (hypotheses) or `id<TAB>regex<TAB>why<TAB>effect<TAB>n_repos<TAB>ci` rows (**proven** — the cross-customer library has measured the change), `#` comments and blanks ignored, anything that isn't exactly 3 or 6 tab fields skipped, ids de-duplicated (first wins, so built-ins keep their regex). Writing the briefing's named debt patterns there (Step 3) lets new hypotheses ship without a skill release; `<AUDIT> patterns` lists them — annotating proven ids with their library evidence — and notes the source file.

### `header-audit deps`

Output lines:

- `ECOSYSTEM <name> <manifest>` — detected ecosystems (npm is also detected one directory level deep, e.g. `frontend/package.json` in a monorepo).
- `TOOL <name> <version|-> <ok|too-old|absent>` — package-manager version vs. the minimum that honors a cooldown gate (npm ≥ 11.10, pip ≥ 26.1). Emitted only for detected ecosystems.
- `GATE <name> <present|absent|n/a> <path|->` — whether an install-cooldown / `min-release-age` configuration is in place. **`n/a` means the repo doesn't use that ecosystem — skip the row, exactly like the rails scan's `n/a`**; never recommend an npm/pip gate to a repo that installs through neither.

Surface:

- **Supply-chain cooldown.** `GATE npm absent` or `GATE pip absent` (never `n/a`) → recommend a `min-release-age` / `--uploaded-prior-to` gate so freshly-compromised releases (the chalk/debug, eslint-config-prettier class) are blocked until they're caught. This matters most where the install runs with secrets (CI runners). Get the exact snippet:

  ```bash
  <AUDIT> gate npm 7      # prints .npmrc content (min-release-age=7)
  <AUDIT> gate pip 7      # prints pip cooldown guidance (--uploaded-prior-to P7D)
  ```

  `TOOL npm too-old` / `TOOL pip too-old` → the gate is **silently ignored** until the tool is bumped locally **and in CI**.
- **Outdated / vulnerable deps.** Run the ecosystem's own tools (`npm outdated`, `npm audit`, `pip list --outdated`). Security patches → `[Apply now]`. Minor / patch upgrades with clean changelogs → `[Apply with review]` (one sanity replicate if you're nervous). Major upgrades where behavior may shift → `[Experiment]`.

### `header-audit cost`

Makes the audit **cost-aware** — it opens with where the tokens actually go. Defers all pricing to the sibling `header-cost` (single source of truth for the price table, cache-write split, and legacy-Opus handling); this scan just locates usage and reshapes `header-cost report --json` into audit rows.

**Scoped to the current repo by default.** It reads only *this* repo's transcript dir — `$HOME/.claude/projects/<repo-key>`, where `<repo-key>` is the absolute git-root path with every non-alphanumeric char replaced by `-` (Claude Code's own convention; e.g. `/Users/me/forge` → `…/projects/-Users-me-forge`). If that dir doesn't exist it emits a `NOTE` and stops — it **never** silently aggregates every project (that over-attribution is exactly what produced a misleading cross-repo recommendation; HEA-435). `--all-projects` opts into the machine-wide aggregate (clearly labeled `global`); `--input F` prices an explicit usage JSONL; `--since T` scopes the window; `--harness NAME` overrides harness detection. Output lines:

- `COST-SCOPE repo <repo>` — default: spend is this repo's transcripts only.
- `COST-SCOPE global <dir> <n> project dirs` — `--all-projects`: machine-wide aggregate. Background context only, never a per-repo recommendation.
- `COST-SCOPE input <path>` — `--input` was used.
- `COST-INPUT <dir> <n> files` — the repo-scoped transcript dir actually priced.
- `COST-HARNESS <harness> claude-transcripts` — whose usage this is. `header-cost` only parses Claude Code transcripts, so when `<harness>` is `codex` the spend is historical Claude usage, not the active engine.
- `COST-NOTE harness-mismatch <why>` — active harness is Codex over Claude data; downgrade the recommendation (see Step 4).
- `SPEND-TOTAL <usd> <calls> [<since>]` — total measured spend (API rates) over the window.
- `SPEND <model> <calls> <usd> <share_pct>` — one per model, sorted by cost; `share_pct` is its slice of the total.
- `ROUTE-CANDIDATE <model> <usd> <share_pct>` — the costliest model: the headline model-routing experiment candidate.
- `NOTE cost <reason>` — no usage history for this repo, or `header-cost` not found. Degrade gracefully: skip the spend lead, mention it in one line (and that `--all-projects` exists).

**Run the scope + harness sanity check before presenting any spend (Step 4).** Only when `COST-SCOPE` is `repo` and `COST-HARNESS` is `claude` should spend lead the scorecard and `ROUTE-CANDIDATE` become a ranked model-routing `[Experiment]`. A `global` scope or a Codex harness-mismatch is **background only**. When it does lead: surface the breakdown first (with `header-cost`'s price-source/freshness + billing-mode notes — see `reference/cost.md`), then convert `ROUTE-CANDIDATE` into the model-routing `[Experiment]`. It's a **candidate to prove, never a projected saving**: re-rating the same tokens on a cheaper model is a guess; the honest number comes from `header-experiment` (model-swap). This is the audit's most on-thesis upgrade — it grounds the model-migration hypothesis (the moat's first learning) in the user's real money.

### `header-audit waste`

Usage accounting over the same transcripts `cost` prices: what the harness **pays for vs what it uses**. Every row is deterministic evidence from the user's own sessions — no experiment needed, removing dead weight is the cleanest measured win. Scope discipline mirrors `cost` (this repo's transcripts by default; a missing dir is a `NOTE`; `--all-projects` is the explicit global opt-in; `--since T` windows it). Output lines:

- `WASTE-SCOPE` / `WASTE-INPUT` — same semantics as the cost scan's scope rows. Apply the same sanity check before presenting: a `global` scope is background context, never a per-repo recommendation.
- `TOOL-USE <tool> <calls> <errors>` — per-tool usage over the window, sorted by calls.
- `MCP-SERVER <server> <calls> <errors>` — rollup of `mcp__<server>__*` calls per server.
- `MCP-UNUSED <server> <config-file>` — configured in the repo's `.mcp.json`, **zero calls in the window**. Its tool schemas are loaded into context every turn for nothing — surface as `[Apply with review]`: remove the server entry (diff-faithful, trivially reversible). Ledger key `waste-mcp-<server>`.
- `SKILL-USE <name> <n>` / `SKILL-UNUSED <name> <path>` — Skill invocations seen vs **repo-installed** skills never invoked here (`[Apply with review]`, ledger `waste-skill-<name>`). User-scope skills are never flagged unused — they serve other repos — but still appear in the harness `CONTEXT-TAX skills user` row.
- `ERROR-RATE <tool> <errors> <calls> <pct>` — a tool failing ≥20% of ≥10 calls. A hypothesis generator, not a verdict: look at *what* keeps failing (a broken hook, a misconfigured MCP server, a permission gap) and surface the likely fix.
- `COMPACTIONS <n> <files>` — context-pressure signal: the agent ran out of window <n> times across <files> session files.
- `SCAN-DEGRADED waste <detail>` — tool_use blocks the parser could not read (a transcript-format change). **The counts above are an undercount — never present them as evidence of low usage**, and say the scan degraded when this row appears. A clean report and a degraded one must never be indistinguishable.

(The always-loaded `SKILL-TAX` / `CONTEXT-TAX` rows are emitted by **`harness`**, not `waste` — see the harness scan above.)

### header-audit rails

The **constructive** scan: where `harness`/`deps`/`cost` find debt to remove, `rails` finds guardrails to *add*. It detects whether the repo has the determinism rails that make AI-written code reliable, and reports the environment the delivery chooser needs. Read the line types here; the full pitch + install flow is in `reference/rails.md`. Output lines (tab-separated):

- `RAIL-ENV <key> <value>` — context for adapting + delivering the scaffold:
  - `ecosystem <python|npm|go|cargo|bundler|unknown>` — primary stack (precedence order), used to adapt the gate's checks. `ecosystem-all` lists every detected stack.
  - `git-remote <yes|no>` — a configured remote means a shared repo, so team propagation matters (favor the PreToolUse delivery, or both).
  - `hooks-path <value|unset>` — `core.hooksPath`.
  - `claude <yes|no>` — a `.claude/` dir; the PreToolUse delivery is only available when `yes`.
  - `tests <path|none>` — a detected test suite; `none` makes the ratchet `n/a`.
- `RAIL-INERT <name> <path> <why>` — **machinery that is present and cannot fail**: a gate whose checks end in `|| true` (or `set +e`), CI with `continue-on-error: true`, a ratchet whose override is armed in the committed environment. **Strictly worse than an absent rail** — it earns rails credit while enforcing nothing, so everyone downstream believes they are covered. **Graded identically to absent.** Surface it *above* the absent-rails bundle and say plainly that the gate runs and cannot fail. (`TOOL npm too-old` from the `deps` scan is the same finding in the supply-chain axis — a cooldown gate that is present and silently ignored. Group them when both fire.) Key `inert-<name>`.
- `RAIL <name> <present|likely-present|absent|n/a> <evidence>` — one per rail (`precommit-gate`, `test-ratchet`, `compound-memory`, `roundtrip-invariant`). Detection is deliberately conservative — a false *present* (re-nagging a repo that already has a gate) is worse than a false *absent*. `likely-present` = word-match evidence only (e.g. the ratchet-signature vocabulary in a gate script): treat it as present for grading/nagging purposes, but present it with its caveat — the scan has not verified the machinery blocks anything. `n/a` means the rail doesn't apply (e.g. a test ratchet with no test suite, or `roundtrip-invariant` on a repo with no value pipeline) — skip it, don't surface it.

**Scaffold printer (the `gate` analogue):**

```bash
<AUDIT> rail precommit-gate --ecosystem <eco> --delivery <git|pretooluse|both> [--ratchet on|off]
<AUDIT> rail test-ratchet                 # the standalone ratchet block, to insert into an existing gate
<AUDIT> rail compound-memory              # native /header wrapup pointer + a seed .claude/memory/MEMORY.md (standalone /compound skill optional)
<AUDIT> rail roundtrip-invariant --ecosystem <eco>   # a stack-adapted round-trip test + the strict-parsing companion fix
```

Like `gate npm 7` prints the `.npmrc`, `rail <name>` prints the ready artifact — stack-adapted from the `header/scaffold/` templates, with the chosen delivery wiring appended. `precommit-gate` bundles the test ratchet by default (`--ratchet off` to omit); the correctness-critical bits (the `git commit` detector, the corrected skip/xfail regex) travel verbatim in the template. An unknown ecosystem still prints a usable gate with a `TODO` checks block. The SKILL.md flow writes the files; the bin only prints.

### `header-audit drift`

The **invariant-coverage** scan — the only one that asks whether the machinery covers what the *architecture* depends on, rather than whether machinery exists. Every other scan grades the presence of config; a repo can hold a pre-commit gate, a test ratchet, and a 100% green suite while silently dropping a field between hop 3 and hop 4 on every release.

The target bug: a value pipeline built as a chain of hand-maintained hops — **wire schema → database column → import mapping → export query → serializer → UI**. A field must be added in *every* hop or none; nothing enforces that, so fields drift (a column with no wire field; a wire field the exporter hardcodes to a constant). It stays invisible for two compounding reasons — no test asserts that what goes in comes back out, **and** the schema silently strips unknown keys, so a config authored with the dropped field still parses clean and *looks* complete.

Reads the **source** (not the harness files the `harness` scan greps). Deterministic, read-only, and deliberately high-precision: a repo with no pipeline emits a `NOTE` and nothing else, so it is never nagged and its grade never moves. Output lines:

- `DRIFT-ENV <key> <value>` — `ecosystem` (adapts the scaffold) and `tests`.
- `PIPELINE <kind> <n_files> <example>` — one per hop kind found: `schema` (pydantic / zod / marshmallow / protobuf / prisma / serde), `persist` (ORM models, migrations, DDL), `serde` (function *definitions* that move a value across a boundary — `to_dict`/`from_dict`, `serialize`/`deserialize`, `import_`/`export_`). A pipeline requires a `schema` hop **plus** a `persist` or `serde` hop — a schema alone is a type definition, not a pipeline.
- `ROUNDTRIP <likely-present|absent|n/a> <evidence>` — the headline. `likely-present` when a test either names round-trip or structurally looks like one (a single test exercising both directions) — **word-match evidence, not verified to round-trip the same value**, so relay the caveat rather than claiming coverage. `absent` = a field can be dropped in any hop and nothing in the repo will ever say so → `[Apply with review]`, key `rail-roundtrip-invariant` (the same finding also surfaces as a `RAIL` row; it is **one** recommendation, not two).
- `SCHEMA-LAX <path> <lineno> <lib> <why>` — a schema whose parser silently accepts and discards unknown keys. This is what makes the drift *invisible* rather than merely present. `[Apply now]` — strict mode is one line (`extra="forbid"`, `.strict()`, `deny_unknown_fields`, `DisallowUnknownFields()`). Key `strict-schema-<file>`.

### `header-audit silence`

**The silence axis** — information discarded without a signal. This is the generalization of `SCHEMA-LAX`: a schema that silently strips unknown keys is *one instance* of a wider defect class — code that throws information away and says nothing. The defect is never that something broke; it's that **nothing told you**, so it surfaces later, somewhere expensive. Deterministic and read-only. Output lines:

- `SILENCE-SCOPE repo <repo>` — scope marker.
- `ENV-UNDECLARED <var> <path> <lineno> <why>` — the code reads a config var that **nothing declares**. The classic silent prod break: it's in your shell, so it works on your laptop and dies in the runner. `[Apply now]` — add it to `.env.example` (or whatever the repo declares config in). **Fires only when the repo already has declaration files** (`.env.example`, compose, `Dockerfile`, CI): no declaration discipline means no invariant to violate, and inventing one would be noise. Ambient vars (`HOME`/`PATH`/`CI`/…) and test-only reads are never findings. Key `declare-env-<var>`.
- `SWALLOW <path> <lineno> <why>` — an exception handler with an **empty body**: the error happened and nothing recorded it. `[Apply with review]` — log it, re-raise it, or return an explicit fallback. Precision is the whole product decision here: a handler that logs, re-raises, or returns a fallback is a **decision**, not a swallow, and is never flagged; only a truly empty one counts. Anchors on the `except`/`catch` line. Key `swallow-<file>-<line>`.

Present these **together with `SCHEMA-LAX`** when both fire — they are the same finding class ("what fails quietly here"), and grouping them is far stronger than three scattered entries. Not graded: the five scorecard axes are a stability contract, and these are findings rather than config posture.

### `header-audit retro`

The **coach** scan: behavioral mining of the user's OWN sessions — the signals the accounting scans (`cost`/`waste`) don't surface. Same repo-scope discipline (this repo's transcript dir by default; a missing dir is a `NOTE`; `--all-projects` is the global opt-in; `--since T` windows it; `--input F` reads an explicit JSONL). Read-only; nothing leaves. Output lines:

- `RETRO-SCOPE` / `RETRO-INPUT` — same scope semantics as `cost`/`waste`; a `global` scope is background, never a per-repo claim.
- `SCAN-DEGRADED retro <detail>` — same contract as the waste scan's degraded row: unparseable tool_use blocks mean the behavioral counts are an undercount, never a quiet week. Say so when it appears.
- `RETRO-WINDOW <n_sessions> [<since>]` — sessions in the window. `RETRO-HARNESS claude-transcripts` — the harness these read (see the harness note in the coach lead).
- `RETRO-SHIP <commits> <loc+> <loc->` + `RETRO-PEAK <day> <commits>` — git activity over the window (repo scope, git repo only): the overview's "what shipped" + busiest day.
- `RETRO-PLAN <n_planned> <n_sessions>` — sessions that opened plan mode → a low rate nudges plan-first. `RETRO-CORRECTION <n>` — user redirects → `feedback_` candidates for compound.
- `RETRO-CORR plan-mode <avg_err_planned> <avg_err_unplanned>` — per-session correlation: avg Bash errors in plan vs no-plan sessions (emitted only with ≥2 of each). When `planned < unplanned`, it *quantifies* the plan-first nudge ("planned 0.2 vs 1.1 errors").
- `RETRO-GAP <n_sessions> <total> key=cap-verify` — sessions with an edit + a "fixed/done" claim but **no test run** = a verification gap → a `pitfall` for compound; the `precommit-gate` rail addresses it.
- `RETRO-THRASH <file> <edits>` — a file re-edited ≥5 times: a rework signal (the agent not landing it first pass), sorted desc. Heavy thrash on one file alongside a heavy always-loaded `FILE` + non-zero `COMPACTIONS` is the practical argument to split it.
- `RETRO-FAILS <tool> <errors> <calls>` — failed-tool volume. **Bash errors are the gotcha/pitfall signal** — the count is precise (error attribution), but the *narrative* (what actually broke) you read from your own session context (a wrapup) or the recent transcript. 0 errors → a clean week; say so, don't invent gotchas to fill the section.
- `RETRO-GIT <pattern> <count>` — git-workflow tells (`stash`, `branch-switch`, `worktree`, `reset-hard`, `force-push`). **Interpret, don't verdict** (à la `ERROR-RATE`): counts include git strings that appear in tool inputs (test fixtures, examples), so treat `reset-hard`/`force-push` as soft signals. The CAP derivations below key only off `stash`/`branch-switch`/`worktree` and precise error attribution.
- `RETRO-COCHANGE <fileA> <fileB> <together> <commits> <pct>` / `RETRO-DRIFT <file> <expected-companion> <n_missing> <commits> key=cochange-<a>-<b>` — **co-change drift**, mined from git history alone (no knowledge of the stack). Files that almost always change together encode an invariant the repo never wrote down — *add the column → add the wire field → add the mapping*. `RETRO-DRIFT` names the commits that **broke** it: `<file>` changed `<n_missing>` times without `<expected-companion>`, which it otherwise moves with. This is the generalized shape of the hand-maintained-pipeline bug, and it is **counted, not inferred** — treat it as high-precision and lead the gotchas with it. Conservative by construction: bulk commits (>25 files) are dropped, a coupling needs ≥4 joint commits and ≥70% mutual co-change, and violations must be *exceptions* (≥75% directional) rather than the norm. When the pair sits in a pipeline the `drift` scan also flagged, it is the **same finding** — surface it once.
- `RETRO-CAP <capability> <evidence> key=cap-<capability>` — the **derived** behavior→practice nudges, the ranked spine of the coach lead. Three, each emitted only when its threshold is met:
  - `worktree` — ≥3 branch-juggling events (stash/switch) and **no** worktree use → recommend git worktrees.
  - `guardrail` — ≥3 failed Bash calls → recommend the `precommit-gate` rail (cross-check `RAIL precommit-gate`; **affirm** it if already present).
  - `compound` — ≥3 gotchas **and** no committed `.claude/memory/` → recommend `/header wrapup`.
  Render only the caps that fired, in emission order (= order of demonstrated need). Each carries `key=cap-<name>` — use it verbatim in the ledger. A weak cap (low count) → rank it low and **say it's weak**; never hard-sell (the anti-upsell discipline that the engine-adoption upsell got wrong).

### `header-audit grade`

**TWO composite setup grades** — glanceable marks (e.g. `B+`) over the five scorecard axes, answering "how's my setup?" before the detail. The split is the point: **what you grade must be explicit.**

- **📦 Project setup** grades the repo's **checked-in** agent config — `CLAUDE.md`, `AGENTS.md`, committed `.claude/settings.json`, `.claude/commands|agents`, `.mcp.json`, editor rules, the `.npmrc` cooldown gate, determinism rails. A property of the repo: it travels with the code, is reviewable in a PR, and grades **identically on any machine**. This is the headline (howsmyaicoding.com's "Setup grade B+").
- **💻 Local harness** grades **your machine** — `~/.claude/CLAUDE.md` & `settings.json`, the `settings.local.json` override, the model *you* run (transcript/local), package-tool versions. Machine-dependent by design; reported alongside, **never folded into the project grade**.

Re-runs `harness` + `deps` + `rails` internally (cheap, read-only) and **partitions each finding by scope** — a path under `~/.claude` (or a `settings.local.json`) is local, everything else under the repo is project; `MODEL` carries its own source. **Static-config only:** the transcript-mined scans (`cost` / `waste` / `retro`) are excluded, so the **project** grade is stable whether or not the repo has session history — and identical run-to-run, model-to-model, because it is **computed in the bin, never model-assigned**. Output lines:

- `GRADE-AXIS <axis> <delta> <note>` / `GRADE <letter> <score> 100` — the **project** grade: per-axis deductions (five rows, fixed order: `context` / `model` / `security` / `deps` / `rails`) then the composite (start 100, deduct, clamp 0–100, map to an `A+`…`F` band). Render the **letter only** as the headline; the `<score>` stays in the line for the breakdown + tests.
- `GRADE-AXIS-LOCAL <axis> <delta> <note>` / `GRADE-LOCAL <letter> <score> 100` — the **local harness** grade, same five axes and formulas applied to the local-scope findings. `rails` is always `n/a` here (a repo property). Collapse the whole local section to one line when it's clean (see the scorecard contract).

**What each axis weighs** (a stability contract — same inputs always yield the same grade, so the bands/weights don't drift between runs): **context** = always-loaded tokens (tiered) + prompt-debt `HIT`s + `STALE-REF`s (project: repo files; local: `~/.claude`) · **model** = a `MODEL-STALE` superseded tier (a `MODEL-UPGRADE` *opportunity* is **not** penalized), graded on whichever scope owns the model (repo-pinned → project; the model you run → local) · **security** = a weak Bash posture (`bypass` / `denylist`; "no explicit policy" is fine and doesn't deduct), per scope's settings · **deps** = project docks an absent checked-in cooldown gate, local docks a package-tool too old to honor one (the machine-dependent half lives on the local grade — never the project one) · **rails** = absent determinism guardrails, weighed **light**; project-only. A clean, current, lean setup lands at `A`/`A+`; debt and risk pull it down.
