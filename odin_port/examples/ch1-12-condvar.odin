package main

import "core:container/queue"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"

State :: struct {
	mutex:     sync.Mutex,
	queue:     queue.Queue(int),
	not_empty: sync.Cond,
}

main :: proc() {
	state: State
	queue.init(&state.queue)

	t := thread.create_and_start_with_poly_data(&state, proc(state: ^State) {
		for {
			sync.mutex_lock(&state.mutex)
			item: int
			for {
				ok: bool
				if item, ok = queue.pop_front_safe(&state.queue); ok {
					break
				}
				sync.cond_wait(&state.not_empty, &state.mutex)
			}
			sync.mutex_unlock(&state.mutex)
			fmt.println("item =", item)
		}
	})
	defer thread.destroy(t)

	for i := 0; true; i += 1 {
		sync.mutex_lock(&state.mutex)
		queue.push_back(&state.queue, i)
		sync.mutex_unlock(&state.mutex)
		sync.cond_signal(&state.not_empty)
		time.sleep(1 * time.Second)
	}
}
