package ch9_locks

Condvar :: struct {
	counter:     Atomic(u32),
	num_waiters: Atomic(int), // Rust: AtomicUsize
}

notify_one :: proc(cv: ^Condvar) {
	if atomic_load(&cv.num_waiters, .Relaxed) > 0 {
		atomic_add(&cv.counter, 1, .Relaxed)
		wake_one(&cv.counter)
	}
}

notify_all :: proc(cv: ^Condvar) {
	if atomic_load(&cv.num_waiters, .Relaxed) > 0 {
		atomic_add(&cv.counter, 1, .Relaxed)
		wake_all(&cv.counter)
	}
}

// Named condvar_wait because the futex shim already claims `wait`.
condvar_wait :: proc(cv: ^Condvar, guard: Mutex_Guard($T)) -> Mutex_Guard(T) {
	atomic_add(&cv.num_waiters, 1, .Relaxed)

	counter_value := atomic_load(&cv.counter, .Relaxed)

	mutex := guard.mutex
	unlock(guard)

	wait(&cv.counter, counter_value)

	atomic_sub(&cv.num_waiters, 1, .Relaxed)

	return lock(mutex)
}
