package ch5_channels

// Rust shares ownership of the Channel between the two halves with an Arc
// (which we build ourselves in ch6); the channel is freed when the last
// half is dropped. Odin has no reference counting, so owned_channel()
// heap-allocates and the caller frees the channel (via either half's
// `channel` field) once both halves are done with it.
Owned_Sender :: struct($T: typeid) {
	channel: ^Owned_Channel(T),
}

Owned_Receiver :: struct($T: typeid) {
	channel: ^Owned_Channel(T),
}

Owned_Channel :: struct($T: typeid) {
	message: T,
	ready:   Atomic(bool),
}

owned_channel :: proc($T: typeid) -> (Owned_Sender(T), Owned_Receiver(T)) {
	a := new(Owned_Channel(T))
	return Owned_Sender(T){channel = a}, Owned_Receiver(T){channel = a}
}

// Rust's send(self, ...) consumes the Sender by value, making a second
// send a compile error. Odin has no move-only types: the Sender is passed
// by value here to mirror the API shape, but nothing prevents reuse.
owned_send :: proc(s: Owned_Sender($T), message: T) {
	s.channel.message = message
	atomic_store(&s.channel.ready, true, .Release)
}

owned_is_ready :: proc(r: Owned_Receiver($T)) -> bool {
	return atomic_load(&r.channel.ready, .Relaxed)
}

owned_receive :: proc(r: Owned_Receiver($T)) -> T {
	if !atomic_exchange(&r.channel.ready, false, .Acquire) {
		panic("no message available!")
	}
	return r.channel.message
}
