package main

import "base:intrinsics"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

// As in ch1-11, a semaphore stands in for thread parking:
// sema_wait_with_timeout is like park_timeout, sema_post like unpark.
State :: struct {
	num_done:    int,
	main_wakeup: sync.Sema,
}

main :: proc() {
	state: State

	// A background thread to process all 100 items.
	t := thread.create_and_start_with_poly_data(&state, proc(state: ^State) {
		for i in 0 ..< 100 {
			process_item(i) // Assuming this takes some time.
			intrinsics.atomic_store_explicit(&state.num_done, i + 1, .Relaxed)
			sync.sema_post(&state.main_wakeup) // Wake up the main thread.
		}
	})

	// The main thread shows status updates.
	for {
		n := intrinsics.atomic_load_explicit(&state.num_done, .Relaxed)
		if n == 100 do break
		fmt.printfln("Working.. %d/100 done", n)
		sync.sema_wait_with_timeout(&state.main_wakeup, 1 * time.Second)
	}

	thread.join(t)
	thread.destroy(t)
	fmt.println("Done!")
}

process_item :: proc(_: int) {
	time.sleep(37 * time.Millisecond)
}
