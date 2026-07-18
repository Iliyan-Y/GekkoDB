const std = @import("std");
const domain = @import("domain/index.zig");
const active_log = @import("storage/active_log.zig");
const startup_recovery = @import("storage/startup_recovery.zig");
const storage = @import("storage/storage_record.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    index: domain.Index,
    active_log: active_log.ActiveLog,
    active_segment_id: u32,

    pub fn open(
        allocator: std.mem.Allocator,
        dir: std.Io.Dir,
        io: std.Io,
        path: []const u8,
        active_segment_id: u32,
    ) !@This() {
        var index = domain.Index.init(allocator);
        errdefer index.deinit();

        var log = try active_log.ActiveLog.open(dir, io, path);
        errdefer log.deinit();

        _ = try startup_recovery.recoverActiveLog(
            allocator,
            &index,
            active_segment_id,
            &log,
        );

        return .{
            .allocator = allocator,
            .index = index,
            .active_log = log,
            .active_segment_id = active_segment_id,
        };
    }

    pub fn put(
        self: *@This(),
        key: []const u8,
        value: []const u8,
    ) !void {
        const record = storage.Record{
            .op = .put,
            .key = key,
            .value = value,
        };

        const encoded_length = try record.encodedLength();
        const location_length = std.math.cast(
            u32,
            encoded_length,
        ) orelse return error.RecordTooLarge;

        const encoded = try self.allocator.alloc(u8, encoded_length);
        defer self.allocator.free(encoded);

        const written = try record.encodeInto(encoded);
        const offset = try self.active_log.appendEncoded(encoded[0..written]);

        try self.active_log.sync();

        try self.index.put(key, .{
            .segment_id = self.active_segment_id,
            .offset = offset,
            .length = location_length,
        });
    }

    pub fn getAlloc(
        self: *const @This(),
        allocator: std.mem.Allocator,
        key: []const u8,
    ) !?[]u8 {
        const location = self.index.get(key) orelse return null;

        if (location.segment_id != self.active_segment_id) {
            return error.SegmentNotAvailable;
        }

        const encoded = try self.active_log.readRangeAlloc(allocator, location.offset, location.length);
        defer allocator.free(encoded);

        const decoded = try storage.Record.decode(encoded);

        if (decoded.bytes != encoded.len) {
            return error.InvalidRecordLength;
        }
        if (decoded.record.op != .put) {
            return error.IndexPointsToDelete;
        }
        if (!std.mem.eql(u8, key, decoded.record.key)) {
            return error.IndexKeyMismatch;
        }

        return try allocator.dupe(u8, decoded.record.value);
    }

    pub fn deinit(self: *@This()) void {
        self.active_log.deinit();
        self.index.deinit();
        self.* = undefined;
    }
};
