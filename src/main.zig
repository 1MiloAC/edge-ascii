const std = @import("std");
const stb_image = @import("stb_image.zig");
pub fn main() !void {
    const filename = try std.fs.path.resolve(std.fs.cwd(), "file.png");
    const image = try stb_image.loadImage(filename, 0);
    defer stb_image.freeImage(&image);

    std.debug.print("loaded image size: {}x{} with {} channels\n", .{ image.width, image.height, image.channels });
    std.debug.print("image pixel data: {p}\n", .{image.pixels});
}
