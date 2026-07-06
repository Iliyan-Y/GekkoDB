const std = @import("std");
const root = @import("root.zig");

const KeyValueStore = root.KeyValueStore;

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

test "put replaces an existing value for the same key" {
    var store = KeyValueStore.init(std.testing.allocator);
    defer store.deinit();

    try store.put("name", "lizard");
    try store.put("name", "gekko");
    try std.testing.expectEqualStrings("gekko", store.get("name").?);
}

test "delete missing key does nothing" {
    var store = KeyValueStore.init(std.testing.allocator);
    defer store.deinit();
    store.delete("missing");
    try std.testing.expect(store.get("missing") == null);
}

test "Location index stores record locations by key" {
    var index = root.LocationIndex.init(std.testing.allocator);
    defer index.deinit();
}
