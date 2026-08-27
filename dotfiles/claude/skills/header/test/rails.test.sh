#!/usr/bin/env bash
# test/rails.test.sh — bin/header-audit {rails,rail}. Determinism-rail detection
# and the scaffold printer. Builds sandbox git repos, asserts on the structured
# scan output, and on the printed scaffolds. HOME is sandboxed so the user's real
# git/global config never bleeds in. Never executes the gate (no black/pytest
# dependency) — it only inspects the printed template, like the gate examples.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

AU="$SKILL_DIR/bin/header-audit"

# small helper: a fresh git repo under a sandbox
_mkrepo() { local d="$1"; mkdir -p "$d"; ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t ); }

# ── bare python repo, no rails ────────────────────────────────
sb="$(make_sandbox)"; repo="$sb/repo"; _mkrepo "$repo"
printf 'requests==2.0\n' > "$repo/requirements.txt"
R="$(HOME="$sb" "$AU" rails --repo "$repo")"
assert_contains "$R" $'RAIL-ENV\tecosystem\tpython' "primary ecosystem detected from requirements.txt"
assert_contains "$R" $'RAIL-ENV\tgit-remote\tno'    "a repo with no remote → git-remote no"
assert_contains "$R" $'RAIL-ENV\thooks-path\tunset' "no core.hooksPath → hooks-path unset"
assert_contains "$R" $'RAIL-ENV\tclaude\tno'        "no .claude dir → claude no"
assert_contains "$R" $'RAIL-ENV\ttests\tnone'       "no test suite → tests none"
assert_contains "$R" $'RAIL\tprecommit-gate\tabsent'   "no gate → precommit-gate absent"
assert_contains "$R" $'RAIL\ttest-ratchet\tn/a'        "no tests → test-ratchet n/a (not absent)"
assert_contains "$R" $'RAIL\tcompound-memory\tabsent'  "no memory discipline → compound-memory absent"

# ── tests present but no gate → ratchet flips absent ──────────
mkdir -p "$repo/tests"; printf 'def test_a():\n    pass\n' > "$repo/tests/test_a.py"
R2="$(HOME="$sb" "$AU" rails --repo "$repo")"
assert_contains "$R2" $'RAIL-ENV\ttests\ttests/'      "tests/ dir → tests path reported"
assert_contains "$R2" $'RAIL\ttest-ratchet\tabsent'   "tests present, no ratchet → test-ratchet absent"

# ── a nested / shell-only suite is still a suite ──────────────
# Regression: _rail_testpath used to check only TOP-LEVEL tests|test|spec|__tests__
# plus go/py/rb/js globs, so a shell-first repo nesting its suite (header/test/
# *.test.sh) reported `tests none` → test-ratchet silently n/a, and the repo
# lost the rail. A false "none" is the costly direction here.
sbn="$(make_sandbox)"; rn="$sbn/r"; _mkrepo "$rn"
mkdir -p "$rn/pkg/test"; printf '#!/usr/bin/env bash\nassert_eq 1 1 "x"\n' > "$rn/pkg/test/a.test.sh"
RN="$(HOME="$sbn" "$AU" rails --repo "$rn")"
assert_contains "$RN" $'RAIL-ENV\ttests\tpkg/test/'  "a nested test dir is detected one level deep"
assert_contains "$RN" $'RAIL\ttest-ratchet\tabsent'  "a nested shell suite → test-ratchet absent, not n/a"

# a bare *.test.sh with no test dir at all is still found by the glob arm
sbs="$(make_sandbox)"; rs="$sbs/r"; _mkrepo "$rs"
printf '#!/usr/bin/env bash\n' > "$rs/audit.test.sh"
assert_contains "$(HOME="$sbs" "$AU" rails --repo "$rs")" $'RAIL-ENV\ttests\t*.test.sh' \
  "a bare *.test.sh is detected by the shell glob arm"
# .bats too
sbb="$(make_sandbox)"; rb="$sbb/r"; _mkrepo "$rb"
printf '@test "x" {\n}\n' > "$rb/a.bats"
assert_contains "$(HOME="$sbb" "$AU" rails --repo "$rb")" $'RAIL-ENV\ttests\t*.bats' \
  "a .bats suite is detected"
# and a repo with genuinely no tests still reports none (no false positive)
sbz="$(make_sandbox)"; rz="$sbz/r"; _mkrepo "$rz"; printf 'x\n' > "$rz/README.md"
assert_contains "$(HOME="$sbz" "$AU" rails --repo "$rz")" $'RAIL-ENV\ttests\tnone' \
  "a repo with no tests still reports tests none"

