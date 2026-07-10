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
- Added the first storage-format module at `src/storage/storage_record.zig` with tests in `src/storage/storage_record_test.zig`.
- Kept `src/root.zig` as a small test aggregator for now.
- Chose `storage/` instead of `log/` because append-only logs, recovery, mmap segments, and compaction are all storage-layer concerns.
- Removed a stale unused `std.Io` alias from the index module.
- User preference clarified: avoid re-exporting everything from `root.zig`; import concrete modules directly where needed unless a curated package API becomes useful later.
- User preference clarified: tests should live per file/module rather than in a single broad `root_test.zig`.
- Implemented explicit big-endian `Header` encoding and decoding for the 14-byte storage-record header format.
- `Operation` is non-exhaustive; decoding uses `@enumFromInt` and rejects unknown operation tags with `error.InvalidOperation`.
- Added encoding, decoding, and malformed-operation header tests. The malformed test uses `std.testing.expectError` and passes the fixed-size array by pointer with `&array`.
- Added the borrowed `Record` storage type. Its `createHeader()` method validates operation semantics and converts slice lengths to `u32` only after explicit bounds checks.
- Chose `createHeader()` over `header()` because it constructs a derived header value rather than acting as a getter; this remains allocation-free.
- Renamed the storage format module from `log_record.zig` to `storage_record.zig`; call sites import it as `storage` and use `storage.Record`, `storage.Header`, and `storage.Operation`.
- Added valid-delete and malformed-delete tests: a tombstone has an empty value, and a delete carrying value bytes returns `error.DeleteHasValue`.
- Implemented `Record.encodedLength()` using checked `std.math.add` operations so record-size arithmetic cannot silently overflow `usize`.
- Corrected `encodedLength()` to calculate header bytes plus key bytes plus value bytes.
- Session used implementation-first development followed by focused tests, rather than test-driven development.

## Current Working Shape

- `Index` exists in `src/domain/index.zig`.
- `RecordLocation` exists in `src/domain/index.zig`.
- Index tests live in `src/domain/index_test.zig`.
- Storage record format constants/types, header encoding/decoding, and a logical borrowed record type exist in `src/storage/storage_record.zig`.
- Storage record tests live in `src/storage/storage_record_test.zig`.
- `src/root.zig` imports module-specific tests for Zig test discovery.
- Tests currently verify insert/get, updating an existing key, and deleting a key.
- Storage record tests verify the logical encoded header size, explicit big-endian encoding/decoding, rejection of invalid operation tags, `put`/`delete` header construction, and rejection of delete values.
- `Record.encodedLength()` calculates the complete header, key, and value length without allocating memory and reports `error.RecordTooLarge` on arithmetic overflow.
- No persistence, sockets, or file-backed storage has been added yet.

## Next Likely Step

- Add focused `encodedLength()` tests for both `put` and `delete` records.
- After the length calculation is covered, add full record encoding for `put` and `delete`: `[header][key bytes][value bytes]` for put and `[header][key bytes]` for delete.
