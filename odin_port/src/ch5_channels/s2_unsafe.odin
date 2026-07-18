package ch5_channels

// Rust wraps the message in UnsafeCell<MaybeUninit<T>>: UnsafeCell for
// mutation through a shared reference, MaybeUninit because no message
// exists before the first send. Neither has an Odin equivalent — the
// message is a plain (zero-initialized) field, and the safety rules below
// are enforced by nothing but the comments.
Unsafe_Channel :: struct($T: typeid) {
	message: T,
	ready:   Atomic(bool),
}

// Safety: Only call this once!
unsafe_send :: proc(c: ^Unsafe_Channel($T), message: T) {
	c.message = message
	atomic_store(&c.ready, true, .Release)
}

unsafe_is_ready :: proc(c: ^Unsafe_Channel($T)) -> bool {
	return atomic_load(&c.ready, .Acquire)
}

// Safety: Only call this once,
// and only after is_ready() returns true!
unsafe_receive :: proc(c: ^Unsafe_Channel($T)) -> T {
	return c.message
}
