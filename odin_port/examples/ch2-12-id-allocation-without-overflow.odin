package main

import "base:intrinsics"
import "core:fmt"

next_id: u32

allocate_new_id :: proc() -> u32 {
	id := intrinsics.atomic_load_explicit(&next_id, .Relaxed)
	for {
		assert(id < 1000, "too many IDs!")
		value, ok := intrinsics.atomic_compare_exchange_weak_explicit(&next_id, id, id + 1, .Relaxed, .Relaxed)
		if ok {
			return id
		}
		id = value
	}
}

main :: proc() {
	fmt.println("allocate_new_id() =", allocate_new_id())
	fmt.println("allocate_new_id() =", allocate_new_id())
	fmt.println("allocate_new_id() =", allocate_new_id())
	// TODO
}
