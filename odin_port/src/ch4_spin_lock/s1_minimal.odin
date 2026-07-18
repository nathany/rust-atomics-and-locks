package ch4_spin_lock

import "base:intrinsics"

Minimal_Spin_Lock :: struct {
	locked: Atomic(bool),
}

// Rust's `const fn new` is unnecessary: the zero value is a valid,
// unlocked spinlock.

minimal_lock :: proc(l: ^Minimal_Spin_Lock) {
	for atomic_exchange(&l.locked, true, .Acquire) {
		intrinsics.cpu_relax() // std::hint::spin_loop()
	}
}

minimal_unlock :: proc(l: ^Minimal_Spin_Lock) {
	atomic_store(&l.locked, false, .Release)
}
