const std = @import("std");
const Io = std.Io;

pub const RecordLocation = struct {
    segment_id: u32,
    offset: u64,
    length: u32,
};

pub const KeyValueStore = struct {
    map: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{ .map = std.StringHashMap([]const u8).init(allocator) };
    }

    pub fn deinit(self: *KeyValueStore) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.map.allocator.free(entry.key_ptr.*);
            self.map.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn put(self: *KeyValueStore, key: []const u8, value: []const u8) !void {
        // dupe gives the store its own memory.
        const owned_value = try self.map.allocator.dupe(u8, value);
        errdefer self.map.allocator.free(owned_value);

        // handle value update
        if (self.map.getEntry(key)) |entry| {
            self.map.allocator.free(entry.value_ptr.*);
            entry.value_ptr.* = owned_value;
            return;
        }

        const owned_key = try self.map.allocator.dupe(u8, key);
        errdefer self.map.allocator.free(owned_key);
        try self.map.put(owned_key, owned_value);
    }

    pub fn get(self: *KeyValueStore, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn delete(self: *KeyValueStore, key: []const u8) void {
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
