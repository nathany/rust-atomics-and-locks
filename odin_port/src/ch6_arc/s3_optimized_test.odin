package ch6_arc

import "core:testing"
import "core:thread"

num_drops_optimized: Atomic(int)

@(test)
test_optimized_arc :: proc(t: ^testing.T) {
	// Create an Arc with two weak pointers.
	x := arc_new("hello", proc(data: ^string) {
		atomic_add(&num_drops_optimized, 1, .Relaxed)
	})
	y := arc_downgrade(x)
	z := arc_downgrade(x)

	th := thread.create_and_start_with_poly_data(y, proc(y: Weak(string)) {
		// Weak pointer should be upgradable at this point.
		y_arc, ok := weak_upgrade(y)
		assert(ok)
		assert(arc_get(y_arc)^ == "hello")
		arc_drop(y_arc)
		weak_drop(y)
	})
	testing.expect_value(t, arc_get(x)^, "hello")
	thread.join(th)
	thread.destroy(th)

	// The data shouldn't be dropped yet,
	// and the weak pointer should be upgradable.
	testing.expect_value(t, atomic_load(&num_drops_optimized, .Relaxed), 0)
	upgraded, ok := weak_upgrade(z)
	testing.expect(t, ok)
	arc_drop(upgraded)

	arc_drop(x)

	// Now, the data should be dropped, and the
	// weak pointer should no longer be upgradable.
	testing.expect_value(t, atomic_load(&num_drops_optimized, .Relaxed), 1)
	_, ok2 := weak_upgrade(z)
	testing.expect(t, !ok2)

	weak_drop(z)
}
