const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

const Crc32 = std.hash.Crc32;
const XxHash32 = std.hash.XxHash32;
const XxHash64 = std.hash.XxHash64;
const Sha1 = std.crypto.hash.Sha1;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Sha3_512 = std.crypto.hash.sha3.Sha3_512;

pub fn init(allocator: std.mem.Allocator) void {
    assert(mem_allocator == null);
    mem_allocator = allocator;
    mem_allocations = std.AutoHashMap(usize, usize).init(allocator);

    zstbMallocPtr = zstbMalloc;
    zstbReallocPtr = zstbRealloc;
    zstbFreePtr = zstbFree;
    // stb image resize
    zstbirMallocPtr = zstbirMalloc;
    zstbirFreePtr = zstbirFree;
}

pub fn deinit() void {
    assert(mem_allocator != null);
    mem_allocations.?.deinit();
    mem_allocations = null;
    mem_allocator = null;
}

pub const ImageWriteFormat = enum {
    png,
    jpg,
};

pub const StbImage = struct {
    raw: []u8,
    width: u32,
    height: u32,
    channels: u32,

    /// Destroy the image, release memory
    pub fn destroy(im: *StbImage) void {
        zstbFree(im.raw.ptr);
        im.* = undefined;
    }

    /// Create a new, blank image
    pub fn new(width: u32, height: u32, channels: u32) !StbImage {
        assert(mem_allocator != null);
        const size = width * height * channels;

        const mem = @as([*]u8, @ptrCast(zstbMalloc(size)));
        @memset(mem[0..size], 0);

        return .{
            .raw = mem[0..size],
            .width = width,
            .height = height,
            .channels = channels,
        };
    }

    pub fn write(
        im: *StbImage,
        fname: [:0]const u8,
        out_format: ImageWriteFormat,
    ) !void {
        const w = @as(c_int, @intCast(im.width));
        const h = @as(c_int, @intCast(im.height));
        const ch = @as(c_int, @intCast(im.channels));
        const result = switch (out_format) {
            .png => stbi_write_png(fname.ptr, w, h, ch, im.raw.ptr, 0),
            .jpg => stbi_write_jpg(fname.ptr, w, h, ch, im.raw.ptr, 80),
        };
        // If the result is 0, it's an error (per stb_image_write docs)
        if (result == 0) {
            return error.ImageWriteError;
        }
    }

    /// Create an image from encoded, allocated data.
    /// The creator of the encoded data is responsible for managing that memory.
    pub fn fromData(data: []const u8) !StbImage {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var channels: c_int = undefined;

        // decode the image data into an array of pixels
        const ptr = stbi_load_from_memory(data.ptr, @as(c_int, @intCast(data.len)), &width, &height, &channels, 0);
        if (ptr == null) return error.NoMemory;
        if (channels < 1) return error.NoChannels;
        if (width < 1 or height < 1) return error.NoPixels;

        var im: StbImage = undefined;
        im.width = @as(u32, @intCast(width));
        im.height = @as(u32, @intCast(height));
        im.channels = @as(u32, @intCast(channels));
        im.raw = @as([*]u8, @ptrCast(ptr))[0 .. im.width * im.height * im.channels];

        return im;
    }

    /// Load disk file and return an image.
    /// The memory is managed by this module.
    pub fn fromFile(fname: [:0]const u8) !StbImage {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var channels: c_int = undefined;

        // decode the file into an array of pixels
        const ptr = stbi_load(fname, &width, &height, &channels, 0);
        if (ptr == null) return error.ImageLoadFailed;
        if (channels < 1) return error.NoChannels;
        if (width < 1 or height < 1) return error.NoPixels;

        var im: StbImage = undefined;
        im.width = @as(u32, @intCast(width));
        im.height = @as(u32, @intCast(height));
        im.channels = @as(u32, @intCast(channels));
        im.raw = @as([*]u8, @ptrCast(ptr))[0 .. im.width * im.height * im.channels];

        return im;
    }

    pub fn resize(im: *const StbImage, new_width: u32, new_height: u32) StbImage {
        assert(mem_allocator != null);
        const new_size = new_width * new_height * im.channels;
        const new_data = @as([*]u8, @ptrCast(zstbMalloc(new_size)));

        stbir_resize_uint8_linear(
            im.raw.ptr,
            @as(c_int, @intCast(im.width)),
            @as(c_int, @intCast(im.height)),
            0,
            new_data,
            @as(c_int, @intCast(new_width)),
            @as(c_int, @intCast(new_height)),
            0,
            @as(c_int, @intCast(im.channels)),
        );
        return .{
            .raw = new_data[0..new_size],
            .width = new_width,
            .height = new_height,
            .channels = im.channels,
        };
    }

    pub fn crc32(im: *const StbImage) u32 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        return Crc32.hash(pixels);
    }

    pub fn xxhash32(im: *const StbImage) u64 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        return XxHash32.hash(0, pixels);
    }

    pub fn xxhash64(im: *const StbImage) u64 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        return XxHash64.hash(0, pixels);
    }

    pub fn sha1(im: *const StbImage) [Sha1.digest_length]u8 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        var hashed: [Sha1.digest_length]u8 = undefined;
        Sha1.hash(pixels, &hashed, .{});
        return hashed;
        // const sz = Sha1.digest_length;
        // var hashed: [sz]u8 = undefined;
        // // this long array must be filled with nulls
        // var encoded: [sz * 4]u8 = [_]u8{0} ** (sz * 4);
        // Sha1.hash(pixels, &hashed, .{});
        // return Base64.Encoder.encode(&encoded, &hashed);
    }

    pub fn sha256(im: *const StbImage) [Sha256.digest_length]u8 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        var hashed: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(pixels, &hashed, .{});
        return hashed;
    }

    pub fn sha512(im: *const StbImage) [Sha3_512.digest_length]u8 {
        const pixels = im.raw[0 .. im.width * im.height * im.channels];
        var hashed: [Sha3_512.digest_length]u8 = undefined;
        Sha3_512.hash(pixels, &hashed, .{});
        return hashed;
    }
};

