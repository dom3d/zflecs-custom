const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    _ = b.addModule("root", .{
        .root_source_file = b.path("src/zflecs.zig"),
    });

    const flecs = b.addStaticLibrary(.{
        .name = "flecs",
        .target = target,
        .optimize = optimize,
    });
    flecs.linkLibC();
    flecs.addIncludePath(b.path("libs/flecs"));
    flecs.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "include" }) });
    flecs.addCSourceFile(.{
        .file = b.path("libs/flecs/flecs.c"),
        .flags = &.{
            "-fno-sanitize=undefined",
            "-DFLECS_NO_CPP",
            "-DFLECS_USE_OS_ALLOC",
            if (target.result.os.tag == .emscripten) "-D__EMSCRIPTEN__" else "",
            if (@import("builtin").mode == .Debug) "-DFLECS_SANITIZE" else "",
        },
    });

    b.installArtifact(flecs);

    switch (target.result.os.tag) {
        .windows => {
            flecs.linkSystemLibrary("ws2_32");
        },
        else => {},
    }

    const test_step = b.step("test", "Run zflecs tests");

    const tests = b.addTest(.{
        .name = "zflecs-tests",
        .root_source_file = b.path("src/zflecs.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tests);

    tests.linkLibrary(flecs);

    test_step.dependOn(&b.addRunArtifact(tests).step);
}
