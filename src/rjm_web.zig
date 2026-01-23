const std = @import("std");

pub fn downloadFile(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var redirect_buffer: [8 * 1024]u8 = undefined;

    // Create output file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    var file_writer_buffer: [8 * 1024]u8 = undefined;
    var file_writer = file.writer(&file_writer_buffer);

    std.debug.print("Downloading {s}...\n", .{url});

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .redirect_buffer = &redirect_buffer,
        .response_writer = &file_writer.interface,
        .headers = .{
            .user_agent = .{ .override = "zig-download-example" },
        },
    });

    try file_writer.interface.flush();

    if (result.status != .ok) {
        std.debug.print("Download failed with status: {}\n", .{result.status});
        return error.HttpError;
    }

    std.debug.print("Download complete: {s}\n", .{output_path});
}

pub fn downloadFileWithProgress(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    // Create the request
    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &server_header_buffer,
    });
    defer req.deinit();

    // Send the request and wait for the response headers
    try req.send();
    try req.wait();

    if (req.response.status != .ok) {
        std.debug.print("Download failed with status: {}\n", .{req.response.status});
        return error.HttpError;
    }

    // Get content length to calculate percentage
    const content_length = req.response.content_length;

    // Create output file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    var buf: [8192]u8 = undefined;
    var downloaded: u64 = 0;

    std.debug.print("Downloading {s}...\n", .{url});

    // Read loop to track progress
    while (true) {
        const bytes_read = try req.read(&buf);
        if (bytes_read == 0) break; // EOF

        try file.writeAll(buf[0..bytes_read]);
        downloaded += bytes_read;

        if (content_length) |total| {
            const percent = (@as(f32, @floatFromInt(downloaded)) / @as(f32, @floatFromInt(total))) * 100.0;
            // \r returns the cursor to the start of the line
            std.debug.print("\rProgress: {d: >3.2}% ({d}/{d} bytes)", .{ percent, downloaded, total });
        } else {
            std.debug.print("\rDownloaded: {d} bytes (Unknown total)", .{downloaded});
        }
    }

    std.debug.print("\nDownload complete: {s}\n", .{output_path});
}
