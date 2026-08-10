package main

import "base:intrinsics"
import "core:thread"

A: bool
B: bool

S: [dynamic]u8

main :: proc() {
	a := thread.create_and_start(proc() {
		intrinsics.atomic_store_explicit(&A, true, .Seq_Cst)
		if !intrinsics.atomic_load_explicit(&B, .Seq_Cst) {
			append(&S, '!')
		}
	})

	b := thread.create_and_start(proc() {
		intrinsics.atomic_store_explicit(&B, true, .Seq_Cst)
		if !intrinsics.atomic_load_explicit(&A, .Seq_Cst) {
			append(&S, '!')
		}
	})

	thread.join(a)
	thread.join(b)
	thread.destroy(a)
	thread.destroy(b)
}
