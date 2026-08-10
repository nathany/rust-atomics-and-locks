package ch5_channels

import "core:sync"
import "core:testing"
import "core:thread"

@(test)
test_borrowing_channel :: proc(t: ^testing.T) {
	channel: Borrowing_Channel(string)
	sender, receiver := borrowing_split(&channel)
	wakeup: sync.Sema
	sender_thread := thread.create_and_start_with_poly_data2(
		sender,
		&wakeup,
		proc(sender: Borrowing_Sender(string), wakeup: ^sync.Sema) {
			borrowing_send(sender, "hello world!")
			sync.sema_post(wakeup)
		},
	)
	for !borrowing_is_ready(receiver) {
		sync.sema_wait(&wakeup)
	}
	testing.expect_value(t, borrowing_receive(receiver), "hello world!")
	thread.join(sender_thread)
	thread.destroy(sender_thread)
}
