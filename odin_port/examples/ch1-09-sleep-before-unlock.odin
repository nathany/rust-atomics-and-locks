package main

import "core:sync"
import "core:thread"
import "core:time"

State :: struct {
	mutex: sync.Mutex,
	n:     int,
}

main :: proc() {
	state: State

	threads: [10]^thread.Thread
	for &t in threads {
		t = thread.create_and_start_with_poly_data(&state, proc(state: ^State) {
			sync.guard(&state.mutex)
			for _ in 0 ..< 100 {
				state.n += 1
			}
			time.sleep(1 * time.Second) // New!
		})
	}
	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}
	assert(state.n == 1000)
}
