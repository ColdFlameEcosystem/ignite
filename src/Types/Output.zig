const wl = @import("wayland").server.wl;
const Server = @import("../server.zig");
const mem = @import("std").mem;
const ArrayList = @import("std").ArrayList;
const Self = @This();
const Backend = @import("../backend/backend.zig");

// Output Global State. One for the compositor
global: *const wl.Global,
allocator: mem.Allocator,
server: *const Server,
backend: *const Backend,
coutputs: ArrayList(*COutput),
// Client Output. For every client.
pub const COutput = struct {
    wlOutput: *wl.Output,
    state: *Self,
    index: usize = 0,
};

// We need it for each client. so, state is coutput
fn outputDestroy(output: *wl.Output, coutput: *COutput) void {
    _ = output;

    const index = coutput.index; // Get the current index of the coutput in the list

    _ = coutput.state.coutputs.swapRemove(index); // Remove this coutput from the list and swap it from the end one.
    if (coutput.state.coutputs.items.len != 0)
        coutput.state.coutputs.items[index].index = index;

    const allocator = coutput.state.allocator;
    allocator.destroy(coutput); // Destroy the output
}

// For each client. So, state is coutput (per client)
fn outputRequestHandle(output: *wl.Output, request: wl.Output.Request, coutput: *COutput) void {
    _ = coutput;
    switch (request) {
        .release => {
            wl.Output.destroy(output);
        },
    }
}

// This is for the global compositor. state is the global state of the compositor here
fn bind(client: *wl.Client, state: *Self, version: u32, id: u32) void {
    const coutput = state.allocator.create(COutput) catch return;

    const output = wl.Output.create(client, version, id) catch return;

    coutput.* = .{
        .wlOutput = output,
        .state = state,
        .index = state.coutputs.items.len,
    };

    _ = state.coutputs.append(state.allocator, coutput) catch return;

    output.setHandler(*COutput, outputRequestHandle, outputDestroy, coutput);

    output.sendName("WL-1");
    output.sendDescription("A cool dummy output");

    output.sendGeometry(0, 0, -1, -1, .unknown, "Coldflame", "Ferrofluid", .normal);
    // Send the dummy width x height here not this 100x100
    output.sendMode(.{ .current = true, .preferred = true }, 100, 100, 60);
    output.sendScale(1);
    output.sendDone();
}

pub fn init(allocator: mem.Allocator, server: *const Server, backend: *const Backend) !*Self {
    const ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);

    const global = try wl.Global.create(server.server, wl.Output, 4, *Self, ptr, bind);
    ptr.* = .{
        .global = global,
        .allocator = allocator,
        .server = server,
        .coutputs = .empty,
        .backend = backend,
    };
    return ptr;
}

pub fn deinit(self: *Self) void {
    const allocator = self.allocator;
    self.coutputs.deinit(allocator);
    allocator.destroy(self);
}
