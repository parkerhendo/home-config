#!/usr/bin/env bash
# test/audit.test.sh — bin/header-audit. Builds a sandbox repo with planted debt
# and manifests, then asserts on the structured scan output. HOME is sandboxed so
# the user-global ~/.claude/CLAUDE.md never bleeds in.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

AU="$SKILL_DIR/bin/header-audit"

# ── sandbox repo with planted prompt debt + manifests ─────────
sb="$(make_sandbox)"; repo="$sb/repo"; mkdir -p "$repo/.claude/commands"
cat > "$repo/CLAUDE.md" <<'MD'
# Project
You are an expert Go engineer. Always think step by step before answering.
Do not hallucinate. Respond only in JSON.
Use tabs and run gofmt.
MD
cat > "$repo/.claude/settings.json" <<'JSON'
{ "model": "claude-sonnet-4-6" }
JSON
printf '{"name":"x","dependencies":{"chalk":"^5"}}\n' > "$repo/package.json"
printf 'requests==2.0\n' > "$repo/requirements.txt"

# ── patterns ──────────────────────────────────────────────────
pats="$(HOME="$sb" "$AU" patterns)"
assert_contains "$pats" "step-by-step" "patterns lists the step-by-step debt id"
assert_contains "$pats" "no-hallucinate" "patterns lists the no-hallucinate debt id"

# ── harness scan ──────────────────────────────────────────────
H="$(HOME="$sb" "$AU" harness --repo "$repo")"
assert_contains "$H" "MODEL	claude-sonnet-4-6" "harness reports the declared model"
assert_contains "$H" "FILE	$repo/CLAUDE.md" "harness reports CLAUDE.md as a file"
assert_contains "$H" "	step-by-step	" "harness flags the step-by-step pattern hit"
assert_contains "$H" "	role-puffery	" "harness flags role puffery"
assert_contains "$H" "	no-hallucinate	" "harness flags the don't-hallucinate line"
assert_contains "$H" "	json-nag	" "harness flags JSON-format nagging"
# token estimate present and numeric (bytes/4)
fileline="$(printf '%s\n' "$H" | grep "FILE	$repo/CLAUDE.md")"
est="$(printf '%s' "$fileline" | awk -F'\t' '{print $4}')"
# Bash 3.2 (macOS default) mis-parses `case` inside command substitution, so
# evaluate it as its own statement.
case "$est" in ''|*[!0-9]*) est_numeric=no ;; *) est_numeric=yes ;; esac
assert_eq "yes" "$est_numeric" \
  "harness FILE line carries a numeric token estimate"

# a clean repo yields no HITs
clean="$sb/clean"; mkdir -p "$clean"
printf '# Clean\nUse tabs.\n' > "$clean/CLAUDE.md"
assert_not_contains "$(HOME="$sb" "$AU" harness --repo "$clean")" "HIT	" \
  "a debt-free CLAUDE.md produces no pattern hits"

# ── deps scan ─────────────────────────────────────────────────
D="$(HOME="$sb" "$AU" deps --repo "$repo")"
assert_contains "$D" "ECOSYSTEM	npm	$repo/package.json" "deps detects the npm ecosystem"
assert_contains "$D" "ECOSYSTEM	python	$repo/requirements.txt" "deps detects the python ecosystem"
assert_contains "$D" "GATE	npm	absent" "no .npmrc → npm cooldown gate absent"

# add the gate → now present
HOME="$sb" "$AU" gate npm 7 > "$repo/.npmrc"
assert_contains "$(HOME="$sb" "$AU" deps --repo "$repo")" "GATE	npm	present" \
  "an .npmrc with min-release-age → gate present"

# ── deps: TOOL/GATE rows are scoped to DETECTED ecosystems (0.25.0) ──
# A go-only repo must not be prompted toward an npm/pip cooldown it can't use:
# undetected ecosystems get an explicit n/a (skipped by the flow, like rails).
goonly="$sb/goonly"; mkdir -p "$goonly"
printf 'module x\n' > "$goonly/go.mod"
DG="$(HOME="$sb" "$AU" deps --repo "$goonly")"
assert_contains "$DG" "ECOSYSTEM	go	$goonly/go.mod" "go-only repo detects the go ecosystem"
assert_contains "$DG" "GATE	npm	n/a" "go-only repo: npm gate is n/a, not a finding"
assert_contains "$DG" "GATE	pip	n/a" "go-only repo: pip gate is n/a, not a finding"
assert_not_contains "$DG" "GATE	npm	absent" "no npm gate-recommendation trigger in a go-only repo"
assert_not_contains "$DG" "GATE	pip	absent" "no pip gate-recommendation trigger in a go-only repo"
assert_not_contains "$DG" "TOOL	npm" "no npm TOOL row when the repo doesn't install through npm"
assert_not_contains "$DG" "TOOL	pip" "no pip TOOL row when the repo doesn't install through pip"

# monorepo: a subdir package.json still counts as npm (the gate check already
# honors frontend/.npmrc — detection must not be stricter than the gate).
mono="$sb/mono"; mkdir -p "$mono/frontend"
printf '{"name":"f"}\n' > "$mono/frontend/package.json"
DM="$(HOME="$sb" "$AU" deps --repo "$mono")"
assert_contains "$DM" "ECOSYSTEM	npm	$mono/frontend/package.json" \
  "a one-level-deep package.json is detected (monorepo)"
