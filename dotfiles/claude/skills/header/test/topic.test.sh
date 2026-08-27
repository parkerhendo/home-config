#!/usr/bin/env bash
# test/topic.test.sh — bin/header-topic. Deterministic topic create + bind + the
# briefing-status primitive. Hermetic: the POST/GET are stubbed via
# HEADER_TOPIC_STUB / HEADER_TOPIC_STATUS_STUB so no network is touched.
#
# The stub deliberately mirrors the REAL create response — the topic object nests
# `latest_briefing:{"id":…}`, so a naive "the only bare \"id\" is topic.id" parse
# grabs the wrong one. The suite pins topic.id = the FIRST id (the regression that
# bit the live dogfood: TOPIC_ID came back equal to the briefing id).
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HT="$SKILL_DIR/bin/header-topic"
RP="$SKILL_DIR/bin/header-repo"

# A create response shaped like prod: topic.id (TID-111) precedes the nested
# latest_briefing.id (BID-333), and first_briefing_id (BID-333) is a sibling.
mk_resp() {
  cat > "$1" <<'JSON'
{"topic":{"id":"TID-111-aaaa","name":"My Topic","description":"","owner_id":"acct_x","is_public":false,"created_at":"2026-07-07T00:00:00Z","updated_at":"2026-07-07T00:00:00Z","source_group_ids":["sg-1"],"default_goal_id":"GID-222-bbbb","default_goal_description":"...","keywords":[],"briefing_length":null,"source_count":1,"latest_briefing":{"id":"BID-333-cccc","status":"IN_PROGRESS","summary":""}},"first_briefing_id":"BID-333-cccc"}
JSON
}

# ── create: parses the nested ids correctly + binds topic.id ──
sb="$(make_sandbox)"; HH="$sb/.header"; mk_resp "$sb/resp.json"
out="$(env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_API_KEY=hdr_sk_x HEADER_REPO_KEY=r1 \
  HEADER_TOPIC_STUB="$sb/resp.json" "$HT" create --name "My Topic" --goal "some stack")"
assert_contains "$out" "TOPIC_ID TID-111-aaaa"   "topic.id is the FIRST id (not the nested briefing id)"
assert_not_contains "$out" "TOPIC_ID BID-333"    "topic.id must not be the briefing id (the live-dogfood bug)"
assert_contains "$out" "GOAL_ID GID-222-bbbb"    "default_goal_id parsed"
assert_contains "$out" "BRIEFING_ID BID-333-cccc" "first_briefing_id parsed (the poll target)"
assert_eq "TID-111-aaaa" "$(HEADER_HOME="$HH" HEADER_REPO_KEY=r1 "$RP" get)" \
  "create binds the TOPIC id to this repo (not the briefing id)"

# ── --no-bind: creates but leaves the binding untouched ──
sb="$(make_sandbox)"; HH="$sb/.header"; mk_resp "$sb/resp.json"
env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_API_KEY=hdr_sk_x HEADER_REPO_KEY=r2 \
  HEADER_TOPIC_STUB="$sb/resp.json" "$HT" create --no-bind --name N --goal G >/dev/null
assert_eq "" "$(HEADER_HOME="$HH" HEADER_REPO_KEY=r2 "$RP" get)" \
  "--no-bind creates without binding"

# ── no key → exit 2 ──
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb/empty" "$HT" create --name N --goal G >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "no API key → exit 2"

# ── tier gate (403 + flat error_code) → exit 3 + ERROR_CODE line ──
sb="$(make_sandbox)"; printf '{"error_code":"TOPIC_LIMIT_FREE","message":"Pro only"}' > "$sb/err.json"
rc=0; out="$(env -u HEADER_API_KEY HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x \
  HEADER_TOPIC_STUB="$sb/err.json" HEADER_TOPIC_STUB_CODE=403 "$HT" create --name N --goal G 2>/dev/null)" || rc=$?
assert_exit 3 "$rc" "tier-gate (403) → exit 3"
assert_contains "$out" "ERROR_CODE TOPIC_LIMIT_FREE" "surfaces the flat error_code for the trial/upgrade flow"

# ── missing required flags → exit 1 ──
rc=0; HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x "$HT" create --goal G >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "create without --name → exit 1"

# ── status: parses the briefing status word ──
sb="$(make_sandbox)"; printf '{"id":"b","status":"COMPLETED","summary":"x"}' > "$sb/st.json"
assert_eq "COMPLETED" \
  "$(HEADER_HOME="$sb/.header" HEADER_TOPIC_STATUS_STUB="$sb/st.json" "$HT" status b)" \
  "status parses COMPLETED"
