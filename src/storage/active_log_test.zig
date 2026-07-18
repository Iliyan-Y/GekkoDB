const std = @import("std");
const active_log = @import("active_log.zig");
const storage = @import("storage_record.zig");

const testing = std.testing;

test "active log appends encoded bytes at consecutive offsets" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    const first = "first-record";
    const second = "second-record";

    const first_offset = try log.appendEncoded(first);
    const second_offset = try log.appendEncoded(second);

    try testing.expectEqual(
        @as(u64, 0),
        first_offset,
    );
    try testing.expectEqual(
        @as(u64, first.len),
        second_offset,
    );

    try log.sync();

    const stored = try tmp.dir.readFileAlloc(
        io,
        "active.gkdb",
        testing.allocator,
        .limited(64),
    );
    defer testing.allocator.free(stored);

    try testing.expectEqualSlices(
        u8,
        first ++ second,
        stored,
    );
}

test "active log resumes at the existing file length" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const before_restart = "before-restart";
    const after_restart = "after-restart";

    {
        var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
        defer log.deinit();

        _ = try log.appendEncoded(before_restart);
        try log.sync();
    }

    var reopened = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer reopened.deinit();

    const offset = try reopened.appendEncoded(after_restart);
    try testing.expectEqual(@as(u64, before_restart.len), offset);

    try reopened.sync();

    const stored = try tmp.dir.readFileAlloc(
        io,
        "active.gkdb",
        testing.allocator,
        .limited(64),
    );
    defer testing.allocator.free(stored);

    try testing.expectEqualSlices(
        u8,
        before_restart ++ after_restart,
        stored,
    );
}

test "active log rejects offset overflow before writing" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    log.next_offset = std.math.maxInt(u64);

    try testing.expectError(
        error.LogTooLarge,
        log.appendEncoded("x"),
    );
    try testing.expectEqual(
        std.math.maxInt(u64),
        log.next_offset,
    );
    try testing.expectEqual(
        @as(u64, 0),
        try log.file.length(io),
    );
}

test "active log stores a decodable storage record" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "green",
    };
    var encoded: [storage.ENCODED_SIZE + "gekko".len + "green".len]u8 = undefined;
    const encoded_length = try record.encodeInto(&encoded);

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    const offset = try log.appendEncoded(encoded[0..encoded_length]);
    try testing.expectEqual(@as(u64, 0), offset);
    try log.sync();

    const stored = try tmp.dir.readFileAlloc(
        io,
        "active.gkdb",
        testing.allocator,
        .limited(64),
    );
    defer testing.allocator.free(stored);

    const decoded = try storage.Record.decode(stored);
    try testing.expectEqual(encoded_length, decoded.bytes);
    try testing.expectEqual(storage.Operation.put, decoded.record.op);
    try testing.expectEqualSlices(u8, record.key, decoded.record.key);
    try testing.expectEqualSlices(u8, record.value, decoded.record.value);
}

test "active log reads an exact owned byte range" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    const first = "gekko-record";
    const second = "lizard-record";

    _ = try log.appendEncoded(first);
    _ = try log.appendEncoded(second);

    const bytes = try log.readRangeAlloc(
        testing.allocator,
        first.len,
        @intCast(second.len),
    );
    defer testing.allocator.free(bytes);

    try testing.expectEqualSlices(u8, second, bytes);
}

test "active log rejects invalid read ranges before allocating" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    _ = try log.appendEncoded("gekko");

    try testing.expectError(
        error.InvalidReadRange,
        log.readRangeAlloc(testing.allocator, 4, 2),
    );
    try testing.expectError(
        error.InvalidReadRange,
        log.readRangeAlloc(testing.allocator, std.math.maxInt(u64), 1),
    );
}
