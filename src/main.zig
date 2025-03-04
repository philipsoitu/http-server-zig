const std = @import("std");
const net = std.net;

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
    try stdout.print("client connected!\n", .{});

    var reqIter = std.mem.split(u8, buff, " ");
    _ = reqIter.next();
    const req_target = reqIter.next();

    var pathIter = std.mem.split(u8, req_target.?, "/");
    _ = pathIter.next(); //since first is ""
    const root = pathIter.next();

    if (std.mem.eql(u8, req_target.?, "/")) {
        try stdout.print("just success", .{});
        try success(connection);
    } else if (std.mem.eql(u8, root.?, "echo")) {
        try stdout.print("echo server", .{});
        const second = pathIter.next();
        try echo_server(connection, second.?);
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

pub fn echo_server(connection: net.Server.Connection, string: []const u8) !void {
    const gpa = std.heap.page_allocator;

    const res = try std.fmt.allocPrint(gpa, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ string.len, string });
    defer gpa.free(res);

    _ = try connection.stream.write(res);
}
