const wl = @import("wayland").server.wl;
const mem = @import("std").mem;
const os = @import("std").os.linux;
const Backend = @import("backend/backend.zig");
const Ouput = @import("Types/Output.zig");

server: *wl.Server,
output: *Ouput,
backend: *const Backend,
allocator: mem.Allocator,

const Self = @This();

pub fn init(allocator: mem.Allocator, backend: *const Backend) !*Self {
    const ptr = try allocator.create(Self);

    const server = try wl.Server.create();

    ptr.* = .{
        .server = server,
        .allocator = allocator,
        .output = undefined,
        .backend = backend,
    };

    ptr.*.output = try Ouput.init(allocator, ptr, backend);

    _ = try server.addSocket("wl-1");

    return ptr;
}

pub fn deinit(self: *Self) void {
    self.output.deinit();

    self.server.destroy();
    const allocator = self.allocator;
    allocator.destroy(self);
}

pub fn run(self: *Self) !void {
    const eventLoop = self.server.getEventLoop();
    const serverFd: i32 = @intCast(eventLoop.getFd());

    const clientFd: i32 = @intCast(self.backend.getFd());

    const epollFd = os.epoll_create1(0);

    const ev_server = os.epoll_event{
        .data = .{ .fd = @intCast(serverFd) },
        .events = os.EPOLL.IN,
    };
    _ = os.epoll_ctl(@intCast(epollFd), os.EPOLL.CTL_ADD, @intCast(serverFd), @constCast(&ev_server));

    const ev_client = os.epoll_event{
        .data = .{ .fd = @intCast(clientFd) },
        .events = os.EPOLL.IN,
    };
    _ = os.epoll_ctl(@intCast(epollFd), os.EPOLL.CTL_ADD, @intCast(clientFd), @constCast(&ev_client));

    var events: [2]os.epoll_event = undefined;
    while (true) {
        const n = os.epoll_wait(@intCast(epollFd), &events, 2, -1);

        for (events[0..@intCast(n)]) |e| {
            if (e.data.fd == serverFd) {
                _ = try eventLoop.dispatch(-1);
                self.server.flushClients();
            } else if (e.data.fd == clientFd) {
                self.backend.dispatch();
            }
        }

        if (self.backend.shouldTerminate()) break;
    }
}
