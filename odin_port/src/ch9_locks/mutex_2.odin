package ch9_locks

Mutex_2 :: struct($T: typeid) {
	// 0: unlocked
	// 1: locked, no other threads waiting
	// 2: locked, other threads waiting
	state: Atomic(u32),
	value: T,
}

Mutex_2_Guard :: struct($T: typeid) {
	mutex: ^Mutex_2(T),
}

mutex_2_get :: proc(g: Mutex_2_Guard($T)) -> ^T {
	return &g.mutex.value
}

mutex_2_lock :: proc(m: ^Mutex_2($T)) -> Mutex_2_Guard(T) {
	if _, ok := atomic_compare_exchange(&m.state, 0, 1, .Acquire, .Relaxed); !ok {
		for atomic_exchange(&m.state, 2, .Acquire) != 0 {
			wait(&m.state, 2)
		}
	}
	return Mutex_2_Guard(T){mutex = m}
}

mutex_2_unlock :: proc(g: Mutex_2_Guard($T)) {
	if atomic_exchange(&g.mutex.state, 0, .Release) == 2 {
		wake_one(&g.mutex.state)
	}
}
