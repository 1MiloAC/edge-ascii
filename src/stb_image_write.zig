const std = @import("std");
const stb_image = @import("stb_image.zig");
const c = @cImport(@cInclude("stb_image_write.h"));

pub fn writeImage(filename: [*:0]const u8, image: *stb_image.Image) void {
    if (image.pixels) |ptr| {
        const width: c_int = image.width;
        const height: c_int = image.height;
        const channels: c_int = image.channels;
        std.debug.print("{?}, {?}, {?}, {?},", .{ image.width, image.height, image.channels, image.pixels });
        _ = c.stbi_write_png(filename, width, height, channels, ptr, width * channels);
    } else {
        std.debug.print("Unable to find image data.", .{});
    }
}