// Shamelessly stolen from zig-gamedev:
// https://github.com/zig-gamedev/zig-gamedev/blob/main/libs/zstbi/src/zstbi.zig
var mem_allocator: ?std.mem.Allocator = null;
var mem_allocations: ?std.AutoHashMap(usize, usize) = null;
var mem_mutex: std.Thread.Mutex = .{};

extern var zstbMallocPtr: ?*const fn (size: usize) callconv(.C) ?*anyopaque;
extern var zstbReallocPtr: ?*const fn (ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque;
extern var zstbFreePtr: ?*const fn (maybe_ptr: ?*anyopaque) callconv(.C) void;

fn zstbMalloc(size: usize) callconv(.C) ?*anyopaque {
    mem_mutex.lock();
    defer mem_mutex.unlock();

    const mem = mem_allocator.?.alloc(u8, size) catch @panic("ZSTBI: out of memory");
    mem_allocations.?.put(@intFromPtr(mem.ptr), size) catch @panic("ZSTBI: hm out of memory");

    return mem.ptr;
}

fn zstbRealloc(ptr: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
    mem_mutex.lock();
    defer mem_mutex.unlock();

    const old_size = if (ptr != null) mem_allocations.?.get(@intFromPtr(ptr.?)).? else 0;
    const old_mem = if (old_size > 0)
        @as([*]u8, @ptrCast(ptr))[0..old_size]
    else
        @as([*]u8, undefined)[0..0];

    const new_mem = mem_allocator.?.realloc(old_mem, size) catch @panic("ZSTBI: out of memory");

    if (ptr != null) {
        const removed = mem_allocations.?.remove(@intFromPtr(ptr.?));
        assert(removed);
    }

    mem_allocations.?.put(@intFromPtr(new_mem.ptr), size) catch @panic("ZSTBI: hm out of memory");

    return new_mem.ptr;
}

fn zstbFree(maybe_ptr: ?*anyopaque) callconv(.C) void {
    if (maybe_ptr) |ptr| {
        mem_mutex.lock();
        defer mem_mutex.unlock();

        const size = mem_allocations.?.fetchRemove(@intFromPtr(ptr)).?.value;
        const mem = @as([*]u8, @ptrCast(ptr))[0..size];

        mem_allocator.?.free(mem);
    }
}

extern var zstbirMallocPtr: ?*const fn (size: usize, maybe_context: ?*anyopaque) callconv(.C) ?*anyopaque;
extern var zstbirFreePtr: ?*const fn (maybe_ptr: ?*anyopaque, maybe_context: ?*anyopaque) callconv(.C) void;

fn zstbirMalloc(size: usize, _: ?*anyopaque) callconv(.C) ?*anyopaque {
    return zstbMalloc(size);
}

fn zstbirFree(maybe_ptr: ?*anyopaque, _: ?*anyopaque) callconv(.C) void {
    zstbFree(maybe_ptr);
}

pub extern fn stbi_info_from_memory(
    data: [*]const u8,
    len: c_int,
    x: *c_int,
    y: *c_int,
    channels: *c_int,
) c_int;

pub extern fn stbi_load_from_memory(
    data: [*]const u8,
    len: c_int,
    x: *c_int,
    y: *c_int,
    channels: *c_int,
    desired_channels: c_int,
) ?[*]u8;

extern fn stbi_load(
    fname: [*:0]const u8,
    x: *c_int,
    y: *c_int,
    channels: *c_int,
    desired_channels: c_int,
) ?[*]u8;

extern fn stbi_write_jpg(
    fname: [*:0]const u8,
    w: c_int,
    h: c_int,
    channels: c_int,
    data: [*]const u8,
    quality: c_int,
) c_int;

extern fn stbi_write_png(
    fname: [*:0]const u8,
    w: c_int,
    h: c_int,
    channels: c_int,
    data: [*]const u8,
    stride_in_bytes: c_int,
) c_int;

extern fn stbir_resize_uint8_linear(
    input_pixels: [*]const u8,
    input_w: c_int,
    input_h: c_int,
    input_stride_in_bytes: c_int,
    output_pixels: [*]u8,
    output_w: c_int,
    output_h: c_int,
    output_stride_in_bytes: c_int,
    stbir_pixel_layout: c_int,
) void;

test "empty raw image" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.new(1, 1, 3);
    defer im1.destroy();

    im1.raw[2] = 200;

    try testing.expect(im1.width == 1);
    try testing.expect(im1.height == 1);
    try testing.expect(im1.channels == 3);
    try testing.expectEqualSlices(u8, &.{ 0, 0, 200 }, im1.raw);
}

