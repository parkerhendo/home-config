#!/usr/bin/env bash
# test/preamble.test.sh — extracts the "## Preamble" bash block from the SHIPPED
# SKILL.md and runs it sandboxed. This verifies the extracted bash logic; that a
# harness actually executes the block is covered by the manual E2E checklist in
# the plan, not here.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

# Extract the first ```bash block under the "## Preamble" heading.
PREAMBLE="$(awk '
  /^## Preamble/                 { inpre = 1 }
  inpre && /^```bash/            { incode = 1; next }
  inpre && incode && /^```/      { exit }
  inpre && incode               { print }
' "$SKILL_DIR/SKILL.md")"

assert_contains "$PREAMBLE" "HEADER_INSTALL:" "preamble bash block extracted from SKILL.md"

# run_preamble <skill_dir_token> <home> [EXTRA_ENV=val ...]
# Substitutes {SKILL_DIR}, runs the block in a clean env, returns stdout+stderr.
run_preamble() {
  local sdir="$1" home="$2"; shift 2
  local block
  block="$(printf '%s' "$PREAMBLE" | sed "s|{SKILL_DIR}|$sdir|g")"
  env -i PATH="$PATH" HOME="$home" HEADER_HOME="$home/.header" "$@" bash -c "$block" 2>&1
}

# ── install missing: nothing resolves ─────────────────────────
sb="$(make_sandbox)"
out="$(run_preamble "$sb/nope" "$sb")"
assert_contains "$out" "HEADER_INSTALL: missing" "no bin/ anywhere → HEADER_INSTALL: missing"
assert_contains "$out" "HEADER_NOTICE:" "missing install prints the reinstall notice"

# ── install ok via {SKILL_DIR} ────────────────────────────────
sb="$(make_sandbox)"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "HEADER_INSTALL: ok" "{SKILL_DIR} with bin/ → HEADER_INSTALL: ok"
assert_contains "$out" "HEADER_BIN: $SKILL_DIR/bin/header-config" "HEADER_BIN echoes the resolved header-config path"
assert_eq "yes" "$([ -d "$sb/.header" ] && echo yes || echo no)" "ok install creates ~/.header"

# ── install ok via a hardcoded fallback path ──────────────────
sb="$(make_sandbox)"
mkdir -p "$sb/.claude/skills/header/bin"
cp "$SKILL_DIR/bin/header-config" "$sb/.claude/skills/header/bin/header-config"
chmod +x "$sb/.claude/skills/header/bin/header-config"
out="$(run_preamble "$sb/bogus-not-real" "$sb")"
assert_contains "$out" "HEADER_INSTALL: ok" "fallback path ~/.claude/skills/header → ok"

# ── self-heal: bin/ present but not executable (Codex/npx GitHub download) ──
sb="$(make_sandbox)"
mkdir -p "$sb/.claude/skills/header"
cp -R "$SKILL_DIR/bin" "$sb/.claude/skills/header/bin"
for _f in "$sb/.claude/skills/header/bin/"*; do chmod -x "$_f" 2>/dev/null; done
out="$(run_preamble "$sb/bogus-not-real" "$sb")"
assert_contains "$out" "HEADER_SELFHEAL:" "non-executable bin/ is chmod-repaired in the preamble"
assert_contains "$out" "HEADER_INSTALL: ok" "self-heal makes an exec-bit-stripped install resolve ok"
assert_eq "yes" "$([ -x "$sb/.claude/skills/header/bin/header-config" ] && echo yes || echo no)" \
  "self-heal leaves header-config executable on disk"

# ── HEADER_STATE: writable vs sandbox-readonly ────────────────
sb="$(make_sandbox)"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "HEADER_STATE: ok" \
  "writable HEADER_HOME → HEADER_STATE: ok"
if [ "$(id -u)" != "0" ]; then   # root bypasses file perms — skip the negative case
  sb="$(make_sandbox)"; mkdir -p "$sb/.header"; chmod 500 "$sb/.header"
  out="$(run_preamble "$SKILL_DIR" "$sb")"
  assert_contains "$out" "HEADER_STATE: readonly" "unwritable HEADER_HOME → HEADER_STATE: readonly"
  assert_contains "$out" "HEADER_NOTICE:" "readonly state prints the actionable remedy"
  chmod 700 "$sb/.header" 2>/dev/null || true
