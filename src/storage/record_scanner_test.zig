const scanner_module = @import("record_scanner.zig");
const storage = @import("storage_record.zig");
const std = @import("std");
const testing = std.testing;
const expectEq = testing.expectEqual;

const encoded_log = [_]u8{
    // Put "lizard" = "green"
    0x47, 0x4b, 0x44, 0x42,
    0x01, 0x01, 0x00, 0x00,
    0x00, 0x06, 0x00, 0x00,
    0x00, 0x05, 0x6c, 0x69,
    0x7a, 0x61, 0x72, 0x64,
    0x67, 0x72, 0x65, 0x65,
    0x6e,

    // Delete "gekko"
    0x47, 0x4b, 0x44,
    0x42, 0x01, 0x02, 0x00,
    0x00, 0x00, 0x05, 0x00,
    0x00, 0x00, 0x00, 0x67,
    0x65, 0x6b, 0x6b, 0x6f,
};

test "scanner returns consecutive records with their offsets" {
    var scanner = scanner_module.RecordScanner.init(&encoded_log);

    // The .? unwraps an optional value. It is appropriate after
    // constructing a fixture known to contain two records.
    // Production recovery code must handle null instead of assuming
    // a record exists.
    const first = (try scanner.next()).?;
    const second = (try scanner.next()).?;

    try expectEq(@as(usize, 0), first.offset);
    try expectEq(storage.Operation.put, first.record.op);
    try testing.expectEqualSlices(u8, "lizard", first.record.key);
    try testing.expectEqualSlices(u8, "green", first.record.value);

    try expectEq(first.bytes, second.offset);
    try expectEq(storage.Operation.delete, second.record.op);
    try testing.expectEqualSlices(u8, "gekko", second.record.key);
    try expectEq(@as(usize, 0), second.record.value.len);

    try expectEq(encoded_log.len, first.bytes +
        second.bytes);
    try testing.expect((try scanner.next()) == null);
}

test "scanner remains at the failing record after a decode error" {
    const truncated_log = encoded_log[0 .. encoded_log.len - 1];
    var scanner = scanner_module.RecordScanner.init(truncated_log);

    const first = (try scanner.next()).?;
    const failing_offset = scanner.offset;

    try testing.expectError(
        error.TruncatedRecord,
        scanner.next(),
    );

    try expectEq(first.bytes, failing_offset);
    try expectEq(failing_offset, scanner.offset);
}
