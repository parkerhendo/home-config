# ── TODO: Header couldn't detect this repo's stack — fill in your checks. ──
# Replace the placeholders below with this repo's formatter, linter, and test
# runner. Each check must call `fail "<agent-actionable remediation>"` on
# failure, so a blocked agent knows the EXACT next command (not a vague
# diagnostic). See Header's scaffold/checks/{python,npm,go,cargo,bundler}.sh for
# worked examples.
#
#   FILES="$(git diff --cached --name-only --diff-filter=ACM | grep '\.EXT$' || true)"
#   [ -n "$FILES" ] && { printf '%s\n' "$FILES" | xargs <formatter> --check \
#       || fail "format: run <formatter> on the staged files and re-stage."; }
#   <linter>      || fail "lint: run <linter>; fix in place, don't disable rules to silence."
#   <test-runner> || fail "tests: run <test command>; fix the code, don't skip tests (the ratchet re-blocks)."
echo "INFO: pre-commit-gate installed without stack checks. Edit scripts/pre-commit-gate.sh and replace the TODO block with your formatter / linter / test runner (examples in Header's scaffold/checks/)." >&2