assert_contains "$DM" "GATE	npm	absent" \
  "the monorepo keeps its REAL absent finding (n/a only when npm is truly unused)"

# ── gate snippets ─────────────────────────────────────────────
gnpm="$(HOME="$sb" "$AU" gate npm 14)"
assert_contains "$gnpm" "min-release-age=14" "gate npm parameterizes the day count"
assert_contains "$gnpm" "npm >= 11.10" "gate npm states the minimum npm version"
gpip="$(HOME="$sb" "$AU" gate pip 7)"
assert_contains "$gpip" "uploaded-prior-to P7D" "gate pip emits the ISO-8601 cooldown flag"
assert_contains "$gpip" "pip>=26.1" "gate pip states the minimum pip version"

# ── bash tool security posture ────────────────────────────────
sb2="$(make_sandbox)"; r="$sb2/r"; mkdir -p "$r/.claude"
cat > "$r/.claude/settings.json" <<'J'
{
  "permissions": { "defaultMode": "bypassPermissions" }
}
J
assert_contains "$(HOME="$sb2" "$AU" harness --repo "$r")" $'SECURITY\tbash\tbypass' \
  "bypassPermissions → SECURITY bash bypass (no gating)"
cat > "$r/.claude/settings.json" <<'J'
{
  "permissions": { "deny": [ "Bash(curl:*)", "Bash(rm:*)" ] }
}
J
assert_contains "$(HOME="$sb2" "$AU" harness --repo "$r")" $'SECURITY\tbash\tdenylist' \
  "a Bash deny-list → denylist (blacklist)"
cat > "$r/.claude/settings.json" <<'J'
{
  "permissions": { "allow": [ "Bash(npm run test:*)" ], "deny": [ "Read(./.env)" ] }
}
J
Hsec="$(HOME="$sb2" "$AU" harness --repo "$r")"
assert_contains "$Hsec" $'SECURITY\tbash\tallowlist' \
  "a Bash allow-list → allowlist (whitelist); a non-Bash deny doesn't flip it"
assert_contains "$Hsec" $'SECURITY-DETAIL\tallow\tBash(npm run test:*)' \
  "allow-list entry detail is surfaced"
cat > "$r/.claude/settings.json" <<'J'
{
  "permissions": { "allow": [ "Read(./src/**)" ] }
}
J
assert_not_contains "$(HOME="$sb2" "$AU" harness --repo "$r")" $'SECURITY\tbash' \
  "settings with no Bash rules → no SECURITY line"

# ── model staleness ───────────────────────────────────────────
# the main sandbox pins sonnet-4-6 (current) → no MODEL-STALE line.
assert_not_contains "$H" "MODEL-STALE" "a current model id is not flagged stale"
sb_stale="$(make_sandbox)"; rstale="$sb_stale/r"; mkdir -p "$rstale/.claude"
printf '{ "model": "claude-3-5-sonnet-20241022" }\n' > "$rstale/.claude/settings.json"
printf '# x\n' > "$rstale/CLAUDE.md"
Hstale="$(HOME="$sb_stale" "$AU" harness --repo "$rstale")"
assert_contains "$Hstale" $'MODEL-STALE\tclaude-3-5-sonnet-20241022' \
  "a Claude 3.x model id is flagged as a superseded tier"
printf '{ "model": "claude-opus-4-1-20250805" }\n' > "$rstale/.claude/settings.json"
assert_contains "$(HOME="$sb_stale" "$AU" harness --repo "$rstale")" $'MODEL-STALE\tclaude-opus-4-1' \
  "early Opus 4 (4.1) is flagged as superseded by Opus 4.5+"

# ── model upgrade opportunity (newer same-family model — not debt) ──
printf '{ "model": "claude-opus-4-7" }\n' > "$rstale/.claude/settings.json"
Hup="$(HOME="$sb_stale" "$AU" harness --repo "$rstale")"
assert_contains "$Hup" $'MODEL-UPGRADE\tclaude-opus-4-7\tclaude-opus-4-8' \
  "Opus 4.7 → MODEL-UPGRADE names Opus 4.8 as the newer same-family candidate"
assert_not_contains "$Hup" "MODEL-STALE" \
  "a current (4.7) model is an upgrade opportunity, not stale debt"
printf '{ "model": "claude-opus-4-8" }\n' > "$rstale/.claude/settings.json"
Hup48="$(HOME="$sb_stale" "$AU" harness --repo "$rstale")"
assert_contains "$Hup48" $'MODEL-UPGRADE\tclaude-opus-4-8\tclaude-fable-5' \
  "Opus 4.8 → MODEL-UPGRADE names Fable 5 as the tier above"
assert_contains "$Hup48" "2x the token price" \
  "the Fable 5 upgrade message is honest about the price (not a same-price move)"
printf '{ "model": "claude-fable-5" }\n' > "$rstale/.claude/settings.json"
assert_not_contains "$(HOME="$sb_stale" "$AU" harness --repo "$rstale")" "MODEL-UPGRADE" \
  "the top tier (Fable 5) is not flagged for upgrade"
printf '{ "model": "claude-opus-4-1-20250805" }\n' > "$rstale/.claude/settings.json"
assert_not_contains "$(HOME="$sb_stale" "$AU" harness --repo "$rstale")" "MODEL-UPGRADE" \
  "a superseded tier is flagged STALE, not as an upgrade opportunity"

