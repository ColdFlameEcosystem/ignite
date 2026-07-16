ptr: *anyopaque,
vtable: VTable,

const Self = @This();

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
};

pub fn deinit(self: *const Self) void {
    self.vtable.deinit(self.ptr);
}
