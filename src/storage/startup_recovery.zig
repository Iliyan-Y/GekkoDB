const std = @import("std");
const active_log = @import("active_log.zig");
const domain = @import("../domain/index.zig");
const recovery = @import("recovery.zig");

pub fn recoverActiveLog(
    allocator: std.mem.Allocator,
    index: *domain.Index,
    segment_id: u32,
    log: *active_log.ActiveLog,
) !recovery.RecoveryResult {
    const bytes = try log.readAllAlloc(allocator);
    defer allocator.free(bytes);

    const result = try recovery.recoverActiveSegment(index, segment_id, bytes);

    if (result.discarded_tail_bytes != 0) {
        const valid_length = std.math.cast(
            u64,
            result.valid_bytes,
        ) orelse return error.ValidLengthTooLarge;

        try log.truncateTo(valid_length);
        try log.sync();
    }

    return result;
}
