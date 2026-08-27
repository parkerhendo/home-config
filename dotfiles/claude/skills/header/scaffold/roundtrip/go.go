// roundtrip_test.go — the invariant nothing else in this repo asserts.
//
// The bug this catches: a value pipeline built as a chain of hand-maintained hops
// (wire schema → column → import mapping → export query → serializer → UI) needs a
// field added in EVERY hop or none. Nothing enforces that, so fields drift — you
// end up with a column and no wire field, or a wire field the exporter hardcodes.
// It stays invisible until a human notices wrong numbers.
//
// This test does not care how many hops there are. It only asserts: what goes in
// comes back out.
//
// WIRE UP: replace the TODOs.

package myapp

import (
	"reflect"
	"testing"
)

// fullyPopulated returns a config with EVERY field set to a distinctive
// non-default value. Zero values are the enemy: a field that drifts to its zero
// value still compares equal, so the test passes while the field is dropped.
func fullyPopulated() Config {
	// TODO(1): every field, non-zero values.
	return Config{
		// Allocation:  7,
		// PeriodScope: "monthly",
		// MaxSeats:    12, // the field an exporter loves to hardcode
	}
}

func TestRoundTripPreservesEveryField(t *testing.T) {
	original := fullyPopulated()

	// TODO(2): your real import + export entrypoints.
	// imported, err := ImportConfig(original)
	// if err != nil {
	// 	t.Fatalf("import: %v", err)
	// }
	// exported, err := ExportConfig(imported)
	// if err != nil {
	// 	t.Fatalf("export: %v", err)
	// }
	exported := original // TODO: remove once wired

	if !reflect.DeepEqual(original, exported) {
		t.Fatalf("pipeline did not preserve the config\n in: %+v\nout: %+v", original, exported)
	}

	// Field-by-field, so the failure names the field rather than dumping structs.
	ov, ev := reflect.ValueOf(original), reflect.ValueOf(exported)
	for i := 0; i < ov.NumField(); i++ {
		name := ov.Type().Field(i).Name
		if of, ef := ov.Field(i).Interface(), ev.Field(i).Interface(); !reflect.DeepEqual(of, ef) {
			t.Errorf("field %s did not survive the round trip: in=%v out=%v", name, of, ef)
		}
		if ov.Field(i).IsZero() {
			t.Errorf("field %s is zero in the fixture — it cannot detect drift; give it a real value", name)
		}
	}
}
