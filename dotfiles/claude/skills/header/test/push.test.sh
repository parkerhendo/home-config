#!/usr/bin/env bash
# test/push.test.sh — unit tests for `header-experiment push` (cloud sync).
#
# No network: exercises --dry-run payload assembly, lineage recovery from the
# ledger, the privacy contract (task BODIES never leave), kind inference, the
# task-title resolution chain, and the no-key opt-out gate. The live POST is
# thin glue over curl and needs a server, so it is out of scope here.
#
# HEADER_HOME is pinned to a sandbox so nothing touches the real ~/.header.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HE="$SKILL_DIR/bin/header-experiment"
sb="$(make_sandbox)"
HH="$sb/.header"
mkdir -p "$sb/myrepo"          # a (non-git) repo path the specs point at
CFG="$SKILL_DIR/bin/header-config"
PUSH() { HEADER_HOME="$HH" "$HE" push "$@"; }
# Lifecycle commands with auto-sync hard-disabled (no network, no recommend).
EXP() { HEADER_HOME="$HH" HEADER_EXPERIMENT_NOSYNC=1 "$HE" "$@"; }
# Lifecycle with NO key present → auto-sync takes the "recommend an account" path
# (still no network — a missing key short-circuits before any curl).
EXP_NOKEY() { env -u HEADER_API_KEY HEADER_HOME="$HH" "$HE" "$@"; }

# mk_spec <id> — create experiment dir + read a full spec from stdin.
mk_spec() { local id="$1"; mkdir -p "$HH/experiments/$id/tasks"; cat > "$HH/experiments/$id/spec"; }

# ── 1. model-swap, no hypothesis, no result ──────────────────────
printf '# Refactor the token parser\nsecret-impl-detail-xyz stays on the machine\n' \
  > /dev/null   # (written per-experiment below)
mk_spec swap <<EOF
id: swap
description: opus vs sonnet
repo: $sb/myrepo
commit: HEAD
replicates: 3
non_inferiority_margin: 0.02

[arm:A]
model: claude-opus-4-7
overrides_dir:

[arm:B]
model: claude-sonnet-4-6
overrides_dir:

[task:t1]
prompt: tasks/t1.md
verify: npm test
timeout_s: 600
EOF
printf '# Refactor the token parser\nsecret-impl-detail-xyz stays on the machine\n' \
  > "$HH/experiments/swap/tasks/t1.md"

out="$(PUSH swap --dry-run 2>/dev/null)"
assert_contains "$out" '"client_key"'           "payload has client_key"
assert_contains "$out" '"experiment"'           "payload has experiment block"
assert_contains "$out" '"audit_basis"'          "payload has audit_basis block"
assert_contains "$out" '"repo"'                 "payload has repo block"
assert_contains "$out" '"machine"'              "payload has machine block"
assert_contains "$out" '"kind": "model-swap"'   "two distinct models → kind=model-swap"
assert_contains "$out" '"statement":"opus vs sonnet"' "no hypothesis: field → statement falls back to description"
assert_contains "$out" '"ledger_key":""'        "no finding → hypothesis provenance ledger_key blank"
assert_contains "$out" '"result": null'         "not analyzed → result null"
assert_contains "$out" '"status": "defined"'    "no runs/result → status defined"

# Privacy contract: the derived TITLE (first heading) may appear; the BODY must not.
assert_contains     "$out" "Refactor the token parser"  "first-line heading becomes the task title"
assert_not_contains "$out" "secret-impl-detail-xyz"     "task BODY never leaves the machine"
assert_contains     "$out" '"title_source":"derived"'   "title derived from prompt when not authored"
assert_contains     "$out" '"prompt_sha256":"'          "prompt identified by sha256, not body"

# Valid JSON (if python available).
if command -v python3 >/dev/null 2>&1; then
  pj="$(printf '%s\n' "$out" | sed '/^#/d; /^[[:space:]]*$/d' | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")' 2>/dev/null || echo fail)"
  assert_eq "ok" "$pj" "dry-run payload is valid JSON"
fi

# ── 2. harness-change kind (same model, arm B has overrides) ─────
mk_spec harness <<EOF
id: harness
description: trim CLAUDE.md
repo: $sb/myrepo
commit: HEAD
replicates: 3
non_inferiority_margin: 0.02

[arm:A]
model:
overrides_dir:

[arm:B]
model:
overrides_dir: arms/B

[task:t1]
prompt: tasks/t1.md
verify: true
timeout_s: 600
EOF
echo "do the thing" > "$HH/experiments/harness/tasks/t1.md"
out="$(PUSH harness --dry-run 2>/dev/null)"
assert_contains "$out" '"kind": "harness-change"' "same model + overrides → kind=harness-change"
assert_contains "$out" '"overrides":"arms/B"'     "arm B overrides path carried (not contents)"

