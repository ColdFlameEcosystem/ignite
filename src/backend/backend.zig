pub const WaylandClient = @import("wayland/wayland.zig");
const Window = @import("../Types/Window.zig");
ptr: *anyopaque,
vtable: VTable,

const Self = @This();

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    createWindow: *const fn (*const anyopaque) anyerror!Window,

    // event loop
    getFd: *const fn (*const anyopaque) i32,
    dispatch: *const fn (*const anyopaque) void,
    flush: *const fn (*const anyopaque) void,

    // terminator
    shouldTerminate: *const fn (*const anyopaque) bool,
};

pub fn deinit(self: *const Self) void {
    self.vtable.deinit(self.ptr);
}

pub fn createWindow(self: *const Self) anyerror!Window {
    return self.vtable.createWindow(self.ptr);
}

pub fn getFd(self: *const Self) i32 {
    return self.vtable.getFd(self.ptr);
}

pub fn dispatch(self: *const Self) void {
    self.vtable.dispatch(self.ptr);
}

pub fn flush(self: *const Self) void {
    self.vtable.flush(self.ptr);
}

pub fn shouldTerminate(self: *const Self) bool {
    return self.vtable.shouldTerminate(self.ptr);
}
