ptr: *anyopaque,
vtable: VTable,

const Self = @This();

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    shouldClose: *const fn (*const anyopaque) bool,
};

pub fn deinit(self: *const Self) void {
    self.vtable.deinit(self.ptr);
}

pub fn shouldClose(self: *const Self) bool {
    return self.vtable.shouldClose(self.ptr);
}
