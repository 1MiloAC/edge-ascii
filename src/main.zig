const std = @import("std");
const stb_image = @import("stb_image.zig");
const stb_image_write = @import("stb_image_write.zig");
//const shader_wgsl = @embedFile("shader.wgsl");

const shader_wgsl =
\\@group(0) @binding(0) var<storage, read> input_buffer: array<u32>;
\\@group(0) @binding(1) var<storage, read_write> output_buffer: array<u32>;
\\
\\@compute @workgroup_size(64) // A single workgroup of size 1x1x1
\\fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
\\    let index = global_id.x;
\\
\\    // Ensure we don't go out of bounds
\\    if (index >= arrayLength(&input_buffer)) {
\\        return;
\\    }
\\
\\    // Simple operation: copy input value to output value
\\    output_buffer[index] = input_buffer[index];
\\}
;

const Error = error{ImageLoadFailed};
const wgpu = @cImport({
    @cInclude("wgpu.h");
});

const State = struct {
    adapter: ?*wgpu.struct_WGPUAdapterImpl = null,
    device: ?*wgpu.struct_WGPUDeviceImpl = null,
    queue: ?*wgpu.struct_WGPUQueueImpl = null,
    instance: ?*wgpu.struct_WGPUInstanceImpl = null,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    adapter_ready: bool = false,
    device_ready: bool = false,
    bmap_ready: bool = false,
};

//var device: ?*wgpu.struct_WGPUDeviceImpl = null;
//var queue: ?*wgpu.struct_WGPUQueueImpl = null;
var state = State{};

