package main

import "core:slice"

// Odin has no RefCell; no runtime borrow tracking is needed.
f :: proc(v: ^[dynamic]int) {
	append(v, 1) // We can modify the array directly.
}

main :: proc() {
	v: [dynamic]int
	defer delete(v)
	append(&v, 1, 2, 3)

	f(&v)
	assert(slice.equal(v[:], []int{1, 2, 3, 1}))
}
