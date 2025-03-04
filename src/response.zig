const std = @import("std");
const net = std.net;

pub fn streamResponse(
    protocol: []const u8,
    status_code: u16,
    status_text: []const u8,
    content_type: []const u8,
    content_length: u16,
    body: []const u8,
    connection: net.Server.Connection,
    allocator: std.mem.Allocator,
) !void {
    const res_str = try std.fmt.allocPrint(
        allocator,
        "{s} {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\n\r\n{s}",
        .{ protocol, status_code, status_text, content_type, content_length, body },
    );
    defer allocator.free(res_str);
    _ = try connection.stream.write(res_str);
}

pub fn sendHelloWorld(connection: net.Server.Connection, allocator: std.mem.Allocator) !void {
    try streamResponse(
        "HTTP/1.1",
        200,
        "OK",
        "text/plain",
        12,
        "Hello World!",
        connection,
        allocator,
    );
}
