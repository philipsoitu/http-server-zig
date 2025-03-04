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

pub fn sendText(
    connection: net.Server.Connection,
    allocator: std.mem.Allocator,
    response: []const u8,
) !void {
    // Cast the length of the response to u16 (be mindful of responses longer than u16's max)
    const content_length: u16 = @intCast(response.len);
    try streamResponse(
        "HTTP/1.1",
        200,
        "OK",
        "text/plain",
        content_length,
        response,
        connection,
        allocator,
    );
}

pub fn notFound(
    connection: net.Server.Connection,
    allocator: std.mem.Allocator,
) !void {
    // Cast the length of the response to u16 (be mindful of responses longer than u16's max)
    try streamResponse(
        "HTTP/1.1",
        404,
        "Not Found",
        "text/plain",
        0,
        "",
        connection,
        allocator,
    );
}
