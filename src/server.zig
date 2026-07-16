const wl = @import("wayland").server.wl;
const mem = @import("std").mem;
const Backend = @import("backend/backend.zig");
const Ouput = @import("Types/Output.zig");

server: *wl.Server,
output: *Ouput,
allocator: mem.Allocator,
const Self = @This();
pub fn init(allocator: mem.Allocator, backend: *Backend) !*Self {
    const ptr = try allocator.create(Self);

    const server = try wl.Server.create();

    const output = try Ouput.init(allocator, server, backend);

    ptr.* = .{
        .server = server,
        .allocator = allocator,
        .output = output,
    };
    return ptr;
}

pub fn deinit(self: *Self) void {
    self.output.deinit();

    self.server.destroy();
    const allocator = self.allocator;
    allocator.destroy(self);
}
