const builtin = @import("builtin");
const std = @import("std");

pub const GitHubRelease = struct {
    tag_name: []const u8,
    name: []const u8,
    assets: []Asset,
    const Asset = struct {
        name: []const u8,
        browser_download_url: []const u8,
    };
};

pub fn getLatestDownloadUri(allocator: std.mem.Allocator) ![]const u8 {
    const latest_tag = try getLatestReleaseTag(allocator);
    defer allocator.free(latest_tag);

    return try allocator.dupe(u8, latest_tag);
}

fn convertTagToFile(tag: []const u8) ![]const u8 {
    _ = tag;
    return switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "Linux 64-bit (x86)",
            .aarch64 => "Linux 64-bit (ARM)",
            else => "Linux (Other Arch)",
        },
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => "Windows 64-bit",
            else => "Windows (Other/32-bit)",
        },
        .macos => switch (builtin.cpu.arch) {
            .x86_64 => "macOS (Intel)",
            .aarch64 => "macOS (Apple Silicon/M-series)",
            else => "macOS (Other Arch)",
        },
        else => "Unsupported Operating System",
    };
}

pub fn getLatestReleaseTag(allocator: std.mem.Allocator) ![]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://api.github.com/repos/richardltc/boxwallet2/releases/latest");

    // var writer_buffer: [8 * 1024]u8 = undefined;
    var redirect_buffer: [8 * 1024]u8 = undefined;

    // Create a writer to collect the response
    var body_writer: std.Io.Writer.Allocating = .init(allocator);
    defer body_writer.deinit();

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .redirect_buffer = &redirect_buffer,
        .response_writer = &body_writer.writer,
        .headers = .{
            .user_agent = .{ .override = "zig-fetch-example" },
        },
    });

    if (result.status != .ok) return error.HttpError;

    const response_body = body_writer.written();

    const parsed = try std.json.parseFromSlice(
        GitHubRelease,
        allocator,
        response_body,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    return try allocator.dupe(u8, parsed.value.tag_name);
}
