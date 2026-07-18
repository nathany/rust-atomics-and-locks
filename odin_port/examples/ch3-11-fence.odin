package main

import "base:intrinsics"
import "core:fmt"
import "core:slice"
import "core:thread"
import "core:time"

DATA: [10]u64
READY: [10]bool

main :: proc() {
	for i in 0 ..< 10 {
		thread.create_and_start_with_poly_data(i, proc(i: int) {
			data := some_calculation(i)
			DATA[i] = data
			intrinsics.atomic_store_explicit(&READY[i], true, .Release)
		})
	}
	time.sleep(500 * time.Millisecond)
	ready: [10]bool
	for i in 0 ..< 10 {
		ready[i] = intrinsics.atomic_load_explicit(&READY[i], .Relaxed)
	}
	if slice.contains(ready[:], true) {
		intrinsics.atomic_thread_fence(.Acquire)
		for i in 0 ..< 10 {
			if ready[i] {
				fmt.printfln("data%d = %d", i, DATA[i])
			}
		}
	}
}

some_calculation :: proc(i: int) -> u64 {
	time.sleep(time.Duration(400 + i % 3 * 100) * time.Millisecond)
	return 123
}
