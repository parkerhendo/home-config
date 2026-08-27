# ── python: black + flake8 (staged .py) then pytest ──
# Prefer a project venv if present, else fall back to PATH.
_py() { for p in "./venv/bin/$1" "./.venv/bin/$1" "$1"; do command -v "$p" >/dev/null 2>&1 && { printf '%s' "$p"; return; }; done; printf '%s' "$1"; }
BLACK="$(_py black)"; FLAKE8="$(_py flake8)"; PYTEST="$(_py pytest)"
PY_FILES="$(git diff --cached --name-only --diff-filter=ACM | grep '\.py$' || true)"
if [ -n "$PY_FILES" ]; then
  printf '%s\n' "$PY_FILES" | xargs "$BLACK" --check --quiet 2>/dev/null \
    || fail "black: staged .py files not formatted. Run: $BLACK \$(git diff --cached --name-only --diff-filter=ACM | grep '\\.py\$') and re-stage. Do NOT add '# fmt: off' to silence."
  printf '%s\n' "$PY_FILES" | xargs "$FLAKE8" \
    || fail "flake8 reported errors above. Fix in place on the files you touched; do NOT add '# noqa' to silence."
fi
"$PYTEST" -q \
  || fail "pytest failed. Read the FAILED test name above and fix the production code; do NOT delete or skip the test (the ratchet will re-block). Re-run one test: $PYTEST path/to/test.py::test_name -x -q."
