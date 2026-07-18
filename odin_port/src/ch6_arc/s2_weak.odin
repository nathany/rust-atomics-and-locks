package ch6_arc

import "base:intrinsics"
import "base:runtime"

Simple_Arc_Data :: struct($T: typeid) {
	// Number of Arcs.
	data_ref_count:  Atomic(int),
	// Number of Arcs and Weaks combined.
	alloc_ref_count: Atomic(int),
	// The data. nil if there's only weak pointers left.
	// (Rust: UnsafeCell<Option<T>> — Maybe is Odin's Option.)
	data:            Maybe(T),
	data_drop:       proc(data: ^T),
	allocator:       runtime.Allocator,
}

Simple_Arc :: struct($T: typeid) {
	weak: Simple_Weak(T),
}

Simple_Weak :: struct($T: typeid) {
	ptr: ^Simple_Arc_Data(T),
}

simple_arc_new :: proc(data: $T, data_drop: proc(data: ^T) = nil) -> Simple_Arc(T) {
	return Simple_Arc(T) {
		weak = {
			ptr = new_clone(Simple_Arc_Data(T){
				alloc_ref_count = {_raw = 1},
				data_ref_count = {_raw = 1},
				data = data,
				data_drop = data_drop,
				allocator = context.allocator,
			}),
		},
	}
}

simple_arc_get_mut :: proc(arc: ^Simple_Arc($T)) -> (data: ^T, ok: bool) {
	if atomic_load(&arc.weak.ptr.alloc_ref_count, .Relaxed) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		// Safety: Nothing else can access the data, since
		// there's only one Arc, to which we have exclusive access,
		// and no Weak pointers.
		// We know the data is still available since we
		// have an Arc to it, so this won't panic.
		return &arc.weak.ptr.data.(T), true
	}
	return nil, false
}

simple_arc_downgrade :: proc(arc: Simple_Arc($T)) -> Simple_Weak(T) {
	return simple_weak_clone(arc.weak)
}

simple_weak_upgrade :: proc(weak: Simple_Weak($T)) -> (arc: Simple_Arc(T), ok: bool) {
	n := atomic_load(&weak.ptr.data_ref_count, .Relaxed)
	for {
		if n == 0 {
			return {}, false
		}
		assert(n <= max(int) / 2)
		value, swapped := atomic_compare_exchange_weak(&weak.ptr.data_ref_count, n, n + 1, .Relaxed, .Relaxed)
		if swapped {
			return Simple_Arc(T){weak = simple_weak_clone(weak)}, true
		}
		n = value
	}
}

// Rust's Deref: the unwrap can't fail while an Arc exists.
simple_arc_get :: proc(arc: Simple_Arc($T)) -> ^T {
	// Safety: Since there's an Arc to the data,
	// the data exists and may be shared.
	return &arc.weak.ptr.data.(T)
}

simple_weak_clone :: proc(weak: Simple_Weak($T)) -> Simple_Weak(T) {
	if atomic_add(&weak.ptr.alloc_ref_count, 1, .Relaxed) > max(int) / 2 {
		panic("too many references")
	}
	return Simple_Weak(T){ptr = weak.ptr}
}

simple_arc_clone :: proc(arc: Simple_Arc($T)) -> Simple_Arc(T) {
	weak := simple_weak_clone(arc.weak)
	if atomic_add(&weak.ptr.data_ref_count, 1, .Relaxed) > max(int) / 2 {
		panic("too many references")
	}
	return Simple_Arc(T){weak = weak}
}

simple_weak_drop :: proc(weak: Simple_Weak($T)) {
	if atomic_sub(&weak.ptr.alloc_ref_count, 1, .Release) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		free(weak.ptr, weak.ptr.allocator)
	}
}

simple_arc_drop :: proc(arc: Simple_Arc($T)) {
	if atomic_sub(&arc.weak.ptr.data_ref_count, 1, .Release) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		// Safety: The data reference counter is zero,
		// so nothing will access it.
		if arc.weak.ptr.data_drop != nil {
			arc.weak.ptr.data_drop(&arc.weak.ptr.data.(T))
		}
		arc.weak.ptr.data = nil
	}
	// In Rust, the Arc's inner Weak field is dropped implicitly after
	// Arc::drop runs. Explicit here:
	simple_weak_drop(arc.weak)
}
