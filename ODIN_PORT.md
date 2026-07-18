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
dev-2026-07`.

[`odin_port/src`](odin_port/src) mirrors the book's library code in
[`src`](src): each chapter directory is a standalone Odin package (no
`lib.rs`/`mod.rs` equivalents needed), tested with:

```sh
odin test odin_port/src/ch4_spin_lock
```

Library-port conventions:

- Each chapter package defines its own small `Atomic($T)` wrapper
  (`atomic.odin`) instead of using raw intrinsics: in library code the
  wrapper marks which fields are shared and makes non-atomic access a
  visible convention violation. The duplication per chapter is deliberate —
  chapters stay standalone. Orderings stay explicit via a `$order` constant
  parameter.
- Rust modules within a chapter (e.g. `s1_minimal`, `s2_unsafe`) become
  files in the one package, so each version's types need distinct names:
  earlier teaching versions get prefixed names (`Minimal_Spin_Lock`), the
  chapter's final version gets the clean name (`Spin_Lock`).
- `#[test]` functions become `@(test)` procs in a `*_test.odin` file.

Two gaps found while porting have been reported upstream:
[odin-lang/Odin#7080](https://github.com/odin-lang/Odin/issues/7080)
(compare-exchange failure-ordering rule, write-up in
[ISSUE_cas_failure_ordering.md](ISSUE_cas_failure_ordering.md)) and
[odin-lang/Odin#7079](https://github.com/odin-lang/Odin/issues/7079)
(atomic max/min intrinsics, write-up in
[ISSUE_atomic_max_min.md](ISSUE_atomic_max_min.md)).

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
| `fence(ordering)` | `intrinsics.atomic_thread_fence(.Ordering)` |
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

### Chapter 3 — Memory Ordering

The orderings and `atomic_thread_fence` map one-to-one, so these are near
line-by-line translations. Deltas:

- **`static mut` + `unsafe`** (ch3-07, 08, 10, 11): Odin globals are always
  mutable and freely accessible; the Rust `// Safety:` comments are kept, but
  nothing enforces them.
- **Ordering pairs** (ch3-09): Odin enforces the pre-C++17 rule that a
  compare-exchange *failure* ordering may not be stronger than its *success*
  ordering. Rust's `compare_exchange(_, _, Release, Acquire)` is rejected;
  use `.Acq_Rel` success ordering instead (a strict superset, same codegen
  on common targets).
- **`AtomicPtr<T>`** (ch3-09): the atomic intrinsics work directly on `^Data`
  pointers; `Box::into_raw(Box::new(v))` becomes `new_clone(v)` and
  `drop(Box::from_raw(p))` becomes `free(p)`.
- **`String` as shared data** (ch3-08, ch3-10): ported as a global
  `[dynamic]u8`. The zero-valued dynamic array picks up the default heap
  allocator on first `append`, which is thread-safe.

### Chapter 4 — Building Our Own Spin Lock

First library port: [`odin_port/src/ch4_spin_lock`](odin_port/src/ch4_spin_lock),
introducing the `Atomic($T)` wrapper.

- `std::hint::spin_loop()` → `intrinsics.cpu_relax()`.
- `const fn new()` disappears: the zero value is a valid unlocked lock.
- `UnsafeCell` and `unsafe impl Sync` (s2, s3) have no equivalent — the
  value is a plain struct field and nothing checks cross-thread sharing.
  The `// Safety:` comments are preserved as documentation only.
- **`Guard`'s `Drop`** (s3) is the real casualty: Odin has no destructors,
  and the usual substitute — `@(deferred_out=unlock)` — is rejected on
  polymorphic procedures (`core:sync`'s `guard()` works because `Mutex`
  isn't generic). So `unlock(g)` is explicit; `defer unlock(g)` at the call
  site is the idiom. `Deref`/`DerefMut` become an explicit `guard_value(g)`
  accessor, and nothing prevents using the pointer after unlock.

### Chapter 5 — Building Our Own Channels

[`odin_port/src/ch5_channels`](odin_port/src/ch5_channels). Note that Odin
ships channels (`core:sync/chan`); these ports rebuild them from scratch
for the same educational purpose as the book. Six versions share one
package: `Simple_Channel` (s1), `Unsafe_Channel` (s2), `Checked_Channel`
(s3), `Single_Atomic_Channel` (s3, one-atomic variant), `Owned_*` (s4),
`Borrowing_*` (s5), and the final blocking version takes the clean
`Channel`/`Sender`/`Receiver` names.

- **`MaybeUninit<T>`** → a plain zero-initialized field. Odin has no
  uninitialized-memory type; "no message yet" is just the zero value, and
  the ready flag/state machine is the only thing giving it meaning.
- **`Drop` for unreceived messages** (s3 onward): omitted — Odin has no
  destructors for `T` either, so cleanup of an unreceived message that owns
  resources falls to the channel's owner.
- **`Arc<Channel>`** (s4): ch6 builds Arc, so this chapter substitutes a
  plain heap allocation; the caller frees the channel via either half's
  `channel` field once both halves are done.
- **Move-semantics APIs** (`send(self)`, `receive(self)`): the halves are
  passed by value to mirror the API shape, but Odin has no move-only
  types — reuse after consumption is not a compile error.
- **`Receiver: !Send`** (s6): Rust pins the receiver to one thread so the
  sender's captured `Thread` handle wakes the right thread. The port puts
  a semaphore in the channel instead: the sender needn't know the
  receiving thread, which sidesteps the (inexpressible) `!Send` bound.

### Chapter 6 — Building Our Own "Arc"

[`odin_port/src/ch6_arc`](odin_port/src/ch6_arc). Odin's core library has no
reference-counted pointer at all (manual memory management is the
philosophy), so unlike ch5's channels this builds something Odin genuinely
lacks. Versions: `Basic_Arc` (s1), `Simple_Arc`/`Simple_Weak` (s2),
`Arc`/`Weak` (s3, optimized).

- **`Drop` is the whole ballgame**: Rust's entire release mechanism is
  implicit. The port makes every drop explicit (`arc_drop`, `weak_drop`),
  including the sneaky implicit ones — in s2, dropping a Rust `Arc` also
  drops its inner `Weak` *field* afterward, which becomes a visible
  `simple_weak_drop(arc.weak)` at the end of `simple_arc_drop`.
- **`Drop` for `T`**: `arc_new` takes an optional `data_drop: proc(^T)`
  callback, stored in `Arc_Data` — the Odin idiom for "run cleanup when
  the count hits zero", and what lets the book's `DetectDrop` tests port
  faithfully.
- **`ManuallyDrop<T>`** (s3) dissolves into a plain field: suppressing
  automatic drop *is* Odin's default semantics.
- **Odin-specific addition**: `Arc_Data` stores `context.allocator` from
  creation time, so the final `free` is correct no matter which thread
  drops last. A Rust `Box` carries its (global) allocator implicitly.
- **`Option<T>`** (s2) maps to `Maybe(T)`; Rust's
  `(*ptr).as_ref().unwrap()` deref becomes `&data.(T)`, whose panic on nil
  mirrors the unwrap.
- `usize::MAX` as get_mut's locked sentinel (s3) → `max(int)`.
- The tests double as leak checks: `odin test`'s tracking allocator would
  flag any refcount bug that leaks or double-frees the allocation.

### Chapter 8 — Operating System Primitives

One example: `ch8-01-futex.odin`. The Rust original is Linux-only (raw
futex syscall); the Odin port uses `sync.futex_wait`/`sync.futex_signal`
from `core:sync`, which wrap the same operation portably (futex on Linux,
`__ulock` on macOS, `WaitOnAddress` on Windows) — so unlike the original,
it runs everywhere. `sync.Futex` is a distinct `u32`.

### Chapter 9 — Building Our Own Locks

[`odin_port/src/ch9_locks`](odin_port/src/ch9_locks): three mutexes, two
condition variables, three reader-writer locks. Numbered versions keep
their numbers (`Mutex_1`, `RW_Lock_1`, …); the final version of each gets
the clean name (`Mutex`, `Condvar`, `RW_Lock`).

- **The `atomic-wait` crate** becomes `futex.odin`: `wait`/`wake_one`/
  `wake_all` on `^Atomic(u32)`, casting the storage to `^sync.Futex`.
  As with ch8, the port is more portable than the original.
- The lock logic itself — mutex_3's spin-then-wait, condvar's counter
  protocol, rwlock_3's odd/even state encoding to avoid writer
  starvation — ports line-for-line; all the book's comments are preserved.
- Guard drops become explicit `*_unlock(g)` procs, as in ch4.
- The condvar's `wait` clashes with the futex shim's `wait` (Odin has one
  package namespace), so it's `condvar_wait`/`condvar_1_wait`.
- Rust leaves mutex_1/2 and the rwlocks untested, and Odin doesn't fully
  type-check polymorphic code until instantiation — so `smoke_test.odin`
  adds contended tests (not in the original) for every version. The
  mutex_3 "bench" tests: ~50 ms for 5M uncontended lock/unlocks, ~500 ms
  for 20M contended across 4 threads (`-o:speed`, Apple Silicon).
