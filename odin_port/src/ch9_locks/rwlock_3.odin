package ch9_locks

RW_Lock :: struct($T: typeid) {
	// The number of read locks times two, plus one if there's a writer
	// waiting. max(u32) if write locked.
	//
	// This means that readers may acquire the lock when
	// the state is even, but need to block when odd.
	state:               Atomic(u32),
	// Incremented to wake up writers.
	writer_wake_counter: Atomic(u32),
	value:               T,
}

Read_Guard :: struct($T: typeid) {
	rwlock: ^RW_Lock(T),
}

Write_Guard :: struct($T: typeid) {
	rwlock: ^RW_Lock(T),
}

read_get :: proc(g: Read_Guard($T)) -> ^T {
	return &g.rwlock.value
}

write_get :: proc(g: Write_Guard($T)) -> ^T {
	return &g.rwlock.value
}

read :: proc(l: ^RW_Lock($T)) -> Read_Guard(T) {
	s := atomic_load(&l.state, .Relaxed)
	for {
		if s % 2 == 0 { // Even.
			assert(s < max(u32) - 2, "too many readers")
			value, ok := atomic_compare_exchange_weak(&l.state, s, s + 2, .Acquire, .Relaxed)
			if ok {
				return Read_Guard(T){rwlock = l}
			}
			s = value
		}
		if s % 2 == 1 { // Odd.
			wait(&l.state, s)
			s = atomic_load(&l.state, .Relaxed)
		}
	}
}

write :: proc(l: ^RW_Lock($T)) -> Write_Guard(T) {
	s := atomic_load(&l.state, .Relaxed)
	for {
		// Try to lock if unlocked.
		if s <= 1 {
			value, ok := atomic_compare_exchange(&l.state, s, max(u32), .Acquire, .Relaxed)
			if ok {
				return Write_Guard(T){rwlock = l}
			}
			s = value
			continue
		}
		// Block new readers, by making sure the state is odd.
		if s % 2 == 0 {
			value, ok := atomic_compare_exchange(&l.state, s, s + 1, .Relaxed, .Relaxed)
			if !ok {
				s = value
				continue
			}
		}
		// Wait, if it's still locked
		w := atomic_load(&l.writer_wake_counter, .Acquire)
		s = atomic_load(&l.state, .Relaxed)
		if s >= 2 {
			wait(&l.writer_wake_counter, w)
			s = atomic_load(&l.state, .Relaxed)
		}
	}
}

read_unlock :: proc(g: Read_Guard($T)) {
	// Decrement the state by 2 to remove one read-lock.
	if atomic_sub(&g.rwlock.state, 2, .Release) == 3 {
		// If we decremented from 3 to 1, that means
		// the RwLock is now unlocked _and_ there is
		// a waiting writer, which we wake up.
		atomic_add(&g.rwlock.writer_wake_counter, 1, .Release)
		wake_one(&g.rwlock.writer_wake_counter)
	}
}

write_unlock :: proc(g: Write_Guard($T)) {
	atomic_store(&g.rwlock.state, 0, .Release)
	atomic_add(&g.rwlock.writer_wake_counter, 1, .Release)
	wake_one(&g.rwlock.writer_wake_counter)
	wake_all(&g.rwlock.state)
}
