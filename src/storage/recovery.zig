const std = @import("std");
const domain = @import("../domain/index.zig");
const scanning = @import("record_scanner.zig");

pub fn recoverSegment(
    index: *domain.Index,
    segment_id: u32,
    segment_bytes: []const u8,
) !void {
    var scanner = scanning.RecordScanner.init(segment_bytes);

    while (try scanner.next()) |scanned| {
        switch (scanned.record.op) {
            .put => {
                const offset = std.math.cast(
                    u64,
                    scanned.offset,
                ) orelse return error.RecordOffsetTooLarge;

                const length = std.math.cast(
                    u32,
                    scanned.bytes,
                ) orelse return error.RecordTooLarge;

                try index.put(scanned.record.key, .{
                    .segment_id = segment_id,
                    .offset = offset,
                    .length = length,
                });
            },
            .delete => index.delete(scanned.record.key),
            else => unreachable,
        }
    }
}
