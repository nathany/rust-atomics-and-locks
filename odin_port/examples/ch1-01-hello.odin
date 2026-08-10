package main

import "core:fmt"
import "core:sync"
import "core:thread"

main :: proc() {
	thread.create_and_start(f)
	thread.create_and_start(f)

	fmt.println("Hello from the main thread.")
}

f :: proc() {
	fmt.println("Hello from another thread!")

	id := sync.current_thread_id()
	fmt.println("This is my thread id:", id)
}
