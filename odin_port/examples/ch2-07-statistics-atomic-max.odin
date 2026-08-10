package main

// VARIANT — does NOT compile on stock Odin (as of dev-2026-07 / master).
//
// This is ch2-07-statistics.odin rewritten to use a native `atomic_max`
// intrinsic instead of the compare-exchange loop workaround. It is kept as a
// target for when upstream lands atomic max/min:
//
//     odin-lang/Odin#7079  (see ISSUE_atomic_max_min.md)
//
// Building today fails at the `atomic_max_explicit` call with an
// "unknown procedure" / invalid-intrinsic error, because base:intrinsics does
// not (yet) expose atomic_max. Once #7079 lands, this replaces the runnable
// ch2-07-statistics.odin. The workaround version stays there until then.
//
// Note `state.max_time` is u64 (unsigned), so this exercises the `umax`
// lowering (atomicrmw umax) rather than signed `max`.

import "base:intrinsics"
import "core:fmt"
import "core:thread"
import "core:time"

State :: struct {
	num_done:   int,
	total_time: u64, // in microseconds
	max_time:   u64, // in microseconds
}

main :: proc() {
	state: State

	// Four background threads to process all 100 items, 25 each.
	threads: [4]^thread.Thread
	for &bt, t in threads {
		bt = thread.create_and_start_with_poly_data2(t, &state, proc(t: int, state: ^State) {
			for i in 0 ..< 25 {
				start := time.tick_now()
				process_item(t * 25 + i) // Assuming this takes some time.
				time_taken := u64(time.duration_microseconds(time.tick_since(start)))
				intrinsics.atomic_add_explicit(&state.num_done, 1, .Relaxed)
				intrinsics.atomic_add_explicit(&state.total_time, time_taken, .Relaxed)
				// The whole point of the variant: one intrinsic, no CAS loop.
				intrinsics.atomic_max_explicit(&state.max_time, time_taken, .Relaxed)
			}
		})
	}

	// The main thread shows status updates, every second.
	for {
		total_time := time.Duration(intrinsics.atomic_load_explicit(&state.total_time, .Relaxed)) * time.Microsecond
		max_time := time.Duration(intrinsics.atomic_load_explicit(&state.max_time, .Relaxed)) * time.Microsecond
		n := intrinsics.atomic_load_explicit(&state.num_done, .Relaxed)
		if n == 100 do break
		if n == 0 {
			fmt.println("Working.. nothing done yet.")
		} else {
			fmt.printfln(
				"Working.. %d/100 done, %.1f ms average, %.1f ms peak",
				n,
				time.duration_milliseconds(total_time / time.Duration(n)),
				time.duration_milliseconds(max_time),
			)
		}
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
