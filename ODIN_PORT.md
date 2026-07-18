# Odin port notes

[`odin_port/examples`](odin_port/examples) mirrors the folder structure and
filenames of the book's [`examples`](examples) (with `.odin` instead of `.rs`).
Every file is a standalone `package main` program:

```sh
odin run odin_port/examples/ch1-01-hello.odin -file
```

Because every file declares `package main`, the directory cannot be built as a
package — always use `-file`, matching how Cargo treats `examples/` as
individual binaries. The ports are verified against `odin version
dev-2026-07`, which uses the new `core:os` API (e.g. `os.stdin` is a `^File`,
converted to a stream with `os.to_stream`).

## General mappings

| Rust | Odin |
|---|---|
| `thread::spawn` | `thread.create_and_start` (`core:thread`) |
| `JoinHandle::join` | `thread.join` + `thread.destroy` |
| closure capturing data | `thread.create_and_start_with_poly_data` — data is passed explicitly |
| `thread::current().id()` | `sync.current_thread_id()` |
| `Mutex<T>` | `sync.Mutex` next to the data it guards (by convention only) |
| `MutexGuard` (drop = unlock) | `sync.guard` (unlocks at end of scope), or explicit `mutex_lock`/`mutex_unlock` |
| `Condvar` | `sync.Cond` (`cond_wait`, `cond_signal`) |
| `park` / `unpark` / `park_timeout` | `sync.Sema`: `sema_wait` / `sema_post` / `sema_wait_with_timeout` (but posts accumulate, unpark tokens don't) |
| `VecDeque` | `queue.Queue` (`core:container/queue`) |
| `AtomicBool`, `AtomicU32`, … | plain `bool`, `u32`, … accessed via `intrinsics.atomic_*` (`base:intrinsics`) |
| `x.load(Relaxed)` | `intrinsics.atomic_load_explicit(&x, .Relaxed)` |
| `x.fetch_add(1, Relaxed)` | `intrinsics.atomic_add_explicit(&x, 1, .Relaxed)` |
| `compare_exchange(_weak)` | `intrinsics.atomic_compare_exchange_strong/weak_explicit` — returns `(old_value, ok)` instead of `Ok`/`Err` |
| `fetch_max` | no intrinsic — compare-exchange loop (see ch2-07) |
| function-local `static` | file-scope global, or `@(static)` local when only one proc needs it |
| `usize` | `int` (except where wrap-around is the point: `u32`) |
| `Instant` | `time.tick_now()` / `time.tick_since` |
| `Duration::from_secs(1)` | `1 * time.Second` |
| `dbg!(x)` | `fmt.println("x =", x)` |

## Concepts with no Odin equivalent

- **Ownership, borrowing, `Send`/`Sync`**: Odin has none of these. Everything
  the Rust examples prove at compile time (no data races, no
  use-after-scope) is the programmer's responsibility in Odin. Where Rust
  *needs* a type to satisfy the borrow checker, the Odin port just uses a
  pointer and a comment.
- **`Rc`** (ch1-05): no reference counting; sharing an allocation is copying
  the pointer, and freeing exactly once is manual.
- **`Cell` / `RefCell`** (ch1-06, ch1-07): interior mutability is a
  Rust-specific concept; any Odin pointer permits mutation. ch1-06 still
  mirrors `Cell`'s take/modify/put-back dance for comparison.
- **Scoped threads** (ch1-04): not needed — Odin lets a thread borrow a local
  as long as you join before it goes out of scope (and nothing checks that
  you do).
- **Thread parking** (ch1-11, ch2-03): closest primitive is a semaphore.
  Semantics differ slightly: multiple `sema_post` calls accumulate, whereas
  multiple `unpark` calls collapse into one token.
- **Panics and `catch_unwind`** (ch2-09, ch2-10): a failed Odin `assert` or
  `panic` aborts the process and cannot be caught. ch2-09 demonstrates the
  leaked `fetch_add` by repeating the pre-assert step directly.

## Chapter notes

### Chapter 1 — Basics of Rust Concurrency

Direct translations throughout; the interesting deltas are all in the list
above. `sync.guard(&m)` is a close `MutexGuard` analog: it locks and defers
the unlock to the end of the enclosing scope. ch1-10's `drop(guard)` becomes
explicit `mutex_lock`/`mutex_unlock`. The ch1-09 vs ch1-10 behavior
difference reproduces exactly: ~10 s (threads serialize on the held lock
while sleeping) vs ~1 s.

### Chapter 2 — Atomics

Odin has no atomic *types*, only atomic *operations* — any suitably sized
integer can be operated on atomically via `base:intrinsics`, and nothing
stops non-atomic access to the same variable. Memory orderings mirror C++:
`.Relaxed`, `.Acquire`, `.Release`, `.Acq_Rel`, `.Seq_Cst`.

- ch2-01: reading stdin lines uses a `bufio.Scanner` over `os.to_stream(os.stdin)`.
- ch2-07: `fetch_max` is hand-rolled with a `compare_exchange_weak` loop —
  the same pattern ch2-11/ch2-12 teach.
- ch2-08/ch2-09: the u32 overflow takes ~10 s when built with `-o:speed`
  (4.3 billion relaxed `fetch_add`s), noticeably longer unoptimized. Both
  reproduce the bug: the counter wraps and hands out ID 0 again.
- ch2-11 note: `new` is a builtin in Odin, so the CAS loop's `new` variable
  is named `next`.
