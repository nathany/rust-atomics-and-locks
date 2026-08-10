package main

import "base:intrinsics"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

// The Rust example is Linux-only: it makes the futex syscall directly.
// Odin's core:sync exposes the same operation portably (futex on Linux,
// __ulock on macOS, WaitOnAddress on Windows), so this port runs
// everywhere. sync.Futex is a distinct u32.

wait :: proc(a: ^sync.Futex, expected: u32) {
	sync.futex_wait(a, expected)
}

wake_one :: proc(a: ^sync.Futex) {
	sync.futex_signal(a)
}

a: sync.Futex

main :: proc() {
	t := thread.create_and_start(proc() {
		time.sleep(3 * time.Second)
		intrinsics.atomic_store_explicit(&a, 1, .Relaxed)
		wake_one(&a)
	})

	fmt.println("Waiting...")
	for intrinsics.atomic_load_explicit(&a, .Relaxed) == 0 {
		wait(&a, 0)
	}
	fmt.println("Done!")

	thread.join(t)
	thread.destroy(t)
}
