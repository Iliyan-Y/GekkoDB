const log = @import("log_record.zig");
const std = @import("std");

test "log record header has expected logical size" {
    const header_size = @sizeOf(u32) + //magic
        @sizeOf(u8) + // version
        @sizeOf(u8) + // op
        @sizeOf(u32) + //key_len
        @sizeOf(u32); //value_len
    try std.testing.expectEqual(@as(usize, 14), header_size);
    try std.testing.expect(@sizeOf(log.LogRecordHeader) >= header_size);
}
