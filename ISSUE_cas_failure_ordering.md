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

---

## Implementation notes (Odin master `2c25fb924`, 2026-07-19)

This is a **one-file, front-end-only** change: relax a validation `switch` in
the checker. The backend and LLVM already do the right thing — the compiler
emits `cmpxchg` with two independent orderings today (see below), so the only
thing rejecting the pairing is the checker running the old C++11 rule.

### The only edit: `src/check_builtin.cpp`

The offending validation is the `success_memory_order` `switch` at
[lines 6423–6469](file:///Users/nathany/src/github.com/odin-lang/Odin/src/check_builtin.cpp),
inside the `atomic_compare_exchange_*` case. It sets `invalid_combination`
whenever the failure ordering is "stronger" than the success ordering — the
pre-C++17 rule. Replace the whole `switch (success_memory_order) { … }` block
with a check on the failure ordering alone (a failed CAS performs no store, so
only `release` / `acq_rel` are meaningless):

```cpp
bool invalid_combination = false;
switch (failure_memory_order) {
case OdinAtomicMemoryOrder_release:
case OdinAtomicMemoryOrder_acq_rel:
    invalid_combination = true;
    break;
default:
    break;
}
```

Leave the `if (invalid_combination) { error(...) }` block at lines 6472–6478 as
is — it still produces a sensible message for `.Release` / `.Acq_Rel` failure
orderings. You may want to reword it, since it currently prints both orderings
("success = …, failure = …") as if the pairing were the problem; after the
change the failure ordering alone is what's illegal.

Note `success_memory_order` is now unused by this block. It's still read a few
lines up by `check_atomic_memory_order_argument` at line 6409, so it won't go
unreferenced — no need to touch that.

### Why nothing else changes

- **Backend already passes both orderings through.** At
  [src/llvm_backend_proc.cpp:3819+](file:///Users/nathany/src/github.com/odin-lang/Odin/src/llvm_backend_proc.cpp),
  the `*_explicit` cases set
  `success_ordering = llvm_atomic_ordering_from_odin(ce->args[3])` and
  `failure_ordering = llvm_atomic_ordering_from_odin(ce->args[4])`
  independently, then hand both to `LLVMBuildAtomicCmpXchg(...)`. The capability
  is wired up and exercised — the checker is the sole gate.
- **LLVM supports it.** `cmpxchg` has taken independent success/failure
  orderings since LLVM 3.5; Odin's `build_odin.sh` requires LLVM ≥ 17, so
  there's no version concern.
- **Host C++ standard is irrelevant.** The `-std=c++14` the compiler builds
  with governs the checker's *own* source, not the atomic semantics of the Odin
  program being compiled. The edit above is plain C++14 (an `enum` `switch`).

### Keep `consume` valid

The current block handles `OdinAtomicMemoryOrder_consume` explicitly. In the
replacement, `consume` falls into the `default` branch and stays legal as a
failure ordering — correct, since it's neither `release` nor `acq_rel`. Worth a
line in the PR so reviewers see it was considered rather than dropped.

### Smoke test

The repro from "Steps to Reproduce" above should now compile. Also confirm the
genuinely-illegal cases still error:

```odin
package main
import "base:intrinsics"

main :: proc() {
    x, p: rawptr
    // was rejected, should now compile:
    _, _ = intrinsics.atomic_compare_exchange_strong_explicit(&x, nil, p, .Release, .Acquire)
    // still illegal (release/acq_rel failure ordering):
    // _, _ = intrinsics.atomic_compare_exchange_strong_explicit(&x, nil, p, .Acquire, .Release)
}
```

Then revisit `odin_port/examples/ch3-09-lazy-init-box.odin`: the CAS there was
forced to `.Acq_Rel` success ordering as a workaround. With this patch it can
drop back to `.Release` success / `.Acquire` failure, matching the book's Rust.
