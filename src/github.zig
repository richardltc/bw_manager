const builtin = @import("builtin");
const std = @import("std");
const rjm_strings = @import("rjm_strings.zig");

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
    // https://github.com/richardltc/boxwallet2/releases/download/v0.0.5/boxwallet-0.0.5-linux-x64.tar.gz
    const base_url: []const u8 = "https://github/richardltc/boxwallet2/releases/download/";

    const latest_tag = try getLatestReleaseTag(allocator);
    defer allocator.free(latest_tag);

    const filename = try convertTagToFile(allocator, latest_tag);

    // Use allocPrint to concatenate the parts into a new string
    const full_url = try std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{
        base_url,
        latest_tag,
        filename,
    });

    return full_url;
}

fn convertTagToFile(allocator: std.mem.Allocator, tag: []const u8) ![]const u8 {
    // boxwallet-0.0.5-linux-x64.tar.gz
    const version = try rjm_strings.replaceString(allocator, tag, "v", "");
    defer allocator.free(version);

    const prefix = "boxwallet-";

    const suffix = switch (builtin.os.tag) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => "linux-x64.tar.gz",
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

    // Construct the final string: boxwallet-0.0.5-linux-x64.tar.gz
    // Note: I removed the "/" from your fmt string to match your comment's format
    return try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{
        prefix,
        version,
        suffix,
    });
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
