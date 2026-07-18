package ch9_locks

// Uses the final mutex (mutex_3), as Rust's condvar_1 uses super::mutex_3.

Condvar_1 :: struct {
	counter: Atomic(u32),
}

condvar_1_notify_one :: proc(cv: ^Condvar_1) {
	atomic_add(&cv.counter, 1, .Relaxed)
	wake_one(&cv.counter)
}

condvar_1_notify_all :: proc(cv: ^Condvar_1) {
	atomic_add(&cv.counter, 1, .Relaxed)
	wake_all(&cv.counter)
}

condvar_1_wait :: proc(cv: ^Condvar_1, guard: Mutex_Guard($T)) -> Mutex_Guard(T) {
	counter_value := atomic_load(&cv.counter, .Relaxed)

	// Unlock the mutex (Rust: by dropping the guard),
	// but remember the mutex so we can lock it again later.
	mutex := guard.mutex
	unlock(guard)

	// Wait, but only if the counter hasn't changed since unlocking.
	wait(&cv.counter, counter_value)

	return lock(mutex)
}
