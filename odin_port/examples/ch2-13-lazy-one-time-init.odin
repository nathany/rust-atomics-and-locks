package main

import "base:intrinsics"
import "core:fmt"

get_key :: proc() -> u64 {
	@(static) KEY: u64
	key := intrinsics.atomic_load_explicit(&KEY, .Relaxed)
	if key == 0 {
		new_key := generate_random_key()
		k, ok := intrinsics.atomic_compare_exchange_strong_explicit(&KEY, 0, new_key, .Relaxed, .Relaxed)
		return new_key if ok else k
	}
	return key
}

generate_random_key :: proc() -> u64 {
	return 123
	// TODO
}

main :: proc() {
	fmt.println("get_key() =", get_key())
	fmt.println("get_key() =", get_key())
	fmt.println("get_key() =", get_key())
}
