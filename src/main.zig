const std = @import("std");
const stb_image = @import("stb_image.zig");
const stb_image_write = @import("stb_image_write.zig");

const Error = error{ImageLoadFailed};
//pub const RImage = struct {
//    width: usize,
//    height: usize,
//    channels: usize,
//    pixels: ?*u8,
//};
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


    var rimg = try resize(alloc, img);
    
    defer stb_image.freeImage(&rimg);



    defer if (img.pixels != null) {
        stb_image.freeImage(&img);
    };

    std.debug.print("loaded image size: {?}x{?} with {?} channels\n", .{ img.width, img.height, img.channels });

    if (img.pixels) |pixels| {
        std.debug.print("image pixel data: {*}\n", .{pixels});
    } else {
        std.debug.print("image pixel data: (null)\n", .{});
    }
    const rfilename = "test2.png";
    const wfilename = "test.png";
    std.debug.print("attempting to write image", .{});

    stb_image_write.writeImage(wfilename, &img);
    stb_image_write.writeImage(rfilename, &rimg);
}

fn resize(allocator: std.mem.Allocator, img: stb_image.Image) !stb_image.Image {
    
    const imgW: usize = @intCast(img.width);
    const imgH: usize = @intCast(img.height);
    const imgC: usize = @intCast(img.channels);
    const bufP: [*]u8 = @ptrCast(img.pixels.?);
    const imgP: []u8 = bufP[0..(imgW * imgH * imgC)];

    const new_w = @divFloor(imgW, 8);
    const new_h = @divFloor(imgH, 8);
    const new_c = imgC;
    const new_pixel_count = new_w * new_h * new_c;
    
    var rimg: stb_image.Image = .{
        .width = @intCast(new_w),
        .height = @intCast(new_h),
        .channels = @intCast(new_c),
        .pixels = undefined,
    };
    
    const slice: []u8 = try allocator.alloc(u8, new_pixel_count);

    for (0..new_h) |y| {
        for(0..new_w) |x| {
            const originX = @divFloor(x * imgW, new_w);
            const originY = @divFloor(y * imgH, new_h);
            const indexN = ((y * new_w + x ) * new_c);
            const indexO = ((originY * imgW + originX) * imgC);

            for (0..new_c) |c| {
                slice[indexN + c] = imgP[indexO + c];
            }
        }
    }

    rimg.pixels = if (slice.len != 0) &slice[0] else null;
    return rimg;
}
