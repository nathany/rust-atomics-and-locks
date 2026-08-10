package ch5_channels

import "core:container/queue"
import "core:sync"

Simple_Channel :: struct($T: typeid) {
	mutex:      sync.Mutex,
	queue:      queue.Queue(T),
	item_ready: sync.Cond,
}

// Rust's new() is unnecessary: the zero value is ready to use, and the
// queue allocates on first push.

simple_send :: proc(c: ^Simple_Channel($T), message: T) {
	sync.mutex_lock(&c.mutex)
	queue.push_back(&c.queue, message)
	sync.mutex_unlock(&c.mutex)
	sync.cond_signal(&c.item_ready)
}

simple_receive :: proc(c: ^Simple_Channel($T)) -> T {
	sync.mutex_lock(&c.mutex)
	defer sync.mutex_unlock(&c.mutex)
	for {
		if message, ok := queue.pop_front_safe(&c.queue); ok {
			return message
		}
		sync.cond_wait(&c.item_ready, &c.mutex)
	}
}
