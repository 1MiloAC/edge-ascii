const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{ .name = "main", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = .Debug, .version = .{
        .major = 0,
        .minor = 1,
        .patch = 0,
    } });
    exe.linkLibC();
    exe.addCSourceFile(.{
        .file = b.path("lib/stb_image.c"),
    });
    exe.addCSourceFile(.{
        .file = b.path("lib/stb_image_write.c"),
    });

    exe.linkFramework("Metal");
    exe.linkFramework("Quartzcore");
    exe.linkFramework("CoreGraphics");
    exe.linkFramework("Foundation");
    exe.linkFramework("CoreFoundation");
    exe.linkFramework("AppKit");
    exe.linkFramework("IOKit");

    exe.addIncludePath(b.path("src"));
    exe.addIncludePath(b.path("lib"));
    exe.addIncludePath(b.path("lib/wgpu/include"));
    exe.addLibraryPath(b.path("lib/wgpu/lib"));
    exe.addObjectFile(b.path("lib/wgpu/lib/libwgpu_native.a"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
