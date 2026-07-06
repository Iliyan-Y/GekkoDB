const std = @import("std");
const Io = std.Io;

pub const RecordLocation = struct {
    segment_id: u32,
    offset: u64,
    length: u32,
};

pub const Index = struct {
    map: std.StringHashMap(RecordLocation),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{ .map = std.StringHashMap(RecordLocation).init(allocator) };
    }

    pub fn deinit(self: *Index) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.map.allocator.free(entry.key_ptr.*);
        }
        self.map.deinit();
    }

    pub fn put(self: *Index, key: []const u8, value: RecordLocation) !void {
        // handle value update
        if (self.map.getEntry(key)) |entry| {
            entry.value_ptr.* = value;
            return;
        }

        const owned_key = try self.map.allocator.dupe(u8, key);
        errdefer self.map.allocator.free(owned_key);

        try self.map.put(owned_key, value);
    }

    pub fn get(self: *Index, key: []const u8) ?RecordLocation {
        return self.map.get(key);
    }

    pub fn delete(self: *Index, key: []const u8) void {
        // fetchRemove lets you free the removed key/value pair on delete.
        if (self.map.fetchRemove(key)) |existing| {
            self.map.allocator.free(existing.key);
            self.map.allocator.free(existing.value);
        }
    }
};

test {
    _ = @import("root_test.zig");
}
