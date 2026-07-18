const std = @import("std");
const domain = @import("domain/index.zig");
const active_log = @import("storage/active_log.zig");
const startup_recovery = @import("storage/startup_recovery.zig");

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

    pub fn deinit(self: *@This()) void {
        self.active_log.deinit();
        self.index.deinit();
        self.* = undefined;
    }
};
