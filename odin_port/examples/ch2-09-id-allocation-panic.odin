package main

import "base:intrinsics"
import "core:fmt"

next_id: u32

// This version is problematic.
allocate_new_id :: proc() -> u32 {
	id := intrinsics.atomic_add_explicit(&next_id, 1, .Relaxed)
	assert(id < 1000, "too many IDs!")
	return id
}

main :: proc() {
	fmt.println("allocate_new_id() =", allocate_new_id()) // This will produce a zero.

	for _ in 1 ..< 1000 {
		allocate_new_id() // 1 through 999.
	}

	fmt.println("overflowing the counter... (this might take a minute)")

	// Odin has no catch_unwind: a failed assert aborts the process and
	// cannot be caught. The bug is the same though — the fetch_add has
	// already happened by the time the assert fires. We demonstrate it by
	// repeating just the fetch_add that each "caught panic" leaves behind.
	for _ in 1000 ..= max(u32) {
		intrinsics.atomic_add_explicit(&next_id, 1, .Relaxed)
	}

	fmt.println("overflowed!")

	fmt.println("allocate_new_id() =", allocate_new_id()) // ⚠️ This will produce zero again. ⚠️
}
