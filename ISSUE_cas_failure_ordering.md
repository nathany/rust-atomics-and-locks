# Issue: compare-exchange rejects failure orderings that C++17 and LLVM allow

Posted as [odin-lang/Odin#7080](https://github.com/odin-lang/Odin/issues/7080)
(July 2026, with light editing).

**Title:** `atomic_compare_exchange_*` rejects failure orderings stronger than the success ordering (pre-C++17 rule)

---

## Context

* Operating System & Odin Version: macOS Tahoe 26.5.2, Odin dev-2026-07
* Please paste `odin report` output:

```
	Odin:    dev-2026-07:6983813b4
	OS:      macOS Tahoe 26.5.2 (build 25F84, kernel 25.5.0)
	CPU:     Apple M1 Max
	RAM:     32768 MiB
	Backend: LLVM 22.1.8
```

## Expected Behavior

`intrinsics.atomic_compare_exchange_strong_explicit(&x, nil, p, .Release, .Acquire)`
should compile. The checker currently enforces the C++11 rule that a
compare-exchange *failure* ordering may not be stronger than its *success*
ordering, but C++17 removed that restriction
([P0418R2](https://wg21.link/p0418r2)), and LLVM's `cmpxchg` accepts any
combination — the only remaining rule is that the failure ordering cannot
be `release` or `acq_rel`, since a failed exchange performs no store. Rust
and C++17 both permit e.g. success = Release, failure = Acquire, a natural
pairing for lazy initialization where the failure value is a pointer
published by another thread.

Suggested change: in the `invalid_combination` tables under the
`atomic_compare_exchange` builtins in `src/check_builtin.cpp` (around line
6470), drop the failure-vs-success comparison and reject only failure
orderings of `.Release` or `.Acq_Rel`. The backend already passes both
orderings through to LLVM's `cmpxchg` unchanged, so no other change is
needed.

## Current Behavior

The combination is rejected at compile time with an
"Illegal memory order pairing" error. The workaround is to strengthen the
success ordering to `.Acq_Rel`, which is semantically a superset but
stronger than what the algorithm needs, and makes porting C++17/Rust code
needlessly lossy.

## Failure Information (for bugs)

### Steps to Reproduce

1. Save the following as `cas_repro.odin`:

```odin
package main

import "base:intrinsics"

main :: proc() {
	x, p: rawptr
	_, _ = intrinsics.atomic_compare_exchange_strong_explicit(&x, nil, p, .Release, .Acquire)
}
```

2. `odin build cas_repro.odin -file`

### Failure Logs

```
cas_repro.odin(7:73) Error: Illegal memory order pairing for 'atomic_compare_exchange_strong_explicit', success = .Release, failure = .Acquire
	... compare_exchange_strong_explicit(&x, nil, p, .Release, .Acquire)
	                                                  ^~~~~~^
```

---

References:

- C++17 [P0418R2](https://wg21.link/p0418r2): "Fail or succeed: there is no atomic lattice"
- [LLVM LangRef, `cmpxchg`](https://llvm.org/docs/LangRef.html#cmpxchg-instruction): failure ordering only excludes release/acq_rel
- [Rust `Atomic::compare_exchange`](https://doc.rust-lang.org/std/sync/atomic/struct.Atomic.html#method.compare_exchange-7):
  "The failure ordering can only be SeqCst, Acquire or Relaxed." — Rust
  lifted the failure-weaker-than-success restriction in 1.64 (2022) via
  [rust-lang/rust#98383](https://github.com/rust-lang/rust/pull/98383),
  following P0418R2.

Encountered while porting the lazy-initialization example from
*Rust Atomics and Locks* (ch. 3).
