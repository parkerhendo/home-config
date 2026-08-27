#!/usr/bin/env bash
# test/experiment.test.sh — unit tests for bin/header-experiment.
#
# Strategy: never invoke a real `claude`. Use HEADER_EXPERIMENT_ADAPTER to
# point at a tiny bash stub that emits deterministic JSON usage. That covers
# the runner's parsing + analyse's stats end-to-end without spending tokens
# or needing network.
#
# HEADER_HOME is pinned to a sandbox so experiment state doesn't touch ~/.header.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

# This suite builds throwaway git repos and exercises worktrees. When the suite
# runs from a git pre-commit hook (.githooks/pre-commit), `git commit` exports
# GIT_DIR / GIT_INDEX_FILE / GIT_WORK_TREE pointing at the OUTER repo — which
# would poison every `git` in our sandboxes. Clear them so the fixtures (and the
# tool under test) bind to the sandbox repos, matching a normal invocation.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_PREFIX 2>/dev/null || true

HE="$SKILL_DIR/bin/header-experiment"
sb="$(make_sandbox)"
# NOSYNC: these tests exercise experiment logic, not cloud sync — keep auto-sync
# (and any network egress) out of the way. push/auto-sync have their own suite.
EXP() { HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 "$HE" "$@"; }

# ── helpers ──────────────────────────────────────────────────
exp_dir_for() { printf '%s/.header/experiments/%s' "$sb" "$1"; }

# write_stub_adapter — make a stub that prints fake usage per arm. By default
# arm A is "expensive + always succeeds", arm B is "cheap + always succeeds".
# Optional second arg makes B fail on one task (to exercise non-inferiority).
write_stub_adapter() {
  local path="$1"; local b_fails_task="${2:-}"
  cat > "$path" <<EOF
#!/usr/bin/env bash
# Stub: task_id arm rep prompt_file
task="\$1"; arm="\$2"; rep="\$3"
case "\$arm" in
  A*) cost="0.10"; tokens=1000 ;;
  B*) cost="0.06"; tokens=600 ;;
  *)  cost="0.08"; tokens=800 ;;
esac
printf '{"type":"result","model":"stub-%s","total_cost_usd":%s,"usage":{"input_tokens":%d,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}\n' \\
  "\$arm" "\$cost" "\$tokens"
# Optional: B fails on the listed task to exercise non-inferiority.
if [ "\$arm" = "B" ] && [ "\$task" = "$b_fails_task" ]; then
  exit 1
fi
exit 0
EOF
  chmod +x "$path"
}

# write_task_prompt — drop a tiny prompt file under the experiment dir.
write_task_prompt() {
  local exp="$1" tid="$2"
  local d; d="$(exp_dir_for "$exp")/tasks"
  mkdir -p "$d"
  echo "prompt for $tid" > "$d/$tid.md"
}

# ── usage + dispatcher ───────────────────────────────────────
EXP >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "no subcommand → exit 1"
EXP bogus >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "unknown subcommand → exit 1"

# ── define: scaffolds a spec with sane defaults ──────────────
EXP define exp-1 --description "first" --arm "A=claude-opus-4-7" --arm "B=claude-sonnet-4-6" --replicates 2 >/dev/null
assert_eq "yes" "$([ -f "$(exp_dir_for exp-1)/spec" ] && echo yes || echo no)" \
  "define wrote spec file"
spec_content="$(cat "$(exp_dir_for exp-1)/spec")"
assert_contains "$spec_content" "id: exp-1"        "spec carries the id"
assert_contains "$spec_content" "description: first" "spec carries description"
assert_contains "$spec_content" "[arm:A]"          "spec has [arm:A] section"
assert_contains "$spec_content" "[arm:B]"          "spec has [arm:B] section"
assert_contains "$spec_content" "model: claude-opus-4-7"   "spec carries arm A model"
assert_contains "$spec_content" "model: claude-sonnet-4-6" "spec carries arm B model"
assert_contains "$spec_content" "replicates: 2"    "spec carries replicates override"
assert_contains "$spec_content" "non_inferiority_margin:" "spec carries margin default"
assert_contains "$spec_content" "[task:example]"   "spec scaffolds a placeholder task"

# refuse duplicate id
EXP define exp-1 >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "define with existing id → exit 1 (no clobber)"

# bad id (path separator) is rejected
EXP define "../bad" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "define rejects unsafe id ('../bad')"

# id is required
EXP define >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "define without <id> → exit 1"

# ── validate: catches missing prompts, bad replicates ────────
EXP validate exp-1 >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "validate fails when prompt file doesn't exist"
# Now create the prompt file → validation passes
write_task_prompt exp-1 example
EXP validate exp-1 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "validate passes once the prompt file exists"
assert_contains "$(EXP validate exp-1 2>&1)" "2 arm(s), 1 task(s)" \
  "validate reports arm + task counts"

# bad replicates value → reject
sed_sub 's/^replicates: 2/replicates: zero/' "$(exp_dir_for exp-1)/spec"
EXP validate exp-1 >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "validate rejects non-integer replicates"
sed_sub 's/^replicates: zero/replicates: 2/' "$(exp_dir_for exp-1)/spec"

# one arm only → reject
EXP define exp-1arm --arm "A=opus" >/dev/null
write_task_prompt exp-1arm example
EXP validate exp-1arm >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "validate rejects experiments with <2 arms"

# ── run: end-to-end with the stub adapter ────────────────────
write_stub_adapter "$sb/adapter.sh"
# Use the exp-1 spec; point repo at a tmp git repo so worktrees work.
git_repo="$sb/repo"
mkdir -p "$git_repo" && (cd "$git_repo" && git init -q && \
  git config user.email t@t && git config user.name t && \
  echo hi > a.txt && git add a.txt && git commit -qm init)
# update spec to use the git repo + a NO-OP verifier (true).
sed_sub "s|^repo: .|repo: $git_repo|" "$(exp_dir_for exp-1)/spec"

EXP run exp-1 --yes --adapter "$sb/adapter.sh" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "run exits 0 with stub adapter"
runs_file="$(exp_dir_for exp-1)/runs.jsonl"
assert_eq "yes" "$([ -s "$runs_file" ] && echo yes || echo no)" "run produced runs.jsonl"
n_lines="$(wc -l < "$runs_file" | tr -d ' ')"
# 2 arms × 1 task × 2 replicates = 4
assert_eq "4" "$n_lines" "runs.jsonl has 4 records (2 arms × 1 task × 2 reps)"
assert_contains "$(cat "$runs_file")" '"arm":"A"' "runs.jsonl includes arm A"
assert_contains "$(cat "$runs_file")" '"arm":"B"' "runs.jsonl includes arm B"
assert_contains "$(cat "$runs_file")" '"cost_usd":0.100000' "arm A cost parsed from adapter JSON"
assert_contains "$(cat "$runs_file")" '"cost_usd":0.060000' "arm B cost parsed from adapter JSON"
assert_contains "$(cat "$runs_file")" '"input_tokens":1000' "arm A input tokens parsed"
assert_contains "$(cat "$runs_file")" '"input_tokens":600'  "arm B input tokens parsed"
assert_contains "$(cat "$runs_file")" '"success":true'      "verify exit 0 → success=true"

# ── run --aa: writes runs-aa.jsonl, both slots use first arm's config ──
EXP run exp-1 --aa --yes --adapter "$sb/adapter.sh" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "run --aa exits 0"
aa_runs="$(exp_dir_for exp-1)/runs-aa.jsonl"
assert_eq "yes" "$([ -s "$aa_runs" ] && echo yes || echo no)" "run --aa produced runs-aa.jsonl"
assert_contains "$(cat "$aa_runs")" '"arm":"A"' "A/A: slot 1 labelled A"
assert_contains "$(cat "$aa_runs")" '"arm":"A_2"' "A/A: slot 2 labelled A_2 (same config as A)"
# the model captured for A_2 should be the arm-A model from the adapter
assert_not_contains "$(cat "$aa_runs")" '"model":"stub-B"' "A/A: never uses arm B's config"

# ── run: refuses missing claude when no adapter set ──────────
# (Only check this when claude is genuinely absent; in CI it may be installed.)
if ! command -v claude >/dev/null 2>&1; then
  EXP run exp-1 --yes >/dev/null 2>&1; rc=$?
  assert_exit 1 "$rc" "run without adapter → exit 1 when 'claude' is not on PATH"
fi

# ── run: cost gate refuses cleanly when no TTY + no --yes ────
# Regression: an earlier version tried to read /dev/tty here. In agent
# subshells /dev/tty exists but open() returns ENXIO (no controlling
# terminal). The fix is to detect no-TTY with `[ -t 0 ]` and exit with a
# helpful error pointing at --yes — NOT to error out via bash's "No such
# device or address" redirect failure.
no_tty_out="$(EXP run exp-1 </dev/null 2>&1)"; rc=$?
assert_exit 1 "$rc" "run without --yes + no TTY → exit 1 (cleanly)"
assert_not_contains "$no_tty_out" "No such device" \
  "no-TTY refusal does NOT leak the /dev/tty 'No such device' error"
assert_contains "$no_tty_out" "no TTY for confirmation" \
  "no-TTY refusal explains the missing TTY"
assert_contains "$no_tty_out" "--yes" \
  "no-TTY refusal points at --yes so callers know how to authorize"

# ── run: cost gate speaks BOTH billing modes (API + subscription headroom)
# Regression after the 2026-05-27 audit where the gate only mentioned dollars,
# misleading users on a Max subscription (no $ per token, just usage-limit
# headroom). header-cost already had the framing; we just hadn't pulled it
# into header-experiment's gate.
gate_out="$(EXP run exp-1 </dev/null 2>&1)"
assert_contains "$gate_out" "API / Console (pay-per-token)" \
  "cost gate mentions API/Console billing basis"
assert_contains "$gate_out" "Claude subscription" \
  "cost gate mentions subscription basis (Pro / Max)"
assert_contains "$gate_out" "usage-limit headroom" \
  "cost gate flags that subscription users spend headroom, not dollars"
# The load-bearing rule appears in the gate itself.
assert_contains "$gate_out" '$60 experiment to prove a $0.10 effect' \
  "cost gate quotes the load-bearing rule verbatim"
# Both levers — magnitude AND experiment-cost — surface for the user.
assert_contains "$gate_out" "Levers to make an experiment cheaper" \
  "cost gate surfaces the cheap-experiment levers"
assert_contains "$gate_out" "Haiku" \
  "cost gate mentions Haiku as a cheap-adapter lever"
assert_contains "$gate_out" "k 1" \
  "cost gate mentions --k 1 as a sanity-only lever"

# ── analyze: bootstrap CI, paired-by-task ────────────────────
# Hand-author a noisy 5-task runs.jsonl: B is reliably cheaper everywhere,
# success holds across the board. Verdict should be "B wins".
EXP define exp-stat --arm "A=opus" --arm "B=sonnet" --replicates 3 >/dev/null
write_task_prompt exp-stat example
sed_sub "s|^repo: .|repo: $git_repo|" "$(exp_dir_for exp-stat)/spec"
five_tasks_runs() {
  local tid c_a c_b s_a s_b
  for tid in t1 t2 t3 t4 t5; do
    case "$tid" in
      t1) c_a=0.10; c_b=0.06 ;;
      t2) c_a=0.20; c_b=0.12 ;;
      t3) c_a=0.15; c_b=0.09 ;;
      t4) c_a=0.25; c_b=0.15 ;;
      t5) c_a=0.30; c_b=0.18 ;;
    esac
    for r in 0 1 2; do
      printf '{"task":"%s","arm":"A","rep":%d,"cost_usd":%s,"success":true}\n' "$tid" "$r" "$c_a"
      printf '{"task":"%s","arm":"B","rep":%d,"cost_usd":%s,"success":true}\n' "$tid" "$r" "$c_b"
    done
  done
}
five_tasks_runs > "$(exp_dir_for exp-stat)/runs.jsonl"

