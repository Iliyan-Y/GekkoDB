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
}
