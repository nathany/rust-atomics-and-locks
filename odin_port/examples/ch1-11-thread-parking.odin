package main

import "core:container/queue"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

// Odin has no thread parking. A semaphore is the closest primitive:
// sema_wait is like park, and sema_post is like unpark — except that a
// semaphore counts posts, whereas unpark requests don't stack up.
State :: struct {
	mutex: sync.Mutex,
	queue: queue.Queue(int),
	ready: sync.Sema,
}

main :: proc() {
	state: State
	queue.init(&state.queue)

	// Consuming thread
	t := thread.create_and_start_with_poly_data(&state, proc(state: ^State) {
		for {
			sync.mutex_lock(&state.mutex)
			item, ok := queue.pop_front_safe(&state.queue)
			sync.mutex_unlock(&state.mutex)
			if ok {
				fmt.println("item =", item)
			} else {
				sync.sema_wait(&state.ready)
			}
		}
	})
	defer thread.destroy(t)

	// Producing thread
	for i := 0; true; i += 1 {
		sync.mutex_lock(&state.mutex)
		queue.push_back(&state.queue, i)
		sync.mutex_unlock(&state.mutex)
		sync.sema_post(&state.ready)
		time.sleep(1 * time.Second)
	}
}