EXP analyze exp-stat --seed 7 --bootstrap 500 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "analyze on 5 tasks exits 0"
result="$(cat "$(exp_dir_for exp-stat)/result.json")"
assert_contains "$result" '"tasks_paired": 5'        "analyze pairs 5 tasks"
assert_contains "$result" '"mode": "ab"'             "analyze tags mode ab"
assert_contains "$result" '"favorable": true'        "cost CI < 0 → favorable=true"
assert_contains "$result" '"non_inferior": true'     "success holds → non_inferior=true"
assert_contains "$result" '"verdict": "B wins'       "verdict: B wins"
assert_contains "$result" '"bootstrap_iters": 500'   "bootstrap iter count carried"
# determinism: same seed, same CI
EXP analyze exp-stat --seed 7 --bootstrap 500 >/dev/null
r2="$(cat "$(exp_dir_for exp-stat)/result.json")"
assert_eq "$result" "$r2" "analyze is deterministic for a fixed seed"

# ── analyze: success regression → no proven win ──────────────
# Same noisy 5-task data but B fails one task entirely. Success diff CI should
# fall below −δ=0.02, blocking the merge even with cost wins.
{
  five_tasks_runs | awk '
    BEGIN{ FS=OFS="" }
    /"arm":"B"/ && /"task":"t5"/ { sub(/"success":true/, "\"success\":false") } { print }'
} > "$(exp_dir_for exp-stat)/runs.jsonl"
EXP analyze exp-stat --seed 7 --bootstrap 500 >/dev/null
result2="$(cat "$(exp_dir_for exp-stat)/result.json")"
assert_contains "$result2" '"favorable": true'      "cost still favourable when B fails one task"
assert_contains "$result2" '"non_inferior": false'  "success non-inferiority fails when B regresses"
assert_contains "$result2" '"verdict": "no proven win"' "blocked by non-inferiority → no proven win"
assert_contains "$result2" "success regressed beyond" "verdict reason mentions success regression"

# ── analyze: underpowered (<5 tasks) → flagged ──────────────
# One-task analysis collapses CI; verdict must flag the lack of power, not
# pretend significance.
EXP define exp-tiny --arm "A=opus" --arm "B=sonnet" >/dev/null
write_task_prompt exp-tiny example
{
  printf '{"task":"t1","arm":"A","rep":0,"cost_usd":0.10,"success":true}\n'
  printf '{"task":"t1","arm":"B","rep":0,"cost_usd":0.06,"success":true}\n'
} > "$(exp_dir_for exp-tiny)/runs.jsonl"
EXP analyze exp-tiny >/dev/null
assert_contains "$(cat "$(exp_dir_for exp-tiny)/result.json")" '"verdict": "data degenerate"' \
  "1-task A/B experiment → verdict 'data degenerate' (paired-by-task CI is a single point at N=1; never \"B wins\")"

# ── analyze --aa: harness validator ──────────────────────────
EXP define exp-aa --arm "A=opus" --arm "B=sonnet" >/dev/null
write_task_prompt exp-aa example
{
  # diffs around 0 — clean harness
  for tid in t1 t2 t3 t4 t5; do
    base="0.10"
    for r in 0 1; do
      printf '{"task":"%s","arm":"A","rep":%d,"cost_usd":%s,"success":true}\n'   "$tid" "$r" "$base"
      printf '{"task":"%s","arm":"A_2","rep":%d,"cost_usd":%s,"success":true}\n' "$tid" "$r" "$base"
    done
  done
} > "$(exp_dir_for exp-aa)/runs-aa.jsonl"
EXP analyze exp-aa --aa >/dev/null
aa_result="$(cat "$(exp_dir_for exp-aa)/result-aa.json")"
assert_contains "$aa_result" '"mode": "aa"'         "analyze --aa tags mode aa"
assert_contains "$aa_result" '"verdict": "A/A OK'   "clean A/A → 'A/A OK' verdict"

# ── analyze --aa: biased harness flagged ─────────────────────
# Inject a systematic bias: arm A is always cheaper than arm A_2 (e.g. cache
# warmup hits the second slot). CI should NOT contain 0 → flagged.
{
  for tid in t1 t2 t3 t4 t5; do
    for r in 0 1; do
      printf '{"task":"%s","arm":"A","rep":%d,"cost_usd":0.10,"success":true}\n'   "$tid" "$r"
      printf '{"task":"%s","arm":"A_2","rep":%d,"cost_usd":0.30,"success":true}\n' "$tid" "$r"
    done
  done
} > "$(exp_dir_for exp-aa)/runs-aa.jsonl"
EXP analyze exp-aa --aa >/dev/null
aa_biased="$(cat "$(exp_dir_for exp-aa)/result-aa.json")"
assert_contains "$aa_biased" '"verdict": "A/A BIASED' \
  "biased A/A (CI excludes 0) → flagged 'A/A BIASED'"

# ── report: pretty output for an A/B result ──────────────────
five_tasks_runs > "$(exp_dir_for exp-stat)/runs.jsonl"
EXP analyze exp-stat --seed 7 >/dev/null
rep_out="$(EXP report exp-stat 2>&1)"
assert_contains "$rep_out" "header-experiment is BETA" "report prints the beta banner"
assert_contains "$rep_out" "A vs B"                    "report header: A vs B"
assert_contains "$rep_out" "B − A"                     "report shows the diff label"
assert_contains "$rep_out" "95% CI"                    "report shows CI"
assert_contains "$rep_out" "Conservative savings rate" "report shows the conservative savings rate"

# report --aa
EXP report exp-aa --aa 2>&1 >/dev/null
rep_aa="$(EXP report exp-aa --aa 2>&1)"
assert_contains "$rep_aa" "A/A (noise floor)" "report --aa header"
assert_contains "$rep_aa" "A/A interpretation" "report --aa explains the verdict"

# ── report needs a result.json ──────────────────────────────
EXP define exp-noresult --arm "A=opus" --arm "B=sonnet" >/dev/null
EXP report exp-noresult >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "report fails when result.json doesn't exist yet"

# ── run: cost-gate prompts when no --yes and no adapter ──────
# We can't easily exercise the TTY prompt in tests; ensure that with --yes the
# gate is skipped and the run proceeds, AND that --adapter also implicitly
# skips it (so test runs don't hang).
EXP run exp-1 --yes --adapter "$sb/adapter.sh" --k 1 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "run with --yes + --adapter proceeds without prompting"

# ── adapter exit-code propagates to success ──────────────────
# Stub that always exits 1 → success=false (the agent itself "failed").
# (Tier-1 oracle is the verify step, but a failing agent also flips success.)
cat > "$sb/fail-adapter.sh" <<'EOF'
#!/usr/bin/env bash
printf '{"type":"result","model":"stub","total_cost_usd":0.05,"usage":{"input_tokens":100,"output_tokens":10}}\n'
exit 0
EOF
chmod +x "$sb/fail-adapter.sh"
# Use a verify cmd that fails ("false") to drive success=false.
sed_sub 's/^verify: true$/verify: false/' "$(exp_dir_for exp-1)/spec"
EXP run exp-1 --yes --adapter "$sb/fail-adapter.sh" --k 1 >/dev/null 2>&1
assert_contains "$(cat "$(exp_dir_for exp-1)/runs.jsonl")" '"success":false' \
  "verify exit != 0 → success=false in runs.jsonl"

# ── new (audit-aware wizard / one-shot) ──────────────────────
# Pre-build a small git repo so --kind prompt-debt-deletion has a real file
# to strip lines from, and --repo can resolve.
nw_repo="$sb/nw-repo"
mkdir -p "$nw_repo" && (cd "$nw_repo" && git init -q && \
  git config user.email t@t && git config user.name t)
cat > "$nw_repo/CLAUDE.md" <<'EOF'
# Project rules
You are an expert engineer.
Always think step by step.
Take a deep breath.
Don't hallucinate.
Be helpful.
EOF
echo '{"name":"x"}' > "$nw_repo/package.json"
(cd "$nw_repo" && git add . && git commit -qm init)

# 1) generic mode (--arm/--task/--verify) writes a complete, valid spec
EXP new gen-1 --arm "A:claude-opus-4-7" --arm "B:claude-sonnet-4-6" \
  --task "Refactor a function — keep tests green." \
  --verify "true" --replicates 2 --description "model swap (generic)" \
  --repo "$nw_repo" >/dev/null
assert_eq "yes" "$([ -f "$(exp_dir_for gen-1)/spec" ] && echo yes || echo no)" \
  "new (generic) wrote a spec"
spec_gen="$(cat "$(exp_dir_for gen-1)/spec")"
assert_contains "$spec_gen" "model: claude-opus-4-7"   "generic spec: arm A model"
assert_contains "$spec_gen" "model: claude-sonnet-4-6" "generic spec: arm B model"
assert_contains "$spec_gen" "description: model swap (generic)" "generic spec: description"
assert_contains "$spec_gen" "repo: $nw_repo"           "generic spec: repo absolute"
# Inline task → file written under exp_dir/tasks/
assert_eq "yes" "$([ -f "$(exp_dir_for gen-1)/tasks/t1.md" ] && echo yes || echo no)" \
  "inline task is written to <exp_dir>/tasks/t1.md"
# validate is implicit: `new` calls it; if validate fails the command errors
EXP new gen-1 --arm A: --arm B: --task t --verify true --repo "$nw_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "new refuses duplicate id (no clobber)"

# 2) --kind prompt-debt-deletion auto-generates arm B's overrides_dir
EXP new debt-1 --kind prompt-debt-deletion \
  --file CLAUDE.md --lines "3,4,5" \
  --task "Tiny task — exit cleanly." --verify "true" \
  --replicates 2 --ledger-key delete-cargo-cult \
  --repo "$nw_repo" >/dev/null
assert_eq "yes" "$([ -f "$(exp_dir_for debt-1)/spec" ] && echo yes || echo no)" \
  "new --kind prompt-debt-deletion wrote a spec"
spec_debt="$(cat "$(exp_dir_for debt-1)/spec")"
# ledger_key must be in the TOP block (before [section]s) so spec_get_scalar finds it
assert_contains "$spec_debt" "ledger_key: delete-cargo-cult" "ledger_key written into spec"
ledger_line="$(awk '/ledger_key/{print NR;exit}' "$(exp_dir_for debt-1)/spec")"
first_section_line="$(awk '/^\[/{print NR;exit}' "$(exp_dir_for debt-1)/spec")"
[ "${ledger_line:-9999}" -lt "${first_section_line:-9999}" ] && lk_in_top=yes || lk_in_top=no
assert_eq "yes" "$lk_in_top" "ledger_key is in the top-level block (above first [section])"
assert_contains "$spec_debt" "overrides_dir: arms/B" "arm B has overrides_dir = arms/B"
# Arm B's CLAUDE.md exists and has lines 3,4,5 removed
arm_b_file="$(exp_dir_for debt-1)/arms/B/CLAUDE.md"
assert_eq "yes" "$([ -f "$arm_b_file" ] && echo yes || echo no)" \
  "arm B's CLAUDE.md materialized under arms/B/"
arm_b_lines="$(wc -l < "$arm_b_file" | tr -d ' ')"
assert_eq "3" "$arm_b_lines" "arm B's CLAUDE.md has 3 lines (original 6 − 3 stripped)"
assert_not_contains "$(cat "$arm_b_file")" "think step by step" "stripped line 3 (cargo-cult)"
assert_not_contains "$(cat "$arm_b_file")" "deep breath"         "stripped line 4 (cargo-cult)"
assert_not_contains "$(cat "$arm_b_file")" "hallucinate"         "stripped line 5 (cargo-cult)"
# Bad --lines (non-integer) → refused
EXP new debt-bad --kind prompt-debt-deletion --file CLAUDE.md --lines "abc" \
  --task t --verify true --repo "$nw_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "new --kind prompt-debt-deletion rejects non-integer --lines"
# Missing file (audit pointed at nonsense) → refused
EXP new debt-nofile --kind prompt-debt-deletion --file does-not-exist.md --lines "1" \
  --task t --verify true --repo "$nw_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "new --kind prompt-debt-deletion rejects missing --file"

# 3) --kind model-swap → two arms differ only in model
EXP new swap-1 --kind model-swap --from claude-opus-4-7 --to claude-sonnet-4-6 \
  --task "Tiny." --verify "true" --replicates 2 --repo "$nw_repo" >/dev/null
