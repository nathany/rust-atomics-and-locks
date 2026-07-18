package ch9_locks

import "core:sync"

// The equivalent of Rust's atomic-wait crate: futex-style wait/wake on any
// 32-bit atomic, portable via core:sync (futex on Linux, __ulock on macOS,
// WaitOnAddress on Windows). sync.Futex is a distinct u32, so the casts
// just reinterpret our Atomic(u32)'s storage.

wait :: proc(a: ^Atomic(u32), expected: u32) {
	sync.futex_wait((^sync.Futex)(&a._raw), expected)
}

wake_one :: proc(a: ^Atomic(u32)) {
	sync.futex_signal((^sync.Futex)(&a._raw))
}

wake_all :: proc(a: ^Atomic(u32)) {
	sync.futex_broadcast((^sync.Futex)(&a._raw))
}
