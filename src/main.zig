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

    var thread_pool: std.Thread.Pool = undefined;
    try std.Thread.Pool.init(&thread_pool, .{
        .allocator = allocator,
        .n_jobs = 10,
    });
    defer thread_pool.deinit();

    try stdout.writeAll("Server started on 127.0.0.1:42069\n");

    while (true) {
        const connection = try listener.accept();
        // Use a closure to handle the error properly
        try thread_pool.spawn(struct {
            fn run(conn: std.net.Server.Connection, out: std.fs.File.Writer, alloc: std.mem.Allocator) void {
                handleConnection(conn, out, alloc) catch |err| {
                    std.log.err("Connection handling failed: {}", .{err});
                };
            }
        }.run, .{ connection, stdout, allocator });
    }
}

fn handleConnection(connection: std.net.Server.Connection, stdout: std.fs.File.Writer, allocator: std.mem.Allocator) !void {
    defer connection.stream.close();
    const buff = try allocator.alloc(u8, 1048);
    defer allocator.free(buff);

    _ = try connection.stream.read(buff);
    try stdout.writeAll("received: \n");

    const req = try request.parseRequest(buff, allocator);
    try request.printRequest(req);

    if (std.mem.eql(u8, req.start_line.target, "/")) {
        try response.sendText(connection, allocator, "");
    } else {
        var pathIter = std.mem.splitAny(u8, req.start_line.target, "/");
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
        } else if (std.mem.eql(u8, root, "files")) {
            const filename = pathIter.next() orelse "";

            switch (req.start_line.method) {
                .GET => {
                    try response.sendFile(connection, allocator, filename);
                },
                .POST => {
                    try response.createFile(connection, allocator, filename, req.body);
                },
            }
        } else {
            try response.notFound(connection, allocator);
        }
    }
}