spec_swap="$(cat "$(exp_dir_for swap-1)/spec")"
assert_contains "$spec_swap" "model: claude-opus-4-7"   "swap spec: arm A model"
assert_contains "$spec_swap" "model: claude-sonnet-4-6" "swap spec: arm B model"
# Neither arm has overrides_dir (it's a model swap, not a file change)
assert_not_contains "$spec_swap" "overrides_dir: arms" "swap spec: no overrides_dir for either arm"

# 4) Unknown --kind → refused
EXP new bad-kind --kind not-a-kind --repo "$nw_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "new rejects unknown --kind"

# 5) Task passed as a real repo-relative file path → stored as relative
mkdir -p "$nw_repo/tasks"
echo "Real prompt." > "$nw_repo/tasks/real.md"
EXP new path-1 --arm A: --arm B: --task "tasks/real.md" --verify true \
  --replicates 1 --repo "$nw_repo" >/dev/null
spec_path="$(cat "$(exp_dir_for path-1)/spec")"
assert_contains "$spec_path" "prompt: tasks/real.md" \
  "repo-relative task path is stored as relative (not absolute)"
EXP validate path-1 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "validate finds the repo-relative task file"
# A path-resolution sanity check: a task path that doesn't exist anywhere is
# treated as inline (file written under exp_dir/tasks/). NOT a fatal error.
EXP new path-inline --arm A: --arm B: --task "Just refactor X." --verify true \
  --replicates 1 --repo "$nw_repo" >/dev/null
assert_eq "yes" "$([ -f "$(exp_dir_for path-inline)/tasks/t1.md" ] && echo yes || echo no)" \
  "non-path --task value is written to <exp_dir>/tasks/t1.md as an inline prompt"

# 6) Magnitude estimate fires for --kind prompt-debt-deletion (v0.12.0)
# Need a bigger CLAUDE.md so a 1-line delete is reliably <5%. Build one.
big_repo="$sb/big-repo"
mkdir -p "$big_repo" && (cd "$big_repo" && git init -q && \
  git config user.email t@t && git config user.name t)
{
  printf '# Project rules\n'
  printf 'You are an expert engineer.\n'
  printf 'Always think step by step.\n'
  for i in $(seq 1 50); do
    printf 'Actual content line %d with real instructions and useful context here.\n' "$i"
  done
} > "$big_repo/CLAUDE.md"
(cd "$big_repo" && git add . && git commit -qm init)

mag_small_out="$(EXP new mag-small --kind prompt-debt-deletion \
  --file CLAUDE.md --lines "3" --task t --verify true \
  --replicates 2 --repo "$big_repo" 2>&1)"
assert_contains "$mag_small_out" "Magnitude estimate" "magnitude estimate prints"
assert_contains "$mag_small_out" "of the file"        "magnitude estimate shows % of file"
assert_contains "$mag_small_out" '$60 experiment to prove a $0.10 effect' \
  "magnitude estimate quotes the load-bearing rule"
assert_contains "$mag_small_out" "<5% of the file"    "small change triggers the <5% pointer"
assert_contains "$mag_small_out" "[Apply with review]" \
  "small-magnitude estimate surfaces the [Apply with review] path"
assert_contains "$mag_small_out" "Haiku"              "small-magnitude estimate surfaces the cheap-experiment Haiku lever"
assert_contains "$mag_small_out" "narrow"             "small-magnitude estimate surfaces the narrow-verify lever"

# 6b) Big change → no [Apply with review] suggestion (magnitude is enough)
big_repo2="$sb/big-repo2"
mkdir -p "$big_repo2" && (cd "$big_repo2" && git init -q && \
  git config user.email t@t && git config user.name t)
{ printf 'line1\nline2\nline3\nline4\nline5\n'; } > "$big_repo2/CLAUDE.md"
(cd "$big_repo2" && git add . && git commit -qm init)
mag_big_out="$(EXP new mag-big --kind prompt-debt-deletion \
  --file CLAUDE.md --lines "1,2,3" --task t --verify true \
  --replicates 2 --repo "$big_repo2" 2>&1)"
assert_contains     "$mag_big_out" "Magnitude estimate" "magnitude estimate prints for big changes too"
assert_not_contains "$mag_big_out" "<5% of the file"   "big-change estimate does NOT trigger the <5% pointer"

# 7) --kind clause-add (insertion experiments)
EXP new clause-1 --kind clause-add \
  --file CLAUDE.md --after-line 1 \
  --text "For model-field changes, invoke the model-field-checklist skill first." \
  --task "tiny" --verify true --replicates 2 --repo "$big_repo" >/dev/null
clause_spec="$(cat "$(exp_dir_for clause-1)/spec")"
assert_contains "$clause_spec" "overrides_dir: arms/B" \
  "clause-add spec: arm B has overrides_dir = arms/B"
arm_b_file="$(exp_dir_for clause-1)/arms/B/CLAUDE.md"
assert_eq "yes" "$([ -f "$arm_b_file" ] && echo yes || echo no)" \
  "clause-add arm B's file materialized"
assert_contains "$(cat "$arm_b_file")" "model-field-checklist skill" \
  "clause-add inserted the new instruction"
# Original file has 53 lines (header + 50 generated); arm B should have 54
orig_lines="$(wc -l < "$big_repo/CLAUDE.md" | tr -d ' ')"
new_lines="$(wc -l < "$arm_b_file" | tr -d ' ')"
assert_eq "$(( orig_lines + 1 ))" "$new_lines" \
  "clause-add added exactly one line"
# Insertion happens AFTER line 1 — line 1 should still be the original header
head1="$(head -1 "$arm_b_file")"
assert_eq "# Project rules" "$head1" "clause-add preserved the existing line 1"
head2="$(sed -n '2p' "$arm_b_file")"
assert_contains "$head2" "model-field-checklist skill" \
  "clause-add inserted at position 2 (after line 1)"

# 7b) clause-add at after-line=0 inserts at the top
EXP new clause-top --kind clause-add \
  --file CLAUDE.md --after-line 0 \
  --text "TOP_LINE_INSERTED" \
  --task "tiny" --verify true --replicates 2 --repo "$big_repo" >/dev/null
top_file="$(exp_dir_for clause-top)/arms/B/CLAUDE.md"
assert_eq "TOP_LINE_INSERTED" "$(head -1 "$top_file")" \
  "clause-add --after-line 0 inserts at the very top of the file"

# 7c) clause-add via --text-file (multi-line content)
multi_file="$sb/multi.txt"
{ printf 'Line A\n'; printf 'Line B\n'; printf 'Line C\n'; } > "$multi_file"
EXP new clause-multi --kind clause-add \
  --file CLAUDE.md --after-line 1 --text-file "$multi_file" \
  --task "tiny" --verify true --replicates 2 --repo "$big_repo" >/dev/null
multi_b="$(exp_dir_for clause-multi)/arms/B/CLAUDE.md"
assert_contains "$(cat "$multi_b")" "Line A" "clause-add --text-file: multi-line content present"
assert_contains "$(cat "$multi_b")" "Line B" "clause-add --text-file: line B present"
assert_contains "$(cat "$multi_b")" "Line C" "clause-add --text-file: line C present"

# 7d) clause-add validates inputs
EXP new clause-badline --kind clause-add --file CLAUDE.md \
  --after-line "abc" --text "x" --task t --verify true \
  --repo "$big_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "clause-add rejects non-integer --after-line"
EXP new clause-nofile --kind clause-add --file does-not-exist.md \
  --after-line 0 --text "x" --task t --verify true \
  --repo "$big_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "clause-add rejects missing --file"
EXP new clause-notext --kind clause-add --file CLAUDE.md \
  --after-line 0 --task t --verify true \
  --repo "$big_repo" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "clause-add requires --text or --text-file"

# ── 0.12.1 fixes ─────────────────────────────────────────────

# 8) Default timeout_s bumped 600 → 1200
EXP new timeout-default --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$nw_repo" >/dev/null
assert_contains "$(cat "$(exp_dir_for timeout-default)/spec")" "timeout_s: 1200" \
  "new()-scaffolded spec defaults timeout_s to 1200 (was 600 in 0.11.x)"
# define()-scaffolded specs also default to 1200 (with --task) and 1200 (without --task)
EXP define timeout-define-1 --arm "A=opus" --arm "B=sonnet" >/dev/null
assert_contains "$(cat "$(exp_dir_for timeout-define-1)/spec")" "timeout_s: 1200" \
  "define() placeholder spec defaults timeout_s to 1200"

# 9) Verify auto-detect nudge in new() output (only when verify was auto-detected)
nudge_auto_out="$(EXP new vnudge-auto --arm A: --arm B: --task "x" \
  --replicates 1 --repo "$nw_repo" 2>&1)"
assert_contains "$nudge_auto_out" "auto-detected from your project manifest" \
  "new prints verify-autodetect nudge when --verify is omitted"
assert_contains "$nudge_auto_out" "REGRESSION check" \
  "verify nudge calls out regression-vs-task-completion distinction"
nudge_explicit_out="$(EXP new vnudge-explicit --arm A: --arm B: --task "x" \
  --verify "pytest && jq ." --replicates 1 --repo "$nw_repo" 2>&1)"
assert_not_contains "$nudge_explicit_out" "auto-detected from your project manifest" \
  "verify nudge is suppressed when --verify is user-supplied"

# 10) analyze drops agent_exit != 0 rows and records excluded_runs
EXP new ex-timeout --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$nw_repo" >/dev/null
cat > "$(exp_dir_for ex-timeout)/runs.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t1","arm":"A","rep":1,"cost_usd":0,"success":true,"agent_exit":124,"verify_exit":0}
{"task":"t1","arm":"A","rep":2,"cost_usd":5.5,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t1","arm":"B","rep":0,"cost_usd":4.0,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t1","arm":"B","rep":1,"cost_usd":0,"success":true,"agent_exit":2,"verify_exit":0}
{"task":"t1","arm":"B","rep":2,"cost_usd":4.5,"success":true,"agent_exit":0,"verify_exit":0}
EOF
EXP analyze ex-timeout --seed 7 --bootstrap 200 >/dev/null
ex_result="$(cat "$(exp_dir_for ex-timeout)/result.json")"
assert_contains "$ex_result" '"excluded_runs": 2' \
  "analyze records excluded_runs:2 (both agent_exit=124 and agent_exit=2 dropped)"
# A_mean is over the 2 clean A rows (5.0+5.5)/2 = 5.25, NOT (5.0+0+5.5)/3 = 3.5
assert_contains "$ex_result" '"A_mean": 5.250000' \
  "A_mean computed from clean rows only (excluded $0 timeout row)"
assert_contains "$ex_result" '"B_mean": 4.250000' \
  "B_mean computed from clean rows only (excluded $0 error row)"

# 11) Report banner surfaces the exclusions (cost-only since 0.24.0 — the rows
# stay on the success axis with the verifier's verdict)
ex_report_out="$(EXP report ex-timeout 2>&1)"
assert_contains "$ex_report_out" "Excluded 2 run(s) from COST means" \
  "report banner names the cost-only exclusion count"
assert_contains "$ex_report_out" "agent_exit ≠ 0" \
  "report banner names the cause (agent_exit ≠ 0)"
assert_contains "$ex_report_out" "success axis" \
  "report banner says excluded rows still count on the success axis"

# 12) Report suppresses degenerate CI when N=1 paired task (paired-by-task)
# Bootstrap on 1 task → CI collapses to a point. Don't print fake precision.
EXP new under-1 --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$nw_repo" >/dev/null
cat > "$(exp_dir_for under-1)/runs.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t1","arm":"B","rep":0,"cost_usd":3.5,"success":true,"agent_exit":0,"verify_exit":0}
EOF
EXP analyze under-1 --seed 7 --bootstrap 200 >/dev/null
under_report_out="$(EXP report under-1 2>&1)"
assert_contains "$under_report_out" "(insufficient data)" \
  "N=1 paired-by-task report replaces CI numerics with 'insufficient data'"
assert_contains "$under_report_out" "Conservative savings rate: not computed" \
  "N=1 paired-by-task report suppresses the conservative-savings number"
# result.json still carries the raw numbers — only the report suppresses them
under_result="$(cat "$(exp_dir_for under-1)/result.json")"
assert_contains "$under_result" '"ci95":' \
  "result.json still carries raw ci95 array (only the report suppresses it)"

# ── 0.12.2 fixes ─────────────────────────────────────────────

