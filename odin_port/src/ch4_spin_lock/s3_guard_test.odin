package ch4_spin_lock

import "core:slice"
import "core:testing"
import "core:thread"

@(test)
test_spin_lock :: proc(t: ^testing.T) {
	x: Spin_Lock([dynamic]int)

	t1 := thread.create_and_start_with_poly_data(&x, proc(x: ^Spin_Lock([dynamic]int)) {
		g := lock(x)
		defer unlock(g)
		append(guard_value(g), 1)
	})
	t2 := thread.create_and_start_with_poly_data(&x, proc(x: ^Spin_Lock([dynamic]int)) {
		g := lock(x)
		append(guard_value(g), 2)
		append(guard_value(g), 2)
		unlock(g)
	})
	thread.join(t1)
	thread.join(t2)
	thread.destroy(t1)
	thread.destroy(t2)

	g := lock(&x)
	v := guard_value(g)[:]
	testing.expect(t, slice.equal(v, []int{1, 2, 2}) || slice.equal(v, []int{2, 2, 1}))
	unlock(g)
}
