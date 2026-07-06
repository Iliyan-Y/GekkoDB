# Project Memory

## Session Notes

- Started with the Zig scaffold and chose an in-memory key/value store as the first learning boundary.
- Used `src/root.zig` for the first tests because it is the shared module boundary in the current scaffold.
- Added a test for `put`, `get`, and `delete`.
- Added a second test to expose ownership problems by mutating caller-owned buffers after insertion.
- Fixed the store so it owns key/value bytes by duplicating them into the allocator and freeing them on delete/deinit.
- Learned that `StringHashMap` stores the value slice but does not manage nested heap ownership automatically.
- Zig lesson from this session: `[]const u8` can be borrowed data or owned data depending on how it was created; tests should make that distinction explicit.
- Replaced the temporary `KeyValueStore` with `Index`, moving toward the real database architecture.
- Added `RecordLocation` as compact metadata for where a record lives in storage.
- `Index` now maps string keys to `RecordLocation`, owning only duplicated key bytes.
- `RecordLocation` is stored by value, not heap-allocated, so it does not need manual free logic.
- Moved tests into `src/root_test.zig` and imported them from `src/root.zig` for Zig test discovery.
- Added index tests for insert/get, update existing key, and delete.
- `zig build test` passed.

## Current Working Shape

- `Index` exists in `src/root.zig`.
- `RecordLocation` exists in `src/root.zig`.
- Tests live in `src/root_test.zig` and are imported by a `test` block in `src/root.zig`.
- Tests currently verify insert/get, updating an existing key, and deleting a key.
- No persistence, sockets, or file-backed storage has been added yet.

## Next Likely Step

- Design the append-only log record binary format before writing file I/O.
- Next implementation should likely define a small `LogRecord` or encoder/decoder boundary for `put` and `delete` records.
