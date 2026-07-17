const recovery = @import("recovery.zig");
const storage = @import("storage_record.zig");
const domain = @import("../domain/index.zig");
const std = @import("std");
const testing = std.testing;
const expectEq = testing.expectEqual;

test "recovery indexes put records in storage order" {
    const k_1 = "lizard";
    const v_1 = "green";
    const k_2 = "gekko";
    const v_2 = "blue";
    const lizard = storage.Record{
        .op = .put,
        .key = k_1,
        .value = v_1,
    };
    const gekko = storage.Record{
        .op = .put,
        .key = k_2,
        .value = v_2,
    };
    var segment: [
        storage.ENCODED_SIZE * 2 + k_1.len + k_2.len +
            v_1.len + v_2.len
    ]u8 = undefined;

    var cursor: usize = 0;

    cursor += try lizard.encodeInto(segment[cursor..]);
    const gekko_offset = cursor;
    cursor += try gekko.encodeInto(segment[cursor..]);

    try expectEq(segment.len, cursor);

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    try recovery.recoverSegment(&index, 7, segment[0..cursor]);
    const lizard_location = index.get(k_1).?;
    const gekko_location = index.get(k_2).?;

    try expectEq(@as(u64, 0), lizard_location.offset);
    try expectEq(
        @as(u32, @intCast(try lizard.encodedLength())),
        lizard_location.length,
    );
    try expectEq(
        @as(u64, @intCast(gekko_offset)),
        gekko_location.offset,
    );
    try expectEq(
        @as(u32, @intCast(try gekko.encodedLength())),
        gekko_location.length,
    );
    try expectEq(@as(u32, 7), lizard_location.segment_id);
    try expectEq(@as(u32, 7), gekko_location.segment_id);
}
test "recovery removes a key when replaying a tombstone" {
    const k = "lizard";
    const del_lizard = storage.Record{
        .op = .delete,
        .key = k,
        .value = "",
    };

    var segment: [storage.ENCODED_SIZE + k.len]u8 = undefined;

    const written = try del_lizard.encodeInto(&segment);
    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    try index.put(k, .{
        .segment_id = 3,
        .offset = 128,
        .length = 25,
    });

    try recovery.recoverSegment(
        &index,
        3,
        segment[0..written],
    );
    try testing.expect(index.get(k) == null);
}

test "active recovery reports a completely valid segment" {
    const key = "gekko";
    const value = "green";
    const record = storage.Record{
        .op = .put,
        .key = key,
        .value = value,
    };

    var segment: [storage.ENCODED_SIZE + key.len + value.len]u8 = undefined;
    const written = try record.encodeInto(&segment);

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    const result = try recovery.recoverActiveSegment(
        &index,
        9,
        segment[0..written],
    );

    try expectEq(written, result.valid_bytes);
    try expectEq(@as(usize, 0), result.discarded_tail_bytes);

    const location = index.get(key).?;
    try expectEq(@as(u32, 9), location.segment_id);
    try expectEq(@as(u64, 0), location.offset);
    try expectEq(@as(u32, @intCast(written)), location.length);
}

test "active recovery reports an incomplete header as a torn tail" {
    const key = "lizard";
    const value = "green";
    const record = storage.Record{
        .op = .put,
        .key = key,
        .value = value,
    };

    var segment: [storage.ENCODED_SIZE + key.len + value.len + 3]u8 = undefined;
    const written = try record.encodeInto(&segment);
    @memcpy(segment[written..], &[_]u8{ 0x47, 0x4b, 0x44 });

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    const result = try recovery.recoverActiveSegment(&index, 4, &segment);

    try expectEq(written, result.valid_bytes);
    try expectEq(@as(usize, 3), result.discarded_tail_bytes);
    try testing.expect(index.get(key) != null);
}

test "active recovery discards an incomplete record payload" {
    const first = storage.Record{
        .op = .put,
        .key = "lizard",
        .value = "green",
    };
    const second = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "blue",
    };

    var segment: [
        storage.ENCODED_SIZE * 2 + "lizard".len + "green".len +
            "gekko".len + "blue".len
    ]u8 = undefined;

    const first_bytes = try first.encodeInto(&segment);
    const second_bytes = try second.encodeInto(segment[first_bytes..]);
    const visible_bytes = first_bytes + second_bytes - 1;

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    const result = try recovery.recoverActiveSegment(
        &index,
        5,
        segment[0..visible_bytes],
    );

    try expectEq(first_bytes, result.valid_bytes);
    try expectEq(visible_bytes - first_bytes, result.discarded_tail_bytes);
    try testing.expect(index.get("lizard") != null);
    try testing.expect(index.get("gekko") == null);
}

test "active recovery still rejects known record corruption" {
    const first = storage.Record{
        .op = .put,
        .key = "lizard",
        .value = "green",
    };
    const second = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "blue",
    };

    var segment: [
        storage.ENCODED_SIZE * 2 + "lizard".len + "green".len +
            "gekko".len + "blue".len
    ]u8 = undefined;

    const first_bytes = try first.encodeInto(&segment);
    _ = try second.encodeInto(segment[first_bytes..]);
    segment[first_bytes] = 0;

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    try testing.expectError(
        error.InvalidMagic,
        recovery.recoverActiveSegment(&index, 6, &segment),
    );

    try testing.expect(index.get("lizard") != null);
    try testing.expect(index.get("gekko") == null);
}

test "strict segment recovery rejects a torn tail" {
    const record = storage.Record{
        .op = .put,
        .key = "gekko",
        .value = "green",
    };

    var segment: [storage.ENCODED_SIZE + "gekko".len + "green".len]u8 = undefined;
    const written = try record.encodeInto(&segment);

    var index = domain.Index.init(testing.allocator);
    defer index.deinit();

    try testing.expectError(
        error.TruncatedRecord,
        recovery.recoverSegment(&index, 8, segment[0 .. written - 1]),
    );
}
