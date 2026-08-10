package main

import "core:slice"

// Odin has no Cell: there are no shared/exclusive borrow rules, so any
// pointer can be used to mutate. Here we still mirror Cell's take/set
// pattern: take the value out, modify it, and put it back.
f :: proc(v: ^[dynamic]int) {
	v2 := v^ // Take the contents, ...
	v^ = {}  // ... leaving an empty array behind.
	append(&v2, 1)
	v^ = v2 // Put the modified array back.
}

main :: proc() {
	v: [dynamic]int
	defer delete(v)
	append(&v, 1, 2, 3)

	f(&v)
	assert(slice.equal(v[:], []int{1, 2, 3, 1}))
}
