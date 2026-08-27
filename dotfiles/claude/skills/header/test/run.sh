#!/usr/bin/env bash
# test/run.sh — plain-bash test harness for the Header skill. Zero dependencies.
#
# Two modes, auto-detected:
#
#   Runner  (executed directly):  ./test/run.sh [name]
#           Runs every test/*.test.sh — or just <name>.test.sh — and reports.
#
#   Library (sourced by a *.test.sh file): provides assert_eq, assert_contains,
#           assert_not_contains, assert_exit, make_sandbox, and t_done. On exit it
#           prints a tally and exits non-zero if any assertion failed OR the file
#           never reached t_done (crash detection).
#
# A test file looks like:
#   source "$(dirname "${BASH_SOURCE[0]}")/run.sh"
#   assert_eq "a" "a" "trivial"
#   t_done
#
# No -e: assertions must keep running after a failed command.
set -uo pipefail

_HARNESS_PATH="${BASH_SOURCE[0]}"
_HARNESS_DIR="$(cd "$(dirname "$_HARNESS_PATH")" && pwd)"

if [ "$_HARNESS_PATH" != "${0}" ]; then
  # ─────────────────── Library mode (sourced) ───────────────────
  # SKILL_DIR — the installed skill folder (test/'s parent). Test files use it
  # to locate bin/header-config, SKILL.md, VERSION, etc.
  SKILL_DIR="$(cd "$_HARNESS_DIR/.." && pwd)"
  _T_PASS=0
  _T_FAIL=0
  _T_DONE=0
  _T_SANDBOXES=()

  assert_eq() {            # assert_eq <expected> <actual> <message>
    if [ "$1" = "$2" ]; then
      _T_PASS=$((_T_PASS + 1))
    else
      _T_FAIL=$((_T_FAIL + 1))
      printf '  FAIL: %s\n        expected: [%s]\n        actual:   [%s]\n' "$3" "$1" "$2" >&2
    fi
  }

  assert_contains() {      # assert_contains <haystack> <needle> <message>
    case "$1" in
      *"$2"*) _T_PASS=$((_T_PASS + 1)) ;;
      *) _T_FAIL=$((_T_FAIL + 1))
         printf '  FAIL: %s\n        missing substring: [%s]\n' "$3" "$2" >&2 ;;
    esac
  }

  assert_not_contains() {  # assert_not_contains <haystack> <needle> <message>
    case "$1" in
      *"$2"*) _T_FAIL=$((_T_FAIL + 1))
              printf '  FAIL: %s\n        unexpected substring: [%s]\n' "$3" "$2" >&2 ;;
      *) _T_PASS=$((_T_PASS + 1)) ;;
    esac
  }

  assert_exit() {          # assert_exit <expected-code> <actual-code> <message>
    if [ "$1" = "$2" ]; then
      _T_PASS=$((_T_PASS + 1))
    else
      _T_FAIL=$((_T_FAIL + 1))
      printf '  FAIL: %s\n        expected exit [%s], got [%s]\n' "$3" "$1" "$2" >&2
    fi
  }

  # make_sandbox — print a fresh temp dir; auto-removed when the test file exits.
  make_sandbox() {
    local d
    d="$(mktemp -d "${TMPDIR:-/tmp}/header-test.XXXXXX")"
    _T_SANDBOXES+=("$d")
    printf '%s\n' "$d"
  }

  # sed_sub — portable in-place substitution. `sed -i` is non-portable (GNU wants
  # `-i`, BSD/macOS wants `-i ''`), so edit via a temp file then mv, the same idiom
  # the bin/ helpers use. Usage: sed_sub <sed-expr> <file>
  sed_sub() {
    local _e="$1" _f="$2" _t
    _t="$(mktemp "${TMPDIR:-/tmp}/header-sed.XXXXXX")"
    sed "$_e" "$_f" > "$_t" && mv "$_t" "$_f"
  }

  # file_append_after — insert lines (read from stdin) immediately after the first
  # line matching a glob <pattern>. Avoids BSD vs GNU `sed a\` differences (BSD does
  # not interpret \n in the appended text). Usage: printf '...\n...' | file_append_after '<glob>' <file>
  file_append_after() {
    local _pat="$1" _f="$2" _t _ins _line _done=0
    _ins="$(cat)"
    _t="$(mktemp "${TMPDIR:-/tmp}/header-app.XXXXXX")"
    while IFS= read -r _line || [ -n "$_line" ]; do
      printf '%s\n' "$_line" >> "$_t"
      if [ "$_done" = 0 ]; then
        case "$_line" in
          $_pat) printf '%s\n' "$_ins" >> "$_t"; _done=1 ;;
        esac
      fi
    done < "$_f"
    mv "$_t" "$_f"
  }

  # file_insert_before — insert lines (read from stdin) immediately before the first
  # line matching a glob <pattern>. Portable counterpart to `sed '/pat/i text'`.
  # Usage: printf '...\n...' | file_insert_before '<glob>' <file>
  file_insert_before() {
    local _pat="$1" _f="$2" _t _ins _line _done=0
    _ins="$(cat)"
    _t="$(mktemp "${TMPDIR:-/tmp}/header-ins.XXXXXX")"
    while IFS= read -r _line || [ -n "$_line" ]; do
      if [ "$_done" = 0 ]; then
        case "$_line" in
          $_pat) printf '%s\n' "$_ins" >> "$_t"; _done=1 ;;
        esac
      fi
      printf '%s\n' "$_line" >> "$_t"
    done < "$_f"
    mv "$_t" "$_f"
  }

  # t_done — call as the LAST line of every test file. Its absence on exit is
  # treated as a crash and fails the suite even with zero failed assertions.
  t_done() { _T_DONE=1; }

  _t_finish() {
    local sb
    for sb in "${_T_SANDBOXES[@]:-}"; do
      [ -n "$sb" ] && rm -rf "$sb" 2>/dev/null
    done
    if [ "$_T_DONE" != "1" ]; then
      printf '  ERROR: test file exited before t_done (crash?) — %d passed, %d failed so far\n' \
        "$_T_PASS" "$_T_FAIL" >&2
      exit 1
    fi
    if [ "$_T_FAIL" -gt 0 ]; then
      printf '  %d passed, %d FAILED\n' "$_T_PASS" "$_T_FAIL"
      exit 1
    fi
    printf '  %d passed\n' "$_T_PASS"
    exit 0
  }
  trap _t_finish EXIT
  return 0
