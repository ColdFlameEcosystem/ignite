const wl = @import("wayland").server.wl;
const mem = @import("std").mem;
const Compositor = @import("Types/Compositor.zig");

server: *wl.Server,
compositor: *wl.Global,
const Self = @This();
pub fn init(allocator: mem.Allocator) !*Self {
    const ptr = try allocator.create(Self);

    const server = try wl.Server.create();

    ptr.* = .{
        .server = server,
    };
    return ptr;
}
