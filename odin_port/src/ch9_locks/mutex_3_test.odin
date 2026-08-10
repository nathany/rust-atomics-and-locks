package ch9_locks

import "core:fmt"
import "core:testing"
import "core:thread"
import "core:time"

@(test)
test_mutex_3 :: proc(t: ^testing.T) {
	m: Mutex(int)
	start := time.tick_now()
	for _ in 0 ..< 5_000_000 {
		g := lock(&m)
		mutex_get(g)^ += 1
		unlock(g)
	}
	duration := time.tick_since(start)
	g := lock(&m)
	fmt.printfln("locked %d times in %.0f ms", mutex_get(g)^, time.duration_milliseconds(duration))
	testing.expect_value(t, mutex_get(g)^, 5_000_000)
	unlock(g)
}

@(test)
test_mutex_3_contended :: proc(t: ^testing.T) {
	m: Mutex(int)
	start := time.tick_now()
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&m, proc(m: ^Mutex(int)) {
			for _ in 0 ..< 5_000_000 {
				g := lock(m)
				mutex_get(g)^ += 1
				unlock(g)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	duration := time.tick_since(start)
	g := lock(&m)
	fmt.printfln("locked %d times in %.0f ms", mutex_get(g)^, time.duration_milliseconds(duration))
	testing.expect_value(t, mutex_get(g)^, 20_000_000)
	unlock(g)
}
