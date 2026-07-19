package main

// VARIANT — does NOT compile on stock Odin (as of dev-2026-07 / master).
//
// This is ch3-09-lazy-init-box.odin with the compare-exchange using the
// orderings the book's Rust actually uses: success = .Release, failure =
// .Acquire. Odin's checker enforces the pre-C++17 rule that a failure ordering
// may not be stronger than the success ordering, so this is rejected today
// with:
//
//     Error: Illegal memory order pairing for
//     'atomic_compare_exchange_strong_explicit', success = .Release, failure = .Acquire
//
// It is kept as a target for when upstream relaxes that rule:
//
//     odin-lang/Odin#7080  (see ISSUE_cas_failure_ordering.md)
//
// Once #7080 lands, this replaces the runnable ch3-09-lazy-init-box.odin, which
// works around the restriction by strengthening success to .Acq_Rel.

import "base:intrinsics"
import "core:fmt"

Data :: struct {
	bytes: [100]u8,
}

get_data :: proc() -> ^Data {
	@(static) PTR: ^Data

	p := intrinsics.atomic_load_explicit(&PTR, .Acquire)

	if p == nil {
		// Box::new + Box::into_raw is a heap allocation: new_clone.
		p = new_clone(generate_data())
		// Matches the book's Rust: Release on success (publish the pointer),
		// Acquire on failure (observe the pointer another thread published).
		if e, ok := intrinsics.atomic_compare_exchange_strong_explicit(&PTR, nil, p, .Release, .Acquire); !ok {
			// Safety: p comes from new_clone right above,
			// and wasn't shared with any other thread.
			free(p)
			p = e
		}
	}

	// Safety: p is not nil and points to a properly initialized value.
	return p
}

generate_data :: proc() -> Data {
	return Data{bytes = {0 ..= 99 = 123}}
}

main :: proc() {
	fmt.printfln("%p", get_data())
	fmt.printfln("%p", get_data()) // Same address as before.
}
