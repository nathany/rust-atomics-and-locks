package ch5_channels

EMPTY: u8 : 0
WRITING: u8 : 1
READY: u8 : 2
READING: u8 : 3

Single_Atomic_Channel :: struct($T: typeid) {
	message: T,
	state:   Atomic(u8),
}

single_atomic_send :: proc(c: ^Single_Atomic_Channel($T), message: T) {
	if _, ok := atomic_compare_exchange(&c.state, EMPTY, WRITING, .Relaxed, .Relaxed); !ok {
		panic("can't send more than one message!")
	}
	c.message = message
	atomic_store(&c.state, READY, .Release)
}

single_atomic_is_ready :: proc(c: ^Single_Atomic_Channel($T)) -> bool {
	return atomic_load(&c.state, .Relaxed) == READY
}

single_atomic_receive :: proc(c: ^Single_Atomic_Channel($T)) -> T {
	if _, ok := atomic_compare_exchange(&c.state, READY, READING, .Acquire, .Relaxed); !ok {
		panic("no message available!")
	}
	return c.message
}
