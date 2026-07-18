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

    pub fn deinit(self: *@This()) void {
        self.active_log.deinit();
        self.index.deinit();
        self.* = undefined;
    }
};
