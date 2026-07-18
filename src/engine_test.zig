const std = @import("std");
const engine_module = @import("engine.zig");
const active_log = @import("storage/active_log.zig");
const storage = @import("storage/storage_record.zig");

const testing = std.testing;

test "engine opens an empty active log" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        7,
    );
    defer engine.deinit();

    try testing.expectEqual(@as(u32, 7), engine.active_segment_id);
    try testing.expectEqual(@as(u64, 0), engine.active_log.next_offset);
    try testing.expect(engine.index.get("gekko") == null);
}

test "engine rebuilds its index from an existing active log" {
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

    {
        var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
        defer log.deinit();

        _ = try log.appendEncoded(encoded[0..encoded_length]);
        try log.sync();
    }

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        9,
    );
    defer engine.deinit();

    const location = engine.index.get("gekko").?;
    try testing.expectEqual(@as(u32, 9), location.segment_id);
    try testing.expectEqual(@as(u64, 0), location.offset);
    try testing.expectEqual(@as(u32, @intCast(encoded_length)), location.length);
}

test "engine repairs a torn active log tail during open" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "lizard",
        .value = "amber",
    };
    var encoded: [storage.ENCODED_SIZE + "lizard".len + "amber".len]u8 = undefined;
    const encoded_length = try record.encodeInto(&encoded);

    {
        var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
        defer log.deinit();

        _ = try log.appendEncoded(encoded[0..encoded_length]);
        _ = try log.appendEncoded(&[_]u8{ 0x47, 0x4b, 0x44 });
        try log.sync();
    }

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        11,
    );
    defer engine.deinit();

    const valid_length: u64 = @intCast(encoded_length);
    try testing.expectEqual(valid_length, engine.active_log.next_offset);
    try testing.expectEqual(valid_length, try engine.active_log.file.length(io));
    try testing.expect(engine.index.get("lizard") != null);
}

test "engine rejects recognizable active log corruption" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "blue",
    };
    var encoded: [storage.ENCODED_SIZE + "gekko".len + "blue".len]u8 = undefined;
    const encoded_length = try record.encodeInto(&encoded);
    encoded[0] = 0;

    {
        var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
        defer log.deinit();

        _ = try log.appendEncoded(encoded[0..encoded_length]);
        try log.sync();
    }

    try testing.expectError(
        error.InvalidMagic,
        engine_module.Engine.open(
            testing.allocator,
            tmp.dir,
            io,
            "active.gkdb",
            13,
        ),
    );
}

test "engine put appends records and indexes their locations" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        17,
    );
    defer engine.deinit();

    try engine.put("gekko", "green");
    try engine.put("lizard", "amber");

    const first_length = storage.ENCODED_SIZE + "gekko".len + "green".len;
    const second_length = storage.ENCODED_SIZE + "lizard".len + "amber".len;

    const first_location = engine.index.get("gekko").?;
    try testing.expectEqual(@as(u32, 17), first_location.segment_id);
    try testing.expectEqual(@as(u64, 0), first_location.offset);
    try testing.expectEqual(@as(u32, first_length), first_location.length);

    const second_location = engine.index.get("lizard").?;
    try testing.expectEqual(@as(u32, 17), second_location.segment_id);
    try testing.expectEqual(@as(u64, first_length), second_location.offset);
    try testing.expectEqual(@as(u32, second_length), second_location.length);

    const stored = try tmp.dir.readFileAlloc(
        io,
        "active.gkdb",
        testing.allocator,
        .limited(128),
    );
    defer testing.allocator.free(stored);

    const first = try storage.Record.decode(stored);
    const second = try storage.Record.decode(stored[first.bytes..]);

    try testing.expectEqual(storage.Operation.put, first.record.op);
    try testing.expectEqualSlices(u8, "gekko", first.record.key);
    try testing.expectEqualSlices(u8, "green", first.record.value);
    try testing.expectEqual(storage.Operation.put, second.record.op);
    try testing.expectEqualSlices(u8, "lizard", second.record.key);
    try testing.expectEqualSlices(u8, "amber", second.record.value);
}

test "engine put does not retain caller-owned buffers" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        19,
    );
    defer engine.deinit();

    var key = [_]u8{ 'g', 'e', 'k', 'k', 'o' };
    var value = [_]u8{ 'g', 'r', 'e', 'e', 'n' };

    try engine.put(&key, &value);

    @memset(&key, 'x');
    @memset(&value, 'y');

    try testing.expect(engine.index.get("gekko") != null);
    try testing.expect(engine.index.get("xxxxx") == null);

    const stored = try tmp.dir.readFileAlloc(
        io,
        "active.gkdb",
        testing.allocator,
        .limited(64),
    );
    defer testing.allocator.free(stored);

    const decoded = try storage.Record.decode(stored);
    try testing.expectEqualSlices(u8, "gekko", decoded.record.key);
    try testing.expectEqualSlices(u8, "green", decoded.record.value);
}

test "engine get returns an owned value and null for a missing key" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var engine = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        21,
    );
    defer engine.deinit();

    try testing.expect((try engine.getAlloc(
        testing.allocator,
        "missing",
    )) == null);

    try engine.put("gekko", "green");

    const first = (try engine.getAlloc(
        testing.allocator,
        "gekko",
    )).?;
    defer testing.allocator.free(first);

    try engine.put("gekko", "blue");

    const latest = (try engine.getAlloc(
        testing.allocator,
        "gekko",
    )).?;
    defer testing.allocator.free(latest);

    try testing.expectEqualSlices(u8, "green", first);
    try testing.expectEqualSlices(u8, "blue", latest);
}

test "engine get reads a record recovered after restart" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    {
        var engine = try engine_module.Engine.open(
            testing.allocator,
            tmp.dir,
            io,
            "active.gkdb",
            23,
        );
        defer engine.deinit();

        try engine.put("lizard", "amber");
    }

    var reopened = try engine_module.Engine.open(
        testing.allocator,
        tmp.dir,
        io,
        "active.gkdb",
        23,
    );
    defer reopened.deinit();

    const value = (try reopened.getAlloc(
        testing.allocator,
        "lizard",
    )).?;
    defer testing.allocator.free(value);

    try testing.expectEqualSlices(u8, "amber", value);
}
