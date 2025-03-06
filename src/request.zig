const std = @import("std");

pub const HttpMethod = enum {
    GET,
    POST,
};

pub const StartLine = struct {
    method: HttpMethod,
    target: []const u8,
    protocol: []const u8,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Request = struct {
    start_line: StartLine,
    headers: std.ArrayList(Header),
    body: []const u8,
};

pub fn parseRequest(buff: []const u8, allocator: std.mem.Allocator) !Request {
    var iter = std.mem.splitSequence(u8, buff, "\r\n");

    // Parse start line
    const start_line_str = iter.next() orelse return error.InvalidRequest;
    var parts = std.mem.splitSequence(u8, start_line_str, " ");
    const method_str = parts.next() orelse return error.InvalidRequest;
    const target = parts.next() orelse return error.InvalidRequest;
    const protocol = parts.next() orelse return error.InvalidRequest;

    const method_enum = try parseMethod(method_str);

    const start_line = StartLine{
        .method = method_enum,
        .target = target,
        .protocol = protocol,
    };

    // Parse headers
    var headers_buf = std.ArrayList(Header).init(allocator);
    while (true) {
        const line = iter.next() orelse break;
        if (std.mem.eql(u8, line, "")) break;

        const colon_index = std.mem.indexOf(u8, line, ":") orelse return error.InvalidRequest;
        const name = line[0..colon_index];
        const value_start = colon_index + 1;
        const value = std.mem.trim(u8, line[value_start..], " ");
        try headers_buf.append(Header{ .name = name, .value = value });
    }

    // Parse body
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

fn parseMethod(method: []const u8) !HttpMethod {
    if (std.mem.eql(u8, method, "GET")) return HttpMethod.GET;
    if (std.mem.eql(u8, method, "POST")) return HttpMethod.POST;
    return error.InvalidMethod;
}

pub fn printRequest(req: Request) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{any} {s} {s}\n", .{ req.start_line.method, req.start_line.target, req.start_line.protocol });
    for (req.headers.items[0..req.headers.items.len]) |header| {
        try stdout.print("{s}: {s}\n", .{ header.name, header.value });
    }
    try stdout.print("\n{s}\n", .{req.body});
}