# 13) Soft gate — N=2-4 tasks gets a verdict + 'WIDE CI / LIMITED POWER',
# not refused. The 0.12.1 hard cliff (refuse <5) was too strict.
EXP new low3 --arm A: --arm B: --task "x" --verify true --repo "$nw_repo" >/dev/null
cat > "$(exp_dir_for low3)/runs.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"B","rep":0,"cost_usd":3.0,"success":true,"agent_exit":0}
{"task":"t2","arm":"A","rep":0,"cost_usd":6.0,"success":true,"agent_exit":0}
{"task":"t2","arm":"B","rep":0,"cost_usd":4.0,"success":true,"agent_exit":0}
{"task":"t3","arm":"A","rep":0,"cost_usd":7.0,"success":true,"agent_exit":0}
{"task":"t3","arm":"B","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0}
EOF
EXP analyze low3 --seed 7 --bootstrap 500 >/dev/null
low3_result="$(cat "$(exp_dir_for low3)/result.json")"
# N=3 should still get a verdict (not refused) but with the wide-CI caveat
assert_contains "$low3_result" '"tasks_paired": 3'         "low-N analysis records the task count"
assert_contains "$low3_result" '"analysis_method": "paired-by-task"' "low-N stays paired-by-task in A/B"
low3_report="$(EXP report low3 2>&1)"
assert_contains "$low3_report" "LIMITED POWER"             "report flags low-power at N=3"
assert_contains "$low3_report" "N=3 paired task"           "report names the N count for context"
# N=3 still shows a real CI (not 'insufficient data') — it's wide, not degenerate
assert_not_contains "$low3_report" "(insufficient data)"   "N=3 CI is shown (wide but real); not suppressed"

# 14) A/A replicate-level fallback when N=1 task × K replicates
# This is the right analysis when you can only afford one task — the
# bias detection question is "do A and A_2 have systematically different
# cost distributions on this one task?", which is a 2-sample test on K reps.
EXP new aa-rep --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$nw_repo" >/dev/null
cat > "$(exp_dir_for aa-rep)/runs-aa.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":1,"cost_usd":5.2,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":2,"cost_usd":4.9,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":3,"cost_usd":5.1,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":0,"cost_usd":5.1,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":1,"cost_usd":5.3,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":2,"cost_usd":4.8,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":3,"cost_usd":5.2,"success":true,"agent_exit":0}
EOF
EXP analyze aa-rep --aa --seed 7 --bootstrap 500 >/dev/null
aa_rep_result="$(cat "$(exp_dir_for aa-rep)/result-aa.json")"
assert_contains "$aa_rep_result" '"analysis_method": "replicate-level"' \
  "A/A N=1 × K reps switches to replicate-level analysis (not paired-by-task)"
assert_contains "$aa_rep_result" '"verdict": "A/A OK' \
  "A/A clean data with replicate-level analysis → 'A/A OK' verdict"
aa_rep_report="$(EXP report aa-rep --aa 2>&1)"
assert_contains "$aa_rep_report" "replicate-level bootstrap" \
  "report banner names the replicate-level method"
assert_contains "$aa_rep_report" "1 task × 4/4 reps" \
  "report verdict shows the (1 task, K reps) shape"

# 14b) A/A replicate-level can also DETECT bias when reps systematically diverge
cat > "$(exp_dir_for aa-rep)/runs-aa.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":1,"cost_usd":5.1,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":2,"cost_usd":5.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"A","rep":3,"cost_usd":5.1,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":0,"cost_usd":7.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":1,"cost_usd":7.2,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":2,"cost_usd":7.1,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":3,"cost_usd":7.3,"success":true,"agent_exit":0}
EOF
EXP analyze aa-rep --aa --seed 7 --bootstrap 500 >/dev/null
aa_rep_biased="$(cat "$(exp_dir_for aa-rep)/result-aa.json")"
assert_contains "$aa_rep_biased" '"verdict": "A/A BIASED' \
  "A/A replicate-level detects systematic offset → 'A/A BIASED' verdict"

# 14c) A/A replicate-level needs ≥2 reps per arm
cat > "$(exp_dir_for aa-rep)/runs-aa.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":5.0,"success":true,"agent_exit":0}
{"task":"t1","arm":"A_2","rep":0,"cost_usd":5.1,"success":true,"agent_exit":0}
EOF
EXP analyze aa-rep --aa --seed 7 >/dev/null
aa_rep_too_few="$(cat "$(exp_dir_for aa-rep)/result-aa.json")"
assert_contains "$aa_rep_too_few" '"verdict": "A/A data degenerate"' \
  "A/A with only 1 task × 1 rep per arm → 'A/A data degenerate' (can't do replicate-level either)"

# 15) Multi-task --task in new
EXP new multi --arm A: --arm B: \
  --task "Task one." --task "Task two." --task "Task three." \
  --verify true --repo "$nw_repo" >/dev/null
multi_spec="$(cat "$(exp_dir_for multi)/spec")"
assert_contains "$multi_spec" "[task:t1]" "multi-task spec has t1"
assert_contains "$multi_spec" "[task:t2]" "multi-task spec has t2"
assert_contains "$multi_spec" "[task:t3]" "multi-task spec has t3"
assert_eq "yes" "$([ -f "$(exp_dir_for multi)/tasks/t1.md" ] && echo yes || echo no)" \
  "multi-task: t1.md written"
assert_eq "yes" "$([ -f "$(exp_dir_for multi)/tasks/t2.md" ] && echo yes || echo no)" \
  "multi-task: t2.md written"
assert_eq "yes" "$([ -f "$(exp_dir_for multi)/tasks/t3.md" ] && echo yes || echo no)" \
  "multi-task: t3.md written"
EXP validate multi >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "multi-task spec validates"

# 16) worktree_include — symlinks repo paths into the worktree before agent runs
wi_repo="$sb/wi-repo"
mkdir -p "$wi_repo/src" "$wi_repo/venv/bin"
(cd "$wi_repo" && git init -q && git config user.email t@t && git config user.name t && \
  echo 'src' > src/x.py && git add . && git commit -qm i)
# venv is untracked — git worktree won't bring it
echo 'fake' > "$wi_repo/venv/bin/pytest"
echo "DATABASE_URL=fake" > "$wi_repo/.env"

EXP new wi-exp --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$wi_repo" >/dev/null
# Set worktree_include (the wizard leaves it commented)
printf 'worktree_include: venv, .env\n' | file_insert_before '# worktree_include:*' "$(exp_dir_for wi-exp)/spec"

# Stub adapter that asserts the symlinks are visible inside the worktree
cat > "$sb/wi-adapter.sh" <<'STUB'
#!/usr/bin/env bash
[ -e venv/bin/pytest ] && v=ok || v=MISS
[ -e .env ] && e=ok || e=MISS
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":1,"output_tokens":1},"_check":"v=%s e=%s"}\n' "$v" "$e"
STUB
chmod +x "$sb/wi-adapter.sh"

EXP run wi-exp --yes --adapter "$sb/wi-adapter.sh" --k 1 >/dev/null 2>&1
log_a="$(exp_dir_for wi-exp)/logs/t1-A-0.json"
assert_contains "$(cat "$log_a")" 'v=ok' "worktree_include symlinks venv/ into the worktree"
assert_contains "$(cat "$log_a")" 'e=ok' "worktree_include symlinks .env into the worktree"
# Missing path → skipped with a warning, doesn't fail the run
sed_sub 's/^worktree_include: venv, .env$/worktree_include: venv, .env, does-not-exist/' "$(exp_dir_for wi-exp)/spec"
wi_missing_out="$(EXP run wi-exp --yes --adapter "$sb/wi-adapter.sh" --k 1 2>&1)"
assert_contains "$wi_missing_out" "'does-not-exist' not found in repo" \
  "worktree_include: missing paths are skipped with a warning, not fatal"

# 16b) Default warning about worktree isolation when worktree_include is unset
EXP new wi-default --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$wi_repo" >/dev/null
wi_default_out="$(EXP run wi-default --yes --adapter "$sb/wi-adapter.sh" --k 1 2>&1)"
assert_contains "$wi_default_out" "TRACKED files" \
  "run prints worktree-isolation warning when worktree_include is unset"
assert_contains "$wi_default_out" "worktree_include" \
  "warning names the worktree_include field as the fix"

# 17) Cache-read pricing nuance in magnitude estimate
mag_nuance_out="$(EXP new mag-nuance --kind prompt-debt-deletion \
  --file CLAUDE.md --lines "3" --task t --verify true --replicates 1 \
  --repo "$big_repo" 2>&1)"
assert_contains "$mag_nuance_out" "Pricing nuance" \
  "magnitude estimate includes the cache-read pricing nuance"
assert_contains "$mag_nuance_out" "cache reads" \
  "pricing nuance names cache-read pricing"
assert_contains "$mag_nuance_out" "ratio is preserved" \
  "pricing nuance preserves the cost-vs-magnitude ratio framing"

# 18) Pre-existing-enforcement nudge for CLAUDE.md / AGENTS.md edits
enforce_out="$(EXP new enforce-claude --kind prompt-debt-deletion \
  --file CLAUDE.md --lines "3" --task t --verify true --replicates 1 \
  --repo "$big_repo" 2>&1)"
assert_contains "$enforce_out" "pre-commit hooks" \
  "CLAUDE.md prompt-debt scaffold mentions checking pre-commit hooks"
assert_contains "$enforce_out" ".claude/settings.json" \
  "CLAUDE.md prompt-debt scaffold mentions Claude Code hooks"
assert_contains "$enforce_out" "redundant" \
  "enforcement nudge calls out the 'CLAUDE.md text becomes redundant' failure mode"

# Other-file deletions don't trigger the CLAUDE.md-specific nudge
big_repo3="$sb/big-repo3"
mkdir -p "$big_repo3" && (cd "$big_repo3" && git init -q && \
  git config user.email t@t && git config user.name t)
{ for i in $(seq 1 50); do echo "line $i"; done; } > "$big_repo3/random.md"
(cd "$big_repo3" && git add . && git commit -qm i)
other_out="$(EXP new enforce-other --kind prompt-debt-deletion \
  --file random.md --lines "3" --task t --verify true --replicates 1 \
  --repo "$big_repo3" 2>&1)"
assert_not_contains "$other_out" "pre-commit hooks" \
  "Non-CLAUDE.md deletions don't trigger the enforcement nudge"

# ── merge ─────────────────────────────────────────────────────
# Synthesize a B-wins runs.jsonl for the prompt-debt experiment, analyze, merge.
synth_runs() {
  # 5 tasks × 2 replicates × 2 arms, B reliably cheaper
  local exp="$1"
  local out; out="$(exp_dir_for "$exp")/runs.jsonl"
  : > "$out"
  local tid c_a c_b r
  for tid in t1 t2 t3 t4 t5; do
    case "$tid" in
      t1) c_a=0.20; c_b=0.12 ;;
      t2) c_a=0.30; c_b=0.18 ;;
      t3) c_a=0.40; c_b=0.24 ;;
      t4) c_a=0.50; c_b=0.30 ;;
      t5) c_a=0.60; c_b=0.36 ;;
    esac
    for r in 0 1; do
      printf '{"task":"%s","arm":"A","rep":%d,"cost_usd":%s,"success":true}\n' "$tid" "$r" "$c_a" >> "$out"
      printf '{"task":"%s","arm":"B","rep":%d,"cost_usd":%s,"success":true}\n' "$tid" "$r" "$c_b" >> "$out"
    done
  done
}

# Re-create CLAUDE.md (an earlier test may have shifted the repo state)
cat > "$nw_repo/CLAUDE.md" <<'EOF'
# Project rules
You are an expert engineer.
Always think step by step.
Take a deep breath.
Don't hallucinate.
Be helpful.
EOF

synth_runs debt-1
EXP analyze debt-1 --seed 7 >/dev/null
# B-wins applies; CLAUDE.md in the repo gets the lines stripped
EXP merge debt-1 --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "merge on B-wins exits 0"
assert_not_contains "$(cat "$nw_repo/CLAUDE.md")" "think step by step" \
  "merge stripped the cargo-cult line from the repo's CLAUDE.md"
assert_not_contains "$(cat "$nw_repo/CLAUDE.md")" "deep breath" \
  "merge stripped 'deep breath' from the repo's CLAUDE.md"
