const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{ .name = "main", .root_source_file = b.path("src/main.zig"), .target = b.host, .optimize = .ReleaseFast, .version = .{
        .major = 0,
        .minor = 1,
        .patch = 0,
        .pre = 1,
    } });
    exe.linkLibC();
    exe.addCSourceFile(b.path("libs/stb_image.c"));

    exe.addIncludePath(b.path("src"));
    exe.addIncludePath(b.path("libs"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
