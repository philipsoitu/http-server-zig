const std = @import("std");
const net = std.net;

pub fn streamResponse(
    protocol: []const u8,
    status_code: u16,
    status_text: []const u8,
    content_type: []const u8,
    content_length: u64,
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

pub fn sendFile(
    connection: net.Server.Connection,
    allocator: std.mem.Allocator,
    filename: []const u8,
) !void {
    const full_path = try std.fmt.allocPrint(allocator, "files/{s}", .{filename});
    defer allocator.free(full_path);

    var file = try std.fs.cwd().openFile(full_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    const bytes = try file.read(buffer);
    if (bytes != file_size) {
        @panic("Wrong file size");
    }
    try streamResponse(
        "HTTP/1.1",
        200,
        "OK",
        "application/octet-stream",
        file_size,
        buffer,
        connection,
        allocator,
    );
}

pub fn createFile(
    connection: net.Server.Connection,
    allocator: std.mem.Allocator,
    filename: []const u8,
    contents: []const u8,
    contents_length: usize,
) !void {
    const full_path = try std.fmt.allocPrint(allocator, "files/{s}", .{filename});
    defer allocator.free(full_path);

    var file = try std.fs.cwd().createFile(full_path, .{});

    const parsed_contents = contents[0..contents_length];
    try file.writeAll(parsed_contents);
    defer file.close();

    try streamResponse(
        "HTTP/1.1",
        201,
        "Created",
        "",
        0,
        "",
        connection,
        allocator,
    );
}
