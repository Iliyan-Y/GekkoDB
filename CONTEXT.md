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
- Reorganized the scaffold toward per-boundary modules and per-file tests.
- Moved the index into `src/domain/index.zig` with tests in `src/domain/index_test.zig`.
- Added the first storage-format module at `src/storage/log_record.zig` with tests in `src/storage/log_record_test.zig`.
- Kept `src/root.zig` as a small test aggregator for now.
- Chose `storage/` instead of `log/` because append-only logs, recovery, mmap segments, and compaction are all storage-layer concerns.
- Removed a stale unused `std.Io` alias from the index module.
- User preference clarified: avoid re-exporting everything from `root.zig`; import concrete modules directly where needed unless a curated package API becomes useful later.
- User preference clarified: tests should live per file/module rather than in a single broad `root_test.zig`.

## Current Working Shape

- `Index` exists in `src/domain/index.zig`.
- `RecordLocation` exists in `src/domain/index.zig`.
- Index tests live in `src/domain/index_test.zig`.
- Log record format constants/types exist in `src/storage/log_record.zig`.
- Log record tests live in `src/storage/log_record_test.zig`.
- `src/root.zig` imports module-specific tests for Zig test discovery.
- Tests currently verify insert/get, updating an existing key, and deleting a key.
- Log record tests currently verify that the logical encoded header size is 14 bytes and that the Zig struct size may include padding.
- No persistence, sockets, or file-backed storage has been added yet.

## Next Likely Step

- Implement and test explicit binary encoding for `LogRecordHeader` in `src/storage/log_record.zig`.
- Teach why DB file formats should write individual integer fields with a chosen endian order instead of dumping raw Zig struct bytes.
- After header encoding is stable, add full record encoding for `put` and `delete`: `[header][key bytes][value bytes]` for put and `[header][key bytes]` for delete.
