package ch4_spin_lock

import "base:intrinsics"

// Rust wraps the value in UnsafeCell to allow mutation through a shared
// reference, and the `unsafe impl Sync` promises this is sound. Odin has
// neither concept: the value is a plain field, and nothing checks what may
// be shared between threads.
Unsafe_Spin_Lock :: struct($T: typeid) {
	locked: Atomic(bool),
	value:  T,
}

unsafe_lock :: proc(l: ^Unsafe_Spin_Lock($T)) -> ^T {
	for atomic_exchange(&l.locked, true, .Acquire) {
		intrinsics.cpu_relax()
	}
	return &l.value
}

// Safety: The ^T from unsafe_lock() must be gone!
// (And no cheating by keeping pointers to fields of that T around!)
unsafe_unlock :: proc(l: ^Unsafe_Spin_Lock($T)) {
	atomic_store(&l.locked, false, .Release)
}
