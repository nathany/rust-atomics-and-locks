package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"

X: i32

a :: proc() {
	intrinsics.atomic_add_explicit(&X, 5, .Relaxed)
	intrinsics.atomic_add_explicit(&X, 10, .Relaxed)
}

b :: proc() {
	a := intrinsics.atomic_load_explicit(&X, .Relaxed)
	b := intrinsics.atomic_load_explicit(&X, .Relaxed)
	c := intrinsics.atomic_load_explicit(&X, .Relaxed)
	d := intrinsics.atomic_load_explicit(&X, .Relaxed)
	fmt.printfln("%d %d %d %d", a, b, c, d)
}

main :: proc() {
	t1 := thread.create_and_start(a)
	t2 := thread.create_and_start(b)
	thread.join(t1)
	thread.join(t2)
	thread.destroy(t1)
	thread.destroy(t2)
}
