const wl = @import("wayland").server.wl;
const Server = @import("server.zig");
const mem = @import("std").mem;

const Self = @This();

compositor: *wl.Compositor,

fn compositorRequest(compositor: *wl.Compositor, request: wl.Compositor.Request, self: *Self) void {
    _ = compositor;
    _ = self;
    switch (request) {
        .create_region => |e| {
            _ = e;
        },
        .create_surface => |e| {
            _ = e;
        },
    }
}

fn compositorDestroy(compositor: *wl.Compositor, self: *Self) void {
    _ = compositor;
    _ = self;
}

fn compositorBind(client: *wl.Client, self: *Self, version: u32, id: u32) void {
    self.compositor = wl.Compositor.create(client, version, id) catch return;

    self.compositor.setHandler(*Self, compositorRequest, compositorDestroy, self);
}

pub fn init(allocator: mem.Allocator, server: *Server) !*Self {
    const ptr = try allocator.create(Self);

    _ = try wl.Global.create(server, wl.Compositor, 6, *Self, ptr, compositorBind);
}
