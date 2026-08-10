package ch9_locks

import "core:testing"
import "core:thread"

// Rust leaves mutex_1, mutex_2, and the rwlocks untested. In Odin,
// polymorphic code isn't fully type-checked until instantiated, so these
// tests (not in the Rust original) exercise every version under
// contention.

@(test)
test_mutex_1 :: proc(t: ^testing.T) {
	m: Mutex_1(int)
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&m, proc(m: ^Mutex_1(int)) {
			for _ in 0 ..< 10_000 {
				g := mutex_1_lock(m)
				mutex_1_get(g)^ += 1
				mutex_1_unlock(g)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	g := mutex_1_lock(&m)
	testing.expect_value(t, mutex_1_get(g)^, 40_000)
	mutex_1_unlock(g)
}

@(test)
test_mutex_2 :: proc(t: ^testing.T) {
	m: Mutex_2(int)
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&m, proc(m: ^Mutex_2(int)) {
			for _ in 0 ..< 10_000 {
				g := mutex_2_lock(m)
				mutex_2_get(g)^ += 1
				mutex_2_unlock(g)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	g := mutex_2_lock(&m)
	testing.expect_value(t, mutex_2_get(g)^, 40_000)
	mutex_2_unlock(g)
}

@(test)
test_rwlock_1 :: proc(t: ^testing.T) {
	l: RW_Lock_1(int)
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&l, proc(l: ^RW_Lock_1(int)) {
			for _ in 0 ..< 10_000 {
				g := rwlock_1_write(l)
				rwlock_1_write_get(g)^ += 1
				rwlock_1_write_unlock(g)
				r := rwlock_1_read(l)
				assert(rwlock_1_read_get(r)^ > 0)
				rwlock_1_read_unlock(r)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	g := rwlock_1_read(&l)
	testing.expect_value(t, rwlock_1_read_get(g)^, 40_000)
	rwlock_1_read_unlock(g)
}

@(test)
test_rwlock_2 :: proc(t: ^testing.T) {
	l: RW_Lock_2(int)
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&l, proc(l: ^RW_Lock_2(int)) {
			for _ in 0 ..< 10_000 {
				g := rwlock_2_write(l)
				rwlock_2_write_get(g)^ += 1
				rwlock_2_write_unlock(g)
				r := rwlock_2_read(l)
				assert(rwlock_2_read_get(r)^ > 0)
				rwlock_2_read_unlock(r)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	g := rwlock_2_read(&l)
	testing.expect_value(t, rwlock_2_read_get(g)^, 40_000)
	rwlock_2_read_unlock(g)
}

@(test)
test_rwlock_3 :: proc(t: ^testing.T) {
	l: RW_Lock(int)
	threads: [4]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data(&l, proc(l: ^RW_Lock(int)) {
			for _ in 0 ..< 10_000 {
				g := write(l)
				write_get(g)^ += 1
				write_unlock(g)
				r := read(l)
				assert(read_get(r)^ > 0)
				read_unlock(r)
			}
		})
	}
	for th in threads {
		thread.join(th)
		thread.destroy(th)
	}
	g := read(&l)
	testing.expect_value(t, read_get(g)^, 40_000)
	read_unlock(g)
}
