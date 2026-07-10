const std = @import("std");

pub const LOG_MAGIC: u32 = 0x474b4442; // "GKDB"
pub const LOG_VERSION: u8 = 1;
pub const encoded_size = 14;

pub const LogOp = enum(u8) {
    put = 1,
    delete = 2,
    _,
};

pub const LogRecordHeader = struct {
    magic: u32,
    version: u8,
    op: LogOp,
    key_len: u32,
    value_len: u32,

    pub fn encode(self: LogRecordHeader, output: *[encoded_size]u8) void {
        std.mem.writeInt(u32, output[0..4], self.magic, .big);
        output[4] = self.version;
        output[5] = @intFromEnum(self.op);
        std.mem.writeInt(u32, output[6..10], self.key_len, .big);
        std.mem.writeInt(u32, output[10..14], self.value_len, .big);
    }

    pub fn decode(input: *const [encoded_size]u8) error{InvalidOperation}!@This() {
        const op: LogOp = @enumFromInt(input[5]);
        switch (op) {
            .put, .delete => {},
            else => return error.InvalidOperation,
        }
        return .{
            .magic = std.mem.readInt(u32, input[0..4], .big),
            .version = input[4],
            .op = op,
            .key_len = std.mem.readInt(u32, input[6..10], .big),
            .value_len = std.mem.readInt(u32, input[10..14], .big),
        };
    }
};

pub const LogRecord = struct {
    op: LogOp,
    key: []const u8,
    value: []const u8,

    pub fn createHeader(self: @This()) error{
        InvalidOperation,
        DeleteHasValue,
        KeyTooLarge,
        ValueTooLarge,
    }!LogRecordHeader {
        switch (self.op) {
            .put => {},
            .delete => {
                if (self.value.len != 0) {
                    return error.DeleteHasValue;
                }
            },
            else => return error.InvalidOperation,
        }
        const max_length = @as(usize, std.math.maxInt(u32));

        if (self.key.len > max_length) {
            return error.KeyTooLarge;
        }
        if (self.value.len > max_length) {
            return error.ValueTooLarge;
        }
        const key_len: u32 = @intCast(self.key.len);
        const value_len: u32 = @intCast(self.value.len);

        return .{
            .magic = LOG_MAGIC,
            .version = LOG_VERSION,
            .op = self.op,
            .key_len = key_len,
            .value_len = value_len,
        };
    }
};
