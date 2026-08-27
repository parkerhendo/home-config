#!/usr/bin/env bash
# test/ratchet.sh — the test ratchet. Coverage may grow; it may not shrink.
#
# A green suite proves the tests that ran passed. It says nothing about the tests
# that were deleted, renamed away, or commented out in the same commit. This
# compares the current suite/assertion counts against the checked-in baseline in
# test/RATCHET and fails when either drops.
#
#   ./test/ratchet.sh          check against the baseline (exit 1 if it dropped)
#   ./test/ratchet.sh --bump   raise the baseline to the current counts
#
# Assertions are counted statically (call sites in *.test.sh), not at runtime, so
# the check is deterministic and needs no suite run.
set -uo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_BASELINE="$_DIR/RATCHET"

_suites="$(ls "$_DIR"/*.test.sh 2>/dev/null | wc -l | tr -d ' ')"
_asserts="$(grep -hoE '\b(assert_eq|assert_contains|assert_not_contains|assert_exit)\b' \
  "$_DIR"/*.test.sh 2>/dev/null | wc -l | tr -d ' ')"

if [ "${1:-}" = "--bump" ]; then
  printf 'suites=%s\nassertions=%s\n' "$_suites" "$_asserts" > "$_BASELINE"
  printf '✓ ratchet baseline set: %s suites, %s assertions\n' "$_suites" "$_asserts"
  exit 0
fi

if [ ! -f "$_BASELINE" ]; then
  printf '✗ no ratchet baseline at %s — create it with: %s --bump\n' \
    "$_BASELINE" "$_DIR/ratchet.sh" >&2
  exit 1
fi

# shellcheck disable=SC1090
_base_suites="$(sed -n 's/^suites=//p' "$_BASELINE")"
_base_asserts="$(sed -n 's/^assertions=//p' "$_BASELINE")"
case "$_base_suites$_base_asserts" in
  ''|*[!0-9]*) printf '✗ malformed ratchet baseline at %s\n' "$_BASELINE" >&2; exit 1 ;;
esac

_rc=0
if [ "$_suites" -lt "$_base_suites" ]; then
  printf '✗ test ratchet: suite count dropped %s → %s\n' "$_base_suites" "$_suites" >&2
  printf '  A suite was deleted or renamed. If that is intentional, say so explicitly:\n' >&2
  printf '    %s --bump   # and mention the removal in the commit message\n' "$_DIR/ratchet.sh" >&2
  _rc=1
fi
if [ "$_asserts" -lt "$_base_asserts" ]; then
  printf '✗ test ratchet: assertion count dropped %s → %s\n' "$_base_asserts" "$_asserts" >&2
  printf '  Assertions were deleted or commented out. A green suite does not cover this.\n' >&2
  printf '  If the removal is intentional: %s --bump\n' "$_DIR/ratchet.sh" >&2
  _rc=1
fi
[ "$_rc" -eq 0 ] || exit 1

if [ "$_suites" -gt "$_base_suites" ] || [ "$_asserts" -gt "$_base_asserts" ]; then
  printf '✗ test ratchet: coverage grew (%s→%s suites, %s→%s assertions) — lock it in:\n' \
    "$_base_suites" "$_suites" "$_base_asserts" "$_asserts" >&2
  printf '    %s --bump && git add %s\n' "$_DIR/ratchet.sh" "$_BASELINE" >&2
  exit 1
fi

printf '✓ test ratchet: %s suites, %s assertions (at baseline)\n' "$_suites" "$_asserts"
