# ── rust: cargo fmt --check then cargo test ──
cargo fmt --check 2>/dev/null \
  || fail "cargo fmt --check failed. Run: cargo fmt and re-stage."
cargo test \
  || fail "cargo test failed. Read the failing test above and fix the code; do NOT delete the test or add #[ignore] (the ratchet will re-block). Re-run one: cargo test test_name."
