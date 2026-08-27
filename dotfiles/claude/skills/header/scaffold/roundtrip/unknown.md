# Round-trip invariant — the test to write

Header detected a value pipeline in this repo (a schema hop plus a persistence or
serde hop) but could not identify the stack well enough to emit a ready test file.
Here is the shape to write in whatever your suite uses.

## The bug this catches

A pipeline built as a chain of hand-maintained hops:

    wire schema → database column → import mapping → export query → serializer → UI

A field must be added in **every** hop or none. Nothing enforces that, so fields
drift: you end up with a database column and no wire field, or a wire field the
exporter hardcodes to a constant. The drift is **silent** — it only surfaces when
a human notices wrong numbers, which is the most expensive possible moment.

## The test

```
config   = <every field, set to a distinctive NON-DEFAULT value>
imported = import(config)
exported = export(imported)
assert exported == config
```

That is the whole thing. It does not care how many hops there are, so it keeps
working as the pipeline grows.

## Three rules that make it actually work

1. **Non-default values everywhere.** A field that drifts to its default still
   compares equal — the test passes while the field is being dropped. Every field
   in the fixture must hold a value it could not have arrived at by accident.

2. **Generate the fixture from the schema, not by hand.** A handwritten fixture
   only covers the fields you thought of. Reflecting over the schema covers every
   field that *exists* — including the one added last week that nobody wired
   through. This is what catches the *next* drift instead of only the current one.

3. **Fail per field, not per struct.** `assert exported == config` tells you
   something broke. Looping the fields and asserting each one tells you *which*,
   which is the difference between a five-minute fix and an afternoon.

## The companion fix

Turn on strict parsing at the import boundary (reject unknown keys). Silent
tolerance of unknown input is what made the drift invisible in the first place: a
config authored with a field nobody wired still parses clean, so it *looks*
complete. With strict mode on, that becomes an immediate, named failure.
