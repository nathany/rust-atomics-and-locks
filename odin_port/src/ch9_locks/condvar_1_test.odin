package ch9_locks

import "core:testing"
import "core:thread"
import "core:time"

@(test)
test_condvar_1 :: proc(t: ^testing.T) {
	mutex: Mutex(int)
	condvar: Condvar_1

	wakeups := 0

	th := thread.create_and_start_with_poly_data2(
		&mutex,
		&condvar,
		proc(mutex: ^Mutex(int), condvar: ^Condvar_1) {
			time.sleep(1 * time.Second)
			g := lock(mutex)
			mutex_get(g)^ = 123
			unlock(g)
			condvar_1_notify_one(condvar)
		},
	)

	m := lock(&mutex)
	for mutex_get(m)^ < 100 {
		m = condvar_1_wait(&condvar, m)
		wakeups += 1
	}

	testing.expect_value(t, mutex_get(m)^, 123)
	unlock(m)

	thread.join(th)
	thread.destroy(th)

	// Check that the main thread actually did wait (not busy-loop),
	// while still allowing for a few spurious wake ups.
	testing.expect(t, wakeups < 10)
}
