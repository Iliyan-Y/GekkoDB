# Project Memory

## Session Notes

- Started with the Zig scaffold and chose an in-memory key/value store as the first learning boundary.
- Used `src/root.zig` for the first tests because it is the shared module boundary in the current scaffold.
- Added a test for `put`, `get`, and `delete`.
- Added a second test to expose ownership problems by mutating caller-owned buffers after insertion.
- Fixed the store so it owns key/value bytes by duplicating them into the allocator and freeing them on delete/deinit.
- Learned that `StringHashMap` stores the value slice but does not manage nested heap ownership automatically.
- Zig lesson from this session: `[]const u8` can be borrowed data or owned data depending on how it was created; tests should make that distinction explicit.

## Current Working Shape

- `KeyValueStore` exists in `src/root.zig`.
- Tests currently verify insert/read/delete and ownership independence from caller buffers.
- No persistence, sockets, or file-backed storage has been added yet.

## Next Likely Step

- Add an overwrite/update test to define behavior when the same key is written twice.