printf '{"id":"b","status":"IN_PROGRESS"}' > "$sb/st.json"
assert_eq "IN_PROGRESS" \
  "$(HEADER_HOME="$sb/.header" HEADER_TOPIC_STATUS_STUB="$sb/st.json" "$HT" status b)" \
  "status parses IN_PROGRESS"
rc=0; HEADER_HOME="$sb/.header" HEADER_TOPIC_STATUS_STUB="$sb/st.json" "$HT" status >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "status without a briefing id → exit 1"

# ── await: resolves on COMPLETED / FAILED, guards no-key + missing arg ──
printf '{"id":"b","status":"COMPLETED"}' > "$sb/done.json"
out="$(HEADER_HOME="$sb/.header" HEADER_TOPIC_STATUS_STUB="$sb/done.json" "$HT" await b)"; rc=$?
assert_exit 0 "$rc" "await: COMPLETED → exit 0 (immediate, no sleep)"
assert_contains "$out" "AWAIT COMPLETED" "await: prints the completion marker"
printf '{"id":"b","status":"FAILED"}' > "$sb/fail.json"
rc=0; HEADER_HOME="$sb/.header" HEADER_TOPIC_STATUS_STUB="$sb/fail.json" "$HT" await b >/dev/null 2>&1 || rc=$?
assert_exit 5 "$rc" "await: FAILED → exit 5"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb/empty" "$HT" await b >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "await: no key → exit 2"
rc=0; HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x "$HT" await >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "await without a briefing id → exit 1"

# ── latest: nested latest_briefing + freshness compare ──
sb="$(make_sandbox)"; HH="$sb/.header"
cat > "$sb/topic.json" <<'JSON'
{"id":"TID-xyz","name":"My Topic","description":"","owner_id":"a","is_public":false,"created_at":"2026-06-15T00:00:00Z","updated_at":"2026-06-15T00:00:00Z","source_group_ids":["SG-1"],"default_goal_id":"GID-1","default_goal_description":"...","keywords":[],"source_count":1,"latest_briefing":{"id":"BID-9","status":"COMPLETED","generated_at":"2026-06-15T00:00:00Z","summary":"hi"}}
JSON
L() { env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_API_KEY=hdr_sk_x HEADER_REPO_KEY=lr \
  HEADER_TOPIC_GET_STUB="$sb/topic.json" "$HT" latest --topic TID-xyz; }
out="$(L)"
assert_contains "$out" "TOPIC_ID TID-xyz"      "latest: topic id (first id)"
assert_contains "$out" "BRIEFING_ID BID-9"     "latest: latest_briefing.id (nested, not topic id)"
assert_contains "$out" "GENERATED_AT 2026-06-15T00:00:00Z" "latest: generated_at from the nested briefing"
assert_contains "$out" "FRESH new"             "latest: no seen marker → FRESH new"
HEADER_HOME="$HH" HEADER_REPO_KEY=lr "$RP" seen "2026-06-01T00:00:00Z"
assert_contains "$(L)" "FRESH new"             "latest: seen older than briefing → FRESH new"
HEADER_HOME="$HH" HEADER_REPO_KEY=lr "$RP" seen "2026-07-01T00:00:00Z"
assert_contains "$(L)" "FRESH current"         "latest: seen newer than briefing → FRESH current"
printf '{"id":"T2","name":"n","default_goal_id":"g","latest_briefing":null}' > "$sb/topic.json"
out="$(L)"; assert_contains "$out" "FRESH none" "latest: null latest_briefing → FRESH none"
assert_not_contains "$out" "BRIEFING_ID"        "latest: no BRIEFING_ID when there's no briefing"

# ── generate: briefing id (first id) + numeric ETA ──
sb="$(make_sandbox)"
printf '{"id":"NEWBID-1","goal_id":"g","status":"IN_PROGRESS","estimated_duration_seconds":300,"source_count":5}' > "$sb/gen.json"
out="$(env -u HEADER_API_KEY HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x \
  HEADER_TOPIC_GET_STUB="$sb/gen.json" "$HT" generate GID-1)"
assert_contains "$out" "BRIEFING_ID NEWBID-1" "generate: briefing id parsed"
assert_contains "$out" "ETA_SECONDS 300"      "generate: numeric ETA parsed"

