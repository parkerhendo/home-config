# ── npm/node: lint then test (whatever package.json defines; --if-present
#    no-ops cleanly when a script is absent) ──
if [ -f package.json ]; then
  npm run lint --if-present \
    || fail "npm run lint failed. Fix the staged TS/JS errors above; do NOT add eslint-disable / @ts-expect-error to silence."
  npm run test --if-present \
    || fail "npm test failed. Read the failing spec above and fix the code; do NOT skip the test (the ratchet will re-block). Re-run one spec with your test runner's path filter."
fi
