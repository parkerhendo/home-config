#!/usr/bin/env bash
# test/silence.test.sh — bin/header-audit {silence, rails RAIL-INERT}.
#
# THE SILENCE AXIS: information discarded without a signal. The generalization of
# SCHEMA-LAX — the defect is not that something broke, it is that NOTHING TOLD YOU.
#
#   RAIL-INERT     — machinery that is PRESENT and cannot fail (a gate whose checks
#                    end in `|| true`, CI with continue-on-error, an armed ratchet
#                    override). Strictly worse than absent: it earns rails credit
#                    while enforcing nothing, so everyone believes they are covered.
#   ENV-UNDECLARED — the code reads a config var nothing declares. Works on your
#                    laptop (it's in your shell), dies in the runner.
#   SWALLOW        — an exception handler with an empty body.
#
# Precision is the product decision throughout: a handler that LOGS or RE-RAISES is
# a decision, not a swallow; a declared var is not a finding; a commented-out
# escape hatch is not an inert gate. Those negative cases are the real tests.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

AU="$SKILL_DIR/bin/header-audit"

_mkrepo() { local d="$1"; mkdir -p "$d"; ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t ); }

# ── RAIL-INERT: the guardrail that cannot fail ────────────────
sb="$(make_sandbox)"; r="$sb/inert"; _mkrepo "$r"
mkdir -p "$r/scripts" "$r/.githooks" "$r/.github/workflows" "$r/tests"
cat > "$r/scripts/pre-commit-gate.sh" <<'EOF'
#!/usr/bin/env bash
pytest -q || true
black --check .
EOF
printf '#!/bin/sh\nexec scripts/pre-commit-gate.sh\n' > "$r/.githooks/pre-commit"
cat > "$r/.github/workflows/ci.yml" <<'EOF'
name: ci
jobs:
  test:
    steps:
      - run: pytest
        continue-on-error: true
    env:
      RATCHET_OVERRIDE: 1
EOF
printf 'def test_a():\n    pass\n' > "$r/tests/test_a.py"

I="$(HOME="$sb" "$AU" rails --repo "$r")"
assert_contains "$I" $'RAIL\tprecommit-gate\tpresent' "the gate IS present — detection is unchanged"
assert_contains "$I" $'RAIL-INERT\tprecommit-gate' "...but its checks end in || true → it cannot fail"
assert_contains "$I" "key=inert-precommit-gate" "RAIL-INERT carries a canonical ledger key"
assert_contains "$I" $'RAIL-INERT\tci' "continue-on-error: true → CI can never fail the build"
assert_contains "$I" $'RAIL-INERT\ttest-ratchet' "an armed RATCHET_OVERRIDE in CI → the ratchet can never block"
# The row must not double-fire: scripts/pre-commit-gate.sh matches both the
# explicit path AND the scripts/*pre-commit* glob, which once emitted it twice
# and double-deducted the rails grade.
assert_eq "1" "$(printf '%s\n' "$I" | grep -c $'RAIL-INERT\tprecommit-gate')" \
  "the same inert gate is reported exactly once (gate-script list is de-duplicated)"

# THE GRADE CONSEQUENCE — the whole point. A rail that cannot fail earns no credit.
G="$(HOME="$sb" "$AU" grade --repo "$r")"
assert_contains "$G" "absent or inert" "the rails axis note names inert machinery, not just absent"
gd="$(printf '%s\n' "$G" | awk -F'\t' '$1=="GRADE-AXIS" && $2=="rails"{print $3}')"
assert_not_contains "$gd" "0" "an inert gate DEDUCTS — presence of machinery is not coverage"

# ── PRECISION: a real gate, and a documented escape hatch, are not inert ──
ok="$sb/ok"; _mkrepo "$ok"; mkdir -p "$ok/scripts" "$ok/.githooks"
cat > "$ok/scripts/pre-commit-gate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Escape hatch (deliberate, one-off): RATCHET_OVERRIDE=1 git commit ... || true
pytest -q
EOF
printf '#!/bin/sh\nexec scripts/pre-commit-gate.sh\n' > "$ok/.githooks/pre-commit"
OK="$(HOME="$sb" "$AU" rails --repo "$ok")"
assert_contains "$OK" $'RAIL\tprecommit-gate\tpresent' "a real gate is present"
assert_not_contains "$OK" "RAIL-INERT" "a commented-out escape hatch is documentation, not an inert gate"