assert_contains "$(cat "$nw_repo/CLAUDE.md")" "You are an expert engineer." \
  "merge preserved the lines that weren't in the deletion list"

# Header-Audit-Finding trailer suggestion appears (provenance for the commit)
merge_out="$(EXP merge debt-1 --yes 2>&1)"
assert_contains "$merge_out" "Header-Audit-Finding: delete-cargo-cult" \
  "merge prints the Header-Audit-Finding trailer suggestion when ledger_key is set"
assert_contains "$merge_out" "header-ledger record applied" \
  "merge prints the ledger record command"

# No-proven-win → refuses (without --force)
synth_flat_runs() {
  local out; out="$(exp_dir_for "$1")/runs.jsonl"
  : > "$out"
  local tid r
  for tid in t1 t2 t3 t4 t5; do for r in 0 1; do
    printf '{"task":"%s","arm":"A","rep":%d,"cost_usd":0.50,"success":true}\n' "$tid" "$r" >> "$out"
    printf '{"task":"%s","arm":"B","rep":%d,"cost_usd":0.51,"success":true}\n' "$tid" "$r" >> "$out"
  done; done
}
EXP new flat-1 --kind prompt-debt-deletion --file CLAUDE.md --lines "6" \
  --task "tiny" --verify true --replicates 2 --repo "$nw_repo" >/dev/null
synth_flat_runs flat-1
EXP analyze flat-1 --seed 7 >/dev/null
EXP merge flat-1 --yes >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "merge refuses when verdict is not 'B wins'"
refuse_out="$(EXP merge flat-1 --yes 2>&1)"
assert_contains "$refuse_out" "refusing to merge" "merge refusal mentions 'refusing to merge'"
# --force overrides the refusal
EXP merge flat-1 --yes --force >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "merge --force overrides the verdict refusal"

# A/A result → refuses (model-swap or otherwise; the spec is the same)
EXP new aa-m --arm A: --arm B: --task "tiny" --verify true \
  --replicates 1 --repo "$nw_repo" >/dev/null
mkdir -p "$(exp_dir_for aa-m)"
cat > "$(exp_dir_for aa-m)/result.json" << 'EOF'
{ "mode": "aa", "arms": ["A","A_2"], "verdict": "A/A OK — harness clean" }
EOF
EXP merge aa-m --yes >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "merge refuses an A/A result (nothing to merge)"

# Missing result.json → error
EXP new noresult --arm A: --arm B: --task t --verify true \
  --replicates 1 --repo "$nw_repo" >/dev/null
EXP merge noresult --yes >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "merge errors when result.json is missing"

# Model-swap merge: no files to copy, prints model-update note + ledger hint
EXP new swap-merge --kind model-swap --from claude-opus-4-7 --to claude-sonnet-4-6 \
  --task "tiny" --verify true --replicates 2 \
  --ledger-key route-boilerplate --repo "$nw_repo" >/dev/null
synth_runs swap-merge
EXP analyze swap-merge --seed 7 >/dev/null
swap_merge_out="$(EXP merge swap-merge --yes 2>&1)"
assert_contains "$swap_merge_out" "engine change (model and/or effort), not a code change" \
  "merge on a model-swap spec explains there are no files to copy"
assert_contains "$swap_merge_out" "/model claude-sonnet-4-6" \
  "merge on a model-swap surfaces the target model to set"
assert_contains "$swap_merge_out" "header-ledger record applied \"route-boilerplate\"" \
  "merge on a model-swap still suggests the ledger record"

# ════════════════════════════════════════════════════════════════════
# 0.12.3 — pre-spend honesty: degenerate-CI warning (#1), --yes still
# discloses (#2), measured noise-floor surfaced at the A/B gate (#3),
# prompt-debt discrimination warning incl. hand-rolled specs (#4).
# ════════════════════════════════════════════════════════════════════

# Clean repo + 1-task spec for the gate tests.
gate_repo="$sb/gate-repo"
mkdir -p "$gate_repo" && (cd "$gate_repo" && git init -q && \
  git config user.email t@t && git config user.name t && \
  echo hi > a.txt && git add a.txt && git commit -qm init)
EXP define gate-1 --arm "A=" --arm "B=" --replicates 2 >/dev/null
write_task_prompt gate-1 example
sed_sub "s#^repo: .*#repo: $gate_repo#" "$(exp_dir_for gate-1)/spec"

# #1 — validate WARNS (does not fail) that a 1-task A/B yields a degenerate CI.
EXP validate gate-1 >/dev/null 2>&1; deg_rc=$?
assert_exit 0 "$deg_rc" "#1 validate still passes (warn, not fail) for a 1-task spec"
assert_contains "$(EXP validate gate-1 2>&1)" "DEGENERATE" \
  "#1 validate warns a 1-task A/B yields a degenerate CI BEFORE any spend"

# #2/#3 — the cost gate. claude is absent from /usr/bin:/bin, so the no-adapter
# branch prints the disclosure then fails cleanly at the claude check — no real
# agent is ever spawned. HEADER_EXPERIMENT_ADAPTER is cleared so it can't leak in.
gate_out="$(HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_ADAPTER="" PATH="/usr/bin:/bin" "$HE" run gate-1 --yes 2>&1)"
assert_contains "$gate_out" "About to launch" \
  "#2 run --yes still prints the cost disclosure (skips the prompt, not the disclosure)"
assert_contains "$gate_out" "authorized non-interactively" \
  "#2 run --yes records that the spend was authorized (disclosure on the record)"
assert_contains "$gate_out" "No A/A noise floor on record" \
  "#3 A/B gate nudges to run --aa first when no A/A result exists"

# #3 — with a prior A/A result on disk, the gate surfaces the MEASURED floor.
cat > "$(exp_dir_for gate-1)/result-aa.json" <<'JSON'
{ "mode": "aa", "cost": { "A_mean": 0.100000, "B_mean": 0.100000, "diff_mean_BA": 0.000000, "ci95": [-0.042000, 0.006000], "favorable": false }, "success": { "ci95": [0.0000, 0.0000] }, "verdict": "A/A OK" }
JSON
floor_out="$(HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_ADAPTER="" PATH="/usr/bin:/bin" "$HE" run gate-1 --yes 2>&1)"
assert_contains "$floor_out" "Noise floor (from your A/A run)" \
  "#3 A/B gate surfaces the measured noise floor when an A/A result exists"
assert_contains "$floor_out" 'half-width ~$0.0240' \
  "#3 noise-floor half-width = (0.006-(-0.042))/2 = 0.0240, computed from the A/A cost CI"

# #4 — prompt-debt discrimination warning, caught even on a HAND-ROLLED spec.
disc_repo="$sb/disc-repo"
mkdir -p "$disc_repo" && (cd "$disc_repo" && git init -q && \
  git config user.email t@t && git config user.name t)
cat > "$disc_repo/CLAUDE.md" <<'EOF'
# Rules
You MUST run the test suite before every commit.
Be concise and helpful.
EOF
echo '{"name":"x"}' > "$disc_repo/package.json"
(cd "$disc_repo" && git add . && git commit -qm init)
# Generic spec (no --kind), arm B overrides_dir = arms/B, materialized BY HAND
# afterwards — exactly the path that bypasses new --kind's scaffold guardrails.
EXP new disc-1 --arm "A:" --arm "B::arms/B" \
  --task "tiny task" --verify "true" --replicates 2 --repo "$disc_repo" >/dev/null 2>&1
mkdir -p "$(exp_dir_for disc-1)/arms/B"
sed '2d' "$disc_repo/CLAUDE.md" > "$(exp_dir_for disc-1)/arms/B/CLAUDE.md"   # drop the MUST line
disc_out="$(EXP validate disc-1 2>&1)"
assert_contains "$disc_out" "Discrimination check" \
  "#4 validate warns when an arm trims a CLAUDE.md (hand-rolled spec caught via diff)"
assert_contains "$disc_out" "behavior MANDATES" \
  "#4 validate escalates when the trimmed text carries an emphatic mandate (MUST)"
# Sentence-case cargo-cult ('Always think...', "Don't...") warns but does NOT
# escalate (fresh repo — don't reuse debt-1, which `merge` overwrites earlier).
cc_repo="$sb/cc-repo"
mkdir -p "$cc_repo" && (cd "$cc_repo" && git init -q && \
  git config user.email t@t && git config user.name t)
cat > "$cc_repo/CLAUDE.md" <<'EOF'
# Rules
Always think step by step.
Don't hallucinate.
Be helpful.
EOF
(cd "$cc_repo" && git add . && git commit -qm init)
EXP new cc-1 --arm "A:" --arm "B::arms/B" \
  --task "tiny" --verify "true" --replicates 2 --repo "$cc_repo" >/dev/null 2>&1
mkdir -p "$(exp_dir_for cc-1)/arms/B"
sed '2,3d' "$cc_repo/CLAUDE.md" > "$(exp_dir_for cc-1)/arms/B/CLAUDE.md"   # drop cargo-cult lines
cc_out="$(EXP validate cc-1 2>&1)"
assert_contains "$cc_out" "Discrimination check" \
  "#4 validate warns for a cargo-cult trim too"
assert_not_contains "$cc_out" "behavior MANDATES" \
  "#4 no mandate escalation for sentence-case cargo-cult (Always/Don't are not MUST/NEVER)"

# ════════════════════════════════════════════════════════════════════
# 0.13.0 — ephemeral-infra lifecycle (setup/teardown), cost-axis caveat,
# guardrail-value nudge.
# ════════════════════════════════════════════════════════════════════
write_stub_adapter "$sb/life-adapter.sh"   # A=0.10, B=0.06 (B cheaper → favorable)
life_repo="$sb/life-repo"
mkdir -p "$life_repo" && (cd "$life_repo" && git init -q && \
  git config user.email t@t && git config user.name t && \
  echo hi > a.txt && git add a.txt && git commit -qm init)

# ── #1 setup/teardown, experiment scope: env reaches verify, teardown runs ──
EXP new life-exp --arm "A:" --arm "B:" \
  --task "tiny" --verify 'test -n "$EXP_DB"' \
  --replicates 1 --repo "$life_repo" >/dev/null 2>&1
life_mark="$sb/life-exp.marker"
# keys go in the TOP block (above [arm:…]) — that's where spec_get_scalar reads.
printf '%s\n' \
  "setup: echo EXP_DB=branch-xyz; touch $life_mark" \
  "teardown: rm -f $life_mark" \
  "setup_scope: experiment" | file_append_after 'commit: HEAD*' "$(exp_dir_for life-exp)/spec"
EXP run life-exp --yes --adapter "$sb/life-adapter.sh" >/dev/null 2>&1
assert_contains "$(cat "$(exp_dir_for life-exp)/runs.jsonl")" '"success":true' \
  "#1 setup-injected env (EXP_DB) reaches the verifier → success=true"
assert_eq "gone" "$([ -e "$life_mark" ] && echo present || echo gone)" \
  "#1 teardown ran at end of experiment scope (marker removed)"
assert_eq "gone" "$([ -e "$(exp_dir_for life-exp)/.run-env" ] && echo present || echo gone)" \
  "#1 transient .run-env cleaned up after the run"

# ── #1 run scope: setup provisions once per (task,arm,rep) ──
EXP new life-run --arm "A:" --arm "B:" \
  --task "tiny" --verify true \
  --replicates 2 --repo "$life_repo" >/dev/null 2>&1
life_count="$sb/life-run.count"; : > "$life_count"
printf '%s\n' \
  "setup: echo prov >> $life_count; echo EXP_DB=x" \
  "teardown: true" \
  "setup_scope: run" | file_append_after 'commit: HEAD*' "$(exp_dir_for life-run)/spec"
EXP run life-run --yes --adapter "$sb/life-adapter.sh" >/dev/null 2>&1
assert_eq "4" "$(wc -l < "$life_count" | tr -d ' ')" \
  "#1 run-scope provisions once per (task,arm,rep) = 1×2×2 = 4"

# ── validate rejects a bad setup_scope ──
EXP new life-bad --arm "A:" --arm "B:" --task "tiny" --verify true \
  --replicates 1 --repo "$life_repo" >/dev/null 2>&1