# ── git-native gate present → precommit-gate present ──────────
mkdir -p "$repo/.githooks"; printf '#!/bin/sh\n' > "$repo/.githooks/pre-commit"
assert_contains "$(HOME="$sb" "$AU" rails --repo "$repo")" $'RAIL\tprecommit-gate\tpresent\t.githooks/pre-commit' \
  "a committed .githooks/pre-commit → precommit-gate present"

# ── a ratchet signature in the gate script → test-ratchet likely-present ──
# (word-match evidence only — the status must not claim more than the grep saw)
printf '#!/bin/sh\n# RATCHET_OVERRIDE escape\n' > "$repo/.githooks/pre-commit"
assert_contains "$(HOME="$sb" "$AU" rails --repo "$repo")" $'RAIL\ttest-ratchet\tlikely-present' \
  "a gate carrying a ratchet signature → test-ratchet likely-present (word-match)"

# ── PreToolUse gate hook (no git hook) → precommit-gate present ──
sb2="$(make_sandbox)"; r2="$sb2/r"; _mkrepo "$r2"; mkdir -p "$r2/.claude"
cat > "$r2/.claude/settings.json" <<'J'
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "scripts/pre-commit-gate.sh" } ] } ] } }
J
PT="$(HOME="$sb2" "$AU" rails --repo "$r2")"
assert_contains "$PT" $'RAIL\tprecommit-gate\tpresent\tPreToolUse gate hook' \
  "a PreToolUse hook that runs the gate → precommit-gate present"
assert_contains "$PT" $'RAIL-ENV\tclaude\tyes' "a .claude dir → claude yes"
# a PreToolUse hook unrelated to commits does NOT count as a gate
cat > "$r2/.claude/settings.json" <<'J'
{ "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo hi" } ] } ] } }
J
assert_contains "$(HOME="$sb2" "$AU" rails --repo "$r2")" $'RAIL\tprecommit-gate\tabsent' \
  "an unrelated PreToolUse hook is NOT counted as a commit gate"

# ── compound-memory detection (dir, MEMORY.md, skill) ─────────
sb3="$(make_sandbox)"; r3="$sb3/r"; _mkrepo "$r3"
mkdir -p "$r3/.claude/memory"; printf '# note\n' > "$r3/.claude/memory/pitfall_x.md"
assert_contains "$(HOME="$sb3" "$AU" rails --repo "$r3")" $'RAIL\tcompound-memory\tpresent\t.claude/memory/' \
  ".claude/memory/*.md → compound-memory present"
rm -rf "$r3/.claude/memory"; printf '# Memory\n' > "$r3/MEMORY.md"
assert_contains "$(HOME="$sb3" "$AU" rails --repo "$r3")" $'RAIL\tcompound-memory\tpresent\tMEMORY.md' \
  "a root MEMORY.md → compound-memory present"