# ── detection: no pinned model → fall back to the most recent transcript model ──
# (so plain /header offers the upgrade even when the user rides the default alias)
# Real Claude Code nests transcripts one level per project:
# ~/.claude/projects/<project-key>/<session>.jsonl — the fixture MUST be nested,
# or the test passes against a layout that doesn't exist (the 0.21.1 regression).
sb_tx="$(make_sandbox)"; rtx="$sb_tx/r"; mkdir -p "$rtx" "$sb_tx/.claude/projects/-home-u-proj"
printf '# x\n' > "$rtx/CLAUDE.md"   # NO .claude/settings.json → unpinned
printf '{"type":"assistant","message":{"model":"claude-opus-4-7","usage":{}}}\n' > "$sb_tx/.claude/projects/-home-u-proj/s.jsonl"
Htx="$(HOME="$sb_tx" "$AU" harness --repo "$rtx")"
assert_contains "$Htx" $'MODEL\tclaude-opus-4-7' \
  "MODEL is detected from the most recent NESTED transcript when settings pin nothing"
assert_contains "$Htx" $'MODEL-UPGRADE\tclaude-opus-4-7\tclaude-opus-4-8' \
  "MODEL-UPGRADE fires off the transcript-detected model (plain /header offers it unpinned)"
# Newest-wins across layouts: an older flat-layout file must not shadow the
# newer nested one (and flat stays tolerated for back-compat).
printf '{"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{}}}\n' > "$sb_tx/.claude/projects/old-flat.jsonl"
touch -t 202001010000 "$sb_tx/.claude/projects/old-flat.jsonl"
assert_contains "$(HOME="$sb_tx" "$AU" harness --repo "$rtx")" $'MODEL\tclaude-opus-4-7' \
  "the newest transcript wins across nested + flat layouts"

# ── @import following + stale references ──────────────────────
sb_imp="$(make_sandbox)"; rimp="$sb_imp/r"; mkdir -p "$rimp/docs" "$rimp/scripts"
printf 'x\n' > "$rimp/scripts/deploy.sh"          # exists → not stale
printf 'imported guidance\n' > "$rimp/docs/extra.md"
cat > "$rimp/CLAUDE.md" <<'MD'
# Project
See `scripts/deploy.sh` to deploy and `scripts/gone.sh` for cleanup.
Conventions live at `path/to/placeholder.md` (a doc placeholder, ignore).
@docs/extra.md
@docs/missing.md
MD
Himp="$(HOME="$sb_imp" "$AU" harness --repo "$rimp")"
assert_contains "$Himp" $'IMPORT\t'"$rimp/CLAUDE.md"$'\t'"$rimp/docs/extra.md" \
  "a resolvable @import emits an IMPORT edge"
assert_contains "$Himp" "FILE	$rimp/docs/extra.md" \
  "an @imported file is scanned as an always-loaded FILE (counts toward the per-turn sum)"
assert_contains "$Himp" $'STALE-REF\t'"$rimp/CLAUDE.md"$'\t5\t@docs/missing.md' \
  "an unresolvable @import is a STALE-REF"
assert_contains "$Himp" $'STALE-REF\t'"$rimp/CLAUDE.md"$'\t2\tscripts/gone.sh' \
  "a backtick path that no longer exists is a STALE-REF"
assert_not_contains "$Himp" "scripts/deploy.sh	referenced path not found" \
  "a backtick path that still exists is not flagged"
assert_not_contains "$Himp" "path/to/placeholder.md	referenced path not found" \
  "a path/to/ documentation placeholder is not flagged"

# ── STALE-REF precision: the 12/12 false-positive shapes from real sessions ──
# Reproduces the revturbine AGENTS.md FPs (branch-name examples, gitignore/folder
# tokens in a fence, forbidden-file + absolute examples) and asserts they are all
# suppressed, while a genuine moved-file ref still fires.
sb_fp="$(make_sandbox)"; rfp="$sb_fp/r"; mkdir -p "$rfp/scripts"
printf 'x\n' > "$rfp/scripts/build.sh"                 # exists → the existing-file control
cat > "$rfp/AGENTS.md" <<'MD'
# Conventions

Do not create `.cursor/rules` or commit into `/code`.
Name branches like `feat/add-login`, `fix/null-pointer`, or `mark/update-specs`.
Run `scripts/build.sh` before committing, never `scripts/gone.sh`.

Folder layout and ignores (illustrative):

```
to_do/
inprogress/
completed/
deferred/
```

```gitignore
.pnpm-store/
dist/
build/
```
MD
Hfp="$(HOME="$sb_fp" "$AU" harness --repo "$rfp")"
for fp_tok in ".cursor/rules" "/code" "feat/add-login" "fix/null-pointer" \
              "mark/update-specs" "to_do/" "inprogress/" "completed/" \
              "deferred/" ".pnpm-store/" "dist/" "build/"; do
  assert_not_contains "$Hfp" "$fp_tok	referenced path not found" \
    "STALE-REF suppresses the false-positive shape '$fp_tok'"
done
assert_contains "$Hfp" $'scripts/gone.sh\treferenced path not found' \
  "a real moved-file ref (extensioned, in prose) still fires"
assert_not_contains "$Hfp" "scripts/build.sh	referenced path not found" \
  "an existing extensioned file ref is not flagged"
# a fenced extensioned example must be suppressed (fence wins over extension)
printf '\n```sh\nrun `scripts/fenced-example.sh`\n```\n' >> "$rfp/AGENTS.md"
Hfp2="$(HOME="$sb_fp" "$AU" harness --repo "$rfp")"
assert_not_contains "$Hfp2" "scripts/fenced-example.sh	referenced path not found" \
  "an extensioned ref inside a code fence is suppressed (illustrative, not live)"

