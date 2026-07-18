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
