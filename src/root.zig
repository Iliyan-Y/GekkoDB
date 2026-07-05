const std = @import("std");
const Io = std.Io;

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
        const owned_key = try self.map.allocator.dupe(u8, key);
        errdefer self.map.allocator.free(owned_key);

        const owned_value = try self.map.allocator.dupe(u8, value);
        errdefer self.map.allocator.free(owned_value);

        // fetchPut lets you clean up old values when replacing an existing key.
        if (try self.map.fetchPut(owned_key, owned_value)) |existing| {
            self.map.allocator.free(existing.key);
            self.map.allocator.free(existing.value);
        }
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

test "key value store put get delete" {
    var store = KeyValueStore.init(std.testing.allocator);
    defer store.deinit();

    try store.put("name", "gekko");
    try std.testing.expectEqualStrings("gekko", store.get("name").?);

    store.delete("name");
    try std.testing.expect(store.get("name") == null);
}
test "store keeps data independent from caller buffers" {
    const allocator = std.testing.allocator;
    var store = KeyValueStore.init(allocator);
    defer store.deinit();

    var key_buf = try allocator.dupe(u8, "name");
    defer allocator.free(key_buf);

    var value_buf = try allocator.dupe(u8, "gekko");
    defer allocator.free(value_buf);

    try store.put(key_buf, value_buf);

    key_buf[0] = 'X';
    value_buf[0] = 'Y';
    try std.testing.expectEqualStrings("gekko", store.get("name").?);
}