# ── nested CLAUDE.md (on-demand, reported apart from always-loaded) ──
mkdir -p "$rimp/sub"; printf '# nested rules\n' > "$rimp/sub/CLAUDE.md"
Hnest="$(HOME="$sb_imp" "$AU" harness --repo "$rimp")"
assert_contains "$Hnest" "NESTED	$rimp/sub/CLAUDE.md" "a subdir CLAUDE.md is reported as NESTED"
assert_not_contains "$Hnest" "NESTED	$rimp/CLAUDE.md" "the repo-root CLAUDE.md is not double-counted as NESTED"

# ── hooks (arbitrary shell on agent events) ───────────────────
sb_hk="$(make_sandbox)"; rhk="$sb_hk/r"; mkdir -p "$rhk/.claude"; printf '# x\n' > "$rhk/CLAUDE.md"
cat > "$rhk/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo guard" } ] } ],
    "Stop": [ { "hooks": [ { "type": "command", "command": "notify-send done" } ] } ]
  }
}
JSON
Hhk="$(HOME="$sb_hk" "$AU" harness --repo "$rhk")"
assert_contains "$Hhk" $'HOOK\tPreToolUse\techo guard' "a PreToolUse hook command is surfaced"
assert_contains "$Hhk" $'HOOK\tStop\tnotify-send done' "a Stop hook command is surfaced"
# a settings file with no hooks key yields no HOOK lines
printf '{ "model": "claude-opus-4-8" }\n' > "$rhk/.claude/settings.json"
assert_not_contains "$(HOME="$sb_hk" "$AU" harness --repo "$rhk")" $'HOOK\t' \
  "settings with no hooks key → no HOOK line"
# an mcpServers "command" sharing the file is NOT a hook (no "type":"command" anchor)
cat > "$rhk/.claude/settings.json" <<'JSON'
{
  "hooks": { "Stop": [ { "hooks": [ { "type": "command", "command": "real-hook" } ] } ] },
  "mcpServers": { "fs": { "command": "npx", "args": ["-y", "server"] } }
}
JSON
Hmcp="$(HOME="$sb_hk" "$AU" harness --repo "$rhk")"
assert_contains "$Hmcp" $'HOOK\tStop\treal-hook' "the real hook command is still surfaced"
assert_not_contains "$Hmcp" "npx" "an mcpServers command is not misattributed as a hook"

# ── installed skills (supply-chain + execution surface) ───────
sb_sk="$(make_sandbox)"; rsk="$sb_sk/r"
mkdir -p "$rsk/.claude/skills/withbin/bin" "$rsk/.claude/skills/nobin" "$sb_sk/.claude/skills/usertool/bin"
printf '# x\n' > "$rsk/CLAUDE.md"
printf '#!/bin/sh\n' > "$rsk/.claude/skills/withbin/bin/run"; chmod +x "$rsk/.claude/skills/withbin/bin/run"
printf '# skill\n' > "$rsk/.claude/skills/nobin/SKILL.md"
printf '#!/bin/sh\n' > "$sb_sk/.claude/skills/usertool/bin/x"
Hsk="$(HOME="$sb_sk" "$AU" harness --repo "$rsk")"
assert_contains "$Hsk" $'SKILL\twithbin\t'"$rsk/.claude/skills/withbin"$'\tyes\trepo' \
  "a repo skill carrying bin scripts → SKILL has-bin yes, scope repo"
assert_contains "$Hsk" $'SKILL\tnobin\t'"$rsk/.claude/skills/nobin"$'\tno\trepo' \
  "a repo skill with no bin → SKILL has-bin no"
assert_contains "$Hsk" $'SKILL\tusertool\t'"$sb_sk/.claude/skills/usertool"$'\tyes\tuser' \
  "a user-scope skill is reported with scope user"

# ── briefing-supplied debt patterns ───────────────────────────
sb_bp="$(make_sandbox)"; rbp="$sb_bp/r"; hh="$sb_bp/.header"; mkdir -p "$rbp" "$hh"
printf 'Please be very careful and double-check everything.\n' > "$rbp/CLAUDE.md"
# well-formed extra pattern + one malformed (4 fields) that must be skipped
printf 'over-caution\tbe very careful|double.?check everything\tBriefing-flagged over-caution.\n' > "$hh/patterns.tsv"
printf 'bad\tregex\twhy\textra-field-should-skip\n' >> "$hh/patterns.tsv"
Pbp="$(HEADER_HOME="$hh" HOME="$sb_bp" "$AU" patterns)"
assert_contains "$Pbp" "over-caution" "patterns lists a briefing-supplied id"
assert_not_contains "$Pbp" "bad " "a malformed (4-field) briefing pattern is skipped from the listing"
Hbp="$(HEADER_HOME="$hh" HOME="$sb_bp" "$AU" harness --repo "$rbp")"
assert_contains "$Hbp" $'\tover-caution\t' "a briefing-supplied pattern produces a HIT in the harness scan"

