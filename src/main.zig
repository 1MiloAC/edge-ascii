const std = @import("std");
const stb_image = @import("stb_image.zig");
const stb_image_write = @import("stb_image_write.zig");

const Error = error{ImageLoadFailed};
const wgpu = @cImport({
    @cInclude("wgpu.h");
});

const State = struct {
    adapter: ?*wgpu.struct_WGPUAdapterImpl = null,
    instance: ?*wgpu.struct_WGPUInstanceImpl = null,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    adapter_ready: bool = false,
};

var state = State{};

pub fn main() !void {
    const options: wgpu.WGPURequestAdapterOptions = .{
        .powerPreference = wgpu.WGPUPowerPreference_HighPerformance,
        .compatibleSurface = null,
        .forceFallbackAdapter = wgpu.WGPUOptionalBool_False,
    };
    const callback_info: wgpu.WGPURequestAdapterCallbackInfo = .{
        .nextInChain = null,
        .callback = adapterCallback,
        .userdata1 = &state,
        .userdata2 = null,
    };

    state.instance = wgpu.wgpuCreateInstance(null);
    _ = wgpu.wgpuInstanceRequestAdapter(state.instance, &options, callback_info);

    state.mutex.lock();
    while (!state.adapter_ready) {
        state.cond.wait(&state.mutex);
    }
    state.mutex.unlock();
    std.debug.print("adapter recievedd {any}\n",.{state.adapter});

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

fn adapterCallback(
    status: wgpu.WGPURequestAdapterStatus,
    adapter: ?*wgpu.struct_WGPUAdapterImpl,
    message: wgpu.WGPUStringView,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
) callconv(.C) void {
    _ = status;
    _ = message;
    _ = userdata2;

    const state_ptr: *State = @alignCast(@ptrCast(userdata1.?));

    state_ptr.mutex.lock();
    defer state_ptr.mutex.unlock();

    state_ptr.adapter = adapter;
    state_ptr.adapter_ready = true;
    state_ptr.cond.signal();
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
    const pixel_count = imgW * imgH * imgC;

    var rimg: stb_image.Image = .{
        //        .width = @intCast(new_w),
        //        .height = @intCast(new_h),
        //        .channels = @intCast(new_c),
        .width = img.width,
        .height = img.height,
        .channels = img.channels,
        .pixels = undefined,
    };

    const slice: []u8 = try allocator.alloc(u8, new_pixel_count);
    const upscale: []u8 = try allocator.alloc(u8, pixel_count);

    const linear = try luminize(imgW, imgH, imgC, imgP, allocator);

    for (0..new_w) |x| {
        for (0..new_h) |y| {
            const originX = @divFloor(x * imgW, new_w);
            const originY = @divFloor(y * imgH, new_h);
            const indexN = ((y * new_w + x) * new_c);
            const indexO = ((originY * imgW + originX) * imgC);

            for (0..new_c) |c| {
                slice[indexN + c] = linear[indexO + c];
            }
        }
    }
    for (0..new_w) |x| {
        for (0..new_h) |y| {
            const oX = @divFloor(x * imgW, new_w);
            const oY = @divFloor(y * imgH, new_h);
            const index = ((y * new_w + x) * new_c);
            std.debug.print("x is {}\n", .{x});

            for (0..8) |w| {
                for (0..8) |h| {
                    const uX = oX + w;
                    const uY = oY + h;
                    const indexO = ((uY * imgW + uX) * imgC);

                    for (0..new_c) |c| {
                        upscale[indexO + c] = slice[index + c];
                    }
                }
            }
        }
    }

    rimg.pixels = if (upscale.len != 0) &upscale[0] else null;
    return rimg;
}
fn luminize(w: usize, h: usize, c: usize, p: []u8, alloc: std.mem.Allocator) ![]u8 {
    const pc = w * h * c;
    const linearized: []u8 = try alloc.alloc(u8, pc);
    for (0..w) |x| {
        for (0..h) |y| {
            const indexL = ((y * w + x) * c);

            const r: f32 = @floatFromInt(p[indexL + 0]);
            const g: f32 = @floatFromInt(p[indexL + 1]);
            const b: f32 = @floatFromInt(p[indexL + 2]);
            const vR: f32 = linearize(r / 255.0);
            const vG: f32 = linearize(g / 255.0);
            const vB: f32 = linearize(b / 255.0);
            const lum = vR * 0.2126 + vG * 0.7152 + vB * 0.0722;
            const constrained = @floor(lum * 10) / 10;

            for (0..c) |i| {
                linearized[indexL + i] = @intFromFloat(std.math.clamp(constrained * 255, 0, 255));
            }
        }
    }
    return linearized;
}

fn srgbize(c: f32) f32 {
    if (c <= 0.0031308) {
        return c * 12.92;
    } else {
        return std.math.pow(f32, c, 1.0 / 2.4) - 0.055;
    }
}
fn linearize(c: f32) f32 {
    if (c <= 0.04045) {
        return c / 12.92;
    } else {
        return std.math.pow(f32, ((c + 0.055) / 1.055), 2.4);
    }
}
