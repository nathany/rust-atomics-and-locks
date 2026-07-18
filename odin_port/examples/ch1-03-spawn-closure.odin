package main

import "core:fmt"
import "core:thread"

// Odin has no capturing closures. Instead of moving `numbers` into a
// closure, we pass it to the thread explicitly as an argument.
main :: proc() {
	numbers := []int{1, 2, 3}

	t := thread.create_and_start_with_poly_data(numbers, proc(numbers: []int) {
		for n in numbers {
			fmt.println(n)
		}
	})
	thread.join(t)
	thread.destroy(t)
}
