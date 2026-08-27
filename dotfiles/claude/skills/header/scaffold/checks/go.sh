# ── go: gofmt check (staged .go) then go test ./... ──
GO_FILES="$(git diff --cached --name-only --diff-filter=ACM | grep '\.go$' || true)"
if [ -n "$GO_FILES" ]; then
  UNFMT="$(printf '%s\n' "$GO_FILES" | xargs gofmt -l 2>/dev/null || true)"
  [ -n "$UNFMT" ] && fail "gofmt: not formatted: $(printf '%s' "$UNFMT" | tr '\n' ' '). Run: gofmt -w $(printf '%s' "$UNFMT" | tr '\n' ' ') and re-stage."
fi
go test ./... \
  || fail "go test ./... failed. Read the failing test above and fix the code; do NOT delete the test or add t.Skip (the ratchet will re-block). Re-run one: go test ./pkg -run TestName."
