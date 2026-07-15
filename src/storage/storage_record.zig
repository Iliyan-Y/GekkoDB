const std = @import("std");

pub const LOG_MAGIC: u32 = 0x474b4442; // "GKDB"
pub const LOG_VERSION: u8 = 1;
pub const ENCODED_SIZE = 14;

pub const Operation = enum(u8) {
    put = 1,
    delete = 2,
    _,
};

pub const Header = struct {
    magic: u32,
    version: u8,
    op: Operation,
    key_len: u32,
    value_len: u32,

    pub fn encode(self: Header, output: *[ENCODED_SIZE]u8) void {
        std.mem.writeInt(u32, output[0..4], self.magic, .big);
        output[4] = self.version;
        output[5] = @intFromEnum(self.op);
        std.mem.writeInt(u32, output[6..10], self.key_len, .big);
        std.mem.writeInt(u32, output[10..14], self.value_len, .big);
    }

    pub fn decode(input: *const [ENCODED_SIZE]u8) error{InvalidOperation}!@This() {
        const op: Operation = @enumFromInt(input[5]);
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

pub const Record = struct {
    op: Operation,
    key: []const u8,
    value: []const u8,

    pub fn createHeader(self: @This()) error{
        InvalidOperation,
        DeleteHasValue,
        KeyTooLarge,
        ValueTooLarge,
    }!Header {
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

    pub fn encodedLength(self: @This()) error{
        InvalidOperation,
        DeleteHasValue,
        KeyTooLarge,
        ValueTooLarge,
        RecordTooLarge,
    }!usize {
        _ = try self.createHeader();

        // check header for overflow
        const header_and_key = std.math.add(
            usize,
            ENCODED_SIZE,
            self.key.len,
        ) catch return error.RecordTooLarge;

        // check and return the record or overflow error
        return std.math.add(
            usize,
            header_and_key,
            self.value.len,
        ) catch return error.RecordTooLarge;
    }

    pub fn encodeInto(self: @This(), output: []u8) error{
        InvalidOperation,
        DeleteHasValue,
        KeyTooLarge,
        ValueTooLarge,
        RecordTooLarge,
        BufferTooSmall,
    }!usize {
        const required_length = try self.encodedLength();

        if (output.len < required_length) {
            return error.BufferTooSmall;
        }

        const header = try self.createHeader();

        var encoded_header: [ENCODED_SIZE]u8 = undefined;
        header.encode(&encoded_header);

        @memcpy(output[0..ENCODED_SIZE], &encoded_header);

        const key_end = ENCODED_SIZE + self.key.len;
        @memcpy(output[ENCODED_SIZE..key_end], self.key);
        @memcpy(output[key_end..required_length], self.value);

        return required_length;
    }
};