fi

# ─────────────────── Runner mode (executed) ───────────────────
# Usage: run.sh [repo|installed|smoke|<suite-name>]
#   repo       run every suite, including install.test.sh (needs repo-root install.sh)
#   installed  validate the installed payload only; skips install.test.sh
#   smoke      alias for installed — a fast post-install check from ~/.codex/skills/header
#   <name>     run only <name>.test.sh (e.g. 'audit')
# With no argument the mode is auto-detected: 'repo' when the repo-root install.sh exists
# (a full checkout), otherwise 'installed' (an installed skill directory has no install.sh).
# ('repo'/'installed'/'smoke' are reserved words — don't name a suite after them.)
_arg="${1:-}"
_mode=""
_filter=""
case "$_arg" in
  repo|installed) _mode="$_arg" ;;
  smoke)          _mode="installed" ;;
  "")             if [ -f "$_HARNESS_DIR/../../install.sh" ]; then _mode="repo"; else _mode="installed"; fi ;;
  *)              _filter="$_arg"; _mode="filter" ;;
esac

if [ -n "$_filter" ]; then _mode_label="filter ($_filter)"; else _mode_label="$_mode"; fi
printf 'mode: %s\n' "$_mode_label"

# Installed mode: the helper binaries must be executable, or every suite that shells
# out to them fails confusingly. Check once, up front, with a clear remedy (HEA-429).
if [ "$_mode" = "installed" ]; then
  _missing=""
  for _b in "$_HARNESS_DIR"/../bin/*; do
    [ -e "$_b" ] || continue
    [ -x "$_b" ] || _missing="$_missing $(basename "$_b")"
  done
  if [ -n "$_missing" ]; then
    printf '✗ helper binaries are not executable:%s\n' "$_missing" >&2
    printf '  fix: chmod +x %s/bin/* %s/run.sh\n' \
      "$(cd "$_HARNESS_DIR/.." && pwd)" "$_HARNESS_DIR" >&2
    exit 1
  fi
fi

_suite_rc=0
_ran=0
_failed=0
for _tf in "$_HARNESS_DIR"/*.test.sh; do
  [ -f "$_tf" ] || continue
  _name="$(basename "$_tf" .test.sh)"
  # filter mode: run only the named suite
  if [ -n "$_filter" ] && [ "$_name" != "$_filter" ]; then
    continue
  fi
  # installed mode: skip suites that assume a full repo checkout (repo-root install.sh)
  if [ "$_mode" = "installed" ] && [ "$_name" = "install" ]; then
    continue
  fi
  _ran=$((_ran + 1))
  printf '▶ %s\n' "$_name"
  if bash "$_tf"; then
    :
  else
    _suite_rc=1
    _failed=$((_failed + 1))
  fi
done

if [ "$_ran" -eq 0 ]; then
  printf 'No test files matched.\n' >&2
  exit 1
fi

printf -- '----\n'
if [ "$_suite_rc" -eq 0 ]; then
  printf '✓ all %d suite(s) passed (mode: %s)\n' "$_ran" "$_mode_label"
else
  printf '✗ %d of %d suite(s) failed (mode: %s)\n' "$_failed" "$_ran" "$_mode_label" >&2
fi
exit "$_suite_rc"
