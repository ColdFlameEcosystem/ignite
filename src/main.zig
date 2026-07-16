const Backend = @import("backend/backend.zig");
const wc = Backend.WaylandClient;
const Server = @import("server.zig");
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const backend = try wc.init(gpa);
    defer backend.deinit();

    const window = try backend.createWindow();
    defer window.deinit();

    while (window.shouldClose() == false)
        backend.poll();
}