fi

# ── interactivity — ★ non-interactive regression ──────────────
sb="$(make_sandbox)"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "INTERACTIVE: yes" "no CI / HEADER_NONINTERACTIVE → interactive"
out="$(run_preamble "$SKILL_DIR" "$sb" CI=1)"
assert_contains "$out" "INTERACTIVE: no" "★ CI=1 → non-interactive (scheduled-run guard holds)"
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_NONINTERACTIVE=1)"
assert_contains "$out" "INTERACTIVE: no" "★ HEADER_NONINTERACTIVE=1 → non-interactive"

# ── config values echoed (env > config > default) ─────────────
sb="$(make_sandbox)"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "LANGUAGE: English" "LANGUAGE echoed — default English"
assert_contains "$out" "STALENESS_DAYS: 7" "STALENESS_DAYS echoed — default 7"
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_LANGUAGE=Klingon)"
assert_contains "$out" "LANGUAGE: Klingon" "HEADER_LANGUAGE env overrides the default"

# ── REPO_TOPIC (per-repo binding) ─────────────────────────────
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "REPO_TOPIC:" \
  "REPO_TOPIC echoed (empty when this repo has no binding)"
printf '{"key":"k1","topic":"bound-xyz","name":"X"}\n' > "$sb/.header/repos.jsonl"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_REPO_KEY=k1)" "REPO_TOPIC: bound-xyz" \
  "REPO_TOPIC echoes the topic bound to this repo"

# ── markers ───────────────────────────────────────────────────
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "WELCOME_SEEN: no" "no marker → WELCOME_SEEN: no"
assert_contains "$out" "LANGUAGE_PROMPTED: no" "no marker → LANGUAGE_PROMPTED: no"
assert_contains "$out" "SIGNUP_STATE: unset" "no .signup-state file → SIGNUP_STATE: unset"
assert_contains "$out" "TELEMETRY_PROMPTED: no" "no marker → TELEMETRY_PROMPTED: no"
touch "$sb/.header/.welcome-seen"
touch "$sb/.header/.language-prompted"
printf 'public-only\n' > "$sb/.header/.signup-state"
touch "$sb/.header/.telemetry-prompted"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "WELCOME_SEEN: yes" ".welcome-seen marker → WELCOME_SEEN: yes"
assert_contains "$out" "LANGUAGE_PROMPTED: yes" ".language-prompted marker → LANGUAGE_PROMPTED: yes"
assert_contains "$out" "SIGNUP_STATE: public-only" ".signup-state value echoed"
assert_contains "$out" "TELEMETRY_PROMPTED: yes" ".telemetry-prompted marker → TELEMETRY_PROMPTED: yes"

# ── HAS_KEY ───────────────────────────────────────────────────
sb="$(make_sandbox)"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "HAS_KEY: no" \
  "no key anywhere → HAS_KEY: no"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_API_KEY=hdr_sk_x)" "HAS_KEY: yes" \
  "HEADER_API_KEY env → HAS_KEY: yes"
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
printf 'HEADER_API_KEY=hdr_sk_fromfile\n' > "$sb/.header/credentials"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "HAS_KEY: yes" \
  "credentials file containing a key → HAS_KEY: yes"

# ── ENRICH_MODE / ACCOUNT / AUTO_REGISTER (anonymous-onboarding signals) ──
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
out="$(run_preamble "$SKILL_DIR" "$sb")"
assert_contains "$out" "ACCOUNT: none"        "no account → ACCOUNT: none"
assert_contains "$out" "AUTO_REGISTER: true"  "AUTO_REGISTER default true"
assert_contains "$out" "ENRICH_MODE: unset"   "ENRICH_MODE unset by default"
assert_contains "$out" "CLAIM_NUDGED: no"     "CLAIM_NUDGED no by default"
touch "$sb/.header/.claim-nudged"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "CLAIM_NUDGED: yes" ".claim-nudged marker → CLAIM_NUDGED: yes"

