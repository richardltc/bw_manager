const std = @import("std");

/// Replaces all occurrences of `target` in `source` with `replace`.
/// Caller owns the returned memory and must free it.
pub fn replaceString(allocator: std.mem.Allocator, source: []const u8, target: []const u8, replace: []const u8) ![]u8 {
    if (target.len == 0) {
        // If target is empty, return a copy of source
        return try allocator.dupe(u8, source);
    }

    // Count occurrences of target in source
    var count: usize = 0;
    var pos: usize = 0;
    while (pos <= source.len - target.len) {
        if (std.mem.eql(u8, source[pos..][0..target.len], target)) {
            count += 1;
            pos += target.len;
        } else {
            pos += 1;
        }
    }

    // Calculate the size of the result
    const result_len = source.len - (count * target.len) + (count * replace.len);
    var result = try allocator.alloc(u8, result_len);

    // Build the result string
    var src_pos: usize = 0;
    var dst_pos: usize = 0;

    while (src_pos < source.len) {
        if (src_pos <= source.len - target.len and
            std.mem.eql(u8, source[src_pos..][0..target.len], target))
        {
            // Found a match, copy the replacement
            @memcpy(result[dst_pos..][0..replace.len], replace);
            src_pos += target.len;
            dst_pos += replace.len;
        } else {
            // No match, copy the character
            result[dst_pos] = source[src_pos];
            src_pos += 1;
            dst_pos += 1;
        }
    }

    return result;
}

// Example usage
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try replaceString(allocator, "Hello world!", "world", "");
    defer allocator.free(result);

    std.debug.print("Result: '{s}'\n", .{result});
}
