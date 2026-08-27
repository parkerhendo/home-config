# ── Test ratchet: block silencing of failing tests ───────────────────
# The #1 reward-hack for a non-deterministic agent is turning the suite green by
# DELETING or SKIPPING the failing test instead of fixing the code. This blocks a
# net removal of test functions and newly-added UNCONDITIONAL skip/xfail/ignore
# markers in staged test files. Multi-language (py / js-ts / go / rust / sh-bats).
# Shell suites count `@test` (bats) and `assert_*` helper calls as test units —
# a suite whose cases are bare assertions has no function to count otherwise.
# Escape (a real feature or dead-code removal): RATCHET_OVERRIDE=1 git commit ...
if [ "${RATCHET_OVERRIDE:-}" = "1" ] || printf '%s' "${CMD:-}" | grep -q 'RATCHET_OVERRIDE=1'; then
  echo "INFO: RATCHET_OVERRIDE=1 — test ratchet skipped." >&2
else
  RATCHET_DIFF="$(git diff --cached -M -U0 -- \
      'tests/*' 'test/*' 'spec/*' '__tests__/*' '*_test.go' '*.test.*' '*.spec.*' '*_spec.rb' '*_test.py' 'test_*.py' '*_test.sh' '*.bats' 2>/dev/null || true)"
  if [ -n "$RATCHET_DIFF" ]; then
    _UNIT='((async[[:space:]]+)?def test_|(it|test)\(|func Test|#\[test\]|@test[[:space:]]|assert_[a-zA-Z0-9_]+[[:space:]])'
    REMOVED=$(printf '%s\n' "$RATCHET_DIFF" | grep -cE "^-[[:space:]]*$_UNIT" || true)
    ADDED=$(printf '%s\n' "$RATCHET_DIFF" | grep -cE "^\+[[:space:]]*$_UNIT" || true)
    NET_REMOVED=$((REMOVED - ADDED))
    # Unconditional skip/xfail/ignore markers ONLY (a conditional skipif / xfail
    # with a positional condition is legitimate and allowed). The xfail kwarg-only
    # arm catches xfail(reason="..."), xfail(strict=True) — which an earlier,
    # looser regex let slip through. The trailing `skip` arm is bats.
    NEW_SKIPS=$(printf '%s\n' "$RATCHET_DIFF" | grep -cE '^\+[[:space:]]*(@pytest\.mark\.skip([^a-zA-Z0-9_]|$)|@pytest\.mark\.xfail([^a-zA-Z0-9_(]|$)|@pytest\.mark\.xfail\([[:space:]]*\)|@pytest\.mark\.xfail\([[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=|test\.skip\(\)|t\.Skip\(|#\[ignore\]|skip([[:space:]]|$))' || true)
    if [ "$NET_REMOVED" -gt 0 ] || [ "$NEW_SKIPS" -gt 0 ]; then
      _msg="Test ratchet:"
      [ "$NET_REMOVED" -gt 0 ] && _msg="$_msg $NET_REMOVED test function(s) removed;"
      [ "$NEW_SKIPS" -gt 0 ] && _msg="$_msg $NEW_SKIPS unconditional skip/xfail/ignore marker(s) added;"
      _msg="$_msg fix the production code instead of silencing the test. Genuinely removing a feature or dead test? Re-run with: RATCHET_OVERRIDE=1 git commit ..."
      fail "$_msg"
    fi
  fi
fi
