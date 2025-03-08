const std = @import("std");
const net = std.net;
const http = std.http;

pub fn main() !void {
    const addr = net.Address.parseIp4("127.0.0.1", 6969) catch |err| {
        std.debug.print("Error parsing address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});
    startServer(&server);
}

fn startServer(server: *net.Server) void {
    while (true) {
        var connection = server.accept() catch |err| {
            std.debug.print("Accept error: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        var read_buffer: [1024]u8 = undefined;
        var http_server = http.Server.init(connection, &read_buffer);

        var request = http_server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => continue,
            else => |e| {
                std.debug.print("Error receiving request head: {}\n", .{e});
                continue;
            },
        };

        handleRequest(&request) catch |err| {
            std.debug.print("Request handling error: {}\n", .{err});
        };
    }
}

fn handleRequest(request: *http.Server.Request) !void {
    std.debug.print("Received request for {s}\n", .{request.head.target});
    try request.respond("Hello, Zig HTTP server!\n", .{});
}
