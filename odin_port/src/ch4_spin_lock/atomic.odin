package ch4_spin_lock

import "base:intrinsics"

Ordering :: intrinsics.Atomic_Memory_Order

// A Rust-style atomic type: the wrapper marks which variables are shared
// and makes non-atomic access a visible convention violation, since Odin
// itself allows any access to any variable.
Atomic :: struct($T: typeid) {
	_raw: T, // Only access through the atomic_* procs below.
}

atomic_load :: proc(a: ^Atomic($T), $order: Ordering) -> T {
	return intrinsics.atomic_load_explicit(&a._raw, order)
}

atomic_store :: proc(a: ^Atomic($T), value: T, $order: Ordering) {
	intrinsics.atomic_store_explicit(&a._raw, value, order)
}

atomic_exchange :: proc(a: ^Atomic($T), value: T, $order: Ordering) -> T {
	return intrinsics.atomic_exchange_explicit(&a._raw, value, order)
}
