package main

import "base:intrinsics"
import "core:thread"

DATA: [dynamic]u8
LOCKED: bool

f :: proc() {
	if _, ok := intrinsics.atomic_compare_exchange_strong_explicit(&LOCKED, false, true, .Acquire, .Relaxed); ok {
		// Safety: We hold the exclusive lock, so nothing else is accessing DATA.
		append(&DATA, '!')
		intrinsics.atomic_store_explicit(&LOCKED, false, .Release)
	}
}

main :: proc() {
	threads: [100]^thread.Thread
	for &t in threads {
		t = thread.create_and_start(f)
	}
	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}
	// DATA now contains at least one exclamation mark (and maybe more).
	assert(len(DATA) > 0)
	for c in DATA {
		assert(c == '!')
	}
}
