package ch6_arc

import "base:intrinsics"
import "base:runtime"

Arc :: struct($T: typeid) {
	ptr: ^Arc_Data(T),
}

Weak :: struct($T: typeid) {
	ptr: ^Arc_Data(T),
}

Arc_Data :: struct($T: typeid) {
	// Number of Arcs.
	data_ref_count:  Atomic(int),
	// Number of Weaks, plus one if there are any Arcs.
	alloc_ref_count: Atomic(int),
	// The data. Dropped if there are only weak pointers left.
	// (Rust wraps this in ManuallyDrop<T> to suppress the automatic
	// drop — which is Odin's default behavior for everything.)
	data:            T,
	data_drop:       proc(data: ^T),
	allocator:       runtime.Allocator,
}

arc_new :: proc(data: $T, data_drop: proc(data: ^T) = nil) -> Arc(T) {
	return Arc(T) {
		ptr = new_clone(Arc_Data(T){
			alloc_ref_count = {_raw = 1},
			data_ref_count = {_raw = 1},
			data = data,
			data_drop = data_drop,
			allocator = context.allocator,
		}),
	}
}

arc_get_mut :: proc(arc: ^Arc($T)) -> (data: ^T, ok: bool) {
	// Acquire matches weak_drop's Release decrement, to make sure any
	// upgraded pointers are visible in the next data_ref_count load.
	if _, swapped := atomic_compare_exchange(&arc.ptr.alloc_ref_count, 1, max(int), .Acquire, .Relaxed); !swapped {
		return nil, false
	}
	is_unique := atomic_load(&arc.ptr.data_ref_count, .Relaxed) == 1
	// Release matches Acquire increment in arc_downgrade, to make sure any
	// changes to the data_ref_count that come after arc_downgrade don't
	// change the is_unique result above.
	atomic_store(&arc.ptr.alloc_ref_count, 1, .Release)
	if !is_unique {
		return nil, false
	}
	// Acquire to match arc_drop's Release decrement, to make sure nothing
	// else is accessing the data.
	intrinsics.atomic_thread_fence(.Acquire)
	return &arc.ptr.data, true
}

arc_downgrade :: proc(arc: Arc($T)) -> Weak(T) {
	n := atomic_load(&arc.ptr.alloc_ref_count, .Relaxed)
	for {
		if n == max(int) {
			intrinsics.cpu_relax()
			n = atomic_load(&arc.ptr.alloc_ref_count, .Relaxed)
			continue
		}
		assert(n <= max(int) / 2)
		// Acquire synchronises with arc_get_mut's release-store.
		value, swapped := atomic_compare_exchange_weak(&arc.ptr.alloc_ref_count, n, n + 1, .Acquire, .Relaxed)
		if swapped {
			return Weak(T){ptr = arc.ptr}
		}
		n = value
	}
}

// Rust's Deref.
arc_get :: proc(arc: Arc($T)) -> ^T {
	// Safety: Since there's an Arc to the data,
	// the data exists and may be shared.
	return &arc.ptr.data
}

weak_upgrade :: proc(weak: Weak($T)) -> (arc: Arc(T), ok: bool) {
	n := atomic_load(&weak.ptr.data_ref_count, .Relaxed)
	for {
		if n == 0 {
			return {}, false
		}
		assert(n <= max(int) / 2)
		value, swapped := atomic_compare_exchange_weak(&weak.ptr.data_ref_count, n, n + 1, .Relaxed, .Relaxed)
		if swapped {
			return Arc(T){ptr = weak.ptr}, true
		}
		n = value
	}
}

weak_clone :: proc(weak: Weak($T)) -> Weak(T) {
	if atomic_add(&weak.ptr.alloc_ref_count, 1, .Relaxed) > max(int) / 2 {
		panic("too many references")
	}
	return Weak(T){ptr = weak.ptr}
}

weak_drop :: proc(weak: Weak($T)) {
	if atomic_sub(&weak.ptr.alloc_ref_count, 1, .Release) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		free(weak.ptr, weak.ptr.allocator)
	}
}

arc_clone :: proc(arc: Arc($T)) -> Arc(T) {
	if atomic_add(&arc.ptr.data_ref_count, 1, .Relaxed) > max(int) / 2 {
		panic("too many references")
	}
	return Arc(T){ptr = arc.ptr}
}

arc_drop :: proc(arc: Arc($T)) {
	if atomic_sub(&arc.ptr.data_ref_count, 1, .Release) == 1 {
		intrinsics.atomic_thread_fence(.Acquire)
		// Safety: The data reference counter is zero,
		// so nothing will access the data anymore.
		if arc.ptr.data_drop != nil {
			arc.ptr.data_drop(&arc.ptr.data)
		}
		// Now that there's no Arcs left,
		// drop the implicit weak pointer that represented all Arcs.
		weak_drop(Weak(T){ptr = arc.ptr})
	}
}
