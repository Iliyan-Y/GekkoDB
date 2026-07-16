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
