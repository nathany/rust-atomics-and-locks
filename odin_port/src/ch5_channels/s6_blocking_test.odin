package ch5_channels

import "core:testing"
import "core:thread"

@(test)
test_blocking_channel :: proc(t: ^testing.T) {
	channel: Channel(string)
	sender, receiver := split(&channel)
	sender_thread := thread.create_and_start_with_poly_data(
		sender,
		proc(sender: Sender(string)) {
			send(sender, "hello world!")
		},
	)
	testing.expect_value(t, receive(receiver), "hello world!")
	thread.join(sender_thread)
	thread.destroy(sender_thread)
}
