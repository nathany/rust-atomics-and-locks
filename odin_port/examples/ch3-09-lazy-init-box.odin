package main

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
		// Rust uses (Release, Acquire) here, but Odin enforces the pre-C++17
		// rule that the failure ordering may not be stronger than the success
		// ordering — .Acq_Rel on success is the equivalent allowed pairing.
		if e, ok := intrinsics.atomic_compare_exchange_strong_explicit(&PTR, nil, p, .Acq_Rel, .Acquire); !ok {
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
