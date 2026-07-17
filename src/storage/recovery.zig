const std = @import("std");
const domain = @import("../domain/index.zig");
const scanning = @import("record_scanner.zig");

pub const RecoveryResult = struct {
    valid_bytes: usize,
    discarded_tail_bytes: usize,
};

fn applyScannedRecord(
    index: *domain.Index,
    segment_id: u32,
    scanned: scanning.ScannedRecord,
) !void {
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

pub fn recoverSegment(
    index: *domain.Index,
    segment_id: u32,
    segment_bytes: []const u8,
) !void {
    var scanner = scanning.RecordScanner.init(segment_bytes);

    while (try scanner.next()) |scanned| {
        try applyScannedRecord(index, segment_id, scanned);
    }
}

pub fn recoverActiveSegment(
    index: *domain.Index,
    segment_id: u32,
    segment_bytes: []const u8,
) !RecoveryResult {
    var scanner = scanning.RecordScanner.init(segment_bytes);

    while (true) {
        const maybe_scanned = scanner.next() catch |err|
            switch (err) {
                error.TruncatedRecord => return .{
                    .valid_bytes = scanner.offset,
                    .discarded_tail_bytes = segment_bytes.len -
                        scanner.offset,
                },
                else => return err,
            };
        const scanned = maybe_scanned orelse return .{
            .valid_bytes = segment_bytes.len,
            .discarded_tail_bytes = 0,
        };

        try applyScannedRecord(index, segment_id, scanned);
    }
}
