#!/usr/bin/env bash
# test/binexit.test.sh — bin tools must not leak a non-zero exit on a success
# path. Two regressions from the 0.12.4 audit:
#   1. `header-audit harness`/`deps` emitted a full audit but exited 1, because
#      the last command in the branch (a literal-glob `[ -f ]` test that matched
#      nothing, or scan_file's trailing pipeline) returned non-zero with nothing
#      to short-circuit on. A caller running the tool under a tool-wrapper saw a
#      spurious "Error: Exit code 1" and cancelled parallel work.
#   2. `--help` exited 1 on every tool except header-update-check. Explicit help
#      is a success action; only no-arg / unknown subcommands are usage errors.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

B="$SKILL_DIR/bin"
export HEADER_HOME="$(make_sandbox)/.header"; mkdir -p "$HEADER_HOME"

# ── --help is a success action → exit 0 on every tool ─────────
for t in header-audit header-auth header-config header-cost header-experiment \
         header-ledger header-repo header-telemetry header-topic header-update-check; do
  "$B/$t" --help >/dev/null 2>&1 </dev/null; rc=$?
  assert_exit 0 "$rc" "$t --help exits 0 (help is success, not a usage error)"
done

# ── genuine misuse still errors (we only normalized explicit --help) ──
# header-update-check takes no subcommands, so it's excluded — any arg is a
# no-op check run that legitimately exits 0.
for t in header-audit header-auth header-config header-cost header-experiment \
         header-ledger header-repo header-telemetry header-topic; do
  "$B/$t" zzz-not-a-subcommand >/dev/null 2>&1 </dev/null; rc=$?
  assert_exit 1 "$rc" "$t unknown subcommand still exits 1"
done

# ── header-audit emits a full audit and exits 0 even on a 'clean' repo ──
# (no .claude/agents|commands dir → literal glob; no cargo-cult HITS → grep
# returns 1). This is the exact shape that leaked before the trailing exit 0.
sbx="$(make_sandbox)"; mkdir -p "$sbx/.claude"
printf '# rules\nbe good\n' > "$sbx/CLAUDE.md"
printf '{"model":"claude-opus-4-7"}\n' > "$sbx/.claude/settings.json"
out_h="$("$B/header-audit" harness --repo "$sbx" 2>/dev/null </dev/null)"; rc=$?
assert_exit 0 "$rc" "header-audit harness exits 0 on a clean repo (no agents/commands, no HITS)"
assert_contains "$out_h" "$sbx/CLAUDE.md" "header-audit harness still emits its FILE rows"
"$B/header-audit" deps --repo "$sbx" >/dev/null 2>&1 </dev/null; rc=$?
assert_exit 0 "$rc" "header-audit deps exits 0"
"$B/header-audit" patterns >/dev/null 2>&1 </dev/null; rc=$?
assert_exit 0 "$rc" "header-audit patterns exits 0"

t_done
