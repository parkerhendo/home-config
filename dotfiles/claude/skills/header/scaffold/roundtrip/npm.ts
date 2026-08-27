// tests/roundtrip.test.ts — the invariant nothing else in this repo asserts.
//
// The bug this catches: a value pipeline built as a chain of hand-maintained hops
// (wire schema → column → import mapping → export query → serializer → UI) needs a
// field added in EVERY hop or none. Nothing enforces that, so fields drift — you
// end up with a column and no wire field, or a wire field the exporter hardcodes.
// It stays invisible until a human notices wrong numbers.
//
// This test does not care how many hops there are. It only asserts: what goes in
// comes back out. That is enough to make every one of those drifts loud.
//
// WIRE UP: replace the three TODOs. Nothing else needs to change.

import { describe, expect, it } from "vitest"; // or: from "@jest/globals"

// TODO(1): import your real import + export entrypoints.
// import { importConfig, exportConfig } from "../src/io";
// TODO(2): import the wire schema, so the fixture is generated FROM it rather than
// hand-typed (a hand-typed fixture only covers the fields you remembered — same bug).
// import { ConfigSchema } from "../src/schema";

/**
 * A config with EVERY field set to a distinctive non-default value.
 *
 * Defaults are the enemy: a field that drifts to its default still compares
 * equal, so the test passes while the field is being dropped.
 */
function fullyPopulated(): Record<string, unknown> {
  // TODO(3): every field, non-default values.
  return {
    // allocation: 7,
    // period_scope: "monthly",
    // max_seats: 12,   // the field an exporter loves to hardcode to 999999
  };
}

describe("pipeline round-trip", () => {
  it("preserves every field", () => {
    const original = fullyPopulated();
    expect(
      Object.keys(original).length,
      "populate fullyPopulated() — an empty fixture asserts nothing",
    ).toBeGreaterThan(0);

    // const exported = exportConfig(importConfig(original));
    const exported = original; // TODO: remove once wired

    expect(exported).toEqual(original);
  });

  // ── The stronger version: drive the fixture from the schema ────────────────
  // A handwritten fixture only covers fields you thought of. Reflecting over the
  // schema covers every field that EXISTS — including the one added last week
  // that nobody wired through. This catches the NEXT drift, not just this one.
  //
  // it.each(Object.keys(ConfigSchema.shape))("field %s survives the round trip", (field) => {
  //   const original = fullyPopulated();
  //   expect(original, `${field} is in the schema but not in the fixture`).toHaveProperty(field);
  //   const exported = exportConfig(importConfig(original)) as Record<string, unknown>;
  //   expect(exported[field], `${field} is in the schema but the exporter drops it`)
  //     .toEqual(original[field]);
  // });
});
