package main

import "core:fmt"
import "core:sync"
import "core:thread"

main :: proc() {
	t1 := thread.create_and_start(f)
	t2 := thread.create_and_start(f)

	fmt.println("Hello from the main thread.")

	thread.join(t1)
	thread.join(t2)
	thread.destroy(t1)
	thread.destroy(t2)
}

f :: proc() {
	fmt.println("Hello from another thread!")

	id := sync.current_thread_id()
	fmt.println("This is my thread id:", id)
}
