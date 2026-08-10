package main

import "base:intrinsics"
import "core:fmt"

next_id: u32

// This version is problematic.
allocate_new_id :: proc() -> u32 {
	return intrinsics.atomic_add_explicit(&next_id, 1, .Relaxed)
}

main :: proc() {
	fmt.println("allocate_new_id() =", allocate_new_id()) // 0
	fmt.println("allocate_new_id() =", allocate_new_id()) // 1
	fmt.println("allocate_new_id() =", allocate_new_id()) // 2

	fmt.println("overflowing the counter... (this might take a minute)")

	for _ in 3 ..= max(u32) {
		allocate_new_id()
	}

	fmt.println("overflowed!")

	fmt.println("allocate_new_id() =", allocate_new_id()) // ⚠️ This will produce zero again. ⚠️
}
