#!/usr/bin/env bash
# test/install.test.sh — install.sh installs the skill folder into a sandboxed
# skills directory, makes bin/ executable, and is idempotent.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

REPO_ROOT="$(cd "$SKILL_DIR/.." && pwd)"
INSTALLER="$REPO_ROOT/install.sh"

assert_eq "yes" "$([ -f "$INSTALLER" ] && echo yes || echo no)" \
  "install.sh exists at the repo root"

# Run with a sandboxed HOME — install.sh finds the skill locally (no network).
sb="$(make_sandbox)"
env -i PATH="$PATH" HOME="$sb" sh "$INSTALLER" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "install.sh exits 0"

dest="$sb/.claude/skills/header"
assert_eq "yes" "$([ -f "$dest/SKILL.md" ] && echo yes || echo no)" "SKILL.md installed"
assert_eq "yes" "$([ -f "$dest/VERSION" ] && echo yes || echo no)" "VERSION installed"
assert_eq "yes" "$([ -x "$dest/bin/header-config" ] && echo yes || echo no)" \
  "bin/header-config installed and executable"
assert_eq "yes" "$([ -f "$dest/data/engine-adoption/opus-4.8.md" ] && echo yes || echo no)" \
  "engine-adoption snapshot installed (data/ ships with the skill)"
assert_eq "yes" "$([ -f "$dest/data/engine-adoption/fable-5.md" ] && echo yes || echo no)" \
  "fable-5 engine-adoption snapshot installed"
assert_eq "no" "$([ -e "$dest/.git" ] && echo yes || echo no)" \
  "no .git copied into the installed skill"

# The installed copy actually runs.
assert_eq "English" "$(HEADER_HOME="$sb/.hdr" "$dest/bin/header-config" get language)" \
  "installed header-config runs correctly"

# Idempotent — a second run still succeeds and leaves a valid install.
env -i PATH="$PATH" HOME="$sb" sh "$INSTALLER" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "install.sh re-run exits 0 (idempotent)"
assert_eq "yes" "$([ -f "$dest/SKILL.md" ] && echo yes || echo no)" \
  "skill still present and intact after re-run"
assert_eq "" "$(ls -d "$dest".* 2>/dev/null)" \
  "no .new/.bak staging dirs left behind after the atomic swap"

# Legacy header-briefing/ at the same skills root must be removed by the install.
# Migration guard: a 0.9.x install must not coexist with the 0.10.0+ header/.
sb="$(make_sandbox)"
legacy="$sb/.claude/skills/header-briefing"
mkdir -p "$legacy/bin"
printf 'stale\n' > "$legacy/SKILL.md"
env -i PATH="$PATH" HOME="$sb" sh "$INSTALLER" >/dev/null 2>&1; rc=$?
assert_exit 0 "$rc" "install.sh exits 0 with a legacy header-briefing/ present"
assert_eq "yes" "$([ -f "$sb/.claude/skills/header/SKILL.md" ] && echo yes || echo no)" \
  "new header/ installed alongside the legacy folder"
assert_eq "no" "$([ -e "$legacy" ] && echo yes || echo no)" \
  "legacy header-briefing/ is removed after install (no stale /header-briefing command)"

t_done
