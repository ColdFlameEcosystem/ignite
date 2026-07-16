pub const WaylandClient = @import("wayland/wayland.zig");
const Window = @import("../Types/Window.zig");
ptr: *anyopaque,
vtable: VTable,

const Self = @This();

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    createWindow: *const fn (*const anyopaque) anyerror!Window,
    poll: *const fn (*const anyopaque) void,
};

pub fn deinit(self: *const Self) void {
    self.vtable.deinit(self.ptr);
}

pub fn createWindow(self: *const Self) anyerror!Window {
    return self.vtable.createWindow(self.ptr);
}

pub fn poll(self: *const Self) void {
    self.vtable.poll(self.ptr);
}
