const WaylandClient = @import("backend/backend.zig").WaylandClient;
const Server = @import("server.zig");
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const client = try WaylandClient.Client.init(gpa);
    defer client.deinit();

    const window = try WaylandClient.Window.init(gpa, client);
    defer window.deinit();

    while (window.close == false)
        client.poll();
}