# ── cost (cost-aware audit) ───────────────────────────────────
sb_co="$(make_sandbox)"
cat > "$sb_co/usage.jsonl" <<'JSONL'
{"model":"claude-opus-4-8","input_tokens":200000,"output_tokens":80000,"ts":"2026-05-21T10:00:00Z"}
{"model":"claude-opus-4-8","input_tokens":100000,"output_tokens":50000,"ts":"2026-05-20T10:00:00Z"}
{"model":"claude-haiku-4-5","input_tokens":50000,"output_tokens":10000,"ts":"2026-05-22T10:00:00Z"}
JSONL
C="$(HOME="$sb_co" "$AU" cost --input "$sb_co/usage.jsonl")"
assert_contains "$C" $'COST-SCOPE\tinput\t' "cost --input labels its scope as input"
assert_contains "$C" $'SPEND-TOTAL\t' "cost emits a SPEND-TOTAL line"
assert_contains "$C" $'SPEND\tclaude-opus-4-8\t' "cost breaks spend down by model"
assert_contains "$C" $'ROUTE-CANDIDATE\tclaude-opus-4-8\t' \
  "cost names the top-spend model as the model-routing candidate"
# the route candidate is the costliest model, not merely the first or last seen
rc_model="$(printf '%s\n' "$C" | awk -F'\t' '$1=="ROUTE-CANDIDATE"{print $2}')"
assert_eq "claude-opus-4-8" "$rc_model" "ROUTE-CANDIDATE is the costliest model"
# a missing input file degrades to a NOTE, never an error row
assert_contains "$(HOME="$sb_co" "$AU" cost --input "$sb_co/nope.jsonl")" $'NOTE\tcost\t' \
  "cost with a missing input emits a NOTE, not a crash"

# ── cost: repo-scoped by default, no cross-project leakage (HEA-435) ──
# Two projects under ~/.claude/projects keyed by repo path (Claude Code's own
# convention: abs path → non-alphanumerics replaced by '-'). repoA spends little
# (haiku); repoB spends a lot (opus). A default audit of repoA must report ONLY
# repoA's spend — the large global total must never leak in.
sb_sc="$(make_sandbox)"; repoA="$sb_sc/repoA"; repoB="$sb_sc/repoB"
mkdir -p "$repoA" "$repoB"
keyA="$(printf '%s' "$repoA" | sed 's/[^A-Za-z0-9]/-/g')"
keyB="$(printf '%s' "$repoB" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$sb_sc/.claude/projects/$keyA" "$sb_sc/.claude/projects/$keyB"
printf '{"model":"claude-haiku-4-5","input_tokens":50000,"output_tokens":10000,"ts":"2026-05-22T10:00:00Z"}\n' \
  > "$sb_sc/.claude/projects/$keyA/a.jsonl"
printf '{"model":"claude-opus-4-8","input_tokens":2000000,"output_tokens":800000,"ts":"2026-05-21T10:00:00Z"}\n' \
  > "$sb_sc/.claude/projects/$keyB/b.jsonl"

SCA="$(HOME="$sb_sc" "$AU" cost --repo "$repoA")"
assert_contains "$SCA" $'COST-SCOPE\trepo\t'"$repoA" "default cost is scoped to the current repo"
assert_contains "$SCA" $'COST-INPUT\t'"$sb_sc/.claude/projects/$keyA"$'\t1\tfiles' \
  "cost names the repo-scoped transcript dir it priced"
assert_contains "$SCA" $'SPEND\tclaude-haiku-4-5\t' "repo-scoped cost prices this repo's models"
assert_not_contains "$SCA" $'SPEND\tclaude-opus-4-8\t' \
  "the other project's opus spend does NOT leak into this repo's report"
assert_contains "$SCA" $'COST-HARNESS\tclaude\tclaude-transcripts' "cost labels the active harness"

# A repo with no matching transcript dir → NOTE, and crucially NO SPEND (never a
# silent machine-wide aggregate).
SCN="$(HOME="$sb_sc" "$AU" cost --repo "$sb_sc/repoNone")"
assert_contains "$SCN" $'NOTE\tcost\t' "a repo with no transcripts degrades to a NOTE"
assert_not_contains "$SCN" $'SPEND-TOTAL\t' "no-data repo never falls back to a global aggregate"

# --all-projects is the explicit machine-wide opt-in: labeled global, totals cover
# both projects (so opus reappears).
SCG="$(HOME="$sb_sc" "$AU" cost --all-projects)"
assert_contains "$SCG" $'COST-SCOPE\tglobal\t' "--all-projects labels its scope as global"
assert_contains "$SCG" $'SPEND\tclaude-opus-4-8\t' "--all-projects aggregates every project"

# Codex harness over Claude transcripts is a cross-harness mismatch: label it and
# flag it so the presentation downgrades the routing recommendation.
SCX="$(HOME="$sb_sc" "$AU" cost --repo "$repoA" --harness codex)"
assert_contains "$SCX" $'COST-HARNESS\tcodex\tclaude-transcripts' "Codex harness is labeled on the cost source"
assert_contains "$SCX" $'COST-NOTE\tharness-mismatch\t' "Codex over Claude transcripts flags a harness mismatch"
# the mismatch NOTE is suppressed under the explicit cross-harness opt-in
assert_not_contains "$(HOME="$sb_sc" "$AU" cost --all-projects --harness codex)" \
  $'COST-NOTE\tharness-mismatch\t' "--all-projects suppresses the harness-mismatch NOTE (explicit opt-in)"

