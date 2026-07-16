const Client = @import("Client.zig");
const wl = @import("wayland").client.wl;
const xdg = @import("wayland").client.xdg;
const zxdg = @import("wayland").client.zxdg;
const std = @import("std");
const os = std.os.linux;

surface: *wl.Surface,
xdgSurface: *xdg.Surface,
xdgToplevel: *xdg.Toplevel,
allocator: std.mem.Allocator,
decoration: ?*zxdg.ToplevelDecorationV1 = null,
shmPool: ?*wl.ShmPool = null,
buffer: ?*wl.Buffer = null, // Could be double buffered,
currentOutput: ?*wl.Output = null,
bufferScale: i32 = 0,
transform: wl.Output.Transform = .normal,
format: wl.Shm.Format = .argb8888,
width: i32 = 100,
height: i32 = 100,
configured: bool = false,
client: *Client,
close: bool = false,
fd: i32 = 0,
index: usize = 0,

// Supposed to be hidden
maxSize: i32 = 0,
const Self = @This();

fn bufferRelease(buffer: *wl.Buffer, event: wl.Buffer.Event, data: *Self) void {
    switch (event) {
        .release => {
            buffer.destroy();
            data.buffer = null;
        },
    }
}

fn surfaceListener(srfc: *wl.Surface, event: wl.Surface.Event, data: *Self) void {
    _ = srfc;
    switch (event) {
        .enter => |e| {
            data.currentOutput = e.output;
        },
        .leave => {
            data.currentOutput = null;
        },
        .preferred_buffer_scale => |e| {
            data.bufferScale = e.factor;
        },
        .preferred_buffer_transform => |e| {
            data.transform = e.transform;
        },
    }
}

fn xdgSurfaceListener(srfc: *xdg.Surface, event: xdg.Surface.Event, ptr: *Self) void {
    switch (event) {
        .configure => |e| {
            srfc.ackConfigure(e.serial);

            if (ptr.configured == true) return;
            const size = ptr.width * ptr.height * 4;
            if (size == 0) return;
            if (size > ptr.maxSize) {
                ptr.maxSize = size;
                _ = os.ftruncate(@intCast(ptr.fd), @intCast(size));
                ptr.shmPool.?.resize(size);
            }
            const addr = os.mmap(null, @intCast(size), .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, @intCast(ptr.fd), 0);
            const pixl: [*]u32 = @ptrFromInt(addr);

            const image = pixl[0..@divExact(@as(usize, @intCast(ptr.width)) * @as(usize, @intCast(ptr.height)), 1)];
            @memset(image[0..@divExact(@as(usize, @intCast(size)), 4)], 0xFFFFFFFF);

            const buffer = ptr.shmPool.?.createBuffer(0, ptr.width, ptr.height, @intCast(ptr.width * 4), ptr.format) catch return;
            buffer.setListener(*Self, bufferRelease, ptr);
            ptr.buffer = buffer;
            ptr.surface.attach(buffer, 0, 0);
            ptr.surface.damage(0, 0, ptr.width, ptr.height);
            const opaqueRegion = ptr.client.compositor.?.createRegion() catch return;
            opaqueRegion.add(0, 0, ptr.width, ptr.height);
            ptr.surface.setOpaqueRegion(opaqueRegion);
            ptr.surface.commit();
            _ = ptr.client.display.roundtrip();
            ptr.configured = true;
        },
    }
}

fn xdgToplevelListener(toplevel: *xdg.Toplevel, event: xdg.Toplevel.Event, data: *Self) void {
    _ = toplevel;
    switch (event) {
        .configure => |e| {
            if ((e.width == 0) or (e.height == 0)) return;
            data.height = e.height;
            data.width = e.width;
            data.configured = false;
        },
        .close => {
            data.close = true;
        },
        .configure_bounds => {},
        .wm_capabilities => {},
    }
}

fn redraw(cb: *wl.Callback, event: wl.Callback.Event, ptr: *Self) void {
    switch (event) {
        .done => {
            if (ptr.buffer) |b| {
                ptr.surface.attach(b, 0, 0);
                ptr.surface.damage(0, 0, ptr.width, ptr.height);
                ptr.surface.commit();
            }
            cb.destroy();
        },
    }
}
fn allocateSharedMemory(size: usize) !i32 {
    const fd = os.memfd_create("ignite-shm", 0);
    _ = os.ftruncate(@intCast(fd), @intCast(size));

    return @intCast(fd);
}

pub fn init(allocator: std.mem.Allocator, client: *Client) !*Self {
    const ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);

    const srfc = try client.compositor.?.createSurface();
    errdefer srfc.destroy();
    const xdgSrfc = try client.xdgWmBase.?.getXdgSurface(srfc);
    errdefer {
        xdgSrfc.destroy();
        srfc.destroy();
    }

    const xdgToplevel = try xdgSrfc.getToplevel();
    errdefer {
        xdgToplevel.destroy();
        xdgSrfc.destroy();
        srfc.destroy();
    }

    var decor: ?*zxdg.ToplevelDecorationV1 = null;
    if (client.xdgDecorManager) |decorManager| {
        decor = try decorManager.getToplevelDecoration(xdgToplevel);
    }

    ptr.* = .{
        .client = client,
        .allocator = allocator,
        .surface = srfc,
        .xdgToplevel = xdgToplevel,
        .xdgSurface = xdgSrfc,
    };

    if (decor != null) {
        ptr.*.decoration = decor.?;
    }

    const size = ptr.width * ptr.height * 4;
    const fd = try allocateSharedMemory(@intCast(size));
    ptr.fd = fd;
    const shmPool = try client.shm.?.createPool(fd, @intCast(size));
    ptr.shmPool = shmPool;

    srfc.setListener(*Self, surfaceListener, ptr);
    xdgSrfc.setListener(*Self, xdgSurfaceListener, ptr);
    xdgToplevel.setListener(*Self, xdgToplevelListener, ptr);

    srfc.commit();
    _ = client.display.roundtrip();

    const buffer = try shmPool.createBuffer(0, ptr.width, ptr.height, @intCast(ptr.width * 4), ptr.format);
    xdgToplevel.setAppId("com.ignite.compositor");
    xdgToplevel.setTitle("Ignite Wayland Compositor is igniting...");
    ptr.buffer = buffer;
    srfc.attach(ptr.buffer.?, 0, 0);
    srfc.damage(0, 0, ptr.width, ptr.height);
    srfc.commit();
    ptr.buffer.?.setListener(*Self, bufferRelease, ptr);
    _ = client.display.roundtrip();

    ptr.index = client.surfaces.items.len;
    _ = try client.surfaces.append(allocator, ptr);

    return ptr;
}

pub fn deinit(self: *Self) void {
    if (self.buffer) |buff| buff.destroy();
    if (self.shmPool) |shm| shm.destroy();
    if (self.decoration) |decor| decor.destroy();
    self.xdgToplevel.destroy();
    self.xdgSurface.destroy();
    self.surface.destroy();

    const index = self.index;

    _ = self.client.surfaces.swapRemove(index);
    if (self.client.surfaces.items.len != 0)
        self.client.surfaces.items[index].index = index;

    const allocator = self.allocator;
    allocator.destroy(self);
}
