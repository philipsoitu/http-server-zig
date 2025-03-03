const std = @import("std");
const net = std.net;
const request = @import("request.zig");
const response = @import("response.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    const address = try net.Address.resolveIp("127.0.0.1", 42069);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    const buff = try allocator.alloc(u8, 2048);
    defer allocator.free(buff);

    const connection = try listener.accept();
    defer connection.stream.close();

    _ = try connection.stream.read(buff);
    try stdout.print("received: \n", .{});

    const req = try request.parseRequest(buff, allocator);
    try request.printRequest(req);

    if (std.mem.eql(u8, req.start_line.target, "/")) {
        try response.sendText(connection, allocator, "");
    } else {
        var pathIter = std.mem.split(u8, req.start_line.target, "/");
        _ = pathIter.next();

        const root = pathIter.next() orelse "";
        if (std.mem.eql(u8, root, "echo")) {
            const second = pathIter.next() orelse "";
            try response.sendText(connection, allocator, second);
        } else if (std.mem.eql(u8, root, "user-agent")) {
            var user_agent_str: []const u8 = "";
            for (req.headers.items) |header| {
                if (std.mem.eql(u8, header.name, "User-Agent")) {
                    user_agent_str = header.value;
                    break;
                }
            }
            try response.sendText(connection, allocator, user_agent_str);
        } else {
            try response.notFound(connection, allocator);
        }
    }
}
