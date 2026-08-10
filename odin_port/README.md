# Odin port

Odin ports of the book's Rust code, mirroring the folder structure and
filenames of [`../examples`](../examples) and [`../src`](../src) (with
`.odin` instead of `.rs`).

Each file in `examples/` is a standalone program; each chapter directory in
`src/` is a standalone package:

```sh
odin run examples/ch1-01-hello.odin -file
odin test src/ch4_spin_lock
```

Where Rust relies on a type that has no Odin equivalent (`Rc`, `Cell`,
`RefCell`, scoped threads, thread parking), the port demonstrates the same
behavior with the closest Odin idiom and notes the difference in a comment.

See [ODIN_PORT.md](../ODIN_PORT.md) for the full Rust→Odin mappings and
per-chapter porting notes.
