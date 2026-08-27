#!/usr/bin/env bash
# test/telemetry.test.sh — bin/header-telemetry. No network: tier-gating and the
# strip-before-send logic are checked via `sync --dry-run`. HEADER_TELEMETRY_NOSYNC
# stops `log` from firing a real background sync.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

TM="$SKILL_DIR/bin/header-telemetry"
HC="$SKILL_DIR/bin/header-config"
export HEADER_TELEMETRY_NOSYNC=1

# ── off (default) → no-op ─────────────────────────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$TM" log skill_run --outcome success
assert_eq "no" "$([ -s "$sb/.header/telemetry.jsonl" ] && echo yes || echo no)" \
  "telemetry off (default) → nothing logged"
assert_eq "" "$(HEADER_HOME="$sb/.header" "$TM" sync --dry-run)" \
  "off → sync is a no-op"

# ── anonymous → logs locally; send strips local-only + id ─────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set telemetry anonymous
HEADER_HOME="$sb/.header" "$TM" log skill_run --outcome success --path default --recs-surfaced 3 --recs-applied 1
log="$(cat "$sb/.header/telemetry.jsonl")"
assert_contains "$log" '"event":"skill_run"' "anonymous → event logged locally"
assert_contains "$log" '"_repo"' "local log keeps _repo (local-only)"
dry="$(HEADER_HOME="$sb/.header" "$TM" sync --dry-run)"
assert_contains "$dry" '"event":"skill_run"' "sent batch includes the event"
assert_contains "$dry" '"recs_surfaced":"3"' "sent batch includes usage metadata"
assert_not_contains "$dry" '_repo' "sent batch strips _repo — project data never leaves"
assert_not_contains "$dry" '_branch' "sent batch strips _branch"
assert_not_contains "$dry" 'installation_id' "anonymous batch strips installation_id"

# ── full → stable installation id, kept on send ───────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set telemetry full
HEADER_HOME="$sb/.header" "$TM" log skill_run --outcome success
assert_eq "yes" "$([ -f "$sb/.header/installation-id" ] && echo yes || echo no)" \
  "full → installation-id generated"
dry="$(HEADER_HOME="$sb/.header" "$TM" sync --dry-run)"
assert_contains "$dry" 'installation_id' "full batch keeps installation_id"
assert_not_contains "$dry" '_repo' "full batch still strips _repo"

# ── event_id (idempotency key) on every event ─────────────────
sb="$(make_sandbox)"
HEADER_HOME="$sb/.header" "$HC" set telemetry anonymous
HEADER_HOME="$sb/.header" "$TM" log skill_run --outcome success
assert_contains "$(cat "$sb/.header/telemetry.jsonl")" '"event_id"' "events carry an event_id locally"
assert_contains "$(HEADER_HOME="$sb/.header" "$TM" sync --dry-run)" '"event_id"' "event_id is sent in the batch"

# ── batch capped at 100 events ────────────────────────────────
sb="$(make_sandbox)"; mkdir -p "$sb/.header"
HEADER_HOME="$sb/.header" "$HC" set telemetry anonymous
i=0; while [ "$i" -lt 101 ]; do
  printf '{"v":1,"event_id":"e%s","ts":"t","event":"skill_run","version":"x","os":"x","outcome":"success"}\n' "$i" >> "$sb/.header/telemetry.jsonl"
  i=$((i + 1))
done
n="$(HEADER_HOME="$sb/.header" "$TM" sync --dry-run | grep -o '"event":"skill_run"' | wc -l | tr -d ' ')"
assert_eq "100" "$n" "sync sends at most 100 events per batch"

t_done
