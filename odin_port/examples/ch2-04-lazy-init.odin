package main

import "base:intrinsics"
import "core:fmt"
import "core:time"

get_x :: proc() -> u64 {
	@(static) X: u64
	x := intrinsics.atomic_load_explicit(&X, .Relaxed)
	if x == 0 {
		x = calculate_x()
		intrinsics.atomic_store_explicit(&X, x, .Relaxed)
	}
	return x
}

calculate_x :: proc() -> u64 {
	time.sleep(1 * time.Second)
	return 123
}

main :: proc() {
	fmt.println("get_x() =", get_x())
	fmt.println("get_x() =", get_x())
}
