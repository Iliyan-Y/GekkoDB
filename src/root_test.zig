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

test "index updates an existing key location" {
    var index = Index.init(std.testing.allocator);
    defer index.deinit();

    try index.put("name", .{
        .segment_id = 1,
        .offset = 128,
        .length = 5,
    });

    try index.put("name", .{
        .segment_id = 2,
        .offset = 256,
        .length = 9,
    });

    const location = index.get("name").?;

    try std.testing.expectEqual(@as(u32, 2), location.segment_id);
    try std.testing.expectEqual(@as(u64, 256), location.offset);
    try std.testing.expectEqual(@as(u32, 9), location.length);
}

test "index delete removes key location" {
    var index = Index.init(std.testing.allocator);
    defer index.deinit();

    try index.put("name", .{
        .segment_id = 1,
        .offset = 128,
        .length = 5,
    });

    index.delete("name");

    try std.testing.expect(index.get("name") == null);
}
