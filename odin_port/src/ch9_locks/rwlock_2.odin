package ch9_locks

RW_Lock_2 :: struct($T: typeid) {
	// The number of readers, or max(u32) if write-locked.
	state:               Atomic(u32),
	// Incremented to wake up writers.
	writer_wake_counter: Atomic(u32),
	value:               T,
}

Read_Guard_2 :: struct($T: typeid) {
	rwlock: ^RW_Lock_2(T),
}

Write_Guard_2 :: struct($T: typeid) {
	rwlock: ^RW_Lock_2(T),
}

rwlock_2_read_get :: proc(g: Read_Guard_2($T)) -> ^T {
	return &g.rwlock.value
}

rwlock_2_write_get :: proc(g: Write_Guard_2($T)) -> ^T {
	return &g.rwlock.value
}

rwlock_2_read :: proc(l: ^RW_Lock_2($T)) -> Read_Guard_2(T) {
	s := atomic_load(&l.state, .Relaxed)
	for {
		if s < max(u32) {
			assert(s < max(u32) - 1, "too many readers")
			value, ok := atomic_compare_exchange_weak(&l.state, s, s + 1, .Acquire, .Relaxed)
			if ok {
				return Read_Guard_2(T){rwlock = l}
			}
			s = value
		}
		if s == max(u32) {
			wait(&l.state, max(u32))
			s = atomic_load(&l.state, .Relaxed)
		}
	}
}

rwlock_2_write :: proc(l: ^RW_Lock_2($T)) -> Write_Guard_2(T) {
	for {
		if _, ok := atomic_compare_exchange(&l.state, 0, max(u32), .Acquire, .Relaxed); ok {
			return Write_Guard_2(T){rwlock = l}
		}
		w := atomic_load(&l.writer_wake_counter, .Acquire)
		if atomic_load(&l.state, .Relaxed) != 0 {
			// Wait if the RwLock is still locked, but only if
			// there have been no wake signals since we checked.
			wait(&l.writer_wake_counter, w)
		}
	}
}

rwlock_2_read_unlock :: proc(g: Read_Guard_2($T)) {
	if atomic_sub(&g.rwlock.state, 1, .Release) == 1 {
		atomic_add(&g.rwlock.writer_wake_counter, 1, .Release) // New!
		wake_one(&g.rwlock.writer_wake_counter) // Changed!
	}
}

rwlock_2_write_unlock :: proc(g: Write_Guard_2($T)) {
	atomic_store(&g.rwlock.state, 0, .Release)
	atomic_add(&g.rwlock.writer_wake_counter, 1, .Release) // New!
	wake_one(&g.rwlock.writer_wake_counter) // New!
	wake_all(&g.rwlock.state)
}
