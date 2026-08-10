package ch5_channels

import "core:sync"
import "core:testing"
import "core:thread"

@(test)
test_owned_channel :: proc(t: ^testing.T) {
	sender, receiver := owned_channel(string)
	defer free(receiver.channel)
	wakeup: sync.Sema
	sender_thread := thread.create_and_start_with_poly_data2(
		sender,
		&wakeup,
		proc(sender: Owned_Sender(string), wakeup: ^sync.Sema) {
			owned_send(sender, "hello world!")
			sync.sema_post(wakeup)
		},
	)
	for !owned_is_ready(receiver) {
		sync.sema_wait(&wakeup)
	}
	testing.expect_value(t, owned_receive(receiver), "hello world!")
	thread.join(sender_thread)
	thread.destroy(sender_thread)
}
