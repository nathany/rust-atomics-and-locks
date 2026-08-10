package main

import "base:intrinsics"
import "core:thread"

X: i32
Y: i32

main :: proc() {
	a := thread.create_and_start(proc() {
		x := intrinsics.atomic_load_explicit(&X, .Relaxed)
		intrinsics.atomic_store_explicit(&Y, x, .Relaxed)
	})
	b := thread.create_and_start(proc() {
		y := intrinsics.atomic_load_explicit(&Y, .Relaxed)
		intrinsics.atomic_store_explicit(&X, y, .Relaxed)
	})
	thread.join(a)
	thread.join(b)
	thread.destroy(a)
	thread.destroy(b)
	assert(intrinsics.atomic_load_explicit(&X, .Relaxed) == 0) // Might fail?
	assert(intrinsics.atomic_load_explicit(&Y, .Relaxed) == 0) // Might fail?
}
