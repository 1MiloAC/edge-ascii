const std = @import("std");
const stb_image = @import("stb_image.zig");
const stb_image_write = @import("stb_image_write.zig");

const Error = error{ImageLoadFailed};
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    const filename = "test.jpeg";
    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");

    std.debug.print("cwd: {s}\n", .{cwd});
    const image = stb_image.loadImage(filename, 0);

    if (image == null) {
        return Error.ImageLoadFailed;
    }

    var img = image.?;

    defer if (img.pixels != null) {
        stb_image.freeImage(&img);
    };

    std.debug.print("loaded image size: {?}x{?} with {?} channels\n", .{ img.width, img.height, img.channels });

    if (img.pixels) |pixels| {
        std.debug.print("image pixel data: {*}\n", .{pixels});
    } else {
        std.debug.print("image pixel data: (null)\n", .{});
    }

    const wfilename = "test.png";
    std.debug.print("attempting to write image", .{});

    stb_image_write.writeImage(wfilename, &img);
}
