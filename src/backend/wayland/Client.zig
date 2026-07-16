const wl = @import("wayland").client.wl;
const xdg = @import("wayland").client.xdg;
const zxdg = @import("wayland").client.zxdg;
const mem = @import("std").mem;

display: *wl.Display,
registry: *wl.Registry,
compositor: ?*wl.Compositor = null,
xdgWmBase: ?*xdg.WmBase = null,
xdgDecorManager: ?*zxdg.DecorationManagerV1 = null,
shm: ?*wl.Shm = null,
seat: ?*wl.Seat = null,
allocator: mem.Allocator,

const Self = @This();

fn xdgWmBaseListener(wmBase: *xdg.WmBase, event: xdg.WmBase.Event, data: *Self) void {
    _ = data;
    switch (event) {
        .ping => |e| {
            wmBase.pong(e.serial);
        },
    }
}

fn registryListener(reg: *wl.Registry, event: wl.Registry.Event, data: *Self) void {
    switch (event) {
        .global => |e| {
            if (mem.orderZ(u8, wl.Compositor.interface.name, e.interface) == .eq) {
                data.compositor = reg.bind(e.name, wl.Compositor, 6) catch return;
            } else if (mem.orderZ(u8, wl.Seat.interface.name, e.interface) == .eq) {
                data.seat = reg.bind(e.name, wl.Seat, 9) catch return;
            } else if (mem.orderZ(u8, wl.Shm.interface.name, e.interface) == .eq) {
                data.shm = reg.bind(e.name, wl.Shm, 2) catch return;
            } else if (mem.orderZ(u8, xdg.WmBase.interface.name, e.interface) == .eq) {
                data.xdgWmBase = reg.bind(e.name, xdg.WmBase, 5) catch return;
            } else if (mem.orderZ(u8, zxdg.DecorationManagerV1.interface.name, e.interface) == .eq) {
                data.xdgDecorManager = reg.bind(e.name, zxdg.DecorationManagerV1, 1) catch return;
            }
        },
        .global_remove => {},
    }
}

pub fn init(allocator: mem.Allocator) !*Self {
    const ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);

    const disp = try wl.Display.connect(null);

    const registry = try wl.Display.getRegistry(disp);
    errdefer {
        registry.destroy();
        disp.disconnect();
    }

    ptr.* = .{
        .display = disp,
        .registry = registry,
        .allocator = allocator,
    };
    registry.setListener(*Self, registryListener, ptr);

    _ = disp.roundtrip();

    ptr.xdgWmBase.?.setListener(*Self, xdgWmBaseListener, ptr);

    _ = disp.roundtrip();
    return ptr;
}

pub fn poll(self: *Self) void {
    _ = self.display.dispatch();
}

pub fn deinit(self: *Self) void {
    if (self.xdgDecorManager) |de| de.destroy();
    if (self.shm) |s| s.destroy();
    if (self.xdgWmBase) |x| x.destroy();
    if (self.seat) |s| s.destroy();
    if (self.compositor) |c| c.destroy();
    self.registry.destroy();
    self.display.disconnect();
    const allocator = self.allocator;
    allocator.destroy(self);
}