# ── ecosystem precedence + git-remote yes ─────────────────────
sb4="$(make_sandbox)"; r4="$sb4/r"; _mkrepo "$r4"
printf '{"name":"x"}\n' > "$r4/package.json"; printf 'requests==2.0\n' > "$r4/requirements.txt"
( cd "$r4" && git remote add origin https://example.com/x.git )
R4="$(HOME="$sb4" "$AU" rails --repo "$r4")"
assert_contains "$R4" $'RAIL-ENV\tecosystem\tpython' "python takes precedence over npm as the primary stack"
assert_contains "$R4" $'RAIL-ENV\tecosystem-all\t' "ecosystem-all line is present"
assert_contains "$R4" $'RAIL-ENV\tgit-remote\tyes' "a configured remote → git-remote yes"
# unknown ecosystem when no manifest is present
sb5="$(make_sandbox)"; r5="$sb5/r"; _mkrepo "$r5"
assert_contains "$(HOME="$sb5" "$AU" rails --repo "$r5")" $'RAIL-ENV\tecosystem\tunknown' \
  "no manifest → ecosystem unknown"

# ── rail printer: precommit-gate, python, both ────────────────
G="$(HOME="$sb" "$AU" rail precommit-gate --ecosystem python --delivery both)"
assert_contains "$G" "scripts/pre-commit-gate.sh" "gate names the install path"
assert_contains "$G" "pytest" "python gate runs pytest"
assert_contains "$G" "black" "python gate runs black"
assert_contains "$G" "import shlex" "gate carries the shlex git-commit detector verbatim"
assert_contains "$G" "RATCHET_OVERRIDE" "ratchet is included by default (--ratchet on)"
assert_contains "$G" ".githooks/pre-commit" "delivery both prints the git-native wiring"
assert_contains "$G" "PreToolUse" "delivery both prints the Claude Code wiring"
assert_contains "$G" "HEADER_GATE_FORCE=1" "the git-native wiring sets HEADER_GATE_FORCE"

# delivery selection is honored
GG="$(HOME="$sb" "$AU" rail precommit-gate --ecosystem python --delivery git)"
assert_contains "$GG" ".githooks/pre-commit" "delivery git prints the git wiring"
assert_not_contains "$GG" "===== WIRING (Claude Code PreToolUse" "delivery git omits the PreToolUse wiring"
GP="$(HOME="$sb" "$AU" rail precommit-gate --ecosystem python --delivery pretooluse)"
assert_contains "$GP" "===== WIRING (Claude Code PreToolUse" "delivery pretooluse prints the PreToolUse wiring"
assert_not_contains "$GP" "===== WIRING (git-native" "delivery pretooluse omits the git wiring"

# ratchet off omits the ratchet
GO="$(HOME="$sb" "$AU" rail precommit-gate --ecosystem python --ratchet off)"
assert_not_contains "$GO" "RATCHET_OVERRIDE" "--ratchet off excludes the ratchet block"

# unknown ecosystem → TODO placeholder, still a usable gate
GU="$(HOME="$sb" "$AU" rail precommit-gate --ecosystem cobol --delivery git)"
assert_contains "$GU" "TODO" "an unknown ecosystem prints a TODO placeholder block"
assert_contains "$GU" "import shlex" "an unknown-ecosystem gate still carries the commit detector"

# ── rail printer: test-ratchet (standalone block) ─────────────
TR="$(HOME="$sb" "$AU" rail test-ratchet)"
assert_contains "$TR" "Test ratchet" "test-ratchet prints the ratchet block"
# the corrected kwarg-only xfail arm (Finding 5) must be present
assert_contains "$TR" 'xfail\([[:space:]]*[a-zA-Z_]' "ratchet carries the corrected kwarg-only xfail regex"
# a ratchet that can't see shell test units would be a hollow rail on a shell-first
# repo: it captures the diff via '*.test.*' but counts 0 removals and never fires.
assert_contains "$TR" '@test[[:space:]]' "ratchet counts bats @test as a test unit"
assert_contains "$TR" 'assert_[a-zA-Z0-9_]+[[:space:]]' "ratchet counts shell assert_* helpers as test units"
assert_contains "$TR" "'*.bats'" "ratchet's staged-file pathspec includes .bats"
assert_contains "$TR" "'*_test.sh'" "ratchet's staged-file pathspec includes *_test.sh"

# ── rail printer: compound-memory ─────────────────────────────
# Native-first (v0.29.0): the rail leads with /header wrapup (Header runs capture
# itself), seeds the committed index, and offers the standalone /compound skill
# only as an option for sessions that don't use Header.
CM="$(HOME="$sb" "$AU" rail compound-memory)"
assert_contains "$CM" "/header wrapup" "compound-memory leads with the native /header wrapup capture"
assert_contains "$CM" "/header compound" "compound-memory names the native /header compound verb"
assert_contains "$CM" "natively" "compound-memory frames capture as native, not a skill install"
assert_contains "$CM" ".claude/memory/MEMORY.md" "compound-memory still seeds the committed index path"
assert_contains "$CM" ".claude/skills/compound/SKILL.md" "compound-memory still offers the standalone skill (optional)"
assert_contains "$CM" "name: compound" "the standalone skill carries its frontmatter"

# ── canonical ledger keys: absent rails only ──────────────────
# An absent rail is a recommendation → it pre-mints the documented ledger key
# (rail-<name>); present and n/a rows are status and carry none.
assert_contains "$R" "key=rail-precommit-gate" "an absent precommit-gate carries key=rail-precommit-gate"
assert_contains "$R" "key=rail-compound-memory" "an absent compound-memory carries key=rail-compound-memory"
assert_not_contains "$(printf '%s\n' "$R" | grep 'RAIL	test-ratchet')" "key=" \
  "an n/a rail carries no key"
assert_not_contains "$(HOME="$sb" "$AU" rails --repo "$repo" | grep 'RAIL	precommit-gate	present')" "key=" \
  "a present rail carries no key"

# ── errors ────────────────────────────────────────────────────
HOME="$sb" "$AU" rail bogus >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "an unknown rail name → exit 1"
HOME="$sb" "$AU" rail >/dev/null 2>&1; rc=$?
assert_exit 1 "$rc" "rail with no name → exit 1"

t_done
