const std = @import("std");
const net = std.net;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const address = try net.Address.resolveIp("127.0.0.1", 42069);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    const allocator = std.heap.page_allocator;
    const buff = try allocator.alloc(u8, 2048);
    defer allocator.free(buff);

    const connection = try listener.accept();
    defer connection.stream.close();

    _ = try connection.stream.read(buff);
    try stdout.print("client connected!\n", .{});

    var split = std.mem.split(u8, buff, " ");
    const request_type = split.next();
    const request_target = split.next();
    try stdout.print("request_type: {?s}\n", .{request_type});
    try stdout.print("request_target: {?s}\n", .{request_target});

    if (std.mem.eql(u8, request_type.?, "GET")) {
        if (std.mem.eql(u8, request_target.?, "/")) {
            try success(connection);
        } else {
            try not_found(connection);
        }
    } else {
        try not_found(connection);
    }
}

pub fn success(connection: net.Server.Connection) !void {
    _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
}

pub fn not_found(connection: net.Server.Connection) !void {
    _ = try connection.stream.write("HTTP/1.1 404 Not Found\r\n\r\n");
}
