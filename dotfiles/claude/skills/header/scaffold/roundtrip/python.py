# tests/test_roundtrip.py — the invariant nothing else in this repo asserts.
#
# The bug this catches: a value pipeline built as a chain of hand-maintained hops
# (wire schema → column → import mapping → export query → serializer → UI) needs a
# field added in EVERY hop or none. Nothing enforces that, so fields drift — you
# end up with a column and no wire field, or a wire field the exporter hardcodes.
# It stays invisible until a human notices wrong numbers.
#
# This test does not care how many hops there are. It only asserts: what goes in
# comes back out. That is enough to make every one of those drifts loud.
#
# WIRE UP: replace the three TODOs. Nothing else needs to change.

import pytest

# TODO(1): import your real import + export entrypoints.
# from myapp.io import import_config, export_config
# TODO(2): import the wire schema so the fixture is generated FROM it, not hand-typed
# (a hand-typed fixture only covers the fields you remembered — the same bug).
# from myapp.schema import ConfigModel


def _fully_populated():
    """A config with EVERY field set to a distinctive non-default value.

    Defaults are the enemy here: a field that drifts to its default still
    compares equal, so the test passes while the field is being dropped.
    Prefer generating this from the schema (see test_roundtrip_generated below).
    """
    # TODO(3): every field, non-default values.
    return {
        # "allocation": 7,
        # "period_scope": "monthly",
        # "max_seats": 12,        # the field an exporter loves to hardcode
    }


def test_roundtrip_preserves_every_field():
    original = _fully_populated()
    assert original, "populate _fully_populated() — an empty fixture asserts nothing"

    # imported = import_config(original)
    # exported = export_config(imported)
    exported = original  # TODO: remove once wired

    missing = {k: original[k] for k in original if k not in exported}
    changed = {
        k: (original[k], exported[k])
        for k in original
        if k in exported and exported[k] != original[k]
    }
    assert not missing, f"fields dropped in the pipeline: {sorted(missing)}"
    assert not changed, f"fields mutated in the pipeline: {changed}"


# ── The stronger version: generate the fixture from the schema ────────────────
# A handwritten fixture only covers fields you thought of. Reflecting over the
# schema covers every field that EXISTS — including the one added last week that
# nobody wired through. This is the version that catches the NEXT drift, not just
# the current one.
#
# @pytest.mark.parametrize("field", list(ConfigModel.model_fields))
# def test_every_schema_field_survives_roundtrip(field):
#     original = _fully_populated()
#     assert field in original, (
#         f"{field} is in the wire schema but not in the round-trip fixture — "
#         "either wire it through the pipeline or remove it from the schema"
#     )
#     exported = export_config(import_config(original))
#     assert field in exported, f"{field} is in the schema but the exporter drops it"
#     assert exported[field] == original[field], f"{field} did not survive the round trip"
