const log = @import("log_record.zig");
const std = @import("std");
const testing = std.testing;
const expectEq = testing.expectEqual;

const encodedStub = [log.encoded_size]u8{
    0x47, 0x4b, 0x44, 0x42,
    0x01, 0x02, 0x00, 0x00,
    0x00, 0x03, 0x00, 0x00,
    0x00, 0x05,
};

test "log record header has expected logical size" {
    const header_size = @sizeOf(u32) + //magic
        @sizeOf(u8) + // version
        @sizeOf(u8) + // op
        @sizeOf(u32) + //key_len
        @sizeOf(u32); //value_len
    try std.testing.expectEqual(@as(usize, 14), header_size);
    try std.testing.expect(@sizeOf(log.LogRecordHeader) >= header_size);
}

test "log record header encodes as big-endian bytes" {
    const header = log.LogRecordHeader{
        .magic = log.LOG_MAGIC,
        .version = log.LOG_VERSION,
        .op = .put,
        .key_len = 3,
        .value_len = 5,
    };
    var encoded: [14]u8 = undefined;
    header.encode(&encoded);

    try std.testing.expectEqualSlices(u8, &.{
        0x47, 0x4b, 0x44, 0x42,
        0x01, 0x01, 0x00, 0x00,
        0x00, 0x03, 0x00, 0x00,
        0x00, 0x05,
    }, &encoded);
}

test "log record header decodes big-endian bytes" {
    const header = try log.LogRecordHeader.decode(&encodedStub);
    try expectEq(log.LOG_MAGIC, header.magic);
    try expectEq(log.LOG_VERSION, header.version);
    try expectEq(log.LogOp.delete, header.op);
    try expectEq(@as(u32, 3), header.key_len);
    try expectEq(@as(u32, 5), header.value_len);
}

test "invalid log Op throws error" {
    var malfromed = encodedStub;
    malfromed[5] = 0xff;

    try testing.expectError(error.InvalidOperation, log.LogRecordHeader.decode(&malfromed));
}
test "put record builds a matching header" {
    const record = log.LogRecord{
        .op = .put,
        .key = "cat",
        .value = "meow",
    };

    const header = try record.createHeader();

    try expectEq(log.LOG_MAGIC, header.magic);
    try expectEq(log.LOG_VERSION, header.version);
    try expectEq(log.LogOp.put, header.op);
    try expectEq(@as(u32, 3), header.key_len);
    try expectEq(@as(u32, 4), header.value_len);
}
