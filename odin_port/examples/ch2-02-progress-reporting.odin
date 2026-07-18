package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"
import "core:time"

main :: proc() {
	num_done := 0

	// A background thread to process all 100 items.
	t := thread.create_and_start_with_poly_data(&num_done, proc(num_done: ^int) {
		for i in 0 ..< 100 {
			process_item(i) // Assuming this takes some time.
			intrinsics.atomic_store_explicit(num_done, i + 1, .Relaxed)
		}
	})

	// The main thread shows status updates, every second.
	for {
		n := intrinsics.atomic_load_explicit(&num_done, .Relaxed)
		if n == 100 do break
		fmt.printfln("Working.. %d/100 done", n)
		time.sleep(1 * time.Second)
	}

	thread.join(t)
	thread.destroy(t)
	fmt.println("Done!")
}

process_item :: proc(_: int) {
	time.sleep(37 * time.Millisecond)
}