# ── ENV-UNDECLARED: read here, declared nowhere ───────────────
e="$sb/env"; _mkrepo "$e"; mkdir -p "$e/app" "$e/tests"
printf 'DATABASE_URL=postgres://x\n' > "$e/.env.example"
cat > "$e/app/main.py" <<'EOF'
import os
db = os.environ["DATABASE_URL"]
key = os.environ["STRIPE_SECRET_KEY"]
region = os.getenv("AWS_REGION")
home = os.environ["HOME"]
EOF
printf 'const t = process.env.SEGMENT_TOKEN;\n' > "$e/app/client.ts"
printf 'import os\nx = os.environ["TEST_ONLY_VAR"]\n' > "$e/tests/test_a.py"
E="$(HOME="$sb" "$AU" silence --repo "$e")"
assert_contains "$E" $'ENV-UNDECLARED\tSTRIPE_SECRET_KEY\tapp/main.py' "read in source, absent from .env.example → flagged, with the read site"
assert_contains "$E" $'ENV-UNDECLARED\tAWS_REGION'    "os.getenv() is a read too"
assert_contains "$E" $'ENV-UNDECLARED\tSEGMENT_TOKEN' "process.env.X is a read too"
assert_contains "$E" "key=declare-env-stripe-secret-key" "ENV-UNDECLARED carries a per-var canonical key"
assert_not_contains "$E" "DATABASE_URL"  "a DECLARED var is not a finding"
assert_not_contains "$E" "HOME"          "ambient shell vars (HOME/PATH/CI/...) are never findings"
assert_not_contains "$E" "TEST_ONLY_VAR" "a var read only in tests is not a prod break"

# No declaration discipline → no invariant to violate → say nothing.
nd="$sb/nodecl"; _mkrepo "$nd"; mkdir -p "$nd/app"
printf 'import os\nk = os.environ["ANYTHING"]\n' > "$nd/app/m.py"
ND="$(HOME="$sb" "$AU" silence --repo "$nd")"
assert_contains "$ND" $'NOTE\tsilence' "no .env.example/compose/Dockerfile/CI → NOTE, not a pile of findings"
assert_not_contains "$ND" "ENV-UNDECLARED" "without a declaration file there is no invariant to violate"

# ── SWALLOW: the empty handler ────────────────────────────────
w="$sb/swallow"; _mkrepo "$w"; mkdir -p "$w/app"
printf 'X=1\n' > "$w/.env.example"
cat > "$w/app/h.py" <<'EOF'
def bad():
    try:
        parse()
    except ValueError:
        pass

def logged():
    try:
        parse()
    except ValueError:
        log.exception("bad parse")

def reraised():
    try:
        parse()
    except ValueError:
        raise RuntimeError("wrapped")

def fallback():
    try:
        return parse()
    except ValueError:
        return None
EOF
printf 'try { go(); } catch (e) {}\ntry { go(); } catch (e) { log(e); }\n' > "$w/app/c.ts"
W="$(HOME="$sb" "$AU" silence --repo "$w")"
assert_contains "$W" $'SWALLOW\tapp/h.py\t4' "except: pass → the error happened and nothing recorded it"
assert_contains "$W" $'SWALLOW\tapp/c.ts\t1' "empty catch block → swallow"
assert_contains "$W" "key=swallow-app-h-py-4" "SWALLOW carries a per-site canonical key"
# The negative cases ARE the product. A handler that does something is a DECISION.
# NB: the scan anchors on the `except` LINE (4/10/16/22), not the body line. An
# earlier version of these asserted the body lines (11/17/23) — which the scan
# never emits under any circumstances, so they passed vacuously and tested
# nothing. Assert the lines that WOULD be emitted if precision broke.
assert_not_contains "$W" $'SWALLOW\tapp/h.py\t10' "a handler that LOGS is a decision, not a swallow"
assert_not_contains "$W" $'SWALLOW\tapp/h.py\t16' "a handler that RE-RAISES is a decision, not a swallow"
assert_not_contains "$W" $'SWALLOW\tapp/h.py\t22' "a handler that returns a FALLBACK is a decision, not a swallow"
assert_eq "1" "$(printf '%s\n' "$W" | grep -c $'SWALLOW\tapp/h\.py')" "exactly ONE of the four python handlers is a swallow"
assert_eq "1" "$(printf '%s\n' "$W" | grep -c $'SWALLOW\tapp/c\.ts')" "the logging catch on line 2 is not flagged"

# ── multi-line empty catch — the common formatting ────────────
# `catch (e) {` then only blank lines then `}` is the same swallow as `catch {}`
# on one line; a comment inside the block is a DECISION and does not count.
cat > "$w/app/m.ts" <<'EOF'
try { go(); } catch (e) {
}
try { go(); } catch (e) {

}
try { go(); } catch (e) {
  // deliberate: offline mode falls through
}
EOF
M="$(HOME="$sb" "$AU" silence --repo "$w")"
assert_contains "$M" $'SWALLOW\tapp/m.ts\t1' "multi-line empty catch (immediate close) → swallow"
assert_contains "$M" $'SWALLOW\tapp/m.ts\t3' "multi-line empty catch (blank line inside) → swallow"
assert_eq "2" "$(printf '%s\n' "$M" | grep -c $'SWALLOW\tapp/m\.ts')" \
  "a catch containing only a comment is a decision, not a swallow"

# ── exit codes: read-only emitters never leak an incidental status ──
HOME="$sb" "$AU" silence --repo "$nd" >/dev/null 2>&1
assert_eq "0" "$?" "silence with nothing to report exits 0"
HOME="$sb" "$AU" silence --repo "$w" >/dev/null 2>&1
assert_eq "0" "$?" "silence with findings exits 0"

t_done
