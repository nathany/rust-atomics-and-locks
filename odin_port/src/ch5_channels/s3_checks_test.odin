package ch5_channels

import "core:sync"
import "core:testing"
import "core:thread"

@(test)
test_checked_channel :: proc(t: ^testing.T) {
	channel: Checked_Channel(string)
	wakeup: sync.Sema
	sender := thread.create_and_start_with_poly_data2(
		&channel,
		&wakeup,
		proc(channel: ^Checked_Channel(string), wakeup: ^sync.Sema) {
			checked_send(channel, "hello world!")
			sync.sema_post(wakeup)
		},
	)
	for !checked_is_ready(&channel) {
		sync.sema_wait(&wakeup)
	}
	testing.expect_value(t, checked_receive(&channel), "hello world!")
	thread.join(sender)
	thread.destroy(sender)
}
