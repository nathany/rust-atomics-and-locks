package ch5_channels

Checked_Channel :: struct($T: typeid) {
	message: T,
	in_use:  Atomic(bool),
	ready:   Atomic(bool),
}

// Panics when trying to send more than one message.
checked_send :: proc(c: ^Checked_Channel($T), message: T) {
	if atomic_exchange(&c.in_use, true, .Relaxed) {
		panic("can't send more than one message!")
	}
	c.message = message
	atomic_store(&c.ready, true, .Release)
}

checked_is_ready :: proc(c: ^Checked_Channel($T)) -> bool {
	return atomic_load(&c.ready, .Relaxed)
}

// Panics if no message is available yet,
// or if the message was already consumed.
//
// Tip: Use checked_is_ready to check first.
checked_receive :: proc(c: ^Checked_Channel($T)) -> T {
	if !atomic_exchange(&c.ready, false, .Acquire) {
		panic("no message available!")
	}
	// Safety: We've just checked (and reset) the ready flag.
	return c.message
}

// Rust's Drop impl drops an unreceived message. Odin has no destructors
// (and no Drop for T either), so if an unreceived message owns resources,
// cleaning them up is the channel owner's responsibility.
