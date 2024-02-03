const std = @import("std");
const stb = @import("stb.zig");

const fs = std.fs;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        std.debug.print("Must specify an image path!\n", .{});
        return;
    }

    const max_size = std.math.maxInt(usize);
    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], max_size);
    defer allocator.free(data);

    const img = try stb.StbImage.create(data);
    std.debug.print("W: {}, H: {}, Chan: {}\n", .{ img.width, img.height, img.channels });
}