# ── canonical ledger keys (the trailing key= field) ───────────
# Recommendation-capable lines pre-mint their ledger key so the model never
# invents one per run (model-minted keys fragmented cross-run dedup: the same
# finding re-surfaced as route-low-stakes-to-cheaper / route-fable5-cheaper /
# route-low-stakes-cheaper across four audits of one repo). The derivations
# below are a stability contract — changing one orphans users' ledger history.
assert_contains "$H" "key=delete-step-by-step" "HIT pre-mints key=delete-<pattern-id>"
assert_contains "$H" "key=trim-claude-md" "FILE pre-mints key=trim-<repo-relative-slug>"
assert_contains "$D" $'GATE\tnpm\tabsent\t-\tkey=gate-npm' "an absent npm gate carries key=gate-npm"
assert_contains "$D" $'GATE\tpip\tabsent\t-\tkey=gate-pip' "an absent pip gate carries key=gate-pip"
assert_not_contains "$(HOME="$sb" "$AU" deps --repo "$repo" | grep 'GATE	npm	present')" "key=" \
  "a present gate carries no key (status, not a recommendation)"
assert_not_contains "$DG" "key=gate" "n/a gates carry no key (nothing to recommend)"
assert_contains "$Hstale" "key=migrate-claude-3-5-sonnet-20241022" \
  "MODEL-STALE pre-mints key=migrate-<model-slug>"
assert_contains "$Hup" "key=adopt-claude-opus-4-8" "MODEL-UPGRADE (4.7) pre-mints key=adopt-claude-opus-4-8"
assert_contains "$Hup48" "key=adopt-claude-fable-5" "MODEL-UPGRADE (4.8) pre-mints key=adopt-claude-fable-5"
assert_contains "$Himp" "key=stale-ref-scripts-gone-sh" "STALE-REF pre-mints key=stale-ref-<ref-slug>"
assert_contains "$Himp" "key=stale-ref-docs-missing-md" "an unresolved @import STALE-REF also carries a key"
assert_contains "$Hhk" "key=hook-pretooluse-echo-guard" "HOOK pre-mints key=hook-<event>-<command-slug>"
assert_contains "$Hsk" "key=review-skill-withbin" "SKILL pre-mints key=review-skill-<name>"
assert_contains "$C" "key=route-claude-opus-4-8" "ROUTE-CANDIDATE pre-mints key=route-<model-slug>"
cat > "$r/.claude/settings.json" <<'J'
{ "permissions": { "deny": [ "Bash(curl:*)" ] } }
J
assert_contains "$(HOME="$sb2" "$AU" harness --repo "$r")" $'SECURITY\tbash\tdenylist\t'"$r/.claude/settings.json"$'\tkey=bash-allowlist' \
  "a weak Bash posture (denylist) carries key=bash-allowlist"
cat > "$r/.claude/settings.json" <<'J'
{ "permissions": { "allow": [ "Bash(npm run test:*)" ] } }
J
assert_not_contains "$(HOME="$sb2" "$AU" harness --repo "$r" | grep 'SECURITY	bash')" "key=" \
  "an allowlist posture carries no key (affirmation, not a finding)"

# ── composite setup grade (the website's "Setup grade B+") ────
# Deterministic letter grade over the five scorecard axes. The canonical
# website-example scenario — lean CLAUDE.md, current model, ONE absent
# supply-chain gate, 0/3 determinism rails — must land EXACTLY on B+ (87). This
# is a stability contract: the weights/bands are pinned, so a change here is a
# deliberate decision, not a silent drift of everyone's grade.
sb_gr="$(make_sandbox)"; rgr="$sb_gr/site"; mkdir -p "$rgr/.claude" "$rgr/tests"
cat > "$rgr/CLAUDE.md" <<'MD'
# Project
Use tabs. Run the test suite before committing.
MD
printf '{ "model": "claude-opus-4-8" }\n' > "$rgr/.claude/settings.json"
printf '{"name":"x"}\n' > "$rgr/package.json"
printf 'def test_x(): pass\n' > "$rgr/tests/test_x.py"
G="$(HOME="$sb_gr" "$AU" grade --repo "$rgr")"
assert_contains "$G" $'GRADE\tB+\t87\t100' \
  "the website-example scenario grades exactly B+ (87/100)"
assert_contains "$G" $'GRADE-AXIS\tdeps\t-7\t1 supply-chain gate' \
  "the deps axis docks the one absent cooldown gate"
assert_contains "$G" $'GRADE-AXIS\trails\t-6\t3 determinism rail' \
  "the rails axis docks the three absent rails (weighed light)"
assert_contains "$G" $'GRADE-AXIS\tmodel\t0\t' \
  "a MODEL-UPGRADE opportunity (opus-4-8) is NOT penalized — a current tier costs nothing"
# determinism: identical run-to-run (computed in the bin, never model-assigned)
assert_eq "$G" "$(HOME="$sb_gr" "$AU" grade --repo "$rgr")" \
  "grade is deterministic — same repo, byte-identical output"
# all five axes present
for ax in context model security deps rails; do
  assert_contains "$G" "GRADE-AXIS	$ax	" "grade emits the $ax axis row"
done

# a lean, current, dependency-free repo → A band (only the light rail dings apply)
rcl="$sb_gr/clean"; mkdir -p "$rcl"
printf '# Clean\nUse tabs.\n' > "$rcl/CLAUDE.md"
Gcl="$(HOME="$sb_gr" "$AU" grade --repo "$rcl")"
assert_contains "$Gcl" $'GRADE\tA\t' "a clean, current, dependency-free setup grades in the A band"
assert_contains "$Gcl" $'GRADE-AXIS\tdeps\t0\t' "no ecosystem → no deps deduction (n/a, not absent)"

