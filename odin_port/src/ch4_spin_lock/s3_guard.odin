package ch4_spin_lock

import "base:intrinsics"

Spin_Lock :: struct($T: typeid) {
	locked: Atomic(bool),
	value:  T,
}

Guard :: struct($T: typeid) {
	lock: ^Spin_Lock(T),
}

lock :: proc(l: ^Spin_Lock($T)) -> Guard(T) {
	for atomic_exchange(&l.locked, true, .Acquire) {
		intrinsics.cpu_relax()
	}
	return Guard(T){lock = l}
}

// Deref/DerefMut: the very existence of this Guard guarantees we've
// exclusively locked the lock. (Unlike Rust, nothing stops you from
// keeping this pointer around after unlocking.)
guard_value :: proc(g: Guard($T)) -> ^T {
	return &g.lock.value
}

// Rust unlocks in the Guard's Drop implementation. Odin has no
// destructors, and its scope-based substitute is off the table too:
// @(deferred_out=unlock) is not allowed on polymorphic procedures.
// (core:sync's guard() gets away with it because Mutex isn't generic.)
// So unlocking is explicit: call unlock(g), or `defer unlock(g)` at the
// call site.
unlock :: proc(g: Guard($T)) {
	atomic_store(&g.lock.locked, false, .Release)
}
