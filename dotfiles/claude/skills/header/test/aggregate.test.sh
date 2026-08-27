#!/usr/bin/env bash
# test/aggregate.test.sh — `header-experiment aggregate`: the anonymized
# cross-customer submit (proven-changes library, design §7.3) + the PROVEN
# pattern rows it feeds back into the audit.
#
# No live network: --dry-run renders offline; send paths point
# HEADER_AGGREGATE_URL at a dead local port. The privacy contract is the core
# under test: NO identity, NO repo, NO prompts, NO free text on the wire.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

HE="$SKILL_DIR/bin/header-experiment"
AU="$SKILL_DIR/bin/header-audit"
CFG="$SKILL_DIR/bin/header-config"
sb="$(make_sandbox)"
HH="$sb/.header"
DEAD_URL="http://127.0.0.1:9/aggregate"   # nothing listens; curl fails fast
mkdir -p "$sb/myrepo"; touch "$sb/myrepo/pyproject.toml"

AGG() { HEADER_HOME="$HH" HEADER_AGGREGATE_URL="$DEAD_URL" "$HE" aggregate "$@"; }

# mk_exp <id> <ledger_key> — an analyzed experiment with a mined-style task
# (sha-bearing id) and free text that must never reach the wire.
mk_exp() {
  local id="$1" lk="$2"
  mkdir -p "$HH/experiments/$id/tasks"
  cat > "$HH/experiments/$id/spec" <<EOF
id: $id
description: secret project xyzzy details
hypothesis: sonnet matches opus on internal-acme-service
repo: $sb/myrepo
commit: HEAD
replicates: 3
non_inferiority_margin: 0.02
ledger_key: $lk

[arm:A]
model: claude-opus-4-7
effort: xhigh
overrides_dir:

[arm:B]
model: claude-sonnet-4-6
overrides_dir:

[task:t-abc1234]
prompt: tasks/t1.md
verify: pytest -q
commit: abc1234
apply_from: def5678
apply_paths: tests/test_x.py
lock_paths: tests/test_x.py
timeout_s: 600
EOF
  echo "task body stays local" > "$HH/experiments/$id/tasks/t1.md"
  cat > "$HH/experiments/$id/result.json" <<'EOF'
{
  "mode": "ab",
  "arms": ["A", "B"],
  "tasks_paired": 5,
  "n_per_arm": [15, 15],
  "excluded_runs": 0,
  "analysis_method": "paired-by-task",
  "bootstrap_iters": 2000,
  "non_inferiority_margin": 0.02,
  "cost": {
    "A_mean": 0.500000,
    "B_mean": 0.300000,
    "diff_mean_BA": -0.200000,
    "ci95": [-0.300000, -0.100000],
    "favorable": true
  },
  "success": {
    "A_rate": 1.0000,
    "B_rate": 1.0000,
    "diff_BA": 0.0000,
    "ci95": [0.0000, 0.0000],
    "non_inferior": true
  },
  "per_task": [
    {"task":"t-abc1234","A_cost":0.5,"B_cost":0.3,"diff_cost":-0.2,"A_succ":1.0,"B_succ":1.0}
  ],
  "verdict": "B wins (cost lower, success non-inferior)"
}
EOF
}

# ── 1. payload shape (dry-run) ───────────────────────────────────
mk_exp agg1 step-by-step          # a CURATED built-in pattern id
out="$(AGG agg1 --dry-run 2>/dev/null)"
assert_contains "$out" '"kind": "model-swap"'           "kind inferred"
assert_contains "$out" '"category": "step-by-step"'     "a curated pattern id passes as the category"
assert_contains "$out" '"ecosystem": "python"'          "ecosystem detected from the repo manifests"
assert_contains "$out" '"task_class": "tests-oracle"'   "apply_from tasks classify as tests-oracle"
assert_contains "$out" '"model_family":"opus"'          "arm carries the coarse model family"
assert_contains "$out" '"effort":"xhigh"'               "arm carries the (public) effort level"
assert_contains "$out" '"verdict": "B wins (cost lower, success non-inferior)"' "result verdict embedded"
assert_contains "$out" '"ci95": [-0.300000, -0.100000]' "result cost CI embedded"