# a high-risk repo (bypass perms + superseded model + heavy always-loaded file) → F
rbad="$sb_gr/bad"; mkdir -p "$rbad/.claude"
head -c 140000 /dev/zero | tr '\0' 'x' > "$rbad/CLAUDE.md"
printf '{ "model": "claude-3-5-sonnet-20241022", "permissions": { "defaultMode": "bypassPermissions" } }\n' > "$rbad/.claude/settings.json"
Gbad="$(HOME="$sb_gr" "$AU" grade --repo "$rbad")"
assert_contains "$Gbad" $'GRADE\tF\t' "a bypass-perms, superseded-model, bloated-context setup grades F"
assert_contains "$Gbad" $'GRADE-AXIS\tsecurity\t-18\tBash permissions bypassed' \
  "bypassPermissions docks the security axis hardest"
assert_contains "$Gbad" $'GRADE-AXIS\tmodel\t-12\ton a superseded tier' \
  "a Claude 3.x model docks the model axis as superseded debt"

# ── on-demand files (slash-commands / subagents) are NOT always-loaded ──
# Regression: counting every .claude/{commands,agents}/*.md BODY as an always-loaded
# FILE summed dozens of on-demand files into a phantom 30k+ "always-loaded" load and
# pinned the grade to F. They must emit ONDEMAND (excluded from the per-turn sum and
# the grade); only their registry frontmatter is a per-turn CONTEXT-TAX.
sb_od="$(make_sandbox)"; rod="$sb_od/repo"; mkdir -p "$rod/.claude/commands" "$rod/.claude/agents"
printf '# Lean\nUse tabs.\n' > "$rod/CLAUDE.md"
printf '{ "model": "claude-opus-4-8" }\n' > "$rod/.claude/settings.json"
i=1; while [ "$i" -le 20 ]; do
  { printf -- '---\nname: cmd%s\ndescription: does thing %s\n---\n' "$i" "$i"; head -c 1500 /dev/zero | tr '\0' x; printf '\n'; } > "$rod/.claude/commands/cmd$i.md"
  i=$((i + 1))
done
i=1; while [ "$i" -le 18 ]; do
  { printf -- '---\nname: ag%s\ndescription: agent %s\n---\n' "$i" "$i"; head -c 1500 /dev/zero | tr '\0' x; printf '\n'; } > "$rod/.claude/agents/ag$i.md"
  i=$((i + 1))
done
Hod="$(HOME="$sb_od" "$AU" harness --repo "$rod")"
assert_contains "$Hod" "ONDEMAND	$rod/.claude/commands/cmd1.md" "a slash-command body emits ONDEMAND"
assert_contains "$Hod" "ONDEMAND	$rod/.claude/agents/ag1.md"   "a subagent body emits ONDEMAND"
assert_not_contains "$Hod" "FILE	$rod/.claude/commands/cmd1.md" "a slash-command is NOT an always-loaded FILE"
assert_not_contains "$Hod" "FILE	$rod/.claude/agents/ag1.md"   "a subagent is NOT an always-loaded FILE"
assert_contains "$Hod" $'CONTEXT-TAX\tregistry\trepo\t38\t' "harness reports the repo-scope registry frontmatter tax (38 on-demand files)"
# the grade is NOT inflated by ~57k bytes of on-demand bodies: context axis stays 0, no F.
# (static-config grade → identical with or without transcripts; a fresh clone grades the same.)
God="$(HOME="$sb_od" "$AU" grade --repo "$rod")"
assert_contains "$God" $'GRADE-AXIS\tcontext\t0\t0.0k always-loaded tokens' \
  "on-demand bodies are excluded from the grade's always-loaded context (no phantom F)"
case "$God" in *"	F	"*) od_f=yes ;; *) od_f=no ;; esac
assert_eq "no" "$od_f" "a lean repo with many commands/subagents does NOT grade F"
# ONDEMAND bodies are still scanned for prompt debt (puffery in a subagent → HIT)
sb_od2="$(make_sandbox)"; rod2="$sb_od2/repo"; mkdir -p "$rod2/.claude/agents"
printf '# P\nUse tabs.\n' > "$rod2/CLAUDE.md"
printf -- '---\nname: rev\ndescription: reviewer\n---\nYou are a senior expert engineer with deep experience.\n' > "$rod2/.claude/agents/rev.md"
Hod2="$(HOME="$sb_od2" "$AU" harness --repo "$rod2")"
assert_contains "$Hod2" "ONDEMAND	$rod2/.claude/agents/rev.md" "the subagent emits ONDEMAND"
assert_contains "$Hod2" "	role-puffery	" "an ONDEMAND subagent body is still scanned for prompt debt"

# ── always-loaded context tax lives in HARNESS (static), split by install scope ──
# Skills + command/subagent registry frontmatter is always-loaded; it's static config,
# so it's emitted by `harness` (reports on a fresh clone, transcript-independent) and
# split repo→📦 project / user→💻 local so the two-grade scorecard stays scope-clean.
sb_tx="$(make_sandbox)"; rtx="$sb_tx/repo"
mkdir -p "$rtx/.claude/commands" "$rtx/.claude/skills/reposkill" \
         "$sb_tx/.claude/commands" "$sb_tx/.claude/skills/userskill"
