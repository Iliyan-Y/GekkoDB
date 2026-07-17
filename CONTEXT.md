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
- Implemented `Record.encodeInto()` for allocation-free encoding into caller-owned buffers.
- Implemented borrowed record decoding with validation for magic, format version, operation semantics, truncated headers, and truncated payloads.
- Split decoding coverage into `src/storage/storage_record_decode_test.zig` to keep tests focused and file sizes manageable.
- Added tests for put and delete decoding, consecutive records, malformed metadata, and incomplete records.
- Added `RecordScanner` in `src/storage/record_scanner.zig` to iterate over consecutive encoded records without allocating or copying key/value bytes.
- `RecordScanner.next()` returns the record's starting offset and encoded byte length, returns `null` at a clean end of input, and does not advance its offset when decoding fails.
- Added `recoverSegment()` in `src/storage/recovery.zig` to replay one segment into the in-memory index in storage order.
- Recovery stores put locations using the segment ID, encoded-record offset, and complete encoded-record length; delete tombstones remove the corresponding live index entry.
- Recovery performs checked conversions from memory-oriented `usize` offsets/lengths to the compact fixed-width fields in `RecordLocation`.
- Recovery tests construct segment bytes programmatically with `Record.encodeInto()` instead of duplicating binary fixtures.
- Put and delete recovery behavior have separate tests. Put recovery verifies segment ID, offset, and length; delete recovery verifies tombstone removal.
- New examples use lizard/gekko terminology rather than cats.
- Added `ActiveLog` in `src/storage/active_log.zig` as the file-backed append adapter.
- `ActiveLog.open()` owns its file handle, preserves existing bytes with `truncate = false`, and initializes `next_offset` from the existing file length.
- `appendEncoded()` borrows a caller-owned encoded byte slice, writes it positionally without allocating, returns its starting offset, and advances state only after a successful write.
- Durability is explicit: `appendEncoded()` does not sync automatically; callers choose when to call `ActiveLog.sync()` so the future engine can support per-write or batched durability policies.
- Active-log tests cover consecutive offsets and bytes, restart/reopen behavior, offset overflow before mutation, and integration with a decodable storage record.
- `zig build test` passed with the active-log tests included in `src/root.zig`.
- Added `RecoveryResult` with `valid_bytes` and `discarded_tail_bytes` so active-log recovery can report the last safe file boundary without performing file I/O itself.
- Extracted shared single-record replay logic inside `src/storage/recovery.zig`; strict and active recovery now apply decoded records to the index identically.
- Added `recoverActiveSegment()`. It treats only `error.TruncatedRecord` as a recoverable crash-torn tail and continues to propagate known corruption such as invalid magic, version, or operation metadata.
- Kept `recoverSegment()` strict for immutable historical segments; an incomplete record remains a startup error there.
- Added post-development recovery tests for a clean active segment, incomplete header, incomplete payload, known corruption, and strict recovery of a torn tail.
- The newly added recovery tests have not yet been confirmed with `zig build test`; the user will run tests and report failures.

## Current Working Shape

- `Index` exists in `src/domain/index.zig`.
- `RecordLocation` exists in `src/domain/index.zig`.
- Index tests live in `src/domain/index_test.zig`.
- Storage record format constants/types, header encoding/decoding, and a logical borrowed record type exist in `src/storage/storage_record.zig`.
- Storage record encoding tests live in `src/storage/storage_record_test.zig`; decoding and corruption tests live in `src/storage/storage_record_decode_test.zig`.
- `Record.encodeInto()` writes `[header][key][value]` into caller-owned memory without allocating.
- `Record.decode()` returns borrowed key/value slices and the number of encoded bytes consumed.
- `RecordScanner` exists in `src/storage/record_scanner.zig`, with focused tests in `src/storage/record_scanner_test.zig`.
- Segment recovery exists in `src/storage/recovery.zig`, with focused put and tombstone tests in `src/storage/recovery_test.zig`.
- The file-backed active log exists in `src/storage/active_log.zig`, with focused tests in `src/storage/active_log_test.zig`.
- Active-log writes are unbuffered positional writes of already encoded caller-owned bytes; syncing remains an explicit caller decision.
- `src/root.zig` imports module-specific tests for Zig test discovery.
- Tests currently verify insert/get, updating an existing key, and deleting a key.
- Storage record tests verify the logical encoded header size, explicit big-endian encoding/decoding, invalid operation tags, format metadata, truncation handling, `put`/`delete` semantics, and consecutive record decoding.
- `Record.encodedLength()` calculates the complete header, key, and value length without allocating memory and reports `error.RecordTooLarge` on arithmetic overflow.
- Recovery currently operates on an in-memory byte slice; it does not open, map, repair, or persist files.
- Active recovery reports the safe byte boundary and damaged-tail length but does not yet truncate the active-log file.
- `RecordLocation.length` currently means the complete encoded record length, allowing the future read path to slice exactly one record before decoding it.
- No file-backed startup recovery, database engine API, read path, Unix socket protocol, concurrency control, segment rolling, mmap integration, checksum, or compaction exists yet.

## Next Likely Step

- Connect file startup recovery to `recoverActiveSegment()`: read the active file, replay it, and truncate it to `valid_bytes` when `discarded_tail_bytes` is nonzero.
- Preserve the chosen policy: incomplete active-log tails are recoverable, immutable segment tails and recognizable corruption remain startup errors.
- After file append and recovery work, introduce a small database engine that coordinates storage and the index for `put`, `get`, and `delete`.
- Unix domain sockets, multi-client synchronization, segment rolling, mmap reads, checksums, and stress testing remain later MVP work.
