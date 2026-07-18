package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"
import "core:time"

DATA: u64
READY: bool

main :: proc() {
	thread.create_and_start(proc() {
		intrinsics.atomic_store_explicit(&DATA, 123, .Relaxed)
		intrinsics.atomic_store_explicit(&READY, true, .Release) // Everything from before this store ..
	})
	for !intrinsics.atomic_load_explicit(&READY, .Acquire) { // .. is visible after this loads `true`.
		time.sleep(100 * time.Millisecond)
		fmt.println("waiting...")
	}
	fmt.println(intrinsics.atomic_load_explicit(&DATA, .Relaxed))
}