# ── 2. the privacy contract — what must NEVER be on the wire ─────
assert_not_contains "$out" 'xyzzy'             "description free text never leaves"
assert_not_contains "$out" 'acme'              "hypothesis free text never leaves"
assert_not_contains "$out" 'abc1234'           "per_task stripped — mined task ids embed commit shas"
assert_not_contains "$out" '"per_task"'        "per_task array stripped from the result"
assert_not_contains "$out" 'installation_id'   "no machine identity"
assert_not_contains "$out" '"hostname"'        "no hostname"
assert_not_contains "$out" '"client_key"'      "no idempotency identity key"
assert_not_contains "$out" '"repo"'            "no repo block at all"
assert_not_contains "$out" 'prompt_sha256'     "no prompt hashes (linkable fingerprints)"
assert_not_contains "$out" 'myrepo'            "no repo path leakage"

# Valid JSON (if python available).
if command -v python3 >/dev/null 2>&1; then
  pj="$(printf '%s\n' "$out" | sed '/^#/d' | python3 -c 'import json,sys; json.load(sys.stdin); print("ok")' 2>/dev/null || echo fail)"
  assert_eq "ok" "$pj" "dry-run aggregate payload is valid JSON"
fi

# ── 3. non-curated ledger keys map to the EMPTY category ─────────
mk_exp agg2 delete-acme-deploy-rule
out2="$(AGG agg2 --dry-run 2>/dev/null)"
assert_contains "$out2" '"category": ""'              "a user-typed ledger key is NOT a curated category"
assert_not_contains "$out2" 'delete-acme-deploy-rule' "the raw ledger key never leaves"

# ── 4. gates ─────────────────────────────────────────────────────
# Not analyzed → hard error (only measured effects are poolable).
mkdir -p "$HH/experiments/raw/tasks"
cp "$HH/experiments/agg1/spec" "$HH/experiments/raw/spec"
echo task > "$HH/experiments/raw/tasks/t1.md"
rc=0; AGG raw >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "aggregate refuses an un-analyzed experiment"

# Consent: default config (off), no TTY, no --yes → polite opt-out, exit 0, nothing sent.
rc=0; msg="$(AGG agg1 </dev/null 2>&1)" || rc=$?
assert_exit 0 "$rc" "no consent + no TTY → exit 0 (opt-out, not an error)"
assert_contains "$msg" "opt-in" "the gate explains how to opt in"
assert_eq "no" "$([ -f "$HH/experiments/agg1/.last-aggregate" ] && echo yes || echo no)" \
  "nothing was sent without consent (no .last-aggregate marker)"

# --yes authorizes; dead endpoint → exit 1 + marker records the attempt.
rc=0; AGG agg1 --yes </dev/null >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "--yes + unreachable endpoint → exit 1"
assert_contains "$(cat "$HH/experiments/agg1/.last-aggregate" 2>/dev/null)" "000" \
  ".last-aggregate records the attempt (HTTP 000 offline)"

