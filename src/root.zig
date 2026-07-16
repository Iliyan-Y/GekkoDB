test {
    _ = @import("domain/index_test.zig");
    _ = @import("storage/storage_record_test.zig");
    _ = @import("storage/storage_record_decode_test.zig");
    _ = @import("storage/record_scanner_test.zig");
    _ = @import("storage/recovery_test.zig");
}
