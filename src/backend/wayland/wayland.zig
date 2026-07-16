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

fn shouldClose(ptr: *const anyopaque) bool {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));

    var close = c.surfaces.items.len;
    for (c.surfaces.items) |s| {
        if (s.close == true) close -= 1;
    }

    if (close == 0) {
        return true;
    } else {
        return false;
    }
}

fn createWindow(ptr: *const anyopaque) !Window {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));

    const allocator = c.allocator;
    const srfc = try Surface.init(allocator, c);

    return .{
        .ptr = @ptrCast(srfc),
        .vtable = .{
            .deinit = deinitWindow,
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
            .dispatch = dispatch,
            .flush = flush,
            .getFd = getFd,
            .shouldTerminate = shouldClose,
        },
    };
}

fn getFd(ptr: *const anyopaque) i32 {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    return @intCast(c.display.getFd());
}

fn dispatch(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    _ = c.display.dispatch();
}

fn flush(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    _ = c.display.flush();
}

fn deinit(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    c.deinit();
}

fn poll(ptr: *const anyopaque) void {
    const c: *Client = @ptrCast(@alignCast(@constCast(ptr)));
    c.poll();
}
