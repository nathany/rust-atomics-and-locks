package main

import "base:intrinsics"
import "core:fmt"

next_id: u32

allocate_new_id :: proc() -> u32 {
	id := intrinsics.atomic_add_explicit(&next_id, 1, .Relaxed)
	if id >= 1000 {
		intrinsics.atomic_sub_explicit(&next_id, 1, .Relaxed)
		panic("too many IDs!")
	}
	return id
}

main :: proc() {
	fmt.println("allocate_new_id() =", allocate_new_id())
	fmt.println("allocate_new_id() =", allocate_new_id())
	fmt.println("allocate_new_id() =", allocate_new_id())
	// TODO
}
