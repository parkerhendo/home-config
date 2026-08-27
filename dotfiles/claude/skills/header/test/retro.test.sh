#!/usr/bin/env bash
# test/retro.test.sh — bin/header-audit `retro`. Behavioral mining of the user's
# OWN transcripts: edit-thrash, failed-tool volume, git-workflow tells, and the
# DERIVED RETRO-CAP capability nudges that map demonstrated behavior to the
# practice that addresses it. Fixture-driven via --input; HOME sandboxed.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

AU="$SKILL_DIR/bin/header-audit"

# ── no transcripts for the repo → NOTE, never a silent global aggregate ──
sb0="$(make_sandbox)"; r0="$sb0/repo"; mkdir -p "$r0"
N="$(HOME="$sb0" "$AU" retro --repo "$r0")"
assert_contains "$N" $'NOTE\tretro' "no repo transcript dir → NOTE (never a silent global aggregate)"

# ── fixture: 5 edits to one file, 3 failed Bash calls, stash + 2 switches ──
sb="$(make_sandbox)"; repo="$sb/repo"; mkdir -p "$repo"
fix="$sb/s.jsonl"
{
  for i in 1 2 3 4 5; do
    printf '{"type":"assistant","timestamp":"2026-06-10T10:0%s:00Z","message":{"content":[{"type":"tool_use","id":"e%s","name":"Edit","input":{"file_path":"/x/repo/foo.ts","old_string":"a","new_string":"b"}}]}}\n' "$i" "$i"
  done
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b1","name":"Bash","input":{"command":"git stash && git checkout main"}}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"tool_use_id":"b1","type":"tool_result","is_error":true,"content":[{"type":"text","text":"fatal"}]}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b2","name":"Bash","input":{"command":"git checkout -b feat/x"}}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"tool_use_id":"b2","type":"tool_result","is_error":true,"content":[{"type":"text","text":"err"}]}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b3","name":"Bash","input":{"command":"npm test"}}]}}'
  printf '%s\n' '{"type":"user","message":{"content":[{"tool_use_id":"b3","type":"tool_result","is_error":true,"content":[{"type":"text","text":"fail"}]}]}}'
} > "$fix"

R="$(HOME="$sb" "$AU" retro --repo "$repo" --input "$fix")"
assert_contains "$R" $'RETRO-SCOPE\tinput' "input scope reported"
assert_contains "$R" $'RETRO-THRASH\tfoo.ts\t5' "a file edited 5x surfaces as thrash"
assert_contains "$R" $'RETRO-FAILS\tBash\t3\t3' "3 failed Bash calls counted (errors/calls)"
assert_contains "$R" $'RETRO-GIT\tstash\t1' "git stash tell counted"
assert_contains "$R" $'RETRO-GIT\tbranch-switch\t2' "git checkout/switch tells counted"
assert_contains "$R" $'RETRO-CAP\tworktree' "branch juggling with no worktree → worktree nudge"
assert_contains "$R" "key=cap-worktree" "worktree cap carries its ledger key"
assert_contains "$R" $'RETRO-CAP\tguardrail' "repeated Bash failures → guardrail nudge"
assert_contains "$R" "key=cap-guardrail" "guardrail cap carries its ledger key"
assert_contains "$R" $'RETRO-CAP\tcompound' "gotchas + no committed memory → compound nudge"
assert_contains "$R" "key=cap-compound" "compound cap carries its ledger key"

# ── compound cap suppressed once .claude/memory has an entry ──
mkdir -p "$repo/.claude/memory"; printf '# x\n' > "$repo/.claude/memory/pitfall_x.md"
R2="$(HOME="$sb" "$AU" retro --repo "$repo" --input "$fix")"
assert_not_contains "$R2" $'RETRO-CAP\tcompound' "committed .claude/memory suppresses the compound nudge"
assert_contains "$R2" $'RETRO-CAP\tguardrail' "guardrail nudge still fires (independent of memory)"