printf '# P\nUse tabs.\n' > "$rtx/CLAUDE.md"
printf -- '---\nname: rc\ndescription: a repo command\n---\nbody\n' > "$rtx/.claude/commands/rc.md"
printf -- '---\nname: reposkill\ndescription: a repo-scope skill\n---\nbody\n' > "$rtx/.claude/skills/reposkill/SKILL.md"
printf -- '---\nname: uc\ndescription: a user command\n---\nbody\n' > "$sb_tx/.claude/commands/uc.md"
printf -- '---\nname: userskill\ndescription: a global skill\n---\nbody\n' > "$sb_tx/.claude/skills/userskill/SKILL.md"
Htx="$(HOME="$sb_tx" "$AU" harness --repo "$rtx")"
assert_contains "$Htx" $'CONTEXT-TAX\tregistry\trepo\t1\t'  "repo-scope command registry tax → 📦 project context"
assert_contains "$Htx" $'CONTEXT-TAX\tregistry\tuser\t1\t'  "user-scope command registry tax → 💻 local context"
assert_contains "$Htx" $'CONTEXT-TAX\tskills\trepo\t1\t'    "repo-scope skill frontmatter tax → 📦 project context"
assert_contains "$Htx" $'CONTEXT-TAX\tskills\tuser\t1\t'    "user-scope skill frontmatter tax → 💻 local context"
assert_contains "$Htx" $'SKILL-TAX\treposkill\trepo\t'      "per-skill SKILL-TAX carries its install scope (repo)"
assert_contains "$Htx" $'SKILL-TAX\tuserskill\tuser\t'      "per-skill SKILL-TAX carries its install scope (user)"
assert_contains "$Htx" "key=skill-context-tax-repo"        "scoped CONTEXT-TAX keys are scope-suffixed"
assert_contains "$Htx" "key=registry-context-tax-user"     "scoped CONTEXT-TAX keys are scope-suffixed"
# it does NOT depend on transcripts (the whole reason for the move): a fresh clone reports it
assert_contains "$Htx" $'CONTEXT-TAX\tskills\trepo\t' "the context tax reports without any transcripts (fresh clone)"

# ── grade is split: PROJECT (checked-in) vs LOCAL (your machine harness) ──
# Local config must NOT move the project grade (it's a reproducible property of the
# repo); project config must NOT move the local grade. That separation is the point.
sb_sc="$(make_sandbox)"; rsc="$sb_sc/repo"; mkdir -p "$rsc/.claude" "$sb_sc/.claude"
printf '# Lean\nUse tabs.\n' > "$rsc/CLAUDE.md"
head -c 60000 /dev/zero | tr '\0' x > "$sb_sc/.claude/CLAUDE.md"   # bloated GLOBAL memory file → LOCAL
printf '{ "permissions": { "defaultMode": "bypassPermissions" } }\n' > "$sb_sc/.claude/settings.json"  # GLOBAL bypass → LOCAL
Gsc="$(HOME="$sb_sc" "$AU" grade --repo "$rsc")"
assert_contains "$Gsc" $'GRADE-LOCAL\t' "grade emits a separate local-harness grade"
for ax in context model security deps rails; do
  assert_contains "$Gsc" "GRADE-AXIS-LOCAL	$ax	" "local grade emits the $ax axis row"
done
assert_contains "$Gsc" $'GRADE-AXIS-LOCAL\tsecurity\t-18\tBash permissions bypassed' \
  "global ~/.claude bypassPermissions docks the LOCAL security axis"
assert_contains "$Gsc" $'GRADE-AXIS-LOCAL\tcontext\t-9\t' \
  "a heavy ~/.claude/CLAUDE.md docks the LOCAL context axis"
assert_contains "$Gsc" $'GRADE-AXIS-LOCAL\trails\t0\tn/a' \
  "rails are a repo property — n/a on the local harness grade"
# the PROJECT grade is untouched by all that local debt
assert_contains "$Gsc" $'GRADE-AXIS\tcontext\t0\t0.0k' "local memory bloat does NOT inflate the project context axis"
assert_contains "$Gsc" $'GRADE-AXIS\tsecurity\t0\t' "a global bypass does NOT dock the project security axis"
assert_contains "$Gsc" $'GRADE\tA\t' "local-harness debt does not pull the project grade out of the A band"
# model scope: a transcript-only model is the one YOU run → LOCAL, not project
sb_md="$(make_sandbox)"; rmd="$sb_md/repo"; mkdir -p "$rmd/.claude"
printf '# P\nUse tabs.\n' > "$rmd/CLAUDE.md"
mdkey="$(printf '%s' "$rmd" | sed 's/[^A-Za-z0-9]/-/g')"; mdproj="$sb_md/.claude/projects/$mdkey"; mkdir -p "$mdproj"
printf '{"message":{"model":"claude-opus-4-1-20250805"}}\n' > "$mdproj/s.jsonl"
Gmd="$(HOME="$sb_md" "$AU" grade --repo "$rmd")"
assert_contains "$Gmd" $'GRADE-AXIS\tmodel\t0\t' "an un-pinned repo keeps the PROJECT model axis clean"
assert_contains "$Gmd" $'GRADE-AXIS-LOCAL\tmodel\t-12\ton a superseded tier' \
  "the model you actually run (transcript) docks the LOCAL model axis, not the project"

# ── unknown subcommand → exit 1 ───────────────────────────────
HOME="$sb" "$AU" bogus >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "unknown subcommand → exit 1"

t_done
