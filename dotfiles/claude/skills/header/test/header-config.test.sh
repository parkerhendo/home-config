#!/usr/bin/env bash
# test/header-config.test.sh — unit tests for bin/header-config.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HC="$SKILL_DIR/bin/header-config"

# ── get: defaults (missing file) ──────────────────────────────
sb="$(make_sandbox)"
assert_eq "English" "$(HEADER_HOME="$sb/.header" "$HC" get language)" \
  "get language on missing file → default English"
assert_eq "7" "$(HEADER_HOME="$sb/.header" "$HC" get staleness_days)" \
  "get staleness_days on missing file → default 7"
assert_eq "" "$(HEADER_HOME="$sb/.header" "$HC" get default_topic)" \
  "get default_topic on missing file → empty default"
assert_eq "true" "$(HEADER_HOME="$sb/.header" "$HC" get update_check)" \
  "get update_check on missing file → default true"
assert_eq "false" "$(HEADER_HOME="$sb/.header" "$HC" get auto_update)" \
  "get auto_update on missing file → default false"
assert_eq "true" "$(HEADER_HOME="$sb/.header" "$HC" get ledger)" \
  "get ledger on missing file → default true"
assert_eq "off" "$(HEADER_HOME="$sb/.header" "$HC" get telemetry)" \
  "get telemetry on missing file → default off"
assert_eq "false" "$(HEADER_HOME="$sb/.header" "$HC" get auto_tune)" \
  "get auto_tune on missing file → default false"
assert_eq "true" "$(HEADER_HOME="$sb/.header" "$HC" get repo_memory)" \
  "get repo_memory on missing file → default true"
assert_eq "true" "$(HEADER_HOME="$sb/.header" "$HC" get auto_register)" \
  "get auto_register on missing file → default true"
assert_eq "" "$(HEADER_HOME="$sb/.header" "$HC" get enrich_mode)" \
  "get enrich_mode on missing file → empty default (ask per repo)"

# ── set then get; header written on first create ──────────────
HEADER_HOME="$sb/.header" "$HC" set language Turkish
assert_eq "Turkish" "$(HEADER_HOME="$sb/.header" "$HC" get language)" \
  "set then get language → Turkish"
assert_contains "$(cat "$sb/.header/config")" "Header skill config" \
  "first set writes the terse config header"

# ── overwrite an existing key (sed replace path) ──────────────
HEADER_HOME="$sb/.header" "$HC" set language Spanish
assert_eq "Spanish" "$(HEADER_HOME="$sb/.header" "$HC" get language)" \
  "overwrite language → Spanish"
assert_eq "1" "$(grep -c '^language:' "$sb/.header/config")" \
  "overwrite replaces in place — only one language line"

# ── new key appends ───────────────────────────────────────────
HEADER_HOME="$sb/.header" "$HC" set staleness_days 14
assert_eq "14" "$(HEADER_HOME="$sb/.header" "$HC" get staleness_days)" \
  "set new key staleness_days → 14"

# ── sed-metacharacter values round-trip (append + replace) ────
sb2="$(make_sandbox)"
HEADER_HOME="$sb2/.header" "$HC" set default_topic 'a/b&c\d'
assert_eq 'a/b&c\d' "$(HEADER_HOME="$sb2/.header" "$HC" get default_topic)" \
  "metachar value round-trips via the append path"
HEADER_HOME="$sb2/.header" "$HC" set default_topic 'x&y/z'
assert_eq 'x&y/z' "$(HEADER_HOME="$sb2/.header" "$HC" get default_topic)" \
  "metachar value round-trips via the sed-replace path"

# ── embedded newline → first line only ────────────────────────
HEADER_HOME="$sb2/.header" "$HC" set language "$(printf 'Line1\nLine2')"
assert_eq "Line1" "$(HEADER_HOME="$sb2/.header" "$HC" get language)" \
  "value with embedded newline → only first line stored"

# ── invalid keys → exit 1 ─────────────────────────────────────
HEADER_HOME="$sb2/.header" "$HC" get 'bad key' >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "get with invalid key → exit 1"
HEADER_HOME="$sb2/.header" "$HC" set 'bad-key' x >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "set with invalid key → exit 1"

# ── duplicate / malformed lines ───────────────────────────────
sb3="$(make_sandbox)"; mkdir -p "$sb3/.header"
printf 'language: First\nlanguage: Last\n' > "$sb3/.header/config"
assert_eq "Last" "$(HEADER_HOME="$sb3/.header" "$HC" get language)" \
  "duplicate key lines → last wins"
printf 'this is not a config line\nlanguage: Italian\n' > "$sb3/.header/config"
assert_eq "Italian" "$(HEADER_HOME="$sb3/.header" "$HC" get language)" \
  "malformed line ignored, real value still found"

# ── list / defaults ───────────────────────────────────────────
list_out="$(HEADER_HOME="$sb3/.header" "$HC" list)"
assert_contains "$list_out" "language:" "list shows the language key"
assert_contains "$list_out" "(set)"     "list marks file-set values as (set)"
def_out="$(HEADER_HOME="$sb3/.header" "$HC" defaults)"
assert_contains "$def_out" "staleness_days:" "defaults lists staleness_days"
assert_contains "$def_out" "default_topic:"  "defaults lists default_topic"
assert_contains "$def_out" "auto_update:"    "defaults lists auto_update"
assert_contains "$def_out" "update_check:"   "defaults lists update_check"
assert_contains "$def_out" "ledger:"         "defaults lists ledger"
assert_contains "$def_out" "telemetry:"      "defaults lists telemetry"
assert_contains "$def_out" "auto_tune:"      "defaults lists auto_tune"
assert_contains "$def_out" "repo_memory:"    "defaults lists repo_memory"