test "empty image hashes" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.new(1, 1, 3);
    defer im1.destroy();

    try testing.expect(im1.crc32() == 4282505490);
    try testing.expect(im1.xxhash32() == 4270428348);
    try testing.expect(im1.xxhash64() == 3569224950158953636);
    try testing.expectEqualSlices(u8, &.{ 41, 226, 220, 251, 177, 111, 99, 187, 2, 84, 223, 117, 133, 161, 91, 182, 251, 94, 146, 125 }, &im1.sha1());
}

test "create image from data" {
    init(testing.allocator);
    defer deinit();

    const raw1 = try std.fs.cwd().readFileAlloc(testing.allocator, "pics/r_img.png", 1024);
    defer testing.allocator.free(raw1);

    var im1 = try StbImage.fromData(raw1);
    defer im1.destroy();

    try testing.expect(im1.width == 2);
    try testing.expect(im1.height == 2);
    try testing.expect(im1.channels == 3);
    try testing.expectEqualSlices(u8, &.{ 250, 0, 0, 250, 0, 0, 250, 0, 0, 250, 0, 0 }, im1.raw);

    const raw2 = try std.fs.cwd().readFileAlloc(testing.allocator, "pics/r_img.jpg", 1024);
    defer testing.allocator.free(raw2);

    var im2 = try StbImage.fromData(raw2);
    defer im2.destroy();

    try testing.expect(im2.width == 2);
    try testing.expect(im2.height == 2);
    try testing.expect(im2.channels == 3);
}

test "open image from file" {
    init(testing.allocator);
    defer deinit();

    const Checker = struct {
        pub fn check(img: *StbImage) !void {
            try testing.expect(img.width == 2);
            try testing.expect(img.height == 2);
            try testing.expect(img.channels == 3);
        }
    };

    var im2 = try StbImage.fromFile("pics/g_img.png");
    defer im2.destroy();
    try Checker.check(&im2);

    var im3 = try StbImage.fromFile("pics/b_img.png");
    defer im3.destroy();
    try Checker.check(&im3);

    var im4 = try StbImage.fromFile("pics/g_img.jpg");
    defer im4.destroy();
    try Checker.check(&im4);

    var im5 = try StbImage.fromFile("pics/b_img.jpg");
    defer im5.destroy();
    try Checker.check(&im5);
}

test "write PNG image" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.new(1, 1, 3);
    defer im1.destroy();
    im1.raw[1] = 200;
    try im1.write("test_write.png", ImageWriteFormat.png);

    var im2 = try StbImage.fromFile("test_write.png");
    defer im2.destroy();

    try testing.expect(im1.width == im2.width);
    try testing.expect(im1.height == im2.height);
    try testing.expect(im1.channels == im2.channels);

    try std.fs.cwd().deleteFile("test_write.png");
}

test "write JPG image" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.fromFile("pics/b_img.jpg");
    defer im1.destroy();
    try im1.write("test_write.jpg", ImageWriteFormat.jpg);

    var im2 = try StbImage.fromFile("test_write.jpg");
    defer im2.destroy();

    try testing.expect(im1.width == im2.width);
    try testing.expect(im1.height == im2.height);
    try testing.expect(im1.channels == im2.channels);

    try std.fs.cwd().deleteFile("test_write.jpg");
}

test "resize from empty" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.new(1, 1, 3);
    defer im1.destroy();

    var big1 = im1.resize(3, 3);
    defer big1.destroy();

    try testing.expect(big1.width == 3);
    try testing.expect(big1.height == 3);
    try testing.expect(big1.channels == 3);
}

test "resize from image file" {
    init(testing.allocator);
    defer deinit();

    var im1 = try StbImage.fromFile("pics/b_img.png");
    defer im1.destroy();

    var big1 = im1.resize(5, 5);
    defer big1.destroy();

    try testing.expect(big1.width == 5);
    try testing.expect(big1.height == 5);
    try testing.expect(big1.channels == 3);

    var im2 = try StbImage.fromFile("pics/b_img.jpg");
    defer im2.destroy();

    var big3 = im2.resize(4, 4);
    defer big3.destroy();

    try testing.expect(big3.width == 4);
    try testing.expect(big3.height == 4);
    try testing.expect(big3.channels == 3);
}
