package main

import "base:intrinsics"
import "core:fmt"
import "core:thread"
import "core:time"

main :: proc() {
	num_done := 0

	// Four background threads to process all 100 items, 25 each.
	threads: [4]^thread.Thread
	for &bt, t in threads {
		bt = thread.create_and_start_with_poly_data2(t, &num_done, proc(t: int, num_done: ^int) {
			for i in 0 ..< 25 {
				process_item(t * 25 + i) // Assuming this takes some time.
				intrinsics.atomic_add_explicit(num_done, 1, .Relaxed)
			}
		})
	}

	// The main thread shows status updates, every second.
	for {
		n := intrinsics.atomic_load_explicit(&num_done, .Relaxed)
		if n == 100 do break
		fmt.printfln("Working.. %d/100 done", n)
		time.sleep(1 * time.Second)
	}

	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}
	fmt.println("Done!")
}

process_item :: proc(_: int) {
	time.sleep(123 * time.Millisecond)
}
