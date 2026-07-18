package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"
import "core:time"

// Rust marks the non-atomic accesses to DATA `unsafe` and demands a safety
// argument. In Odin there is no such distinction — every access is allowed,
// and the safety comments alone carry the argument.
DATA: u64
READY: bool

main :: proc() {
	thread.create_and_start(proc() {
		// Safety: Nothing else is accessing DATA,
		// because we haven't set the READY flag yet.
		DATA = 123
		intrinsics.atomic_store_explicit(&READY, true, .Release) // Everything from before this store ..
	})
	for !intrinsics.atomic_load_explicit(&READY, .Acquire) { // .. is visible after this loads `true`.
		time.sleep(100 * time.Millisecond)
		fmt.println("waiting...")
	}
	// Safety: Nothing is mutating DATA, because READY is set.
	fmt.println(DATA)
}
