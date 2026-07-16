const storage = @import("storage_record.zig");
const std = @import("std");
const testing = std.testing;
const expectEq = testing.expectEqual;

const encodedRecordStub = [_]u8{
    // Header
    0x47, 0x4b, 0x44, 0x42,
    0x01, 0x01, 0x00, 0x00,
    0x00, 0x05, 0x00, 0x00,
    0x00, 0x05,

    // Key: "gekko"
    0x67, 0x65,
    0x6b, 0x6b, 0x6f,

    // Value: "chirp"
    0x63,
    0x68, 0x69, 0x72, 0x70,
};

test "put record decodes borrowed key and value slices" {
    const decoded = try storage.Record.decode(&encodedRecordStub);

    try expectEq(
        storage.Operation.put,
        decoded.record.op,
    );
    try testing.expectEqualSlices(
        u8,
        "gekko",
        decoded.record.key,
    );
    try testing.expectEqualSlices(
        u8,
        "chirp",
        decoded.record.value,
    );

    try expectEq(encodedRecordStub.len, decoded.bytes);
}

test "delete record decodes a borrowed key and empty value" {
    const encoded = [_]u8{
        // Header
        0x47, 0x4b, 0x44, 0x42,
        0x01, 0x02, 0x00, 0x00,
        0x00, 0x05, 0x00, 0x00,
        0x00, 0x00,

        // Key: "gekko"
        0x67, 0x65,
        0x6b, 0x6b, 0x6f,
    };

    const decoded = try storage.Record.decode(&encoded);

    try expectEq(storage.Operation.delete, decoded.record.op);
    try testing.expectEqualSlices(u8, "gekko", decoded.record.key);
    try expectEq(@as(usize, 0), decoded.record.value.len);
    try expectEq(encoded.len, decoded.bytes);
}

test "record decoding rejects input shorter than its header" {
    const truncated = [_]u8{
        0x47, 0x4b, 0x44, 0x42,
        0x01, 0x01,
    };

    try testing.expectError(
        error.TruncatedRecord,
        storage.Record.decode(&truncated),
    );
}

test "record decoding rejects a payload shorter than declared lengths" {
    const truncated = [_]u8{
        // Header: put, key length 6, value length 4
        0x47, 0x4b, 0x44, 0x42,
        0x01, 0x01, 0x00, 0x00,
        0x00, 0x06, 0x00, 0x00,
        0x00, 0x04,

        // Complete key: "lizard", but the value is missing
        0x6c, 0x69,
        0x7a, 0x61, 0x72, 0x64,
    };

    try testing.expectError(
        error.TruncatedRecord,
        storage.Record.decode(&truncated),
    );
}

test "record decoding rejects an invalid magic number" {
    var malformed = encodedRecordStub;
    malformed[0] = 0x00;

    try testing.expectError(
        error.InvalidMagic,
        storage.Record.decode(&malformed),
    );
}

test "record decoding rejects an unsupported version" {
    var malformed = encodedRecordStub;
    malformed[4] = storage.LOG_VERSION + 1;

    try testing.expectError(
        error.UnsupportedVersion,
        storage.Record.decode(&malformed),
    );
}

test "record decoding rejects a delete with a value" {
    var malformed = encodedRecordStub;
    malformed[5] = @intFromEnum(storage.Operation.delete);

    try testing.expectError(
        error.DeleteHasValue,
        storage.Record.decode(&malformed),
    );
}

test "consecutive records decode by advancing the consumed  byte count" {
    const encoded_delete = [_]u8{
        // Header: delete, key length 6, value length 0
        0x47, 0x4b, 0x44, 0x42,
        0x01, 0x02, 0x00, 0x00,
        0x00, 0x06, 0x00, 0x00,
        0x00, 0x00,

        // Key: "lizard"
        0x6c, 0x69,
        0x7a, 0x61, 0x72, 0x64,
    };

    const log_bytes = encodedRecordStub ++ encoded_delete;

    const first = try storage.Record.decode(&log_bytes);
    const second = try storage.Record.decode(log_bytes[first.bytes..]);

    try expectEq(storage.Operation.put, first.record.op);
    try testing.expectEqualSlices(u8, "gekko", first.record.key);

    try expectEq(storage.Operation.delete, second.record.op);
    try testing.expectEqualSlices(u8, "lizard", second.record.key);
    try expectEq(@as(usize, 0), second.record.value.len);

    try expectEq(log_bytes.len, first.bytes + second.bytes);
}