printf 'setup_scope: bogus\n' | file_append_after 'commit: HEAD*' "$(exp_dir_for life-bad)/spec"
EXP validate life-bad >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "#1 validate rejects setup_scope other than experiment|run"

# ── #2 cost-axis caveat: mandate-deletion with NO measurable cost delta ──
cat > "$sb/equal-adapter.sh" <<'EOF'
#!/usr/bin/env bash
printf '{"type":"result","total_cost_usd":0.05,"usage":{"input_tokens":500,"output_tokens":50,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}\n'
EOF
chmod +x "$sb/equal-adapter.sh"
ca_repo="$sb/ca-repo"
mkdir -p "$ca_repo" && (cd "$ca_repo" && git init -q && \
  git config user.email t@t && git config user.name t)
cat > "$ca_repo/CLAUDE.md" <<'EOF'
# Rules
You MUST run the browser visual check after every frontend change.
Be concise.
EOF
echo '{"name":"x"}' > "$ca_repo/package.json"
(cd "$ca_repo" && git add . && git commit -qm init)
EXP new ca-1 --kind prompt-debt-deletion --file CLAUDE.md --lines 2 \
  --task "tiny" --verify true --replicates 1 --repo "$ca_repo" >/dev/null 2>&1
EXP run ca-1 --yes --adapter "$sb/equal-adapter.sh" >/dev/null 2>&1   # equal cost → favorable=false
EXP analyze ca-1 >/dev/null 2>&1
assert_contains "$(EXP report ca-1 2>&1)" "Cost-axis check" \
  "#2 report flags cost-axis non-discrimination (mandate-deletion, arm A not measurably costlier)"

# ── #2 negative: when B is genuinely cheaper (favorable), no cost-axis caveat ──
EXP new ca-2 --kind prompt-debt-deletion --file CLAUDE.md --lines 2 \
  --task "tiny" --verify true --replicates 1 --repo "$ca_repo" >/dev/null 2>&1
EXP run ca-2 --yes --adapter "$sb/life-adapter.sh" >/dev/null 2>&1   # A=0.10 > B=0.06 → favorable
EXP analyze ca-2 >/dev/null 2>&1
assert_not_contains "$(EXP report ca-2 2>&1)" "Cost-axis check" \
  "#2 no cost-axis caveat when arm B is genuinely cheaper (favorable=true)"

# ── #3 guardrail-value nudge on a mandate deletion ──
assert_contains "$(EXP new guard-1 --kind prompt-debt-deletion --file CLAUDE.md --lines 2 \
  --task tiny --verify true --replicates 1 --repo "$ca_repo" 2>&1)" "guardrail-VALUE" \
  "#3 new --kind prompt-debt-deletion surfaces the guardrail-value recommendation for a mandate"

# ── validate rejects lifecycle keys placed BELOW a [section] (silent no-op) ──
# spec_get_scalar can't see them there → no infra provisioned → false DB isolation.
EXP new life-misplaced --arm "A:" --arm "B:" --task "tiny" --verify true \
  --replicates 1 --repo "$life_repo" >/dev/null 2>&1
printf 'setup: echo DATABASE_URL=throwaway\n' >> "$(exp_dir_for life-misplaced)/spec"  # appended AFTER the sections
EXP validate life-misplaced >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "#1 validate rejects setup/teardown placed below a [section] (silent no-op landmine)"
assert_contains "$(EXP validate life-misplaced 2>&1)" "top block" \
  "#1 misplacement error explains keys must be in the top block"

# ── MINE: git-history task mining + tests-oracle verifier (design §11) ─────────
# Build a real repo whose history contains a FAIL_TO_PASS fix, using a pure-bash
# oracle (no python/npm needed): impl.sh holds functions; tests/check.sh sources
# it and asserts. The fixing commit adds sub() AND the test for it, so at the
# PARENT (with the new test re-applied) the suite fails — exactly what mine looks
# for.  VERIFY = `bash tests/check.sh`.
mine_repo="$sb/mine-repo"; mkdir -p "$mine_repo/tests"
(
  cd "$mine_repo" && git init -q && git config user.email t@t.t && git config user.name t
  printf 'add() { echo $(( $1 + $2 )); }\n' > impl.sh
  printf '. ./impl.sh\n[ "$(add 1 2)" = 3 ] || exit 1\n' > tests/check.sh
  git add -A && git commit -qm "init: add()"
  # the fix: implementation + its test, together (the mineable shape)
  printf 'add() { echo $(( $1 + $2 )); }\nsub() { echo $(( $1 - $2 )); }\n' > impl.sh
  printf '. ./impl.sh\n[ "$(add 1 2)" = 3 ] || exit 1\n[ "$(sub 5 2)" = 3 ] || exit 1\n' > tests/check.sh
  git add -A && git commit -qm "feat: add sub()"
  git rev-parse --short HEAD > "$sb/.fix_sha"
  # a test-only commit (no implementation) — must NOT be a candidate
  printf '. ./impl.sh\n[ "$(add 1 2)" = 3 ] || exit 1\n[ "$(sub 5 2)" = 3 ] || exit 1\ntrue\n' > tests/check.sh
  git add -A && git commit -qm "test: tidy"
  # a source-only commit (no test) — must NOT be a candidate
  printf 'add() { echo $(( $1 + $2 )); }\nsub() { echo $(( $1 - $2 )); }\nmul() { echo $(( $1 * $2 )); }\n' > impl.sh
  git add -A && git commit -qm "feat: add mul() (untested)"
)
FIX_SHA="$(cat "$sb/.fix_sha")"
VC="bash tests/check.sh"

# ── mine --list: discovers the mixed fix commit, excludes test-only/src-only ──
list_out="$(EXP mine ml --repo "$mine_repo" --verify "$VC" --list 2>/dev/null)"
assert_contains "$list_out" "$FIX_SHA" "mine --list surfaces the source+tests fix commit"
assert_contains "$list_out" "tests/check.sh" "mine --list names the commit's test file"
assert_eq "no" "$([ -d "$(exp_dir_for ml)" ] && echo yes || echo no)" \
  "mine --list writes nothing (no experiment dir created)"
# exactly ONE candidate (the test-only and source-only commits are filtered out)
n_cand="$(printf '%s\n' "$list_out" | grep -c 'parent ')"
assert_eq "1" "$n_cand" "mine --list counts only the mixed commit (test-only + src-only excluded)"

# ── mine (build): validates by running the suite, writes a runnable spec ──
mine_out="$(EXP mine mg --repo "$mine_repo" --verify "$VC" --yes 2>&1)"
assert_contains "$mine_out" "tests fail at parent" "mine validates the candidate by running the suite at the parent"
mg_spec="$(exp_dir_for mg)/spec"
assert_eq "yes" "$([ -f "$mg_spec" ] && echo yes || echo no)" "mine wrote a spec"
mg_content="$(cat "$mg_spec")"
assert_contains "$mg_content" "[task:t-$FIX_SHA]"     "spec task is keyed by the fix commit"
assert_contains "$mg_content" "apply_from: $FIX_SHA"  "spec records the fixing commit as apply_from"
assert_contains "$mg_content" "apply_paths: tests/check.sh" "spec records the test file to apply"
assert_contains "$mg_content" "lock_paths: tests/check.sh"  "spec locks the test file at grade time"
assert_contains "$mg_content" "verify: $VC"           "spec uses the repo's own suite as the oracle"
assert_contains "$mg_content" "model: claude-opus-4-8"   "default arm A is a capable model"
assert_contains "$mg_content" "model: claude-sonnet-4-6" "default arm B is the cheaper model"
assert_eq "yes" "$([ -f "$(exp_dir_for mg)/tasks/_oracle.md" ] && echo yes || echo no)" \
  "mine generates the shared task prompt"
assert_contains "$mg_content" "commit: " "spec pins a per-task base commit (the fix's parent)"
# the generated spec must pass validate
EXP validate mg >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "the mined spec passes validate"

# ── the apply→agent→lock→verify pipeline (the tests-oracle in action) ──
# noop agent: changes nothing → the re-applied test fails (sub missing) → success false.
cat > "$sb/m-noop.sh" <<'EOF'
#!/usr/bin/env bash
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5}}\n'
EOF
# fix agent: writes the correct implementation → success true.
cat > "$sb/m-fix.sh" <<'EOF'
#!/usr/bin/env bash
printf 'add() { echo $(( $1 + $2 )); }\nsub() { echo $(( $1 - $2 )); }\n' > impl.sh
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5}}\n'
EOF
# cheat agent: guts the test to pass trivially → lock restores it → success false.
cat > "$sb/m-cheat.sh" <<'EOF'
#!/usr/bin/env bash
printf 'true\n' > tests/check.sh
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5}}\n'
EOF
chmod +x "$sb/m-noop.sh" "$sb/m-fix.sh" "$sb/m-cheat.sh"
mg_runs="$(exp_dir_for mg)/runs.jsonl"

EXP run mg --k 1 --adapter "$sb/m-noop.sh" >/dev/null 2>&1
assert_contains "$(cat "$mg_runs")" '"success":false' "noop agent → applied test fails (apply step works)"
assert_not_contains "$(cat "$mg_runs")" '"success":true' "noop agent never spuriously succeeds"

EXP run mg --k 1 --adapter "$sb/m-fix.sh" >/dev/null 2>&1
assert_contains "$(cat "$mg_runs")" '"success":true' "fix agent → suite passes (impl edits are graded)"

EXP run mg --k 1 --adapter "$sb/m-cheat.sh" >/dev/null 2>&1
assert_contains "$(cat "$mg_runs")" '"success":false' "cheat agent → lock restores the test → cannot game the oracle"
assert_not_contains "$(cat "$mg_runs")" '"success":true' "lock defeats test-tampering (reward-hacking defense)"

# The lock and the seal must hold SIMULTANEOUSLY, and they pull in opposite
# directions: the lock needs the fixing ref at grade time, the agent must never
# reach it. (Sealing naively broke the lock — the grade-time `git checkout` had
# no object store left; the fix snapshots the graded files out before sealing.)
# A cheating agent that ALSO reads git must neither game the oracle nor see the
# commit its task was mined from.
cat > "$sb/m-cheat-spy.sh" <<EOF
#!/usr/bin/env bash
printf 'true\n' > tests/check.sh
{ printf 'REVCOUNT=%s\n' "\$(git rev-list --all --count 2>/dev/null || echo ERR)"
  if git cat-file -e $FIX_SHA 2>/dev/null; then echo FIX_COMMIT_REACHABLE; else echo FIX_COMMIT_SEALED; fi
} >> "\$SPY_OUT" 2>&1
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5}}\n'
EOF
chmod +x "$sb/m-cheat-spy.sh"
export SPY_OUT="$sb/mg-spy.log"; : > "$SPY_OUT"
EXP run mg --k 1 --adapter "$sb/m-cheat-spy.sh" >/dev/null 2>&1
assert_contains "$(cat "$mg_runs")" '"success":false' \
  "cheat+spy agent: the lock still holds under a sealed workspace"
assert_contains "$(cat "$SPY_OUT")" "FIX_COMMIT_SEALED" \
  "the mined task's fixing commit is unreachable from the sealed workspace"
assert_contains "$(cat "$SPY_OUT")" "REVCOUNT=1" \
  "a mined replicate sees exactly one (root) commit"
unset SPY_OUT

# ── arm overrides ──
EXP mine ma --repo "$mine_repo" --verify "$VC" --from m-x --to m-y --yes >/dev/null 2>&1
assert_contains "$(cat "$(exp_dir_for ma)/spec")" "model: m-x" "mine --from sets arm A model"
assert_contains "$(cat "$(exp_dir_for ma)/spec")" "model: m-y" "mine --to sets arm B model"
EXP mine mb --repo "$mine_repo" --verify "$VC" --arm "A:aa" --arm "B:bb" --yes >/dev/null 2>&1
mb_content="$(cat "$(exp_dir_for mb)/spec")"
assert_contains "$mb_content" "model: aa" "mine --arm overrides arm A"
assert_contains "$mb_content" "model: bb" "mine --arm overrides arm B"

# ── --max-files filters out broad commits (the fix touches 2 files) ──
EXP mine mf --repo "$mine_repo" --verify "$VC" --max-files 1 --list >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "mine --max-files 1 excludes the 2-file fix → no candidates → exit 1"

