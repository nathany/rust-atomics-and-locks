package main

import "base:intrinsics"
import "core:bufio"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:time"

// Odin has no atomic types: any integer or boolean can be accessed
// atomically through the intrinsics. Rust's function-local `static`
// becomes a file-scope global here, since both threads need to see it.
stop: bool

main :: proc() {
	// Spawn a thread to do the work.
	background_thread := thread.create_and_start(proc() {
		for !intrinsics.atomic_load_explicit(&stop, .Relaxed) {
			some_work()
		}
	})

	// Use the main thread to listen for user input.
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_stream(os.stdin))
	input: for bufio.scanner_scan(&scanner) {
		switch cmd := bufio.scanner_text(&scanner); cmd {
		case "help":
			fmt.println("commands: help, stop")
		case "stop":
			break input
		case:
			fmt.printfln("unknown command: %q", cmd)
		}
	}

	// Inform the background thread it needs to stop.
	intrinsics.atomic_store_explicit(&stop, true, .Relaxed)

	// Wait until the background thread finishes.
	thread.join(background_thread)
	thread.destroy(background_thread)
}

some_work :: proc() {
	time.sleep(100 * time.Millisecond)
}
