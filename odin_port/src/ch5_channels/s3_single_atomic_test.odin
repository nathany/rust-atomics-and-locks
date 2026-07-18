package ch5_channels

import "core:sync"
import "core:testing"
import "core:thread"

@(test)
test_single_atomic_channel :: proc(t: ^testing.T) {
	channel: Single_Atomic_Channel(string)
	wakeup: sync.Sema
	sender := thread.create_and_start_with_poly_data2(
		&channel,
		&wakeup,
		proc(channel: ^Single_Atomic_Channel(string), wakeup: ^sync.Sema) {
			single_atomic_send(channel, "hello world!")
			sync.sema_post(wakeup)
		},
	)
	for !single_atomic_is_ready(&channel) {
		sync.sema_wait(&wakeup)
	}
	testing.expect_value(t, single_atomic_receive(&channel), "hello world!")
	thread.join(sender)
	thread.destroy(sender)
}
