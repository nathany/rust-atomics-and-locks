package ch9_locks

import "base:intrinsics"

Ordering :: intrinsics.Atomic_Memory_Order

// A Rust-style atomic type: the wrapper marks which variables are shared
// and makes non-atomic access a visible convention violation, since Odin
// itself allows any access to any variable. (Duplicated per chapter to
// keep each chapter package standalone.)
Atomic :: struct($T: typeid) {
	_raw: T, // Only access through the atomic_* procs below.
}

atomic_load :: proc(a: ^Atomic($T), $order: Ordering) -> T {
	return intrinsics.atomic_load_explicit(&a._raw, order)
}

atomic_store :: proc(a: ^Atomic($T), value: T, $order: Ordering) {
	intrinsics.atomic_store_explicit(&a._raw, value, order)
}

atomic_add :: proc(a: ^Atomic($T), value: T, $order: Ordering) -> T {
	return intrinsics.atomic_add_explicit(&a._raw, value, order)
}

atomic_sub :: proc(a: ^Atomic($T), value: T, $order: Ordering) -> T {
	return intrinsics.atomic_sub_explicit(&a._raw, value, order)
}

atomic_exchange :: proc(a: ^Atomic($T), value: T, $order: Ordering) -> T {
	return intrinsics.atomic_exchange_explicit(&a._raw, value, order)
}

atomic_compare_exchange :: proc(
	a: ^Atomic($T),
	expected, desired: T,
	$success, $failure: Ordering,
) -> (
	old: T,
	ok: bool,
) {
	return intrinsics.atomic_compare_exchange_strong_explicit(&a._raw, expected, desired, success, failure)
}

atomic_compare_exchange_weak :: proc(
	a: ^Atomic($T),
	expected, desired: T,
	$success, $failure: Ordering,
) -> (
	old: T,
	ok: bool,
) {
	return intrinsics.atomic_compare_exchange_weak_explicit(&a._raw, expected, desired, success, failure)
}
