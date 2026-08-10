package ch6_arc

import "core:testing"
import "core:thread"

num_drops_basic: Atomic(int)

@(test)
test_basic_arc :: proc(t: ^testing.T) {
	// Create two Arcs sharing an object containing a string, with a
	// drop callback (Rust: a DetectDrop field) to detect when it's dropped.
	x := basic_arc_new("hello", proc(data: ^string) {
		atomic_add(&num_drops_basic, 1, .Relaxed)
	})
	y := basic_arc_clone(x)

	// Send x to another thread, and use it there.
	th := thread.create_and_start_with_poly_data(x, proc(x: Basic_Arc(string)) {
		assert(basic_arc_get(x)^ == "hello")
		basic_arc_drop(x) // Rust: the moved-in x is dropped here implicitly.
	})

	// In parallel, y should still be usable here.
	testing.expect_value(t, basic_arc_get(y)^, "hello")

	// Wait for the thread to finish.
	thread.join(th)
	thread.destroy(th)

	// One Arc, x, should be dropped by now.
	// We still have y, so the object shouldn't have been dropped yet.
	testing.expect_value(t, atomic_load(&num_drops_basic, .Relaxed), 0)

	// Drop the remaining Arc.
	basic_arc_drop(y)

	// Now that y is dropped too, the object should've been dropped.
	testing.expect_value(t, atomic_load(&num_drops_basic, .Relaxed), 1)
}
