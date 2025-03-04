const std = @import("std");
const net = std.net;

const StartLine = struct {
    method: []const u8,
    target: []const u8,
    protocol: []const u8,
};

const Header = struct {
    name: []const u8,
    value: []const u8,
};

const Request = struct {
    start_line: StartLine,
    headers: std.ArrayList(Header),
    body: []const u8,
};

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

    const req: Request = try parseRequest(buff, allocator);

    try printRequest(req);

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
        try echoServer(connection, second.?, allocator);
    } else {
        try not_found(connection);
    }
}

pub fn parseRequest(buff: []const u8, allocator: std.mem.Allocator) !Request {
    var iter = std.mem.split(u8, buff, "\r\n");

    // start line
    const start_line_str = iter.next() orelse return error.InvalidRequest;
    var parts = std.mem.split(u8, start_line_str, " ");
    const method = parts.next() orelse return error.InvalidRequest;
    const target = parts.next() orelse return error.InvalidRequest;
    const protocol = parts.next() orelse return error.InvalidRequest;

    const start_line = StartLine{
        .method = method,
        .target = target,
        .protocol = protocol,
    };

    //headers
    var headers_buf = std.ArrayList(Header).init(allocator);

    while (true) {
        //break conditions
        const line = iter.next() orelse break;
        if (std.mem.eql(u8, line, "")) break;

        const colon_index = std.mem.indexOf(u8, line, ":") orelse return error.InvalidRequest;
        const name = line[0..colon_index];
        const value_start = colon_index + 1; //+1 skips ": "
        const value = std.mem.trim(u8, line[value_start..], " ");
        try headers_buf.append(Header{ .name = name, .value = value });
    }

    const header_end_opt = std.mem.indexOf(u8, buff, "\r\n\r\n");
    var body: []const u8 = "";
    if (header_end_opt) |header_end| {
        body = buff[(header_end + 4)..];
    }
    return Request{
        .start_line = start_line,
        .headers = headers_buf,
        .body = body,
    };
}

pub fn printRequest(req: Request) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s} {s} {s} \n", .{ req.start_line.method, req.start_line.target, req.start_line.protocol });

    for (req.headers.items[0..req.headers.items.len]) |header| {
        try stdout.print("{s}: {s} \n", .{ header.name, header.value });
    }

    try stdout.print("\n{s}\n", .{req.body});
}

pub fn success(connection: net.Server.Connection) !void {
    _ = try connection.stream.write("HTTP/1.1 200 OK\r\n\r\n");
}

pub fn not_found(connection: net.Server.Connection) !void {
    _ = try connection.stream.write("HTTP/1.1 404 Not Found\r\n\r\n");
}

pub fn echoServer(connection: net.Server.Connection, string: []const u8, allocator: std.mem.Allocator) !void {
    const res = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: {d}\r\n\r\n{s}", .{ string.len, string });
    defer allocator.free(res);

    _ = try connection.stream.write(res);
}
