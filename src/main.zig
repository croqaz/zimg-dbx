const std = @import("std");
const stb = @import("stb.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        std.debug.print("Must specify an image path!\n", .{});
        return;
    }

    const data = try std.fs.cwd().readFileAlloc(allocator, args[1], 512 * 1024);
    defer allocator.free(data);

    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const arenaAlloc = arena.allocator();

    stb.init(allocator);
    defer stb.deinit();

    var img = try stb.StbImage.fromData(data);
    defer img.destroy();

    std.debug.print("W: {}, H: {}, Chan: {}, Pix: {}\n", .{ img.width, img.height, img.channels, img.raw.len });

    var thumb = img.resize(128, 128);
    defer thumb.destroy();

    try thumb.write("small.png", stb.ImageWriteFormat.png);
}
