const storage = @import("storage_record.zig");

pub const ScannedRecord = struct {
    record: storage.Record,
    offset: usize,
    bytes: usize,
};

pub const RecordScanner = struct {
    input: []const u8,
    offset: usize,

    pub fn init(input: []const u8) @This() {
        return .{
            .input = input,
            .offset = 0,
        };
    }

    pub fn next(self: *@This()) !?ScannedRecord {
        if (self.offset == self.input.len) {
            return null;
        }

        const record_offset = self.offset;
        const decoded = try storage.Record.decode(self.input[record_offset..]);

        self.offset += decoded.bytes;

        return .{
            .record = decoded.record,
            .offset = record_offset,
            .bytes = decoded.bytes,
        };
    }
};
