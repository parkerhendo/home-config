#!/usr/bin/env bash
# test/version.test.sh — the VERSION file and the SKILL.md frontmatter version:
# must agree. VERSION is canonical; the frontmatter mirrors it.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

file_version="$(cat "$SKILL_DIR/VERSION" 2>/dev/null | head -1 | tr -d '[:space:]')"

# Extract version: from inside the SKILL.md frontmatter only (between the first
# two `---` lines), so a stray `version:` elsewhere can't match.
fm_version="$(awk '
  /^---$/ { n++; next }
  n == 1 && /^version:/ { sub(/^version:[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }
' "$SKILL_DIR/SKILL.md")"

assert_contains "$file_version" "." "VERSION file looks like a dotted version"
assert_eq "$file_version" "$fm_version" \
  "SKILL.md frontmatter version: matches the VERSION file"

# ── frontmatter must be valid YAML (strict loaders, e.g. Codex) ───────
# An unquoted scalar whose value contains ": " (colon-space) is parsed as a
# nested mapping and rejected ("mapping values are not allowed in this
# context"). Claude Code tolerates it; Codex does not. Guard the whole block.
fm="$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$SKILL_DIR/SKILL.md")"
unquoted_colon="$(printf '%s\n' "$fm" | awk '
  /^[A-Za-z_][A-Za-z0-9_-]*:[ ]/ {
    i = index($0, ": "); v = substr($0, i + 2); sub(/^[ ]+/, "", v)
    f = substr(v, 1, 1)
    if (f == "\"" || f == "\047") next        # double- or single-quoted scalar
    if (index(v, ": ") > 0) print             # unquoted value with a colon-space
  }')"
assert_eq "" "$unquoted_colon" \
  "frontmatter scalar with \": \" must be quoted (otherwise invalid YAML)"

# Bonus: if a real YAML parser is available, assert the frontmatter loads.
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' 2>/dev/null; then
  pyok="$(printf '%s\n' "$fm" | python3 -c 'import sys,yaml; yaml.safe_load(sys.stdin.read()); print("ok")' 2>/dev/null || echo fail)"
  assert_eq "ok" "$pyok" "SKILL.md frontmatter parses as valid YAML"
fi

t_done
