#!/usr/bin/env bash
# test/drift.test.sh — bin/header-audit {drift, rails roundtrip-invariant, rail
# roundtrip-invariant}. The INVARIANT-COVERAGE scan: not "does machinery exist?"
# but "does the machinery cover what the architecture depends on?".
#
# The bug under test: a value pipeline built from hand-maintained hops (wire
# schema → column → import mapping → export query → serializer) where a field must
# be added in every hop or none, nothing enforces that, and fields silently drift.
# Two things keep it invisible — no test round-trips the pipeline, and the schema
# strips unknown keys so a config with the dropped field still parses clean.
#
# The precision bar is the whole product decision here: a repo with NO pipeline
# must come back n/a (never nagged, grade never moved). Those are the first tests.
source "$(dirname "${BASH_SOURCE[0]}")/run.sh"

AU="$SKILL_DIR/bin/header-audit"

_mkrepo() { local d="$1"; mkdir -p "$d"; ( cd "$d" && git init -q && git config user.email t@t.t && git config user.name t ); }

# ── PRECISION: no pipeline → n/a, not "absent" ────────────────
# The failure mode that would make this scan unshippable is firing on repos that
# have no pipeline at all. A plain app, and a schema-only repo (types but nothing
# to round-trip THROUGH), must both stay silent.
sb="$(make_sandbox)"; bare="$sb/bare"; _mkrepo "$bare"
printf 'def hello():\n    return 1\n' > "$bare/app.py"
printf 'requests\n' > "$bare/requirements.txt"
D="$(HOME="$sb" "$AU" drift --repo "$bare")"
assert_contains "$D" $'NOTE\tdrift' "no pipeline → NOTE, no rows"
assert_not_contains "$D" "ROUNDTRIP" "no pipeline → never claims a missing round-trip test"
R="$(HOME="$sb" "$AU" rails --repo "$bare")"
assert_contains "$R" $'RAIL\troundtrip-invariant\tn/a' "no pipeline → rail is n/a (never nags, never deducts)"

schemaonly="$sb/schemaonly"; _mkrepo "$schemaonly"
printf 'from pydantic import BaseModel\n\nclass C(BaseModel):\n    name: str\n' > "$schemaonly/types.py"
D0="$(HOME="$sb" "$AU" drift --repo "$schemaonly")"
assert_contains "$D0" $'NOTE\tdrift' "schema hop alone is a type definition, not a pipeline → n/a"

# REGRESSION: one file matching several hop regexes is NOT a chain.
# This bit for real — header-audit carries the hop regexes as string literals, so
# it matched `schema` AND `persist` in a single file and reported a pipeline in the
# Header repo itself. Drift needs somewhere to drift BETWEEN; a lone file has
# nowhere. Generalizes to every linter / scanner / codegen tool that quotes schema
# and ORM identifiers in its own source.
onefile="$sb/onefile"; _mkrepo "$onefile"
cat > "$onefile/scanner.py" <<'EOF'
# a tool that merely MENTIONS these identifiers is not a pipeline
SCHEMA_RX = r"\(BaseModel\)|from pydantic"
PERSIST_RX = r"__tablename__|sqlalchemy"
def serialize_report(r):
    return {}
EOF
D0b="$(HOME="$sb" "$AU" drift --repo "$onefile")"
assert_contains "$D0b" $'NOTE\tdrift' "hops confined to ONE file → not a chain → n/a (the self-match regression)"
Rb="$(HOME="$sb" "$AU" rails --repo "$onefile")"
assert_contains "$Rb" $'RAIL\troundtrip-invariant\tn/a' "one-file 'pipeline' → rail stays n/a, grade unmoved"

# ── the real thing: schema + persistence + serde, no round-trip test ──
# Mirrors the reported bug exactly: a column with no wire field (allocation), and
# an exporter that hardcodes a field the schema never carried (max_seats).
p="$sb/pipeline"; _mkrepo "$p"; mkdir -p "$p/app" "$p/tests" "$p/migrations"
cat > "$p/app/schema.py" <<'EOF'
from pydantic import BaseModel

class EntitlementModel(BaseModel):
    name: str
    seats: int
EOF
cat > "$p/app/models.py" <<'EOF'
from sqlalchemy import Column, Integer, String

class Entitlement:
    __tablename__ = "entitlements"
    allocation = Column(Integer)
EOF
cat > "$p/app/io.py" <<'EOF'
def import_config(payload):
    return EntitlementModel(**payload)

def export_config(ent):
    return {"name": ent.name, "max_seats": 999999}
EOF
printf 'CREATE TABLE entitlements (id int);\n' > "$p/migrations/001.sql"
printf 'def test_name():\n    assert True\n' > "$p/tests/test_basic.py"

D1="$(HOME="$sb" "$AU" drift --repo "$p")"
assert_contains "$D1" $'PIPELINE\tschema'  "pydantic BaseModel → schema hop"
assert_contains "$D1" $'PIPELINE\tpersist' "sqlalchemy/migrations → persistence hop"
assert_contains "$D1" $'PIPELINE\tserde'   "import_/export_ definitions → serde hop"
assert_contains "$D1" $'ROUNDTRIP\tabsent' "pipeline + a test suite that never round-trips it → absent"
assert_contains "$D1" "key=rail-roundtrip-invariant" "ROUNDTRIP absent carries the canonical rail ledger key"
# The rail and the drift scan must agree — same finding, same key, two surfaces.
R1="$(HOME="$sb" "$AU" rails --repo "$p")"
assert_contains "$R1" $'RAIL\troundtrip-invariant\tabsent' "rails agrees with drift: absent"
assert_contains "$R1" "key=rail-roundtrip-invariant" "the rails row carries the same canonical key"