# ── worktree cap suppressed when worktrees are already in use ──
fix2="$sb/s2.jsonl"; cat "$fix" > "$fix2"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b4","name":"Bash","input":{"command":"git worktree add ../wt"}}]}}' >> "$fix2"
R3="$(HOME="$sb" "$AU" retro --repo "$repo" --input "$fix2")"
assert_contains "$R3" $'RETRO-GIT\tworktree\t1' "git worktree usage is tracked"
assert_not_contains "$R3" $'RETRO-CAP\tworktree' "already using worktrees → no worktree nudge"

# ── thrash threshold: a lightly-edited file is below the bar ──
fix3="$sb/s3.jsonl"
{
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"z1","name":"Edit","input":{"file_path":"/x/bar.ts"}}]}}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"z2","name":"Edit","input":{"file_path":"/x/bar.ts"}}]}}'
} > "$fix3"
R4="$(HOME="$sb" "$AU" retro --repo "$repo" --input "$fix3")"
assert_not_contains "$R4" $'RETRO-THRASH\tbar.ts' "a file edited only twice is below the thrash threshold"

# ── plan-mode + corrections + harness label ──
sigf="$sb/sig.jsonl"
{
  printf '%s\n' '{"type":"permission-mode","permissionMode":"plan"}'
  printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"/x.ts"}}]}}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"no, that is wrong — revert that"}}'
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"actually use a different approach"}}'
} > "$sigf"
RS="$(HOME="$sb" "$AU" retro --repo "$repo" --input "$sigf")"
assert_contains "$RS" $'RETRO-HARNESS\tclaude-transcripts' "retro labels the harness its signals come from"
assert_contains "$RS" $'RETRO-PLAN\t1\t1' "a session that opened plan mode is counted"
assert_contains "$RS" $'RETRO-CORRECTION\t2' "user redirects (no…/actually…) counted as corrections"

# ── git ship/peak (repo scope) — commits dated 11d ago validate the 30d floor ──
# (a fixed 7d window would miss them; the floor catches recent commit streams).
gitrepo="$sb/gitrepo"; mkdir -p "$gitrepo"
gd="$(date -d '11 days ago' '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -v-11d '+%Y-%m-%dT%H:%M:%S')"
( cd "$gitrepo" && git init -q && git config user.email t@t.t && git config user.name t \
  && echo a > f && git add f && GIT_AUTHOR_DATE="$gd" GIT_COMMITTER_DATE="$gd" git commit -qm c1 \
  && printf 'a\nbb\n' > f && git add f && GIT_AUTHOR_DATE="$gd" GIT_COMMITTER_DATE="$gd" git commit -qm c2 ) >/dev/null 2>&1
gkey="$(printf '%s' "$gitrepo" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$sb/.claude/projects/$gkey"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"x"}}' > "$sb/.claude/projects/$gkey/s.jsonl"
GS="$(HOME="$sb" "$AU" retro --repo "$gitrepo")"
assert_contains "$GS" $'RETRO-SHIP\t2\t' "RETRO-SHIP reports commits + LOC over the floored window (catches 11d-old commits a 7d window misses)"
assert_contains "$GS" "RETRO-PEAK" "RETRO-PEAK reports the busiest day"

