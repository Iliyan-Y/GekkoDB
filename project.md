# Project Specification: GekkoDB ( in Zig )

## 1. Project Vision & High-Level Goals

GekkoDB is a custom, lightweight, high-performance NoSQL database engine designed to eliminate the massive memory overhead of traditional database systems. It is engineered from the ground up to solve the problem of high-density application hosting on highly resource-constrained hardware, such as a 4GB RAM Virtual Private Server (VPS).

By leveraging a pure systems programming approach, GekkoDB shifts away from high-level runtimes and garbage-collected environments. Instead, it relies on deterministic memory allocation, manual memory tracking, and low-level operating system primitives to ensure a completely predictable and minimal RAM footprint.

The ultimate goal of the Minimum Viable Product (MVP) is to establish a solid, corruption-proof core capable of processing high-speed, standard key-value operations with zero runtime dependencies.

---

## 2. System Architecture & Inter-Process Communication

To allow maximum flexibility across varying backend stacks (such as TypeScript, Go, or Python) while avoiding process-spawning overhead, GekkoDB uses a persistent daemon model.

### The Daemon Model

* **Persistence:** GekkoDB operates as a long-running background service that initializes once upon VPS startup. It boots its storage systems, loads structural lookup indices into memory, and continuously waits for requests.
* **Local Communication Loop:** Instead of relying on heavy HTTP network stacks or TCP ports, the server communicates with application backends via local UNIX Domain Sockets.
* **The Wire Protocol:** Communication occurs over raw byte streams. Application APIs serialize requests into structured byte payloads, write them directly to the socket file, and read raw byte responses back from the database service. This keeps communication overhead exceptionally low and fast.

---

## 3. Storage Strategy: The Hybrid Core

The storage layer relies on a specialized hybrid model that balances strict write safety with zero-copy read performance. It splits the lifetime of data into two separate states: mutable and immutable.

### The Write Path (Active Log)

* **Append-Only Operations:** All database mutations (saving a record or marking it for deletion) are sequentially appended to a single active transaction log file on disk.
* **Crash Resilience:** Because data is only appended and never modified in-place, the database is immune to mid-file corruption during unexpected system crashes or power failures. If a crash occurs, historical data remains pristine.
* **Binary Packaging:** Record keys and values are packed into a compact binary layout to avoid disk space bloat and parsing overhead.

### The Read Path (Immutable Segments & Memory-Mapping)

* **Log Rolling:** When the active transaction log reaches a configured size ceiling, the engine triggers a roll operation. The current active file is permanently closed and frozen as a read-only historical segment file. A fresh active log file is spun up to handle subsequent incoming writes.
* **Memory-Mapping (mmap):** The database maps these closed, read-only historical segment files directly into the virtual memory space of the operating system. Because these files are completely static and fixed in size, the system avoids traditional memory-mapping pitfalls like runtime file resizing failures. The host operating system handles physical file page caching and reclamation dynamically.
* **Zero-Copy Reads:** The system casts raw memory addresses from the memory-mapped files straight into structural variables. Data does not need to be read into intermediate buffers, eliminating CPU parsing and memory allocation penalties during read cycles.

### The In-Memory Index

* **Compact Tracking:** To maintain fast query lookups without keeping raw data payloads in RAM, the engine maintains a lightweight, concurrent-safe sorted index structure entirely in memory.
* **Pointer Offsets:** This index maps document string keys strictly to a compact set of metadata indicators: the specific segment file ID, the exact byte offset where the record begins, and the exact byte length of the payload.
* **State Recovery:** When the database service boots up, it runs a sequential read loop over the transaction files to quickly reconstruct this lightweight lookup index in RAM.

---

## 4. MVP Scope (Core Database Operations)

The initial version of GekkoDB is explicitly focused on mastering standard, fundamental database operations. All advanced indexing and spatial query logic are excluded to ensure absolute stability of the underlying engine.

* **Create / Update (Put):** Appends the binary data payload to the active log file and records the corresponding file offset metadata inside the in-memory lookup index.
* **Read (Get):** Queries the in-memory index to retrieve the exact file segment location and byte offset, then pulls the data bytes instantly from the memory-mapped segment without a sequential disk search.
* **Delete (Delete):** Appends a special deletion marker (a tombstone record) to the active transaction log and purges the string key from the active in-memory index, rendering it immediately inaccessible to subsequent reads.

---

## 5. Post-MVP Scope

Once the core storage mechanics, memory boundaries, and UNIX socket communication layers are proven completely stable under heavy performance tests, the engine will expand to support the following advanced capabilities:

* **Geospatial Proximity Search:** Integration of coordinates-to-geohash encoding utilities. String keys will be stored as specialized composite prefixes, allowing the engine to utilize the sorted in-memory index to perform efficient radius prefix scans without scanning unrelated disk tracks.
* **Compaction / Data Scrubbing:** A background compilation worker that sweeps through historical memory-mapped segments to scrub out dead records, overwritten updates, and active tombstones, reorganizing the files to reclaim physical disk space.

---

## 6. Phased Implementation Roadmap

### Phase 1: Communication Boundary & Daemon Setup

* Initialize the system binary structure and set up the main execution loop.
* Implement the UNIX Domain Socket server to handle persistent local connections.
* Build a minimal text protocol to verify that an external backend API (e.g., Node.js or a separate Go binary) can successfully stream binary chunks down the local socket and receive immediate acknowledgment.

### Phase 2: Explicit Memory Indexing

* Integrate a concurrent-safe, sorted structural index (such as a B-Tree or Skip List) within the system memory.
* Integrate explicit memory allocators, ensuring that all index modifications use localized allocation patterns (such as arena allocators) to guarantee a highly predictable, flat RAM footprint.
* Test index data mutations strictly within temporary memory pools to verify the absolute absence of memory leaks.

### Phase 3: The Append-Only Write System

* Build the transaction recording module responsible for structuring incoming keys and data values into sequential binary layouts.
* Implement file writing routines that handle sequential file descriptor appends for the active transaction log.
* Write the recovery initialization loop that parses the active log sequentially upon application startup to accurately populate the in-memory lookup index.

### Phase 4: Segment Rolling & Memory-Mapping

* Develop the background threshold monitor that safely locks, closes, and rolls the active log into a structured read-only data file when size limits are reached.
* Integrate low-level system calls to establish memory maps over the frozen historical files.
* Update the lookup index to swap raw references over to memory-mapped pointer offsets, completing the full hybrid storage data path.

### Phase 5: Multi-Client Verification & Stress Benchmarking

* Build automated client scripts to simulate multiple backend services writing and reading data from the database daemon concurrently.
* Execute high-volume soak tests to monitor engine performance under intensive load.
* Measure and log physical memory utilization trends, verifying that the memory footprint remains absolutely flat and completely isolated from Out-Of-Memory system events on the 4GB host VPS.
