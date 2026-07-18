package ch5_channels

Borrowing_Channel :: struct($T: typeid) {
	message: T,
	ready:   Atomic(bool),
}

Borrowing_Sender :: struct($T: typeid) {
	channel: ^Borrowing_Channel(T),
}

Borrowing_Receiver :: struct($T: typeid) {
	channel: ^Borrowing_Channel(T),
}

// Rust's split(&mut self) exclusively borrows the channel and ties both
// halves to that borrow: the borrow checker rules out a second split or
// touching the channel while the halves live. Odin hands out plain
// pointers and checks none of that — but resetting the channel here
// mirrors `*self = Self::new()`, which is what makes repeated splits of
// the same channel sound in the Rust version.
borrowing_split :: proc(c: ^Borrowing_Channel($T)) -> (Borrowing_Sender(T), Borrowing_Receiver(T)) {
	c^ = {}
	return Borrowing_Sender(T){channel = c}, Borrowing_Receiver(T){channel = c}
}

borrowing_send :: proc(s: Borrowing_Sender($T), message: T) {
	s.channel.message = message
	atomic_store(&s.channel.ready, true, .Release)
}

borrowing_is_ready :: proc(r: Borrowing_Receiver($T)) -> bool {
	return atomic_load(&r.channel.ready, .Relaxed)
}

borrowing_receive :: proc(r: Borrowing_Receiver($T)) -> T {
	if !atomic_exchange(&r.channel.ready, false, .Acquire) {
		panic("no message available!")
	}
	return r.channel.message
}
