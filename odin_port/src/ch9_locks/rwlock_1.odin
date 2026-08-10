package ch9_locks

RW_Lock_1 :: struct($T: typeid) {
	// The number of readers, or max(u32) if write-locked.
	state: Atomic(u32),
	value: T,
}

Read_Guard_1 :: struct($T: typeid) {
	rwlock: ^RW_Lock_1(T),
}

Write_Guard_1 :: struct($T: typeid) {
	rwlock: ^RW_Lock_1(T),
}

rwlock_1_read_get :: proc(g: Read_Guard_1($T)) -> ^T {
	return &g.rwlock.value
}

rwlock_1_write_get :: proc(g: Write_Guard_1($T)) -> ^T {
	return &g.rwlock.value
}

rwlock_1_read :: proc(l: ^RW_Lock_1($T)) -> Read_Guard_1(T) {
	s := atomic_load(&l.state, .Relaxed)
	for {
		if s < max(u32) {
			assert(s < max(u32) - 1, "too many readers")
			value, ok := atomic_compare_exchange_weak(&l.state, s, s + 1, .Acquire, .Relaxed)
			if ok {
				return Read_Guard_1(T){rwlock = l}
			}
			s = value
		}
		if s == max(u32) {
			wait(&l.state, max(u32))
			s = atomic_load(&l.state, .Relaxed)
		}
	}
}

rwlock_1_write :: proc(l: ^RW_Lock_1($T)) -> Write_Guard_1(T) {
	for {
		s, ok := atomic_compare_exchange(&l.state, 0, max(u32), .Acquire, .Relaxed)
		if ok {
			return Write_Guard_1(T){rwlock = l}
		}
		// Wait while already locked.
		wait(&l.state, s)
	}
}

rwlock_1_read_unlock :: proc(g: Read_Guard_1($T)) {
	if atomic_sub(&g.rwlock.state, 1, .Release) == 1 {
		// Wake up a waiting writer, if any.
		wake_one(&g.rwlock.state)
	}
}

rwlock_1_write_unlock :: proc(g: Write_Guard_1($T)) {
	atomic_store(&g.rwlock.state, 0, .Release)
	// Wake up all waiting readers and writers.
	wake_all(&g.rwlock.state)
}