pub fn main() !void {
    wgpuInit();
    //   const device_desc: wgpu.WGPUDeviceDescriptor = .{
    //       .nextInChain = null,
    //       .label = "MainDevice",
    //       .requiredFeatureCount = 0,
    //       .requiredLimits = null,
    //       .defaultQueue = .{
    //           .nextInChain = null,
    //           .label = "MainQueue",
    //       },
    //   };

    //   device = wgpu.wgpuAdapterRequestDevice(adapter: WGPUAdapter, descriptor: [*c]const WGPUDeviceDescriptor, callbackInfo: WGPURequestDeviceCallbackInfo)

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

    std.debug.print("shader contents:\n{s}\n", .{shader_wgsl});

    var img = image.?;

    if (img.pixels) |p| {
        const h: usize = @intCast(img.height);
        const w: usize = @intCast(img.width);
        const c: usize = @intCast(img.channels);
        const size: usize = h * w * c;
        const buf: [*]u8 = @ptrCast(p);
        const bufp: []u8 = buf[0..size];

        const dispatch: u32 = @intCast(@divTrunc(img.height * img.width - @as(u32, 1), 64));
        const input_buffer = bufferinit(bufp);
        const output_buffer = rbufferinit(size);
        const copy_buffer = cbufferinit(size);

        const buffer_callback: wgpu.WGPUBufferMapCallbackInfo = .{
            .nextInChain = null,
            .callback = callback.bufferCall,
            .userdata1 = &state,
            .userdata2 = null,
        };

        const bind_group_layout = wgpu.wgpuDeviceCreateBindGroupLayout(state.device, &.{
            .entryCount = 2,
            .entries = &[_]wgpu.WGPUBindGroupLayoutEntry{
                .{ .nextInChain = null, .binding = 0, .visibility = wgpu.WGPUShaderStage_Compute, .buffer = .{
                    .type = wgpu.WGPUBufferBindingType_ReadOnlyStorage,
                    .hasDynamicOffset = wgpu.WGPUOptionalBool_False,
                    .minBindingSize = size,
                    },
                },
                .{
                    .nextInChain = null,
                    .binding = 1,
                    .visibility = wgpu.WGPUShaderStage_Compute,
                    .buffer = .{
                        .type = wgpu.WGPUBufferBindingType_Storage,
                        .hasDynamicOffset = wgpu.WGPUOptionalBool_False,
                        .minBindingSize = size,
                    },
                },
            },
            .nextInChain = null,
        });

        const shader_module = createShadderModule(state.device);
        if (shader_module == null){
            return error.ShaderCompilationFailed;
        }

        const pipeline_desc: wgpu.WGPUPipelineLayoutDescriptor = .{
            .nextInChain = null,
            .bindGroupLayoutCount = 1,
            .bindGroupLayouts = @ptrCast(&bind_group_layout),
        };
        const pipeline_layout = wgpu.wgpuDeviceCreatePipelineLayout(state.device, &pipeline_desc);

        const compute_pipleline_desc: wgpu.WGPUComputePipelineDescriptor = .{
            .layout = pipeline_layout,
            .compute = .{ .module = shader_module, .entryPoint = wgpu.struct_WGPUStringView{
                .data = "main",
                .length = 4,
            }, .nextInChain = null },
            .nextInChain = null,
        };
        const pipeline = wgpu.wgpuDeviceCreateComputePipeline(state.device, &compute_pipleline_desc);

        const bind_group = wgpu.wgpuDeviceCreateBindGroup(state.device, &.{ .nextInChain = null, .layout = bind_group_layout, .entryCount = 2, .entries = &[_]wgpu.WGPUBindGroupEntry{
            .{
                .nextInChain = null,
                .binding = 0,
                .buffer = input_buffer,
                .offset = 0,
                .size = size,
            },
            .{
                .nextInChain = null,
                .binding = 1,
                .buffer = output_buffer,
                .offset = 0,
                .size = size,
            },
        } });

        const encoder_desc: wgpu.WGPUCommandEncoderDescriptor = .{
            .nextInChain = null,
        };
        const encoder = wgpu.wgpuDeviceCreateCommandEncoder(state.device, &encoder_desc);

        const pass_desc: wgpu.WGPUComputePassDescriptor = .{
            .nextInChain = null,
        };
        const compute_pass = wgpu.wgpuCommandEncoderBeginComputePass(encoder, &pass_desc);
        _ = wgpu.wgpuComputePassEncoderSetPipeline(compute_pass, pipeline);
        _ = wgpu.wgpuComputePassEncoderSetBindGroup(compute_pass, 0, bind_group, 0, null);
        _ = wgpu.wgpuComputePassEncoderDispatchWorkgroups(compute_pass, dispatch, 1,1);
        _ = wgpu.wgpuComputePassEncoderEnd(compute_pass);
        _ = wgpu.wgpuCommandEncoderCopyBufferToBuffer(encoder, output_buffer, 0, copy_buffer, 0, size);

        const command = wgpu.wgpuCommandEncoderFinish(encoder, null);
        const queue = wgpu.wgpuDeviceGetQueue(state.device);
        _ = wgpu.wgpuQueueSubmit(queue, 1, @ptrCast(&command));
        std.debug.print("queue submitted\n", .{});

        _ = wgpu.wgpuBufferMapAsync(copy_buffer, wgpu.WGPUMapMode_Read, 0, size, buffer_callback);
        _ = wgpu.wgpuDevicePoll(state.device, wgpu.WGPUOptionalBool_True, null);

        state.mutex.lock();
        while (!state.bmap_ready) {
            state.cond.wait(&state.mutex);
        }
        state.mutex.unlock();
        std.debug.print("async done\n", .{});

        const mapped_ptr = wgpu.wgpuBufferGetMappedRange(copy_buffer, 0, size);
        const mapped_bytes: [*]u8 = @ptrCast(mapped_ptr);
        const output_data = mapped_bytes[0..size];

        var final_image = stb_image.Image{
            .width = img.width,
            .height = img.height,
            .channels = img.channels,
            .pixels = undefined,
        };

        final_image.pixels = if (output_data.len != 0) &output_data[0] else null;

        const ofilename = "wgpu.png";

        stb_image_write.writeImage(ofilename, &final_image);

        wgpu.wgpuBufferUnmap(copy_buffer);
    }

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
fn createShadderModule(device: ?*wgpu.struct_WGPUDeviceImpl) ?*wgpu.struct_WGPUShaderModuleImpl {
    std.debug.print("Shader content: {any}\n",.{shader_wgsl});
    std.debug.print("Shader length: {any}\n",.{shader_wgsl.len});
    std.debug.print("device ptr: {*}\n",.{device});

    const wgsl_stype = @as(wgpu.WGPUSType, wgpu.WGPUSType_ShaderSourceWGSL);
    std.debug.print("wgsl_stype: {any}\n",.{wgsl_stype});
    const wgsl_chain: wgpu.WGPUChainedStruct = .{
        .sType = wgsl_stype,
        .next = null,
    };
    const wgsl_desc: wgpu.WGPUShaderSourceWGSL = .{
        .chain = wgsl_chain,
        .code = .{
            .data = shader_wgsl.ptr,
            .length = shader_wgsl.len, },
        
    };
    const shader_desc: wgpu.WGPUShaderModuleDescriptor =.{
        .nextInChain = @ptrCast(&wgsl_desc),
    };
    std.debug.print("Shader ptr: {*}\n",.{shader_desc.nextInChain});

    std.debug.print("creating shader module\n",.{});
    const module = wgpu.wgpuDeviceCreateShaderModule(device, &shader_desc);

    if (module == null) {
        std.debug.print("failed to create shader module",.{});
    } else {
        std.debug.print("shader module created\n",.{});
    }
    return module;
}
fn wgpuInit() void {
    const options: wgpu.WGPURequestAdapterOptions = .{
        .powerPreference = wgpu.WGPUPowerPreference_HighPerformance,
        .compatibleSurface = null,
        .forceFallbackAdapter = wgpu.WGPUOptionalBool_False,
    };
    const adapter_callback: wgpu.WGPURequestAdapterCallbackInfo = .{
        .nextInChain = null,
        .callback = callback.adapterCall,
        .userdata1 = &state,
        .userdata2 = null,
    };
    const device_desc: wgpu.WGPUDeviceDescriptor = .{
        .nextInChain = null,
        .requiredFeatureCount = 0,
        .requiredLimits = null,
        .defaultQueue = .{
            .nextInChain = null,
        },
    };
    const device_callback: wgpu.WGPURequestDeviceCallbackInfo = .{
        .nextInChain = null,
        .callback = callback.deviceCall,
        .userdata1 = &state,
        .userdata2 = null,
    };

    state.instance = wgpu.wgpuCreateInstance(null);
    _ = wgpu.wgpuInstanceRequestAdapter(state.instance, &options, adapter_callback);

    state.mutex.lock();
    while (!state.adapter_ready) {
        state.cond.wait(&state.mutex);
    }
    state.mutex.unlock();
    _ = wgpu.wgpuAdapterRequestDevice(state.adapter.?, &device_desc, device_callback);

    state.mutex.lock();
    while (!state.device_ready) {
        state.cond.wait(&state.mutex);
    }
    state.mutex.unlock();

    std.debug.print("adapter recievedd {any}, device recieved: {any}\n", .{ state.adapter, state.device });
}
const callback = struct {
    pub fn adapterCall(
        status: wgpu.WGPURequestAdapterStatus,
        adapter: ?*wgpu.struct_WGPUAdapterImpl,
        message: wgpu.WGPUStringView,
        userdata1: ?*anyopaque,
        userdata2: ?*anyopaque,
    ) callconv(.C) void {
        _ = message;
        _ = userdata2;

        const state_ptr: *State = @alignCast(@ptrCast(userdata1.?));

        state_ptr.mutex.lock();
        defer state_ptr.mutex.unlock();

        state_ptr.adapter = adapter;
        state_ptr.adapter_ready = (status == wgpu.WGPURequestAdapterStatus_Success);
        state_ptr.cond.signal();
    }
    pub fn deviceCall(
        status: wgpu.WGPURequestDeviceStatus,
        device: ?*wgpu.struct_WGPUDeviceImpl,
        message: wgpu.WGPUStringView,
        userdata1: ?*anyopaque,
        userdata2: ?*anyopaque,
    ) callconv(.C) void {
        _ = message;
        _ = userdata2;

        const state_ptr: *State = @alignCast(@ptrCast(userdata1.?));

        state_ptr.mutex.lock();
        defer state_ptr.mutex.unlock();

        state_ptr.device = device;
        state_ptr.queue = wgpu.wgpuDeviceGetQueue(device.?);
        state_ptr.device_ready = (status == wgpu.WGPURequestDeviceStatus_Success);
        state_ptr.cond.signal();
    }
    pub fn bufferCall(
        status: wgpu.WGPUMapAsyncStatus,
        message: wgpu.WGPUStringView,
        userdata1: ?*anyopaque,
        userdata2: ?*anyopaque,
    ) callconv(.C) void {
        std.debug.print("buffercall status {}\n", .{status});
        _ = userdata2;
        _ = message;
        const state_ptr: *State = @alignCast(@ptrCast(userdata1.?));
        state_ptr.mutex.lock();
        defer state_ptr.mutex.unlock();

        state_ptr.bmap_ready = (status == wgpu.WGPUMapAsyncStatus_Success);

        state_ptr.cond.signal();
    }
};
fn bufferinit(data: []const u8) wgpu.WGPUBuffer {
    const desc: wgpu.WGPUBufferDescriptor = .{
        .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_Storage,
        .size = @as(u64, data.len),
        .mappedAtCreation = wgpu.WGPUOptionalBool_False,
    };
    const buffer = wgpu.wgpuDeviceCreateBuffer(state.device, &desc);
    _ = wgpu.wgpuQueueWriteBuffer(wgpu.wgpuDeviceGetQueue(state.device), buffer, 0, data.ptr, data.len);
    return buffer;
}
fn rbufferinit(size: usize) wgpu.WGPUBuffer {
    const desc: wgpu.WGPUBufferDescriptor = .{
        .usage = wgpu.WGPUBufferUsage_Storage | wgpu.WGPUBufferUsage_CopySrc,
        .size = @as(u64, size),
        .mappedAtCreation = wgpu.WGPUOptionalBool_False,
    };
    return wgpu.wgpuDeviceCreateBuffer(state.device, &desc);
}
fn cbufferinit(size: usize) wgpu.WGPUBuffer {
    const desc: wgpu.WGPUBufferDescriptor = .{
        .usage = wgpu.WGPUBufferUsage_CopyDst | wgpu.WGPUBufferUsage_MapRead,
        .size = @as(u64, size),
        .mappedAtCreation = wgpu.WGPUOptionalBool_False,
    };
    return wgpu.wgpuDeviceCreateBuffer(state.device, &desc);
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
