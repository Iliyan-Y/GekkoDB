const std = @import("std");
const root = @import("root.zig");

const Index = root.Index;

test "Location index stores record locations by key" {
    var index = Index.init(std.testing.allocator);
    defer index.deinit();

    try index.put("name", .{
        .segment_id = 1,
        .offset = 128,
        .length = 5,
    });

    const location = index.get("name").?;

    try std.testing.expectEqual(@as(u32, 1), location.segment_id);
    try std.testing.expectEqual(@as(u64, 128), location.offset);
    try std.testing.expectEqual(@as(u32, 5), location.length);
}
// test "key value store put get delete" {
//     var store = Index.init(std.testing.allocator);
//     defer store.deinit();
//
//     try store.put("name", "gekko");
//     try std.testing.expectEqualStrings("gekko", store.get("name").?);
//
//     store.delete("name");
//     try std.testing.expect(store.get("name") == null);
// }
//
// test "store keeps data independent from caller buffers" {
//     const allocator = std.testing.allocator;
//     var store = Index.init(allocator);
//     defer store.deinit();
//
//     var key_buf = try allocator.dupe(u8, "name");
//     defer allocator.free(key_buf);
//
//     var value_buf = try allocator.dupe(u8, "gekko");
//     defer allocator.free(value_buf);
//
//     try store.put(key_buf, value_buf);
//
//     key_buf[0] = 'X';
//     value_buf[0] = 'Y';
//     try std.testing.expectEqualStrings("gekko", store.get("name").?);
// }
//
// test "put replaces an existing value for the same key" {
//     var store = Index.init(std.testing.allocator);
//     defer store.deinit();
//
//     try store.put("name", "lizard");
//     try store.put("name", "gekko");
//     try std.testing.expectEqualStrings("gekko", store.get("name").?);
// }
//
// test "delete missing key does nothing" {
//     var store = Index.init(std.testing.allocator);
//     defer store.deinit();
//     store.delete("missing");
//     try std.testing.expect(store.get("missing") == null);
// }
//
