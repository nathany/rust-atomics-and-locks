package ch9_locks

import "base:intrinsics"

Mutex :: struct($T: typeid) {
	// 0: unlocked
	// 1: locked, no other threads waiting
	// 2: locked, other threads waiting
	state: Atomic(u32),
	value: T,
}

Mutex_Guard :: struct($T: typeid) {
	mutex: ^Mutex(T),
}

mutex_get :: proc(g: Mutex_Guard($T)) -> ^T {
	return &g.mutex.value
}

lock :: proc(m: ^Mutex($T)) -> Mutex_Guard(T) {
	if _, ok := atomic_compare_exchange(&m.state, 0, 1, .Acquire, .Relaxed); !ok {
		// The lock was already locked. :(
		lock_contended(&m.state)
	}
	return Mutex_Guard(T){mutex = m}
}

lock_contended :: proc(state: ^Atomic(u32)) {
	spin_count := 0

	for atomic_load(state, .Relaxed) == 1 && spin_count < 100 {
		spin_count += 1
		intrinsics.cpu_relax()
	}

	if _, ok := atomic_compare_exchange(state, 0, 1, .Acquire, .Relaxed); ok {
		return
	}

	for atomic_exchange(state, 2, .Acquire) != 0 {
		wait(state, 2)
	}
}

unlock :: proc(g: Mutex_Guard($T)) {
	if atomic_exchange(&g.mutex.state, 0, .Release) == 2 {
		wake_one(&g.mutex.state)
	}
}
