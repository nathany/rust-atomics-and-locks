# Draft issue: atomic max/min intrinsics

Draft for odin-lang/Odin — not yet posted.

**Title:** intrinsics: expose atomic max/min (`atomicrmw max/min/umax/umin`)

## Description

`base:intrinsics` exposes every LLVM `atomicrmw` operation except the
min/max family: `atomic_add`, `atomic_sub`, `atomic_and`, `atomic_nand`,
`atomic_or`, `atomic_xor`, and `atomic_exchange` all exist, but there is no
`atomic_max`/`atomic_min`. LLVM supports these natively (`atomicrmw max`,
`min`, `umax`, `umin`), and on targets with the corresponding instructions
(e.g. ARMv8.1 `LDUMAX`) they lower to a single instruction rather than a
compare-exchange loop.

Atomic max/min is a common primitive for statistics and high-water marks
(peak latency, max queue depth, largest allocation), and both Rust
(`fetch_max`/`fetch_min`, stable since 1.45) and C++26
([P0493R5](https://wg21.link/p0493r5), `fetch_max`/`fetch_min`) provide it.

Current workaround:

```odin
atomic_fetch_max :: proc(dst: ^u64, val: u64) {
	current := intrinsics.atomic_load_explicit(dst, .Relaxed)
	for val > current {
		swapped: bool
		current, swapped = intrinsics.atomic_compare_exchange_weak_explicit(dst, current, val, .Relaxed, .Relaxed)
		if swapped do break
	}
}
```

## Suggested API

Following the existing naming pattern, with signedness taken from `T`
(mapping to `max`/`min` for signed integers and `umax`/`umin` for
unsigned, as Rust does):

```odin
atomic_max          :: proc(dst: ^$T, val: T) -> T ---
atomic_max_explicit :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
atomic_min          :: proc(dst: ^$T, val: T) -> T ---
atomic_min_explicit :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
```

## Affected area

Each atomic intrinsic is a `BuiltinProc_` entry validated in
`src/check_builtin.cpp` and lowered in `src/llvm_backend_proc.cpp`, where
the existing RMW cases map to `LLVMAtomicRMWBinOpAdd` etc. Max/min would
add cases mapping to `LLVMAtomicRMWBinOpMax`/`Min`/`UMax`/`UMin` (picking
signed vs. unsigned from the operand type), plus the stub declarations in
`base/intrinsics/intrinsics.odin`.

Encountered with `odin version dev-2026-07:819fdc7a8` while porting the
statistics example from *Rust Atomics and Locks* (ch. 2).
