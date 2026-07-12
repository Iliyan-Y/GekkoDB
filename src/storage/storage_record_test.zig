const storage = @import("storage_record.zig");
const std = @import("std");
const testing = std.testing;
const expectEq = testing.expectEqual;

const encodedStub = [storage.ENCODED_SIZE]u8{
    0x47, 0x4b, 0x44, 0x42,
    0x01, 0x02, 0x00, 0x00,
    0x00, 0x03, 0x00, 0x00,
    0x00, 0x05,
};

test "storage record header has expected logical size" {
    const header_size = @sizeOf(u32) + //magic
        @sizeOf(u8) + // version
        @sizeOf(u8) + // op
        @sizeOf(u32) + //key_len
        @sizeOf(u32); //value_len
    try std.testing.expectEqual(@as(usize, 14), header_size);
    try std.testing.expect(@sizeOf(storage.Header) >= header_size);
}

test "storage record header encodes as big-endian bytes" {
    const header = storage.Header{
        .magic = storage.LOG_MAGIC,
        .version = storage.LOG_VERSION,
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

test "storage record header decodes big-endian bytes" {
    const header = try storage.Header.decode(&encodedStub);
    try expectEq(storage.LOG_MAGIC, header.magic);
    try expectEq(storage.LOG_VERSION, header.version);
    try expectEq(storage.Operation.delete, header.op);
    try expectEq(@as(u32, 3), header.key_len);
    try expectEq(@as(u32, 5), header.value_len);
}

test "invalid storage operation returns an error" {
    var malfromed = encodedStub;
    malfromed[5] = 0xff;

    try testing.expectError(error.InvalidOperation, storage.Header.decode(&malfromed));
}
test "put record builds a matching header" {
    const record = storage.Record{
        .op = .put,
        .key = "cat",
        .value = "meow",
    };

    const header = try record.createHeader();

    try expectEq(storage.LOG_MAGIC, header.magic);
    try expectEq(storage.LOG_VERSION, header.version);
    try expectEq(storage.Operation.put, header.op);
    try expectEq(@as(u32, 3), header.key_len);
    try expectEq(@as(u32, 4), header.value_len);
}

test "delete record builds a header with no value" {
    const record = storage.Record{
        .op = .delete,
        .key = "lizard",
        .value = "",
    };

    const header = try record.createHeader();

    try expectEq(storage.LOG_MAGIC, header.magic);
    try expectEq(storage.LOG_VERSION, header.version);
    try expectEq(storage.Operation.delete, header.op);
    try expectEq(@as(u32, 6), header.key_len);
    try expectEq(@as(u32, 0), header.value_len);
}

test "delete record rejects a non-empty value" {
    const record = storage.Record{
        .op = .delete,
        .key = "cat",
        .value = "meow",
    };

    try testing.expectError(error.DeleteHasValue, record.createHeader());
}

test "put record calculates its encoded length" {
    const record = storage.Record{
        .op = .put,
        .key = "lizard",
        .value = "gekko",
    };

    const expectedLen = try record.encodedLength();

    try expectEq(storage.ENCODED_SIZE + record.key.len + record.value.len, expectedLen);
}
