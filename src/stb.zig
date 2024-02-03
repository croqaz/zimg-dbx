const c = @cImport({
    @cInclude("stb_image.h");
});

pub const StbImage = struct {
    width: u32,
    height: u32,
    channels: u32,
    raw: []u8,

    pub fn destroy(im: *StbImage) void {
        c.stbi_image_free(im.raw.ptr);
    }

    pub fn create(buffer: []const u8) !StbImage {
        var width: c_int = undefined;
        var height: c_int = undefined;

        if (c.stbi_info_from_memory(buffer.ptr, @as(c_int, @intCast(buffer.len)), &width, &height, null) == 0) {
            return error.NotImageFile;
        }
        if (width < 1 or height < 1) return error.NoPixels;

        var im: StbImage = undefined;
        im.width = @as(u32, @intCast(width));
        im.height = @as(u32, @intCast(height));

        if (c.stbi_is_16_bit_from_memory(buffer.ptr, @as(c_int, @intCast(buffer.len))) != 0) {
            return error.InvalidFormat;
        }

        // c.stbi_set_flip_vertically_on_load(1);
        var channels: c_int = undefined;
        const image_data = c.stbi_load_from_memory(buffer.ptr, @as(c_int, @intCast(buffer.len)), &width, &height, &channels, 0);
        if (image_data == null) return error.NoMem;

        im.channels = @as(u32, @intCast(channels));
        im.raw = image_data[0 .. im.width * im.height * im.channels];

        return im;
    }
};
