# Issue: atomic max/min intrinsics

Posted as [odin-lang/Odin#7079](https://github.com/odin-lang/Odin/issues/7079)
(July 2026, with light editing).

**Title:** intrinsics: expose atomic max/min (`atomicrmw max/min/umax/umin`)

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

Atomic max/min intrinsics alongside the existing read-modify-write
family, following the established naming pattern, with signedness taken
from `T` (mapping to `max`/`min` for signed integers and `umax`/`umin`
for unsigned, as Rust does):

```odin
atomic_max          :: proc(dst: ^$T, val: T) -> T ---
atomic_max_explicit :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
atomic_min          :: proc(dst: ^$T, val: T) -> T ---
atomic_min_explicit :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
```

Atomic max/min is a common primitive for statistics and high-water marks
(peak latency, max queue depth, largest allocation), and both Rust
(`fetch_max`/`fetch_min`, stable since 1.45) and C++26
([P0493R5](https://wg21.link/p0493r5), `fetch_max`/`fetch_min`) provide
it. LLVM supports it natively (`atomicrmw max/min/umax/umin`), and on
targets with the corresponding instructions (e.g. ARMv8.1 `LDUMAX`) it
lowers to a single instruction rather than a compare-exchange loop.

## Current Behavior

`base:intrinsics` exposes every LLVM `atomicrmw` operation except the
min/max family: `atomic_add`, `atomic_sub`, `atomic_and`, `atomic_nand`,
`atomic_or`, `atomic_xor`, and `atomic_exchange` all exist, but there is
no `atomic_max`/`atomic_min`. The workaround is a compare-exchange loop:

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

---

Affected area: each atomic intrinsic is a `BuiltinProc_` entry validated
in `src/check_builtin.cpp` and lowered in `src/llvm_backend_proc.cpp`,
where the existing RMW cases map to `LLVMAtomicRMWBinOpAdd` etc. Max/min
would add cases mapping to `LLVMAtomicRMWBinOpMax`/`Min`/`UMax`/`UMin`,
plus the stub declarations in `base/intrinsics/intrinsics.odin`.

Encountered while porting the statistics example from
*Rust Atomics and Locks* (ch. 2).

---

## Implementation notes (Odin master `2c25fb924`, 2026-07-19)

Follow the existing `atomic_xor` / `atomic_xor_explicit` pair verbatim — it is
the closest template (integer-only RMW, no funny business). There are **four**
files to touch, and they must stay index-aligned across the first two. The one
real subtlety is signedness: unlike every other RMW, max/min needs a *different*
LLVM opcode depending on whether `T` is signed or unsigned, so the backend has
to inspect the element type instead of using a fixed opcode.

### 1. `base/intrinsics/intrinsics.odin` (stub declarations)

After the `atomic_xor*` lines (currently
[lines 123–124](file:///Users/nathany/src/github.com/odin-lang/Odin/base/intrinsics/intrinsics.odin)),
add four stubs mirroring them exactly:

```odin
atomic_max               :: proc(dst: ^$T, val: T) -> T ---
atomic_max_explicit      :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
atomic_min               :: proc(dst: ^$T, val: T) -> T ---
atomic_min_explicit      :: proc(dst: ^$T, val: T, order: Atomic_Memory_Order) -> T ---
```

These are documentation/overload stubs only; the compiler resolves the real
behavior by `BuiltinProc_` id, so placement is cosmetic (but keep it next to the
other RMW ops).

### 2. `src/checker_builtin_procs.hpp` (enum + name table — MUST stay parallel)

Two arrays are indexed by the same enum and must be edited in lockstep:

- **Enum** (`enum BuiltinProc`): add `BuiltinProc_atomic_max` /
  `_atomic_max_explicit` / `_atomic_min` / `_atomic_min_explicit` after
  `BuiltinProc_atomic_xor_explicit`
  ([line 132](file:///Users/nathany/src/github.com/odin-lang/Odin/src/checker_builtin_procs.hpp)),
  still inside the `BuiltinProc__atomic_begin` … `BuiltinProc__atomic_end`
  range (lines 113 / 139).
- **Name/arity table** (`builtin_procs[]`): add the matching rows after the
  `atomic_xor_explicit` entry
  ([line 542](file:///Users/nathany/src/github.com/odin-lang/Odin/src/checker_builtin_procs.hpp)),
  copying the `atomic_xor` / `atomic_xor_explicit` rows (arity 2 and 3
  respectively, `Expr_Expr`, last two flags `false, true`):

  ```cpp
  {STR_LIT("atomic_max"),          2, false, Expr_Expr, BuiltinProcPkg_intrinsics, false, true},
  {STR_LIT("atomic_max_explicit"), 3, false, Expr_Expr, BuiltinProcPkg_intrinsics, false, true},
  {STR_LIT("atomic_min"),          2, false, Expr_Expr, BuiltinProcPkg_intrinsics, false, true},
  {STR_LIT("atomic_min_explicit"), 3, false, Expr_Expr, BuiltinProcPkg_intrinsics, false, true},
  ```

  This table is positional — its Nth row is `BuiltinProc(N)`. If the enum and the
  table drift out of alignment every builtin after the insertion point silently
  resolves to the wrong thing, so insert at the same relative offset in both.

### 3. `src/check_builtin.cpp` (type checking)

Two `switch` cases handle the RMW family; add the new ids to both. Max/min are
integer-only (no float, unlike `exchange`), so they behave exactly like `and` /
`or` / `xor` — do **not** add them to the `exchange` exemption:

- Non-explicit case at
  [lines 6278–6284](file:///Users/nathany/src/github.com/odin-lang/Odin/src/check_builtin.cpp):
  add `case BuiltinProc_atomic_max:` and `case BuiltinProc_atomic_min:`
  alongside `atomic_xor`. The existing `if (id != BuiltinProc_atomic_exchange)`
  guard at line 6299 already enforces `is_type_integer_like` + endianness for
  them — nothing extra needed.
- Explicit case at
  [lines 6316–6322](file:///Users/nathany/src/github.com/odin-lang/Odin/src/check_builtin.cpp):
  add `_max_explicit` / `_min_explicit` alongside `atomic_xor_explicit`; the
  `id != BuiltinProc_atomic_exchange_explicit` guard (line 6342) covers them.

### 4. `src/llvm_backend_proc.cpp` (lowering — the signedness bit)

The shared RMW block is at
[lines 3774–3817](file:///Users/nathany/src/github.com/odin-lang/Odin/src/llvm_backend_proc.cpp).
Add the four ids to the outer `case` list (lines 3774–3787). Then, in the inner
`switch (id)` that picks `LLVMAtomicRMWBinOp` (lines 3795–3810), max/min can't be
a one-liner like the others because the opcode depends on the sign of `T`. Add,
before or after the switch:

```cpp
Type *elem = type_deref(lb_build_expr(p, ce->args[0]).type); // or reuse `dst`
bool is_unsigned = is_type_unsigned(core_type(elem));        // is_type_unsigned @ src/types.cpp:1335
```

and select:

```cpp
case BuiltinProc_atomic_max:
    op = is_unsigned ? LLVMAtomicRMWBinOpUMax : LLVMAtomicRMWBinOpMax;
    ordering = LLVMAtomicOrderingSequentiallyConsistent; break;
case BuiltinProc_atomic_min:
    op = is_unsigned ? LLVMAtomicRMWBinOpUMin : LLVMAtomicRMWBinOpMin;
    ordering = LLVMAtomicOrderingSequentiallyConsistent; break;
case BuiltinProc_atomic_max_explicit:
    op = is_unsigned ? LLVMAtomicRMWBinOpUMax : LLVMAtomicRMWBinOpMax;
    ordering = llvm_atomic_ordering_from_odin(ce->args[2]); break;
case BuiltinProc_atomic_min_explicit:
    op = is_unsigned ? LLVMAtomicRMWBinOpUMin : LLVMAtomicRMWBinOpMin;
    ordering = llvm_atomic_ordering_from_odin(ce->args[2]); break;
```

`dst` is already computed at line 3788 (`lb_build_expr(p, ce->args[0])`); reuse
`type_deref(dst.type)` for `elem` rather than building the expr twice. The
`LLVMBuildAtomicRMW` call at line 3813 needs no change — it just takes `op`.
The LLVM-C enum constants (`LLVMAtomicRMWBinOpMax/Min/UMax/UMin`) are declared in
`src/llvm-c/Core.h:372–378`, so no new include.

### Build & smoke test

Rebuild with `./build_odin.sh` (or `make`) in the Odin checkout, then, from a
scratch file:

```odin
package main
import "base:intrinsics"
import "core:fmt"

main :: proc() {
    s:  i32 = 5;  intrinsics.atomic_max(&s,  3); intrinsics.atomic_max(&s, 9)   // -> 9  (signed, uses `max`)
    u:  u32 = 5;  intrinsics.atomic_max_explicit(&u, 9, .Relaxed)               // -> 9  (unsigned, uses `umax`)
    n:  i32 = -1; intrinsics.atomic_max(&n, -5)                                 // stays -1: proves signed path
    fmt.println(s, u, n)  // 9 9 -1
}
```

Compile with `-o:speed` and disassemble to confirm it lowers to a single
`atomicrmw max`/`umax` (and on ARMv8.1 targets, `LDUMAX`/`LDSMAX`) rather than a
CAS loop. The signed/unsigned split is the one thing worth an explicit test —
get it backwards and `atomic_max` on a negative `i32` silently treats the sign
bit as magnitude.
