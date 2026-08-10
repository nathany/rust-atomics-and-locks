package main

// Odin has no reference-counted pointer like Rust's Rc. Sharing an
// allocation is simply copying the pointer; it is up to the programmer
// to free it exactly once.
main :: proc() {
	a := new_clone([3]int{1, 2, 3})
	defer free(a)

	b := a

	assert(a == b) // Same allocation!
}
