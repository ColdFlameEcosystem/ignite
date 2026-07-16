pub const Client = @import("Client.zig");
pub const Surface = @import("Surface.zig");
const Backend = @import("../backend.zig");
const Window = @import("../../Types/Window.zig");
const mem = @import("std").mem;

const Self = @This();

fn deinitWindow(ptr: *const anyopaque) void {
    const s: *Surface = @ptrCast(@alignCast(@constCast(ptr)));
    s.deinit();
}

fn windowShouldClose(ptr: *const anyopaque) bool {
    const s: *Surface = @ptrCast(@alignCast(@constCast(ptr)));
    return s.close;
}

fn createWindow(ptr: *const anyopaque) !Window {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));

    const allocator = c.allocator;
    const srfc = try Surface.init(allocator, c);

    return .{
        .ptr = @ptrCast(srfc),
        .vtable = .{
            .deinit = deinitWindow,
            .shouldClose = windowShouldClose,
        },
    };
}

pub fn init(allocator: mem.Allocator) !Backend {
    const client = try Client.init(allocator);
    return .{
        .ptr = @ptrCast(client),
        .vtable = .{
            .deinit = deinit,
            .createWindow = createWindow,
            .poll = poll,
        },
    };
}

fn deinit(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    c.deinit();
}

fn poll(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    c.poll();
}
