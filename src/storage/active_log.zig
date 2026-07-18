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

    pub fn truncateTo(self: *@This(), new_length: u64) !void {
        if (new_length > self.next_offset) {
            return error.InvalidTruncateLength;
        }

        try self.file.setLength(self.io, new_length);
        self.next_offset = new_length;
    }

    pub fn readAllAlloc(
        self: *const @This(),
        allocator: std.mem.Allocator,
    ) ![]u8 {
        const length = std.math.cast(usize, self.next_offset) orelse return error.LogTooLarge;

        const bytes = try allocator.alloc(u8, length);
        errdefer allocator.free(bytes);

        const bytes_read = try self.file.readPositionalAll(
            self.io,
            bytes,
            0,
        );

        if (bytes_read != bytes.len) {
            return error.UnexpectedEndOfFile;
        }

        return bytes;
    }

    pub fn readRangeAlloc(
        self: *const @This(),
        allocator: std.mem.Allocator,
        offset: u64,
        length: u32,
    ) ![]u8 {
        const buffer_length = std.math.cast(
            usize,
            length,
        ) orelse return error.ReadTooLarge;

        const end_offset = std.math.add(
            u64,
            offset,
            length,
        ) catch return error.InvalidReadRange;

        if (end_offset > self.next_offset) {
            return error.InvalidReadRange;
        }

        const bytes = try allocator.alloc(u8, buffer_length);
        errdefer allocator.free(bytes);

        const bytes_read = try self.file.readPositionalAll(self.io, bytes, offset);

        if (bytes_read != bytes.len) {
            return error.UnexpectedEndOfFile;
        }

        return bytes;
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

    pub fn deinit(self: *@This()) void {
        self.file.close(self.io);
        self.* = undefined;
    }
};
