package main

import "base:intrinsics"

main :: proc() {
	a := i32(100)
	b := intrinsics.atomic_add_explicit(&a, 23, .Relaxed)
	c := intrinsics.atomic_load_explicit(&a, .Relaxed)

	assert(b == 100)
	assert(c == 123)
}
