package main

import "core:fmt"
import "core:thread"

// Odin has no scoped threads (and no borrow checker to require them).
// Sharing a local variable with a thread is allowed as long as we make
// sure to join before it goes out of scope.
main :: proc() {
	numbers := []int{1, 2, 3}

	t1 := thread.create_and_start_with_poly_data(numbers, proc(numbers: []int) {
		fmt.println("length:", len(numbers))
	})
	t2 := thread.create_and_start_with_poly_data(numbers, proc(numbers: []int) {
		for n in numbers {
			fmt.println(n)
		}
	})

	thread.join(t1)
	thread.join(t2)
	thread.destroy(t1)
	thread.destroy(t2)
}
