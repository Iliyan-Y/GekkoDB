const std = @import("std");
const Io = std.Io;

pub const ActiveLog = struct {
    file: Io.File,
    io: Io,
    next_offset: u64,

    pub fn open(
        dir: Io.Dir,
        io: Io,
        path: []const u8,
    ) !@This() {
        const file = try dir.createFile(io, path, .{
            .read = true,
            .truncate = false,
        });
        errdefer file.close(io);

        return .{ .file = file, .io = io, .next_offset = try file.length(io) };
    }

    pub fn sync(self: *const @This()) !void {
        try self.file.sync(self.io);
    }

    pub fn deinit(self: *@This()) void {
        self.file.close(self.io);
        self.* = undefined;
    }

    pub fn appendEncoded(
        self: *@This(),
        encoded: []const u8,
    ) !u64 {
        const start_offset = self.next_offset;

        const encoded_length = std.math.cast(
            u64,
            encoded.len,
        ) orelse return error.LogTooLarge;

        const end_offset = std.math.add(
            u64,
            start_offset,
            encoded_length,
        ) catch return error.LogTooLarge;

        try self.file.writePositionalAll(self.io, encoded, start_offset);
        self.next_offset = end_offset;

        return start_offset;
    }
};