# ── 3. authored title beats derived; missing prompt → id floor ───
mk_spec titles <<EOF
id: titles
description: title resolution
repo: $sb/myrepo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02

[arm:A]
model: m
overrides_dir:

[arm:B]
model: m
overrides_dir:

[task:t1]
prompt: tasks/t1.md
verify: true
title: Authored human label
timeout_s: 600

[task:t2]
prompt: tasks/does-not-exist.md
verify: true
timeout_s: 600
EOF
echo "# ignored because authored title wins" > "$HH/experiments/titles/tasks/t1.md"
out="$(PUSH titles --dry-run 2>/dev/null)"
assert_contains "$out" '"title":"Authored human label","title_source":"authored"' "authored title used verbatim"
assert_contains "$out" '"title":"t2","title_source":"id"' "missing prompt → task id is the title floor"

# ── 4. hypothesis + audit_basis recovered from the ledger ────────
cat > "$HH/ledger.jsonl" <<EOF
{"ts":"2026-05-27T21:08:08Z","epoch":1779916088,"repo":"myrepo","action":"wanted","key":"trim-debt","title":"Trim cargo-cult lines","briefing_id":"bbb-222","topic_id":"ttt-111","source_url":"https://example.com/why"}
EOF
mk_spec linked <<EOF
id: linked
description: linked to a finding
repo: $sb/myrepo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02
ledger_key: trim-debt

[arm:A]
model: m
overrides_dir:

[arm:B]
model: m
overrides_dir: arms/B

[task:t1]
prompt: tasks/t1.md
verify: true
timeout_s: 600
EOF
echo "task" > "$HH/experiments/linked/tasks/t1.md"
out="$(PUSH linked --dry-run 2>/dev/null)"
assert_contains "$out" '"ledger_key":"trim-debt"'        "hypothesis ledger_key carried"
assert_contains "$out" '"title":"Trim cargo-cult lines"' "hypothesis title from ledger"
assert_contains "$out" '"disposition":"wanted"'          "hypothesis disposition from ledger action"
assert_contains "$out" '"topic_id": "ttt-111"'           "audit_basis topic from ledger"
assert_contains "$out" '"briefing_id": "bbb-222"'        "audit_basis briefing from ledger"
assert_contains "$out" '"source_url":"https://example.com/why"' "hypothesis source_url from ledger"

# Explicit flags override ledger-derived lineage.
out="$(PUSH linked --dry-run --topic OVR-T --goal OVR-G --briefing OVR-B 2>/dev/null)"
assert_contains "$out" '"topic_id": "OVR-T"'    "--topic overrides ledger"
assert_contains "$out" '"goal_id": "OVR-G"'     "--goal flows through"
assert_contains "$out" '"briefing_id": "OVR-B"' "--briefing overrides ledger"

# ── 4b. explicit hypothesis: field is front-and-center, ledger-independent ──
# A later snoozed ledger record with an empty title must NOT empty the statement
# (the bug that buried the hypothesis on the dashboard): statement comes from the
# spec, the ledger only supplies provenance.
cat >> "$HH/ledger.jsonl" <<EOF
{"ts":"2026-05-27T21:09:00Z","epoch":1779916140,"repo":"myrepo","action":"surfaced","key":"hypo-key","title":"Borrowed finding title","briefing_id":"","topic_id":"top-9","source_url":""}
{"ts":"2026-05-27T21:09:01Z","epoch":1779916141,"repo":"myrepo","action":"snoozed","key":"hypo-key","title":"","briefing_id":"","topic_id":"","source_url":""}
EOF
mk_spec hypo <<EOF
id: hypo
description: short one-liner
hypothesis: On routine backend tasks, Sonnet 4.6 matches Opus 4.8 success at lower cost
repo: $sb/myrepo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02
ledger_key: hypo-key

[arm:A]
model: m
overrides_dir:

[arm:B]
model: m
overrides_dir:

[task:t1]
prompt: tasks/t1.md
verify: true
timeout_s: 600
EOF
echo "task" > "$HH/experiments/hypo/tasks/t1.md"
out="$(PUSH hypo --dry-run 2>/dev/null)"
assert_contains "$out" '"statement":"On routine backend tasks, Sonnet 4.6 matches Opus 4.8 success at lower cost"' \
  "explicit hypothesis: field is the statement (beats description, survives snoozed ledger)"
