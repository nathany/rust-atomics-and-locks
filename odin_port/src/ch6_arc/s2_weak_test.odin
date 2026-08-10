package ch6_arc

import "core:testing"
import "core:thread"

num_drops_simple: Atomic(int)

@(test)
test_simple_weak_arc :: proc(t: ^testing.T) {
	// Create an Arc with two weak pointers.
	x := simple_arc_new("hello", proc(data: ^string) {
		atomic_add(&num_drops_simple, 1, .Relaxed)
	})
	y := simple_arc_downgrade(x)
	z := simple_arc_downgrade(x)

	th := thread.create_and_start_with_poly_data(y, proc(y: Simple_Weak(string)) {
		// Weak pointer should be upgradable at this point.
		y_arc, ok := simple_weak_upgrade(y)
		assert(ok)
		assert(simple_arc_get(y_arc)^ == "hello")
		simple_arc_drop(y_arc)
		simple_weak_drop(y)
	})
	testing.expect_value(t, simple_arc_get(x)^, "hello")
	thread.join(th)
	thread.destroy(th)

	// The data shouldn't be dropped yet,
	// and the weak pointer should be upgradable.
	testing.expect_value(t, atomic_load(&num_drops_simple, .Relaxed), 0)
	upgraded, ok := simple_weak_upgrade(z)
	testing.expect(t, ok)
	simple_arc_drop(upgraded) // Rust: the temporary Arc drops right away.

	simple_arc_drop(x)

	// Now, the data should be dropped, and the
	// weak pointer should no longer be upgradable.
	testing.expect_value(t, atomic_load(&num_drops_simple, .Relaxed), 1)
	_, ok2 := simple_weak_upgrade(z)
	testing.expect(t, !ok2)

	simple_weak_drop(z) // Rust: z drops at end of scope, freeing the allocation.
}
