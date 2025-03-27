const std = @import("std");
const c = @cImport(@cInclude("stb_image.h"));

pub const Image = extern struct {
    width: i32,
    height: i32,
    channels: i32,
    pixels: ?*u8,
};

pub fn loadImage(filename: [*:0]const u8, set_channels: i32) ?Image {
    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;

    const pixels = c.stbi_load(filename, &width, &height, &channels, set_channels) orelse return null;

    return Image{
        .width = width,
        .height = height,
        .channels = channels,
        .pixels = pixels,
    };
}

pub fn freeImage(image: *Image) void {
    if (image.pixels) |ptr| {
        std.debug.print("testing freeing memory {*}\n", .{ptr});
        c.stbi_image_free(@ptrCast(ptr));
        image.pixels = null;
        std.debug.print("Freed memory sucessfully!", .{});
    } else {
        std.debug.print("No pixel data to be freed\n", .{});
    }
}
