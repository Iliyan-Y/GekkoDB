const std = @import("std");

pub const LOG_MAGIC: u32 = 0x474b4442; // "GKDB"
pub const LOG_VERSION: u8 = 1;
pub const encoded_size = 14;

pub const LogOp = enum(u8) {
    put = 1,
    delete = 2,
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
        return .{
            .magic = std.mem.readInt(u32, input[0..4], .big),
            .version = input[4],
            .op = op,
            .key_len = std.mem.readInt(u32, input[6..10], .big),
            .value_len = std.mem.readInt(u32, input[10..14], .big),
        };
    }
};
