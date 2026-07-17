const std = @import("std");
const active_log = @import("active_log.zig");
const domain = @import("../domain/index.zig");
const startup_recovery = @import("startup_recovery.zig");
const storage = @import("storage_record.zig");

const testing = std.testing;
const expectEq = testing.expectEqual;

test "startup recovery preserves a completely valid active log" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "green",
    };
    var encoded: [storage.ENCODED_SIZE + "gekko".len + "green".len]u8 = undefined;
    const written = try record.encodeInto(&encoded);

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    _ = try log.appendEncoded(encoded[0..written]);
    try log.sync();

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    const result = try startup_recovery.recoverActiveLog(
        testing.allocator,
        &index,
        12,
        &log,
    );

    try expectEq(written, result.valid_bytes);
    try expectEq(@as(usize, 0), result.discarded_tail_bytes);
    try expectEq(@as(u64, @intCast(written)), log.next_offset);
    try expectEq(log.next_offset, try log.file.length(io));

    const location = index.get("gekko").?;
    try expectEq(@as(u32, 12), location.segment_id);
    try expectEq(@as(u64, 0), location.offset);
    try expectEq(@as(u32, @intCast(written)), location.length);
}

test "startup recovery truncates a torn active log tail" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "lizard",
        .value = "green",
    };
    var encoded: [storage.ENCODED_SIZE + "lizard".len + "green".len]u8 = undefined;
    const written = try record.encodeInto(&encoded);

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    _ = try log.appendEncoded(encoded[0..written]);
    _ = try log.appendEncoded(&[_]u8{ 0x47, 0x4b, 0x44 });
    try log.sync();

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    const result = try startup_recovery.recoverActiveLog(
        testing.allocator,
        &index,
        13,
        &log,
    );

    const valid_length = @as(u64, @intCast(written));
    try expectEq(written, result.valid_bytes);
    try expectEq(@as(usize, 3), result.discarded_tail_bytes);
    try expectEq(valid_length, log.next_offset);
    try expectEq(valid_length, try log.file.length(io));
    try testing.expect(index.get("lizard") != null);

    const next_offset = try log.appendEncoded("next-record");
    try expectEq(valid_length, next_offset);
}

test "startup recovery does not truncate recognizable corruption" {
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const record = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "blue",
    };
    var encoded: [storage.ENCODED_SIZE + "gekko".len + "blue".len]u8 = undefined;
    const written = try record.encodeInto(&encoded);
    encoded[0] = 0;

    var log = try active_log.ActiveLog.open(tmp.dir, io, "active.gkdb");
    defer log.deinit();

    _ = try log.appendEncoded(encoded[0..written]);
    try log.sync();
    const original_length = log.next_offset;

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    try testing.expectError(
        error.InvalidMagic,
        startup_recovery.recoverActiveLog(
            testing.allocator,
            &index,
            14,
            &log,
        ),
    );

    try expectEq(original_length, log.next_offset);
    try expectEq(original_length, try log.file.length(io));
    try testing.expect(index.get("gekko") == null);
}
