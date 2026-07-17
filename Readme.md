# GekkoDB

GekkoDB is a lightweight NoSQL database daemon written in Zig. It uses an
append-only binary log for durable writes and a compact in-memory index that
maps keys to record locations instead of keeping document values in RAM.

The project is currently under development. See `project.md` for the product
direction and phased roadmap.

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
