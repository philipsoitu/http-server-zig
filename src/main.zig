const std = @import("std");
const net = std.net;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const address = try net.Address.resolveIp("127.0.0.1", 42069);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    const connection = try listener.accept();
    defer connection.stream.close();

    try stdout.print("client connected!\n", .{});

    try success(connection);
}

pub fn success(connection: net.Server.Connection) !void {
    _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
}
