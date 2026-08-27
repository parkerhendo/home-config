# ── ruby: rubocop (staged .rb) then rspec / rake test ──
RB_FILES="$(git diff --cached --name-only --diff-filter=ACM | grep '\.rb$' || true)"
if [ -n "$RB_FILES" ] && command -v rubocop >/dev/null 2>&1; then
  printf '%s\n' "$RB_FILES" | xargs rubocop --force-exclusion \
    || fail "rubocop failed. Fix in place on the files you touched; do NOT add '# rubocop:disable' to silence."
fi
if command -v rspec >/dev/null 2>&1; then
  rspec \
    || fail "rspec failed. Read the failing example above and fix the code; do NOT skip the example (the ratchet will re-block)."
elif [ -f Rakefile ]; then
  rake test \
    || fail "rake test failed. Read the failing test above and fix the code; do NOT skip the test (the ratchet will re-block)."
fi