# ── error handling ──
EXP mine mdup --repo "$mine_repo" --verify "$VC" --yes >/dev/null 2>&1
EXP mine mdup --repo "$mine_repo" --verify "$VC" --yes >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "mine refuses to overwrite an existing experiment id"
mkdir -p "$sb/not-git"
EXP mine mng --repo "$sb/not-git" --verify "$VC" --list >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "mine errors on a non-git directory"
nomanifest="$sb/nomani"; mkdir -p "$nomanifest"
( cd "$nomanifest" && git init -q && git config user.email t@t.t && git config user.name t && \
  echo x > a && mkdir tests && echo y > tests/t && git add -A && git commit -qm i )
nm_err="$(EXP mine mnm2 --repo "$nomanifest" 2>&1)"
assert_contains "$nm_err" "couldn't detect a test command" \
  "mine without --verify and no manifest explains it needs a test command"

# ── candidates that PASS at their parent → worktree-isolation diagnostic ──
# (the PEP 660 editable-install footgun: a non-FAIL_TO_PASS commit stands in for
# the defeated-isolation case — the suite runs and passes against parent code.)
nofix="$sb/nofix"; mkdir -p "$nofix/tests"
( cd "$nofix" && git init -q && git config user.email t@t.t && git config user.name t && \
  printf 'foo(){ echo ok; }\n' > impl.sh && printf 'set -e\n. ./impl.sh\n[ "$(foo)" = ok ]\n' > tests/a.sh && \
  git add -A && git commit -qm init && \
  printf 'foo(){ echo ok; } # tweak\n' > impl.sh && printf 'set -e\n. ./impl.sh\n[ "$(foo)" = ok ]\n' > tests/b.sh && \
  git add -A && git commit -qm "chore: tweak impl + add test b" )
nofix_err="$(EXP mine mnofx --repo "$nofix" --verify "bash tests/a.sh && bash tests/b.sh" --yes 2>&1)"
assert_contains "$nofix_err" "PASSED at its parent" \
  "mine flags candidates whose tests pass at the parent (not a real FAIL_TO_PASS)"
assert_contains "$nofix_err" "editable install" \
  "mine names the PEP 660 editable-install / worktree-isolation cause"

# ════════════════════════════════════════════════════════════════════
# 0.18.0 — engine adoption: per-arm effort, `mine --adopt` (+ --sweep / --vs),
# transcript-based model detection, and merge's offer-to-apply.
# ════════════════════════════════════════════════════════════════════

# ── per-arm effort reaches the agent invocation ──────────────────────
# The adapter contract gained <model> <effort> as args 5 & 6. A capture stub
# records them so we can assert each arm's effort flows (the real-claude path
# turns the same values into --model/--effort flags).
cap="$sb/eff-args.log"; : > "$cap"
cat > "$sb/eff-adapter.sh" <<EOF
#!/usr/bin/env bash
printf 'arm=%s model=%s effort=%s\n' "\$2" "\$5" "\$6" >> "$cap"
printf '{"type":"result","model":"stub-%s","total_cost_usd":0.1,"usage":{"input_tokens":100,"output_tokens":10}}\n' "\$2"
EOF
chmod +x "$sb/eff-adapter.sh"

mkdir -p "$(exp_dir_for eff-1)/logs" "$(exp_dir_for eff-1)/tasks"
printf 'do the thing\n' > "$(exp_dir_for eff-1)/tasks/t.md"
cat > "$(exp_dir_for eff-1)/spec" <<EOF
id: eff-1
hypothesis: effort flows per-arm
repo: $git_repo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02
kind: engine-swap

[arm:A]
model: claude-opus-4-7
effort: xhigh
overrides_dir:

[arm:B]
model: claude-opus-4-8
effort: high
overrides_dir:

[task:t1]
prompt: tasks/t.md
verify: true
timeout_s: 60
EOF
EXP run eff-1 --yes --adapter "$sb/eff-adapter.sh" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "engine-swap run with per-arm effort exits 0"
cap_content="$(cat "$cap")"
assert_contains "$cap_content" "arm=A model=claude-opus-4-7 effort=xhigh" "arm A's model+effort reach the agent invocation"
assert_contains "$cap_content" "arm=B model=claude-opus-4-8 effort=high"  "arm B's model+effort reach the agent invocation"

# ── validate guards the effort level (typos would silently degrade) ──
sed_sub 's/^effort: high/effort: bogus/' "$(exp_dir_for eff-1)/spec"
EXP validate eff-1 >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "validate rejects an unknown effort level"
sed_sub 's/^effort: bogus/effort: high/' "$(exp_dir_for eff-1)/spec"
EXP validate eff-1 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "validate accepts a valid effort level"

# ── sync payload carries kind + per-arm effort (forward-compatible) ──
eff_payload="$(EXP push eff-1 --dry-run 2>/dev/null)"
assert_contains "$eff_payload" '"kind": "engine-swap"' "explicit kind: engine-swap reaches the sync payload"
assert_contains "$eff_payload" '"effort":"xhigh"' "arm A effort reaches the sync payload"
assert_contains "$eff_payload" '"effort":"high"'  "arm B effort reaches the sync payload"

# ── report names each arm's engine (model@effort) ───────────────────
EXP analyze eff-1 >/dev/null 2>&1
eff_rep="$(EXP report eff-1 2>&1)"
assert_contains "$eff_rep" "[claude-opus-4-7@xhigh]" "report names arm A's engine (model@effort)"
assert_contains "$eff_rep" "[claude-opus-4-8@high]"  "report names arm B's engine (model@effort)"

# ── mine --adopt: detect-current vs target, model+effort A/B (reuses fixture) ──
# Pass --from / --from-effort for a deterministic spec (detection reads the dev's
# real ~/.claude + env, which we must not depend on — covered separately below).
EXP mine adopt-1 --adopt --repo "$mine_repo" --verify "$VC" \
  --from claude-opus-4-7 --from-effort xhigh --to claude-opus-4-8 --effort high --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "mine --adopt scaffolds an engine-swap from the fixture"
adopt_spec="$(cat "$(exp_dir_for adopt-1)/spec")"
assert_contains "$adopt_spec" "kind: engine-swap"       "adopt records kind: engine-swap"
assert_contains "$adopt_spec" "model: claude-opus-4-7"  "adopt arm A = the current model (--from)"
assert_contains "$adopt_spec" "model: claude-opus-4-8"  "adopt arm B = the target model (--to)"
assert_contains "$adopt_spec" "effort: xhigh"           "adopt arm A carries the current effort"
assert_contains "$adopt_spec" "effort: high"            "adopt arm B carries the target effort"
assert_contains "$adopt_spec" "'claude-opus-4-8' @high matches your current 'claude-opus-4-7' @xhigh" \
  "adopt fills a model+effort hypothesis"
EXP validate adopt-1 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "the adopt-generated spec passes validate"

# refuses the degenerate case (already on the target engine) — BEFORE mining
EXP mine adopt-dup --adopt --repo "$mine_repo" --verify "$VC" \
  --from claude-opus-4-8 --from-effort high --to claude-opus-4-8 --effort high --yes >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "mine --adopt refuses when arm A already equals arm B"
# rejects an invalid --effort up front (no mining)
EXP mine adopt-bad --adopt --effort bogus --from x --from-effort high --repo "$mine_repo" --verify "$VC" >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "mine --adopt rejects an invalid --effort level"

# detection: no --from + no id → defaults the id AND reads the current model from
# the most recent transcript (a sandboxed HOME so it's deterministic). The fixture
# is NESTED (~/.claude/projects/<project-key>/<session>.jsonl) like real Claude
# Code — a flat fixture masked the 0.21.1 detection regression.
mkdir -p "$sb/fakehome/.claude/projects/-home-u-proj"
printf '{"type":"assistant","message":{"model":"claude-opus-4-6","usage":{}}}\n' > "$sb/fakehome/.claude/projects/-home-u-proj/sess.jsonl"
env -u ANTHROPIC_MODEL -u CLAUDE_CODE_EFFORT_LEVEL HOME="$sb/fakehome" HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 \
  "$HE" mine --adopt --repo "$mine_repo" --verify "$VC" --from-effort high --to claude-opus-4-8 --effort high --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "mine --adopt with no id + no --from: defaults the id and detects the model"
det_spec="$(cat "$(exp_dir_for adopt-opus-4-8)/spec" 2>/dev/null)"
assert_contains "$det_spec" "model: claude-opus-4-6" "arm A model detected from the most recent transcript"

# default target: no --to → arm B is the launch default (fable-5), and the
# defaulted id follows it (adopt-fable-5) so the card's CTA stays a bare command.
env -u ANTHROPIC_MODEL -u CLAUDE_CODE_EFFORT_LEVEL HOME="$sb/fakehome" HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 \
  "$HE" mine --adopt --repo "$mine_repo" --verify "$VC" --from-effort high --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "mine --adopt with no --to scaffolds against the default target"
def_spec="$(cat "$(exp_dir_for adopt-fable-5)/spec" 2>/dev/null)"
assert_contains "$def_spec" "model: claude-fable-5" "default arm B is the current adoption target (fable-5)"
assert_contains "$def_spec" "'claude-fable-5' @high matches your current" \
  "the default hypothesis names the fable-5 target"

# ── --sweep: a 3rd effort arm + analyze/report --vs C (the offered frontier) ──
EXP mine adopt-sweep --adopt --repo "$mine_repo" --verify "$VC" \
  --from claude-opus-4-7 --from-effort xhigh --to claude-opus-4-8 --effort high --sweep --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "mine --adopt --sweep scaffolds a 3-arm engine-swap"
sweep_spec="$(cat "$(exp_dir_for adopt-sweep)/spec")"
assert_contains "$sweep_spec" "[arm:C]" "sweep adds a third arm C"
assert_contains "$sweep_spec" $'[arm:C]\nmodel: claude-opus-4-8\neffort: xhigh' "arm C = target @ the next effort up (xhigh)"
EXP run adopt-sweep --k 1 --adapter "$sb/adapter.sh" >/dev/null 2>&1
EXP analyze adopt-sweep --vs C >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "analyze --vs C exits 0 on a 3-arm experiment"
assert_eq "yes" "$([ -f "$(exp_dir_for adopt-sweep)/result-vs-C.json" ] && echo yes || echo no)" \
  "analyze --vs C writes a side result file (canonical result.json preserved)"
assert_contains "$(EXP report adopt-sweep --vs C 2>&1)" "claude-opus-4-8@xhigh" \
  "report --vs C names arm C's engine"

# ── report --frontier: combined N-arm view + cheapest-that-holds recommendation ──
fr_out="$(EXP report adopt-sweep --frontier 2>&1)"
assert_contains "$fr_out" "Engine-adoption frontier"  "report --frontier renders the combined view"
assert_contains "$fr_out" "claude-opus-4-8@high"      "frontier lists arm B's engine"
assert_contains "$fr_out" "claude-opus-4-8@xhigh"     "frontier lists arm C's engine"
assert_contains "$fr_out" "Recommendation:"           "frontier prints a recommendation"
# "stay on A" when the (only) treatment regresses on success
mkdir -p "$(exp_dir_for frn)"
printf 'x\n' > "$(exp_dir_for frn)/runs.jsonl"
cat > "$(exp_dir_for frn)/spec" <<'EOF'
id: frn
repo: .
replicates: 1
non_inferiority_margin: 0.02
kind: engine-swap

[arm:A]
model: claude-opus-4-7
overrides_dir:

[arm:B]
model: claude-opus-4-8
overrides_dir:

[task:t1]
prompt: x
verify: true
EOF
printf '{ "cost":{"A_mean":0.40,"B_mean":0.20,"favorable":true}, "success":{"non_inferior":false}, "verdict":"no proven win" }\n' > "$(exp_dir_for frn)/result.json"
assert_contains "$(EXP report frn --frontier 2>&1)" "No arm holds quality" \
  "frontier recommends staying on A when the treatment regresses on success"

# ── merge offers to apply the engine win to settings.json (--yes = the y/N) ──
mkdir -p "$(exp_dir_for em)/logs" "$(exp_dir_for em)/tasks" "$sb/em-repo/.claude"
printf 'x\n' > "$(exp_dir_for em)/tasks/t.md"
printf '{ "model": "claude-opus-4-7" }\n' > "$sb/em-repo/.claude/settings.json"
cat > "$(exp_dir_for em)/spec" <<EOF
id: em
hypothesis: engine win
repo: $sb/em-repo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02
kind: engine-swap

