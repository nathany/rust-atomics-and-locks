package main

import "base:intrinsics"
import "core:thread"

X: i32

main :: proc() {
	intrinsics.atomic_store_explicit(&X, 1, .Relaxed)
	t := thread.create_and_start(f)
	intrinsics.atomic_store_explicit(&X, 2, .Relaxed)
	thread.join(t)
	thread.destroy(t)
	intrinsics.atomic_store_explicit(&X, 3, .Relaxed)
}

f :: proc() {
	x := intrinsics.atomic_load_explicit(&X, .Relaxed)
	assert(x == 1 || x == 2)
}
