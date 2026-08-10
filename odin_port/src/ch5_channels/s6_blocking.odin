package ch5_channels

import "core:sync"

Channel :: struct($T: typeid) {
	message:         T,
	ready:           Atomic(bool),
	receiver_wakeup: sync.Sema, // New! (see note on Sender below)
}

// Rust's Sender captures the receiving thread's handle at split time so
// send() can unpark it, and Receiver is !Send (PhantomData<*const ()>) to
// pin receive() to that thread. With a semaphore in the channel, the
// sender doesn't need to know the receiver's thread at all, so neither
// the handle nor the (inexpressible in Odin) !Send restriction is needed.
Sender :: struct($T: typeid) {
	channel: ^Channel(T),
}

Receiver :: struct($T: typeid) {
	channel: ^Channel(T),
}

split :: proc(c: ^Channel($T)) -> (Sender(T), Receiver(T)) {
	c^ = {}
	return Sender(T){channel = c}, Receiver(T){channel = c}
}

send :: proc(s: Sender($T), message: T) {
	s.channel.message = message
	atomic_store(&s.channel.ready, true, .Release)
	sync.sema_post(&s.channel.receiver_wakeup) // New!
}

receive :: proc(r: Receiver($T)) -> T {
	for !atomic_exchange(&r.channel.ready, false, .Acquire) {
		sync.sema_wait(&r.channel.receiver_wakeup)
	}
	return r.channel.message
}
