const wl = @import("wayland").server.wl;
const Server = @import("../server.zig");
const mem = @import("std").mem;
const ArrayList = @import("std").ArrayList;
const Self = @This();
const Backend = @import("../backend/backend.zig");

// Output Global State. One for the compositor
global: *wl.Global,
allocator: mem.Allocator,
server: *Server,
backend: *Backend,
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
    coutput.state.coutputs.items[index].index = index; // Update the index of the output which is at this position.

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

    state.coutputs.append(state.allocator, coutput);

    output.setHandler(*COutput, outputRequestHandle, outputDestroy);

    output.sendName("WL-1");
    output.sendDescription("A cool dummy output");

    // Now here we actually get things from our wayland client and send it here.
    // output.sendDone();
}

pub fn init(allocator: mem.Allocator, server: *Server, backend: *Backend) !*Self {
    const ptr = try allocator.create(Self);
    errdefer allocator.destroy(ptr);

    const global = wl.Global.create(server.server, wl.Output, 4, *Self, ptr, bind);
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