# ── unknown / missing subcommand → exit 1 ─────────────────────
"$HC" bogus >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "unknown subcommand → exit 1"
"$HC" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "no subcommand → exit 1"

# ── telemetry value is whitelisted (invalid → off) ────────────
sbT="$(make_sandbox)"
HEADER_HOME="$sbT/.header" "$HC" set telemetry bogus 2>/dev/null
assert_eq "off" "$(HEADER_HOME="$sbT/.header" "$HC" get telemetry)" \
  "set telemetry to an invalid value → coerced to off"
HEADER_HOME="$sbT/.header" "$HC" set telemetry anonymous
assert_eq "anonymous" "$(HEADER_HOME="$sbT/.header" "$HC" get telemetry)" \
  "set telemetry anonymous → anonymous"

# ── enrich_mode value is whitelisted (invalid → cleared) ──────
HEADER_HOME="$sbT/.header" "$HC" set enrich_mode custom
assert_eq "custom" "$(HEADER_HOME="$sbT/.header" "$HC" get enrich_mode)" \
  "set enrich_mode custom → custom"
HEADER_HOME="$sbT/.header" "$HC" set enrich_mode bogus 2>/dev/null
assert_eq "" "$(HEADER_HOME="$sbT/.header" "$HC" get enrich_mode)" \
  "set enrich_mode to an invalid value → cleared (ask per repo)"
# auto_register accepts false (the opt-out); any non-false enables
HEADER_HOME="$sbT/.header" "$HC" set auto_register false
assert_eq "false" "$(HEADER_HOME="$sbT/.header" "$HC" get auto_register)" \
  "auto_register false round-trips (the opt-out)"

# ── auto_register / enrich_mode are egress → refused in team config ──
sbE="$(make_sandbox)"
for bad in auto_register enrich_mode; do
  HEADER_HOME="$sbE/.header" HEADER_TEAM_DIR="$sbE/repo" "$HC" team-set "$bad" custom >/dev/null 2>&1; rc=$?
  assert_exit 1 "$rc" "team-set refuses the egress key '$bad'"
done

# ── team config: allow-list, block-list, isolation ────────────
# HEADER_TEAM_DIR pins the committed file to the sandbox so the real repo is
# never touched (git toplevel would otherwise resolve to this checkout).
sbt="$(make_sandbox)"; td="$sbt/repo"
TEAM() { HEADER_HOME="$sbt/.header" HEADER_TEAM_DIR="$td" "$HC" "$@"; }

assert_eq "" "$(TEAM team-get default_topic)" "team-get on a missing team file → empty"
assert_eq "" "$(TEAM team-path)"              "team-path is empty when no team file exists"

# team-init scaffolds with the topic; a hyphenated UUID is accepted
TEAM team-init 1991163f-be9c-4df2-a33c-046a4d1357e1 >/dev/null
assert_eq "1991163f-be9c-4df2-a33c-046a4d1357e1" "$(TEAM team-get default_topic)" \
  "team-init seeds default_topic (UUID with hyphens accepted)"
assert_eq "$td/.header/config" "$(TEAM team-path)" \
  "team-path points at the committed file once it exists"

# team-init refuses to clobber an existing file
TEAM team-init >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "team-init refuses to overwrite an existing team config"

# allow-listed keys round-trip; integers are validated
TEAM team-set staleness_days 14 >/dev/null
assert_eq "14" "$(TEAM team-get staleness_days)" "team-set staleness_days round-trips"
TEAM team-set staleness_days abc >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "team-set rejects a non-integer staleness_days"

# block-list: consent / code-exec keys are refused on write …
for bad in telemetry auto_update auto_tune update_check; do
  TEAM team-set "$bad" x >/dev/null 2>&1; rc=$?
  assert_exit 1 "$rc" "team-set refuses the personal-only key '$bad'"
done
# … and an unrecognized key is refused too
TEAM team-set bogus x >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "team-set refuses an unrecognized key"

# core security property: even if a committed file SETS a sensitive key by hand,
# team-get ignores it on read — only the allow-list is honored.
printf 'telemetry: full\nauto_update: true\nrepo_memory: false\n' >> "$td/.header/config"
assert_eq "" "$(TEAM team-get telemetry)"   "team-get ignores telemetry from a committed file"
assert_eq "" "$(TEAM team-get auto_update)" "team-get ignores auto_update from a committed file"
assert_eq "" "$(TEAM team-get repo_memory)" "team-get ignores a non-shareable key (repo_memory)"

# team-show surfaces honored values and flags the ignored sensitive ones
show="$(TEAM team-show)"
assert_contains "$show" "default_topic:"  "team-show lists an honored key"
assert_contains "$show" "telemetry: full" "team-show flags an ignored sensitive key"

# isolation: the team layer never leaks into the PERSONAL get surface. Personal
# staleness stays 5 even though the team file says 14 — precedence is resolved by
# the preamble / Step 0, not by `get`.
HEADER_HOME="$sbt/.header" "$HC" set staleness_days 5
assert_eq "5" "$(HEADER_HOME="$sbt/.header" "$HC" get staleness_days)" \
  "personal get is unaffected by the team config (team layering lives in the preamble)"

t_done
