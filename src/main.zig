const std = @import("std");
const net = std.net;
const http = std.http;

pub fn main() !void {
    const addr = net.Address.parseIp4("127.0.0.1", 6969) catch |err| {
        std.debug.print("Error parsing address: {}\n", .{err});
        return;
    };

    const gpa = std.heap.page_allocator;
    var thread_pool: std.Thread.Pool = undefined;
    try std.Thread.Pool.init(&thread_pool, .{
        .allocator = gpa,
        .n_jobs = 4,
    });
    defer thread_pool.deinit();

    var server = try addr.listen(.{});

    while (true) {
        const connection = server.accept() catch |err| {
            std.debug.print("Accept error: {}\n", .{err});
            continue;
        };

        try thread_pool.spawn(struct {
            fn run(conn: std.net.Server.Connection) void {
                handleConnection(conn) catch |err| {
                    std.log.err("Connection handling failed: {}\n", .{err});
                };
            }
        }.run, .{connection});
    }
}

fn handleConnection(connection: std.net.Server.Connection) !void {
    defer connection.stream.close();

    var read_buffer: [1024]u8 = undefined;
    var http_server = http.Server.init(connection, &read_buffer);

    var request = http_server.receiveHead() catch |err| switch (err) {
        error.HttpConnectionClosing => return,
        else => |e| {
            std.debug.print("Error receiving request head: {}\n", .{e});
            return;
        },
    };

    handleRequest(&request) catch |err| {
        std.debug.print("Request handling error: {}\n", .{err});
    };
}

fn handleRequest(request: *http.Server.Request) !void {
    std.debug.print("Received request for {s}\n", .{request.head.target});
    try request.respond("Hello, Zig HTTP server!\n", .{});
}
