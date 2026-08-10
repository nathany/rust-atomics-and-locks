package main

import "base:intrinsics"

increment :: proc(a: ^u32) {
	current := intrinsics.atomic_load_explicit(a, .Relaxed)
	for {
		next := current + 1
		// The compare-exchange intrinsics return the old value plus a bool,
		// instead of Rust's Ok/Err.
		value, ok := intrinsics.atomic_compare_exchange_strong_explicit(a, current, next, .Relaxed, .Relaxed)
		if ok {
			return
		}
		current = value
	}
}

main :: proc() {
	a := u32(0)
	increment(&a)
	increment(&a)
	assert(a == 2)
}
