package ch6_arc

import "base:intrinsics"
import "base:runtime"

Basic_Arc_Data :: struct($T: typeid) {
	ref_count: Atomic(int),
	data:      T,
	// Rust runs T's Drop impl when the last Arc goes away. Odin has no
	// destructors, so the closest equivalent is an optional callback.
	data_drop: proc(data: ^T),
	// So the last drop can free from any thread, remember the allocator
	// the Arc was created with.
	allocator: runtime.Allocator,
}

Basic_Arc :: struct($T: typeid) {
	ptr: ^Basic_Arc_Data(T),
}

basic_arc_new :: proc(data: $T, data_drop: proc(data: ^T) = nil) -> Basic_Arc(T) {
	return Basic_Arc(T) {
		ptr = new_clone(Basic_Arc_Data(T){
			ref_count = {_raw = 1},
			data = data,
			data_drop = data_drop,
			allocator = context.allocator,
		}),
	}
}

// Rust's Deref: a shared &T. Odin has one pointer type for both.
basic_arc_get :: proc(arc: Basic_Arc($T)) -> ^T {
	return &arc.ptr.data
}

basic_arc_get_mut :: proc(arc: ^Basic_Arc($T)) -> (data: ^T, ok: bool) {
	if atomic_load(&arc.ptr.ref_count, .Relaxed) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		// Safety: Nothing else can access the data, since
		// there's only one Arc, to which we have exclusive access.
		return &arc.ptr.data, true
	}
	return nil, false
}

basic_arc_clone :: proc(arc: Basic_Arc($T)) -> Basic_Arc(T) {
	if atomic_add(&arc.ptr.ref_count, 1, .Relaxed) > max(int) / 2 {
		panic("too many references") // std::process::abort()
	}
	return Basic_Arc(T){ptr = arc.ptr}
}

basic_arc_drop :: proc(arc: Basic_Arc($T)) {
	if atomic_sub(&arc.ptr.ref_count, 1, .Release) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		if arc.ptr.data_drop != nil {
			arc.ptr.data_drop(&arc.ptr.data)
		}
		free(arc.ptr, arc.ptr.allocator)
	}
}