# ── dashboard: per-topic next_action from the custom_topics array ──
sb="$(make_sandbox)"
cat > "$sb/dash.json" <<'JSON'
{"custom_topics":[{"id":"DT-1","name":"a","latest_briefing":{"id":"lb1","status":"COMPLETED"},"next_action":"briefing_ready"},{"id":"DT-2","name":"b","latest_briefing":null,"next_action":"nothing"}],"subscribed_topics":[],"has_onboarded":true}
JSON
out="$(env -u HEADER_API_KEY HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x \
  HEADER_TOPIC_GET_STUB="$sb/dash.json" "$HT" dashboard)"
assert_contains "$out" "TOPIC DT-1 briefing_ready" "dashboard: topic id (first id, not nested lb1) + next_action"
assert_contains "$out" "TOPIC DT-2 nothing"        "dashboard: second topic parsed"
assert_not_contains "$out" "lb1"                    "dashboard: nested latest_briefing.id not mistaken for topic id"

# ── get / add-source: arg + key guards (live paths validated against prod) ──
rc=0; HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x "$HT" get >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "get without a briefing id → exit 1"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb/empty" "$HT" get b >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "get with no key → exit 2"
rc=0; HEADER_HOME="$sb/.header" HEADER_API_KEY=hdr_sk_x "$HT" add-source >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "add-source without a url → exit 1"
rc=0; env -u HEADER_API_KEY HEADER_HOME="$sb/empty" "$HT" add-source http://x >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "add-source with no key → exit 2"

# ── latest --public: a published TEAM_TOPIC resolves with NO key ──
# SKILL.md Step 0 case 3 probes a committed team topic over the public endpoint
# before ever claiming an API key is required. If the public path grew a need_key
# call, every keyless contributor to a repo that ships .header/config would
# silently fall through to the generic briefings. Pin both arms.
pub_sb="$(make_sandbox)"
cat > "$pub_sb/topic.json" <<'JSON'
{"id":"TID-pub","name":"Team Topic","is_public":true,"default_goal_id":"GID-1","latest_briefing":{"id":"BID-9","status":"COMPLETED","generated_at":"2026-06-15T00:00:00Z"}}
JSON
pub_out="$(env -u HEADER_API_KEY HEADER_HOME="$pub_sb/empty" \
  HEADER_TOPIC_GET_STUB="$pub_sb/topic.json" "$HT" latest --topic TID-pub --public)"; rc=$?
assert_exit 0 "$rc" "latest --public resolves with no key (published team topic)"
assert_contains "$pub_out" "BRIEFING_ID BID-9" "latest --public returns the briefing id keylessly"
# the authenticated arm still demands a key — the probe is the ONLY keyless path
rc=0; env -u HEADER_API_KEY HEADER_HOME="$pub_sb/empty" \
  HEADER_TOPIC_GET_STUB="$pub_sb/topic.json" "$HT" latest --topic TID-pub >/dev/null 2>&1 || rc=$?
assert_exit 2 "$rc" "latest without --public still requires a key (exit 2)"

# ── dispatch ──
HEADER_HOME="$HH" "$HT" --help >/dev/null 2>&1; assert_exit 0 "$?" "--help exits 0"
HEADER_HOME="$HH" "$HT" zzz >/dev/null 2>&1; assert_exit 1 "$?" "unknown subcommand exits 1"

# ── latest takes the topic id via --topic, never positionally ──
# `latest` has no positional arg: a bare id lands in the flag parser and exits 1.
rc=0; HEADER_HOME="$HH" "$HT" latest --public TID-xyz >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "latest with a positional topic id → exit 1 (unknown flag)"

# ── docs must not drift from that contract ──
# Regression: SKILL.md Step 1 and custom-briefings.md documented
# `latest --public <topic_id>`, which errors. Every copy-pasteable `latest`
# command in the docs must pass the topic id through --topic. Scans command
# lines only (prose may name the flags), with trailing #comments stripped.
_cmds="$(grep -rhE '^[[:space:]]*("<TOPIC>"|header-topic)[[:space:]]+latest' \
  "$SKILL_DIR/SKILL.md" "$SKILL_DIR/reference" 2>/dev/null | sed 's/#.*$//' || true)"
_bad="$(printf '%s\n' "$_cmds" | grep -E 'latest[[:space:]]+[^-[:space:]]|--public[[:space:]]+[^-[:space:]]' || true)"
assert_eq "" "$_bad" "no documented \`latest\` command passes the topic id positionally"

t_done
