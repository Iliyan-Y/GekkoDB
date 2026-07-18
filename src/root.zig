test {
    _ = @import("engine_test.zig");
    _ = @import("domain/index_test.zig");
    _ = @import("storage/storage_record_test.zig");
    _ = @import("storage/storage_record_decode_test.zig");
    _ = @import("storage/record_scanner_test.zig");
    _ = @import("storage/recovery_test.zig");
    _ = @import("storage/active_log_test.zig");
    _ = @import("storage/startup_recovery_test.zig");
}
