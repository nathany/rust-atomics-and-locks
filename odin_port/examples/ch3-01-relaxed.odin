package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"

X: i32
Y: i32

a :: proc() {
	intrinsics.atomic_store_explicit(&X, 10, .Relaxed)
	intrinsics.atomic_store_explicit(&Y, 20, .Relaxed)
}

b :: proc() {
	y := intrinsics.atomic_load_explicit(&Y, .Relaxed)
	x := intrinsics.atomic_load_explicit(&X, .Relaxed)
	fmt.printfln("%d %d", x, y)
}

main :: proc() {
	t1 := thread.create_and_start(a)
	t2 := thread.create_and_start(b)
	thread.join(t1)
	thread.join(t2)
	thread.destroy(t1)
	thread.destroy(t2)
}
