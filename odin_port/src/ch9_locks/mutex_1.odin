package ch9_locks

Mutex_1 :: struct($T: typeid) {
	// 0: unlocked
	// 1: locked
	state: Atomic(u32),
	value: T,
}

Mutex_1_Guard :: struct($T: typeid) {
	mutex: ^Mutex_1(T),
}

// Rust's Deref/DerefMut.
mutex_1_get :: proc(g: Mutex_1_Guard($T)) -> ^T {
	return &g.mutex.value
}

mutex_1_lock :: proc(m: ^Mutex_1($T)) -> Mutex_1_Guard(T) {
	// Set the state to 1: locked.
	for atomic_exchange(&m.state, 1, .Acquire) == 1 {
		// If it was already locked..
		// .. wait, unless the state is no longer 1.
		wait(&m.state, 1)
	}
	return Mutex_1_Guard(T){mutex = m}
}

// Rust: MutexGuard's Drop impl.
mutex_1_unlock :: proc(g: Mutex_1_Guard($T)) {
	// Set the state back to 0: unlocked.
	atomic_store(&g.mutex.state, 0, .Release)
	// Wake up one of the waiting threads, if any.
	wake_one(&g.mutex.state)
}
