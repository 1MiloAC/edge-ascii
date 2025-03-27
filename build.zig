const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{ .name = "main", .root_source_file = b.path("src/main.zig"), .target = target, .optimize = .Debug, .version = .{
        .major = 0,
        .minor = 1,
        .patch = 0,
    } });
    exe.linkLibC();
    exe.addCSourceFile(
        .{
            .file = b.path("libs/stb_image.c"),
        },
    );
    exe.addCSourceFile(
        .{
            .file = b.path("libs/stb_image_write.c"),
        },
    );

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
