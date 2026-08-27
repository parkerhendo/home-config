#!/usr/bin/env bash
# test/update-check.test.sh — bin/header-update-check against an injected version
# endpoint (HEADER_VERSION_JSON), so no network is touched. Version comparisons
# use the real local VERSION, so they survive version bumps.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

UC="$SKILL_DIR/bin/header-update-check"
HC="$SKILL_DIR/bin/header-config"
LOCAL="$(tr -d '[:space:]' < "$SKILL_DIR/VERSION")"

# ── disabled via config ───────────────────────────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set update_check false
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0"}' "$UC")"
assert_eq "" "$out" "update_check=false → no output"

# ── up to date (latest == local) ──────────────────────────────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON="{\"latest\":\"$LOCAL\"}" "$UC")"
assert_eq "UP_TO_DATE $LOCAL" "$out" "latest == local → UP_TO_DATE"

# ── update available (latest > local) ─────────────────────────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0"}' "$UC")"
assert_eq "UPDATE_AVAILABLE $LOCAL 99.0.0" "$out" "latest > local → UPDATE_AVAILABLE"

# ── update required (local < min_supported) takes priority ─────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0","min_supported":"99.0.0"}' "$UC")"
assert_eq "UPDATE_REQUIRED $LOCAL 99.0.0" "$out" "local < min_supported → UPDATE_REQUIRED (priority)"

# ── min present but satisfied → just AVAILABLE ─────────────────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0","min_supported":"0.0.1"}' "$UC")"
assert_eq "UPDATE_AVAILABLE $LOCAL 99.0.0" "$out" "local >= min_supported → AVAILABLE, not REQUIRED"

# ── unreachable endpoint → fail-safe UP_TO_DATE, exit 0 ───────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_URL='file:///nonexistent/header-version' "$UC")"; rc=$?
assert_eq "UP_TO_DATE $LOCAL" "$out" "unreachable endpoint → fail-safe UP_TO_DATE"
assert_exit 0 "$rc" "unreachable endpoint → exit 0 (never breaks the briefing)"

# ── malformed latest → UP_TO_DATE ─────────────────────────────
sb="$(make_sandbox)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"not-a-version"}' "$UC")"
assert_eq "UP_TO_DATE $LOCAL" "$out" "malformed latest → UP_TO_DATE"

# ── raw response cached for the update flow ───────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0","notes_url":"https://joinheader.com/changelog"}' "$UC" >/dev/null
assert_contains "$(cat "$sb/.header/version-info.json" 2>/dev/null)" "notes_url" \
  "raw version info cached to version-info.json"

# ── fresh cache replays; --force bypasses it ──────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0"}' "$UC" >/dev/null
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON="{\"latest\":\"$LOCAL\"}" "$UC")"
assert_contains "$out" "UPDATE_AVAILABLE" "fresh cache replays (no refetch)"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON="{\"latest\":\"$LOCAL\"}" "$UC" --force)"
assert_eq "UP_TO_DATE $LOCAL" "$out" "--force bypasses cache and refetches"

# ── snooze: AVAILABLE goes quiet, REQUIRED ignores it ─────────
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
printf '99.0.0 1 %s\n' "$(date +%s)" > "$sb/.header/update-snoozed"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0"}' "$UC")"
assert_eq "" "$out" "snoozed UPDATE_AVAILABLE → quiet"

sb="$(make_sandbox)"; mkdir -p "$sb/.header"
printf '99.0.0 1 %s\n' "$(date +%s)" > "$sb/.header/update-snoozed"
out="$(HEADER_HOME="$sb/.header" HEADER_VERSION_JSON='{"latest":"99.0.0","min_supported":"99.0.0"}' "$UC")"
assert_contains "$out" "UPDATE_REQUIRED" "UPDATE_REQUIRED ignores snooze"

t_done