assert_not_contains "$out" '"statement":"short one-liner"' "explicit hypothesis: wins over description"
assert_contains "$out" '"ledger_key":"hypo-key"' "ledger_key still carried as provenance"

# ── 5. --all renders every experiment with a spec ────────────────
allout="$(PUSH --all --dry-run 2>/dev/null)"
n="$(printf '%s\n' "$allout" | grep -c '"client_key"')"
assert_eq "5" "$n" "--all renders all 5 specs (swap, harness, titles, linked, hypo)"

# ── 6. no-key live push is a no-op (exit 0) + recommends signup ──
rc=0; msg="$(env -u HEADER_API_KEY HEADER_HOME="$HH" "$HE" push swap 2>&1)" || rc=$?
assert_exit 0 "$rc" "no key → push exits 0 (opt-out, not an error)"
assert_contains "$msg" "no Header API key" "no-key push explains the gate"
assert_contains "$msg" "joinheader.com"    "no-key push points at signup"

# ── 7. usage / dispatch ──────────────────────────────────────────
HEADER_HOME="$HH" "$HE" push --help >/dev/null 2>&1; assert_exit 0 "$?" "push --help → exit 0"
rc=0; HEADER_HOME="$HH" "$HE" push 2>/dev/null || rc=$?
assert_exit 1 "$rc" "push with no id and no --all → exit 1"

# ── 8. config key experiment_sync (off default, closed domain) ──
# Ships off to match the telemetry/consent posture — egress is opt-in, never a
# default the host model has to disarm on sight.
assert_eq "off" "$(HEADER_HOME="$HH" "$CFG" get experiment_sync)" "experiment_sync defaults to off"
HEADER_HOME="$HH" "$CFG" set experiment_sync bogus 2>/dev/null
assert_eq "off" "$(HEADER_HOME="$HH" "$CFG" get experiment_sync)" "invalid experiment_sync coerced to off"
# experiment_sync is egress/consent → must be rejected from a committed team config
rc=0; HEADER_HOME="$HH" HEADER_TEAM_DIR="$sb/team" "$CFG" team-set experiment_sync auto 2>/dev/null || rc=$?
assert_exit 1 "$rc" "experiment_sync refused in a committed team config"

# ── 9. auto-sync on a lifecycle edit: no key → recommend once ────
# Opt into auto first (it ships off now); the recommend-once path is what an
# auto-configured user with no key yet should see.
HEADER_HOME="$HH" "$CFG" set experiment_sync auto >/dev/null 2>&1
msg="$(EXP_NOKEY define ds1 --arm A=m --arm B=m 2>&1)"
assert_contains "$msg" "Connect a Header account" "no-key define → recommends an account"
assert_eq "yes" "$([ -f "$HH/experiments/ds1/.sync-recommended" ] && echo yes || echo no)" \
  "recommendation marker written"
msg2="$(EXP_NOKEY validate ds1 2>&1)"
assert_not_contains "$msg2" "Connect a Header account" "recommendation not repeated (once per experiment)"

# experiment_sync off → no recommend, no sync, even with no key
HEADER_HOME="$HH" "$CFG" set experiment_sync off >/dev/null 2>&1
msg="$(EXP_NOKEY define ds3 --arm A=m --arm B=m 2>&1)"
assert_not_contains "$msg" "Connect a Header account" "experiment_sync off → auto-sync disabled"
HEADER_HOME="$HH" "$CFG" set experiment_sync auto >/dev/null 2>&1

# HEADER_EXPERIMENT_NOSYNC disables it regardless of key/config
msg="$(env -u HEADER_API_KEY HEADER_EXPERIMENT_NOSYNC=1 HEADER_HOME="$HH" "$HE" define ds4 --arm A=m --arm B=m 2>&1)"
assert_not_contains "$msg" "Connect a Header account" "HEADER_EXPERIMENT_NOSYNC disables auto-sync"

# ── 10. status lifecycle reflected in the payload ────────────────
EXP define dl --arm A=m --arm B=m >/dev/null 2>&1
assert_contains "$(PUSH dl --dry-run 2>/dev/null)" '"status": "defined"'  "fresh spec → status defined"
: > "$HH/experiments/dl/runs.jsonl"
assert_contains "$(PUSH dl --dry-run 2>/dev/null)" '"status": "run"'      "runs.jsonl → status run"
echo '{"verdict":"x"}' > "$HH/experiments/dl/result.json"
assert_contains "$(PUSH dl --dry-run 2>/dev/null)" '"status": "analyzed"' "result.json → status analyzed"
: > "$HH/experiments/dl/.merged"
assert_contains "$(PUSH dl --dry-run 2>/dev/null)" '"status": "merged"'   ".merged marker → status merged"

t_done