# ── per-session join: RETRO-CORR (plan → outcome) + RETRO-GAP (claim, no test) ──
psb="$sb/ps"; P="$psb/.claude/projects/-k"; mkdir -p "$P"
printf '%s\n' '{"type":"permission-mode","permissionMode":"plan"}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"/a.ts"}}]}}' > "$P/s1.jsonl"
printf '%s\n' '{"type":"permission-mode","permissionMode":"plan"}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"/a.ts"}}]}}' > "$P/s2.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b","name":"Bash","input":{"command":"x"}}]}}' '{"type":"user","message":{"content":[{"tool_use_id":"b","type":"tool_result","is_error":true,"content":[{"type":"text","text":"e"}]}]}}' > "$P/s3.jsonl"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"b","name":"Bash","input":{"command":"y"}}]}}' '{"type":"user","message":{"content":[{"tool_use_id":"b","type":"tool_result","is_error":true,"content":[{"type":"text","text":"e"}]}]}}' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"fixed it, should now work"}]}}' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e2","name":"Edit","input":{"file_path":"/b.ts"}}]}}' > "$P/s4.jsonl"
PS="$(HOME="$psb" "$AU" retro --repo /k)"
assert_contains "$PS" $'RETRO-PLAN\t2\t4' "plan-mode counted per session (2 of 4 active sessions)"
assert_contains "$PS" $'RETRO-CORR\tplan-mode\t0.00\t1.00' "plan sessions correlate to fewer Bash errors than no-plan"
assert_contains "$PS" $'RETRO-GAP\t1\t4' "a session with edit + fix-claim + no test is a verification gap"

# ── CO-CHANGE DRIFT: the hand-maintained-pipeline bug, mined from git alone ──
# Files that almost always change together encode an invariant the repo never
# wrote down (add the column → add the wire field → add the mapping). The commits
# that BREAK the pattern are where a field got half-wired. Deterministic: the
# violations are counted, not inferred.
csb="$(make_sandbox)"; crepo="$csb/cc"; mkdir -p "$crepo"
( cd "$crepo" && git init -q && git config user.email t@t.t && git config user.name t
  mkdir -p app
  # 9 commits honoring the invariant: schema + column + mapping move together.
  for i in 1 2 3 4 5 6 7 8 9; do
    echo "f$i" >> app/schema.py; echo "f$i" >> app/models.py; echo "f$i" >> app/mapping.py
    git add -A; git commit -qm "feat: field f$i"
  done
  # 2 commits that BREAK it: the column landed, the wire schema never did.
  for i in 10 11; do
    echo "f$i" >> app/models.py; echo "f$i" >> app/mapping.py
    git add -A; git commit -qm "feat: field f$i (column only)"
  done ) >/dev/null 2>&1
# retro reads this repo's transcripts; the key is the repo path slugged.
ckey="$(printf '%s' "$crepo" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$csb/.claude/projects/$ckey"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"/x.py"}}]}}' \
  > "$csb/.claude/projects/$ckey/s.jsonl"
CC="$(HOME="$csb" "$AU" retro --repo "$crepo")"
assert_contains "$CC" $'RETRO-COCHANGE\tapp/mapping.py\tapp/models.py\t11\t11\t100' \
  "two files that ALWAYS move together → a 100% coupling"
assert_contains "$CC" $'RETRO-DRIFT\tapp/models.py\tapp/schema.py\t2\t11' \
  "the column changed 11x, the wire schema only co-changed 9x → 2 drift commits"
assert_contains "$CC" "key=cochange-models-py-schema-py" "RETRO-DRIFT carries a canonical ledger key"
# A 100% coupling has no violations, so it must NOT be reported as drift.
assert_not_contains "$CC" $'RETRO-DRIFT\tapp/mapping.py\tapp/models.py' \
  "a coupling with zero violations is not a drift finding"

# Precision: unrelated files that merely both appear must not fabricate a pair.
usb="$(make_sandbox)"; urepo="$usb/u"; mkdir -p "$urepo"
( cd "$urepo" && git init -q && git config user.email t@t.t && git config user.name t
  for i in 1 2 3 4 5 6 7 8 9 10; do
    echo "$i" >> "f$i.txt"; git add -A; git commit -qm "c$i"
  done ) >/dev/null 2>&1
ukey="$(printf '%s' "$urepo" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$usb/.claude/projects/$ukey"
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"/x"}}]}}' \
  > "$usb/.claude/projects/$ukey/s.jsonl"
UU="$(HOME="$usb" "$AU" retro --repo "$urepo")"
assert_not_contains "$UU" "RETRO-COCHANGE" "files that never co-change → no coupling invented"
assert_not_contains "$UU" "RETRO-DRIFT"    "no coupling → no drift"

t_done