# global enrich_mode default folds in when this repo has no per-repo value
HEADER_HOME="$sb/.header" "$SKILL_DIR/bin/header-config" set enrich_mode generic >/dev/null
assert_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_REPO_KEY=nomode)" "ENRICH_MODE: generic" \
  "global enrich_mode default echoed when no per-repo value"

# per-repo enrich-mode wins over the global default
HEADER_HOME="$sb/.header" HEADER_REPO_KEY=erk "$SKILL_DIR/bin/header-repo" enrich-mode custom
assert_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_REPO_KEY=erk)" "ENRICH_MODE: custom" \
  "per-repo enrich-mode overrides the global default"

# AUTO_REGISTER opt-out echoed
HEADER_HOME="$sb/.header" "$SKILL_DIR/bin/header-config" set auto_register false >/dev/null
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "AUTO_REGISTER: false" "auto_register false echoed"

# an anonymous .account → ACCOUNT: anonymous-unclaimed
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
printf '{"account_id":"a","anonymous":true,"claimed":false,"tier":"trial","trial_ends_at":"","claim_url":"u"}\n' \
  > "$sb/.header/.account"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb")" "ACCOUNT: anonymous-unclaimed" \
  "an anonymous .account → ACCOUNT: anonymous-unclaimed"

# ── credentials file is parsed, never sourced/executed ────────
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
printf 'HEADER_API_KEY=hdr_sk_x\necho PWNED_BY_SOURCE\n' > "$sb/.header/credentials"
assert_not_contains "$(run_preamble "$SKILL_DIR" "$sb")" "PWNED" \
  "credentials file is read as data — never sourced or executed"

# ── team config layer (committed .header/config) ──────────────
# All cases pin HEADER_TEAM_DIR so the real checkout's git toplevel is never read.
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_TEAM_DIR="$sb/empty")"
assert_contains "$out" "TEAM_CONFIG: none"        "no committed .header/config → TEAM_CONFIG: none"
assert_contains "$out" "TEAM_CONFIG_OFFERED: no"  "TEAM_CONFIG_OFFERED echoed (no by default)"

# committed team file → topic surfaced; staleness + language folded in
tr_="$sb/teamrepo"; mkdir -p "$tr_/.header"
printf 'default_topic: team-uuid-123\nstaleness_days: 21\nlanguage: Spanish\n' > "$tr_/.header/config"
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_TEAM_DIR="$tr_")"
assert_contains "$out" "TEAM_CONFIG: $tr_/.header/config" "TEAM_CONFIG echoes the committed file path"
assert_contains "$out" "TEAM_TOPIC: team-uuid-123" "TEAM_TOPIC echoes the committed default_topic"
assert_contains "$out" "STALENESS_DAYS: 21" "team staleness_days folds into STALENESS_DAYS"
assert_contains "$out" "LANGUAGE: Spanish"  "team language folds into LANGUAGE"

# env var still wins over the team layer
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_TEAM_DIR="$tr_" HEADER_STALENESS_DAYS=3)"
assert_contains "$out" "STALENESS_DAYS: 3" "env HEADER_STALENESS_DAYS overrides the team layer"

# team layer wins over the personal config
HEADER_HOME="$sb/.header" "$SKILL_DIR/bin/header-config" set staleness_days 5
out="$(run_preamble "$SKILL_DIR" "$sb" HEADER_TEAM_DIR="$tr_")"
assert_contains "$out" "STALENESS_DAYS: 21" "team staleness_days wins over personal config"

# ── update check surfaces actionable states (injected endpoint) ─
sb="$(make_sandbox)"
assert_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_VERSION_JSON='{"latest":"99.0.0"}')" \
  "UPDATE_CHECK: UPDATE_AVAILABLE" "preamble surfaces an available update"
sb="$(make_sandbox)"
_lv="$(tr -d '[:space:]' < "$SKILL_DIR/VERSION")"
assert_not_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_VERSION_JSON="{\"latest\":\"$_lv\"}")" \
  "UPDATE_CHECK:" "preamble stays quiet when up to date"
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$SKILL_DIR/bin/header-config" set update_check false
assert_not_contains "$(run_preamble "$SKILL_DIR" "$sb" HEADER_VERSION_JSON='{"latest":"99.0.0"}')" \
  "UPDATE_CHECK:" "update_check=false → preamble surfaces nothing"

t_done
