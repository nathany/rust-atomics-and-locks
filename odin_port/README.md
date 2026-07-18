# Odin port

Odin ports of the book's Rust examples, mirroring the folder structure and
filenames of [`../examples`](../examples) (with `.odin` instead of `.rs`).

Each file is a standalone program. Run one with:

```sh
odin run examples/ch1-01-hello.odin -file
```

Where Rust relies on a type that has no Odin equivalent (`Rc`, `Cell`,
`RefCell`, scoped threads, thread parking), the port demonstrates the same
behavior with the closest Odin idiom and notes the difference in a comment.

See [ODIN_PORT.md](../ODIN_PORT.md) for the full Rust→Odin mappings and
per-chapter porting notes.