[arm:A]
model: claude-opus-4-7
effort: xhigh
overrides_dir:

[arm:B]
model: claude-opus-4-8
effort: high
overrides_dir:

[task:t1]
prompt: tasks/t.md
verify: true
timeout_s: 60
EOF
printf '{ "mode":"ab","arms":["A","B"],"verdict":"B wins (cost lower, success non-inferior)" }\n' > "$(exp_dir_for em)/result.json"
EXP merge em --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "merge on an engine-swap with --yes exits 0"
em_applied="$(cat "$sb/em-repo/.claude/settings.json")"
assert_contains "$em_applied" '"model": "claude-opus-4-8"'  "merge --yes wrote the winning model into settings.json"
assert_contains "$em_applied" '"effortLevel": "high"'        "merge --yes wrote the winning effortLevel into settings.json"

# ════════════════════════════════════════════════════════════════════
# 0.24.0 — experiments speed + fairness: success-axis inclusion of agent-error
# rows, run --jobs (wave-parallel blocks), mine targeted-first validation.
# ════════════════════════════════════════════════════════════════════

# ── success-axis fairness: a crashing arm cannot look non-inferior ──
# 3 tasks. t1/t2: clean, B cheaper, both succeed. t3: A clean+passes; B's only
# run is an agent error (timeout) whose verifier failed. OLD behavior dropped
# t3 entirely → "B wins". NEW: t3 counts on the success axis (B rate 2/3) →
# success regresses beyond δ → "no proven win". Cost pairs stay clean-only.
EXP new fair-1 --arm A: --arm B: --task "x" --verify true --replicates 1 --repo "$nw_repo" >/dev/null 2>&1
cat > "$(exp_dir_for fair-1)/runs.jsonl" <<'EOF'
{"task":"t1","arm":"A","rep":0,"cost_usd":0.50,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t1","arm":"B","rep":0,"cost_usd":0.30,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t2","arm":"A","rep":0,"cost_usd":0.60,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t2","arm":"B","rep":0,"cost_usd":0.40,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t3","arm":"A","rep":0,"cost_usd":0.55,"success":true,"agent_exit":0,"verify_exit":0}
{"task":"t3","arm":"B","rep":0,"cost_usd":0,"success":false,"agent_exit":124,"verify_exit":1}
EOF
EXP analyze fair-1 --seed 7 --bootstrap 400 >/dev/null 2>&1
fair_result="$(cat "$(exp_dir_for fair-1)/result.json")"
assert_contains "$fair_result" '"tasks_paired": 2'          "cost pairing uses clean rows only (t3 dropped from cost)"
assert_contains "$fair_result" '"tasks_paired_success": 3'  "success pairing includes the agent-error task"
assert_contains "$fair_result" '"excluded_runs": 1'         "the error row is counted as excluded from cost"
assert_contains "$fair_result" '"verdict": "no proven win"' "B's crash-failure blocks the win (was 'B wins' when dropped)"
assert_contains "$fair_result" "success regressed"          "the reason names the success regression"
fair_report="$(EXP report fair-1 2>&1)"
assert_contains "$fair_report" "2 cost / 3 success"         "report shows both pairings when they differ"

# ── run --jobs: wave-parallel blocks, complete results, clean parts ──
mkdir -p "$(exp_dir_for par-1)/logs" "$(exp_dir_for par-1)/tasks"
printf 'do it\n' > "$(exp_dir_for par-1)/tasks/t.md"
cat > "$(exp_dir_for par-1)/spec" <<EOF
id: par-1
description: parallel blocks
repo: $git_repo
commit: HEAD
replicates: 2
non_inferiority_margin: 0.02

[arm:A]
model: ma
overrides_dir:

[arm:B]
model: mb
overrides_dir:

[task:p1]
prompt: tasks/t.md
verify: true
timeout_s: 60

[task:p2]
prompt: tasks/t.md
verify: true
timeout_s: 60
EOF
EXP run par-1 --yes --jobs 3 --adapter "$sb/adapter.sh" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "run --jobs 3 exits 0"
par_runs="$(exp_dir_for par-1)/runs.jsonl"
assert_eq "8" "$(wc -l < "$par_runs" | tr -d ' ')" \
  "--jobs produces the complete matrix (2 tasks × 2 arms × 2 reps = 8 rows)"
assert_eq "0" "$(find "$(exp_dir_for par-1)" -name '.runs-part.*' | wc -l | tr -d ' ')" \
  "part files are cleaned up after concatenation"
# every (task,arm,rep) combination is present exactly once
for t in p1 p2; do for a in A B; do for r in 0 1; do
  assert_eq "1" "$(grep -c "\"task\":\"$t\",\"arm\":\"$a\",\"rep\":$r," "$par_runs")" \
    "parallel run has exactly one row for ($t,$a,rep$r)"
done; done; done
EXP analyze par-1 --seed 7 --bootstrap 200 >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "analyze works on a parallel run's output"
# invalid --jobs is rejected
rc=0; EXP run par-1 --yes --jobs nope --adapter "$sb/adapter.sh" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "run --jobs rejects a non-integer"

# ── --jobs forced to 1 under setup_scope=run (shared provisioned env) ──
mkdir -p "$(exp_dir_for par-ser)/logs" "$(exp_dir_for par-ser)/tasks"
printf 'x\n' > "$(exp_dir_for par-ser)/tasks/t.md"
cat > "$(exp_dir_for par-ser)/spec" <<EOF
id: par-ser
repo: $git_repo
commit: HEAD
replicates: 1
non_inferiority_margin: 0.02
setup: echo EXP_DB=x
teardown: true
setup_scope: run

[arm:A]
model: ma
overrides_dir:

[arm:B]
model: mb
overrides_dir:

[task:t1]
prompt: tasks/t.md
verify: true
timeout_s: 60
EOF
ser_out="$(EXP run par-ser --yes --jobs 4 --adapter "$sb/adapter.sh" 2>&1)"; rc=$?
assert_exit 0 "$rc" "setup_scope=run + --jobs runs to completion"
assert_contains "$ser_out" "forcing --jobs 1" \
  "setup_scope=run forces serial execution (provisioned env is shared state)"

# ── mine targeted-first validation (pytest narrowing via a stub) ──
# A pytest-shaped repo whose history holds a FAIL_TO_PASS fix; the stub pytest
# logs its argv so we can see WHICH scope the validation ran.
pyt_repo="$sb/pyt-repo"; mkdir -p "$pyt_repo/tests" "$sb/stubbin"
( cd "$pyt_repo" && git init -q && git config user.email t@t.t && git config user.name t
  printf '[project]\nname="x"\n' > pyproject.toml
  printf 'def add(a,b): return a+b\n' > impl.py
  printf 'from impl import add\n' > tests/test_x.py
  git add -A && git commit -qm init
  printf 'def add(a,b): return a+b\ndef sub(a,b): return a-b\n' > impl.py
  printf 'from impl import add, sub\n' > tests/test_x.py
  git add -A && git commit -qm "feat: sub + test" )
PYLOG="$sb/pytest-args.log"; : > "$PYLOG"
cat > "$sb/stubbin/pytest" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$PYLOG"
exit 1
EOF
chmod +x "$sb/stubbin/pytest"
PATH="$sb/stubbin:$PATH" HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 \
  "$HE" mine pyt-t --repo "$pyt_repo" --verify "pytest -q" --max-tasks 1 --yes >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "mine with an auto-detectable runner validates successfully"
assert_contains "$(cat "$PYLOG")" "tests/test_x.py" \
  "validation narrowed pytest to the candidate's re-applied test paths"
: > "$PYLOG"
PATH="$sb/stubbin:$PATH" HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 \
  "$HE" mine pyt-f --repo "$pyt_repo" --verify "pytest -q" --max-tasks 1 --full-validate --yes >/dev/null 2>&1
assert_not_contains "$(cat "$PYLOG")" "tests/test_x.py" \
  "--full-validate runs the whole suite (no per-candidate narrowing)"
assert_contains "$(cat "$PYLOG")" "-q" \
  "--full-validate still ran the (full) suite"
# a custom verify command is never narrowed (we can't scope what we don't know)
mine_custom_out="$(EXP mine pyt-c --repo "$mine_repo" --verify "$VC" --max-tasks 1 --yes 2>&1)"
assert_contains "$mine_custom_out" "tests fail at parent" \
  "a user-supplied verify still validates via the full command"
# the spec's RUNTIME verify stays the FULL suite — narrowing is validation-only
assert_contains "$(cat "$(exp_dir_for pyt-t)/spec")" "verify: pytest -q" \
  "the mined spec's runtime oracle remains the full suite (narrowing is validation-only)"

# ── git-history sealing: the agent must not be able to read the answer ────────
# `mine` derives tasks FROM git history, and `git worktree add` leaves a .git
# pointer into the parent object store — so without sealing the agent under test
# can `git log --all` / `git show` the very commit that fixes the task. The
# adapter below IS the attacker: it greps the object store for a marker that
# only exists in the fixing commit.
seal_sb="$(make_sandbox)"; seal_repo="$seal_sb/repo"
mkdir -p "$seal_repo"
( cd "$seal_repo" && git init -q && git config user.email t@t && git config user.name t \
  && echo 'buggy' > calc.txt && git add -A && git commit -qm bug )
seal_parent="$(cd "$seal_repo" && git rev-parse HEAD)"
( cd "$seal_repo" && echo 'fixed SECRET_ANSWER_9c1f' > calc.txt && git add -A && git commit -qm fix )

# spy adapter: append what git reveals to $SPY_OUT, then emit valid usage JSON
cat > "$seal_sb/spy.sh" <<'SPY'
#!/usr/bin/env bash
{ git log --all -p 2>/dev/null | grep -o 'SECRET_ANSWER_9c1f' | head -1
  printf 'REVCOUNT=%s\n' "$(git rev-list --all --count 2>/dev/null || echo ERR)"; } >> "$SPY_OUT" 2>&1
printf '{"type":"result","model":"stub","total_cost_usd":0.01,"usage":{"input_tokens":10,"output_tokens":5,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}\n'
SPY
chmod +x "$seal_sb/spy.sh"

EXP define exp-seal --description d --arm "A=m1" --arm "B=m2" --replicates 1 >/dev/null 2>&1
mkdir -p "$(exp_dir_for exp-seal)/tasks"; echo "fix it" > "$(exp_dir_for exp-seal)/tasks/example.md"
sed_sub "s|^repo: .*|repo: $seal_repo|" "$(exp_dir_for exp-seal)/spec"
sed_sub "s|^commit: .*|commit: $seal_parent|" "$(exp_dir_for exp-seal)/spec"

# default: sealed → no leak, exactly one (root) commit reachable
export SPY_OUT="$seal_sb/spy.log"; : > "$SPY_OUT"
EXP run exp-seal --yes --adapter "$seal_sb/spy.sh" >/dev/null 2>&1
assert_not_contains "$(cat "$SPY_OUT")" "SECRET_ANSWER_9c1f" \
  "sealed workspace: the agent cannot read the fixing commit out of git"
assert_contains "$(cat "$SPY_OUT")" "REVCOUNT=1" \
  "sealed workspace: exactly one (root) commit is reachable"

# opt-out honored, and it warns — proves the assertions above aren't vacuous
: > "$SPY_OUT"
seal_out="$(HEADER_HOME="$sb/.header" HEADER_EXPERIMENT_NOSYNC=1 HEADER_EXPERIMENT_NO_SEAL=1 \
  "$HE" run exp-seal --yes --adapter "$seal_sb/spy.sh" 2>&1 >/dev/null)"
assert_contains "$seal_out" "NOT sealed" "the no-seal opt-out warns loudly"
assert_contains "$(cat "$SPY_OUT")" "SECRET_ANSWER_9c1f" \
  "without sealing the answer IS reachable (the bug this guards)"
unset SPY_OUT

# sealing leaves no stale worktree registry entry in the parent repo
assert_eq "1" "$(cd "$seal_repo" && git worktree list | wc -l | tr -d ' ')" \
  "sealed replicates prune their worktree registry entries"

t_done