# ── 5. auto-submit after analyze, gated on aggregate_submit=on ───
mkdir -p "$HH/experiments/auto/tasks"
sed 's/^id: agg1$/id: auto/' "$HH/experiments/agg1/spec" > "$HH/experiments/auto/spec"
echo task > "$HH/experiments/auto/tasks/t1.md"
cat > "$HH/experiments/auto/runs.jsonl" <<'EOF'
{"ts":"t","task":"t1","arm":"A","rep":0,"model":"m","cost_usd":0.5,"success":true,"agent_exit":0,"verify_exit":0}
{"ts":"t","task":"t1","arm":"B","rep":0,"model":"m","cost_usd":0.3,"success":true,"agent_exit":0,"verify_exit":0}
{"ts":"t","task":"t2","arm":"A","rep":0,"model":"m","cost_usd":0.6,"success":true,"agent_exit":0,"verify_exit":0}
{"ts":"t","task":"t2","arm":"B","rep":0,"model":"m","cost_usd":0.4,"success":true,"agent_exit":0,"verify_exit":0}
EOF
# default (off): analyze fires NO library submit
msg="$(env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_AGGREGATE_URL="$DEAD_URL" "$HE" analyze auto 2>&1)"
assert_not_contains "$msg" "library:" "aggregate_submit off (default) → analyze does not submit"
# on: analyze fires the quiet submit (dead endpoint → 'offline' status line)
HEADER_HOME="$HH" "$CFG" set aggregate_submit on >/dev/null 2>&1
msg="$(env -u HEADER_API_KEY HEADER_HOME="$HH" HEADER_AGGREGATE_URL="$DEAD_URL" "$HE" analyze auto 2>&1)"
assert_contains "$msg" "library:" "aggregate_submit on → analyze auto-submits (quiet status line)"
# HEADER_EXPERIMENT_NOSYNC suppresses it regardless
msg="$(env -u HEADER_API_KEY HEADER_EXPERIMENT_NOSYNC=1 HEADER_HOME="$HH" HEADER_AGGREGATE_URL="$DEAD_URL" "$HE" analyze auto 2>&1)"
assert_not_contains "$msg" "library:" "HEADER_EXPERIMENT_NOSYNC disables the auto-submit"
HEADER_HOME="$HH" "$CFG" set aggregate_submit off >/dev/null 2>&1

# ── 6. config key: closed domain, personal-only ──────────────────
assert_eq "off" "$(HEADER_HOME="$HH" "$CFG" get aggregate_submit)" "aggregate_submit defaults to off"
HEADER_HOME="$HH" "$CFG" set aggregate_submit bogus 2>/dev/null
assert_eq "off" "$(HEADER_HOME="$HH" "$CFG" get aggregate_submit)" "invalid aggregate_submit coerced to off"
rc=0; HEADER_HOME="$HH" HEADER_TEAM_DIR="$sb/team" "$CFG" team-set aggregate_submit on 2>/dev/null || rc=$?
assert_exit 1 "$rc" "aggregate_submit refused in a committed team config (egress is personal-only)"

# ── 7. PROVEN pattern rows (the library's feedback channel) ──────
mkdir -p "$sb/provrepo"; printf '# Always think step by step.\n' > "$sb/provrepo/CLAUDE.md"
printf 'step-by-step\tthink step.?by.?step\tProven debt.\t-3.1%%\t214\t[-4.2%%,-1.9%%]\nhypo-only\tfoo.?bar\tA hypothesis.\nbadrow\tbaz\twhy\t-1%%\n' \
  > "$HH/patterns.tsv"
H="$(HOME="$sb" HEADER_HOME="$HH" "$AU" harness --repo "$sb/provrepo")"
assert_contains "$H" $'PROVEN\tstep-by-step\t-3.1%\t214\t[-4.2%,-1.9%]' \
  "a 6-field patterns.tsv row emits a PROVEN line from harness"
assert_eq "1" "$(printf '%s\n' "$H" | grep -c $'HIT\t'"$sb/provrepo/CLAUDE.md")" \
  "a proven row reusing a built-in id does NOT double-report HITs (de-dup by id)"
P="$(HOME="$sb" HEADER_HOME="$HH" "$AU" patterns)"
assert_contains "$P" "[proven: -3.1% across 214 repos, CI [-4.2%,-1.9%]]" \
  "patterns annotates proven ids with the library evidence"
assert_contains "$P" "hypo-only" "3-field hypothesis rows still load"
assert_not_contains "$P" "badrow" "a 4-field (malformed) row is skipped, not mis-parsed"
rm -f "$HH/patterns.tsv"

# ── 8. usage / dispatch ──────────────────────────────────────────
HEADER_HOME="$HH" "$HE" aggregate --help >/dev/null 2>&1; assert_exit 0 "$?" "aggregate --help → exit 0"
rc=0; HEADER_HOME="$HH" "$HE" aggregate 2>/dev/null || rc=$?
assert_exit 1 "$rc" "aggregate with no id → exit 1"

t_done