# SCHEMA-LAX: why the drift is INVISIBLE rather than merely present.
assert_contains "$D1" $'SCHEMA-LAX\tapp/schema.py' "lenient pydantic model → SCHEMA-LAX"
assert_contains "$D1" "key=strict-schema-app-schema-py" "SCHEMA-LAX carries a per-file canonical key"

# ── a round-trip test flips it to present ─────────────────────
printf 'def test_roundtrip():\n    assert export_config(import_config({"a": 1})) == {"a": 1}\n' > "$p/tests/test_roundtrip.py"
D2="$(HOME="$sb" "$AU" drift --repo "$p")"
assert_contains "$D2" $'ROUNDTRIP\tlikely-present' "a test naming round-trip → likely-present (word-match, honestly labeled)"
assert_not_contains "$D2" "key=rail-roundtrip-invariant" "a present round-trip carries no ledger key (status only)"

# ── strict mode clears SCHEMA-LAX ─────────────────────────────
cat > "$p/app/schema.py" <<'EOF'
from pydantic import BaseModel, ConfigDict

class EntitlementModel(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str
EOF
D3="$(HOME="$sb" "$AU" drift --repo "$p")"
assert_not_contains "$D3" "SCHEMA-LAX" "extra='forbid' → no longer silently strips unknown keys"

# ── the two-directional test also qualifies (no literal "round-trip") ──
# A single test exercising BOTH serialize and deserialize IS a round-trip test,
# whatever it is named — detection must not depend on the word.
p2="$sb/pipeline2"; _mkrepo "$p2"; mkdir -p "$p2/app" "$p2/tests"
printf 'from pydantic import BaseModel\n\nclass M(BaseModel):\n    a: int\n' > "$p2/app/schema.py"
printf 'def to_dict(m):\n    return {}\n\ndef from_dict(d):\n    return None\n' > "$p2/app/io.py"
printf 'def test_both():\n    x = to_dict(1)\n    y = from_dict(x)\n    assert y == y\n' > "$p2/tests/test_io.py"
D4="$(HOME="$sb" "$AU" drift --repo "$p2")"
assert_contains "$D4" $'ROUNDTRIP\tlikely-present' "a test exercising to_dict AND from_dict is a structural round-trip candidate → likely-present"

# ── zod / npm path ────────────────────────────────────────────
z="$sb/zod"; _mkrepo "$z"; mkdir -p "$z/src"
printf '{"name":"z"}\n' > "$z/package.json"
printf 'import { z } from "zod";\nexport const Cfg = z.object({ name: z.string() });\n' > "$z/src/schema.ts"
printf 'import { Entity } from "typeorm";\n@Entity()\nexport class C {}\n' > "$z/src/db.ts"
printf 'export function serializeCfg(c) { return {}; }\n' > "$z/src/io.ts"
DZ="$(HOME="$sb" "$AU" drift --repo "$z")"
assert_contains "$DZ" $'PIPELINE\tschema'    "z.object → schema hop"
assert_contains "$DZ" $'ROUNDTRIP\tabsent'   "zod pipeline with no test → absent"
assert_contains "$DZ" $'SCHEMA-LAX\tsrc/schema.ts' "z.object without .strict() → SCHEMA-LAX"
printf 'import { z } from "zod";\nexport const Cfg = z.object({ name: z.string() }).strict();\n' > "$z/src/schema.ts"
DZ2="$(HOME="$sb" "$AU" drift --repo "$z")"
assert_not_contains "$DZ2" "SCHEMA-LAX" ".strict() → no longer lenient"

# ── the scaffold printer: the artifact, not advice ────────────
S1="$(HOME="$sb" "$AU" rail roundtrip-invariant --ecosystem python --repo "$p")"
assert_contains "$S1" "FILE: tests/test_roundtrip.py" "python → prints a pytest round-trip file"
assert_contains "$S1" "COMPANION FIX" "the scaffold always prints the strict-parsing companion fix"
assert_contains "$S1" "extra='forbid'" "the companion fix names the pydantic one-liner"
S2="$(HOME="$sb" "$AU" rail roundtrip-invariant --ecosystem npm --repo "$z")"
assert_contains "$S2" "FILE: tests/roundtrip.test.ts" "npm → prints a vitest/jest round-trip file"
assert_contains "$S2" ".strict()" "the companion fix names the zod one-liner"
S3="$(HOME="$sb" "$AU" rail roundtrip-invariant --ecosystem go --repo "$p")"
assert_contains "$S3" "roundtrip_test.go" "go → prints a table-driven go test"
S4="$(HOME="$sb" "$AU" rail roundtrip-invariant --ecosystem unknown --repo "$p")"
assert_contains "$S4" "Round-trip invariant" "unknown stack → still prints the shape to write"

# ── exit codes: a read-only emitter never leaks an incidental status ──
HOME="$sb" "$AU" drift --repo "$bare" >/dev/null 2>&1
assert_eq "0" "$?" "drift on a repo with no pipeline still exits 0"
HOME="$sb" "$AU" drift --repo "$p" >/dev/null 2>&1
assert_eq "0" "$?" "drift on a pipeline repo exits 0"

t_done
