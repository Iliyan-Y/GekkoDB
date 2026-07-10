pub const LOG_MAGIC: u32 = 0x474b4442; // "GKDB"
pub const LOG_VERSION: u8 = 1;

pub const LogOp = enum(u8) {
    put = 1,
    delete = 2,
};

pub const LogRecordHeader = struct {
    magic: u32,
    version: u8,
    op: LogOp,
    key_len: u32,
    value_len: u32,
};
