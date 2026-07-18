# GekkoDB

GekkoDB is a lightweight NoSQL database daemon written in Zig. It uses an
append-only binary log for durable writes and a compact in-memory index that
maps keys to record locations instead of keeping document values in RAM.

The project is currently under development. See `project.md` for the product
direction and phased roadmap.

## Application-level durable write path

The database engine coordinates binary encoding, file persistence, and index
updates. A `put` follows this order:

```text
borrow the caller's key and value
        |
calculate and validate the encoded record length
        |
allocate a temporary encoding buffer
        |
encode [header][key][value] into that buffer
        |
append the encoded bytes to the active log
        |
sync the active log to durable storage
        |
update the in-memory index with the record location
        |
free the temporary encoding buffer
```

The ordering is part of the database correctness contract. The in-memory
index is updated only after the complete record has been appended and synced.
Therefore, a successful `put` means the record is both durable and visible
through the current index.

The temporary encoded buffer has a short, explicit lifetime. The engine owns
and frees it after the operation. `ActiveLog.appendEncoded()` borrows the
buffer only while writing, and `Index.put()` duplicates and owns the key when
a new index entry is required. Values remain in the log rather than being
retained in memory.

If append or sync fails, the index is not updated and the operation returns an
error. A sync failure may still leave complete bytes in the log, because an
I/O error cannot prove that no bytes reached storage. On the next successful
startup, recovery scans the log and reconstructs the authoritative index from
every valid complete record.

Per-write syncing is the initial durability policy. A future batching policy
must remain explicit so callers know whether an acknowledged write is already
durable.

## Startup recovery memory ownership

At startup, GekkoDB reconstructs its in-memory index by reading and scanning
the active log. The temporary file buffer has one clear owner, while the
record decoder and scanner only borrow slices from it:

```text
ActiveLog.readAllAlloc() allocates and returns the file bytes
        |
startup recovery temporarily owns the returned buffer
        |
RecordScanner borrows record, key, and value slices from that buffer
        |
Index.put() duplicates and owns each live key
        |
startup recovery frees the temporary file buffer
```

The `Alloc` suffix in `readAllAlloc` follows a useful Zig naming convention:
the caller owns the returned allocation and must eventually release it with
the same allocator:

```zig
const bytes = try active_log.readAllAlloc(allocator);
defer allocator.free(bytes);
```

`RecordScanner` does not allocate or copy record data. Its decoded key and
value slices are only valid while the temporary file buffer remains alive.
`Index.put()` duplicates a key before storing it, so the index does not retain
a dangling reference when recovery frees that buffer. Values remain on disk;
the index stores only the segment ID, byte offset, and encoded record length.

This separates three memory responsibilities:

- `ActiveLog` is the filesystem adapter and creates the temporary allocation.
- Startup recovery owns and eventually frees that allocation.
- `Index` owns only the duplicated keys needed after recovery.

The read operation also verifies that the number of bytes read matches the
expected active-log length. A shorter read indicates that the file changed
unexpectedly during startup and must not be silently accepted.

## Crash-torn active-log tails

Recovery treats an incomplete final active-log record as a crash-torn tail.
It reports both the last valid byte boundary and the number of bytes to
discard. The file adapter can then truncate the active log to that boundary.

Recognizable corruption, such as invalid magic bytes, an unsupported format
version, or an unknown operation, remains a startup error. Immutable
historical segments also use strict recovery and do not tolerate incomplete
records.
