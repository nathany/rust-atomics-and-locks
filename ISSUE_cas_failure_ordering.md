# Draft issue: compare-exchange rejects failure orderings that C++17 and LLVM allow

Draft for odin-lang/Odin — not yet posted.

**Title:** `atomic_compare_exchange_*` rejects failure orderings stronger than the success ordering (pre-C++17 rule)

## Description

The checker enforces the C++11 rule that a compare-exchange *failure*
ordering may not be stronger than its *success* ordering. C++17 removed
that restriction ([P0418R2](https://wg21.link/p0418r2)), and LLVM's
`cmpxchg` accepts any combination (the only remaining rule is that the
failure ordering cannot be `release` or `acq_rel`, since a failed exchange
performs no store). Rust and C++17 both permit e.g. success = Release,
failure = Acquire — a natural pairing for lazy initialization, where the
failure value is a pointer published by another thread.

```odin
package main

import "base:intrinsics"

main :: proc() {
	x, p: rawptr
	_, _ = intrinsics.atomic_compare_exchange_strong_explicit(&x, nil, p, .Release, .Acquire)
}
```

```
Error: Illegal memory order pairing for 'atomic_compare_exchange_strong_explicit', success = .Release, failure = .Acquire
```

The workaround is to strengthen the success ordering to `.Acq_Rel`, which
is semantically a superset but stronger than what the algorithm needs, and
it makes porting C++17/Rust code needlessly lossy.

## Suggested change

In `src/check_builtin.cpp` (the `invalid_combination` tables under the
`atomic_compare_exchange` builtins, around line 6470), drop the
failure-vs-success comparison and reject only what LLVM rejects:
failure orderings of `.Release` or `.Acq_Rel`. The backend already passes
both orderings through to LLVM's `cmpxchg` unchanged, so no other change
is needed.

## References

- C++17 [P0418R2](https://wg21.link/p0418r2): "Fail or succeed: there is no atomic lattice"
- [LLVM LangRef, `cmpxchg`](https://llvm.org/docs/LangRef.html#cmpxchg-instruction): failure ordering only excludes release/acq_rel
- Rust `compare_exchange` documentation: same rule as LLVM

Encountered with `odin version dev-2026-07:819fdc7a8` while porting the
lazy-initialization example from *Rust Atomics and Locks* (ch. 3).
