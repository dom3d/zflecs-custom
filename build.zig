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

    // todo: constrain to host being OSX
    if (target.result.os.tag == .emscripten) {
        if (b.sysroot == null) {
            b.sysroot = macosSdkDir(b);
        }
        //flecs.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "include" }) });
        flecs.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "usr", "include" }) });
        //flecs.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "cache", "sysroot", "include" }) });
    }
    // flecs.addIncludePath(.{ .path = b.pathJoin(&.{ b.sysroot.?, "include" }) });

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

// helper function to get SDK path on Mac, taken from: https://github.com/prime31/zig-upaya/blob/b040acab13c7af00c3ce0eade03e1f3b0b1d5b02/src/deps/imgui/build.zig#L44
// or https://github.com/gballet/zig/blob/8ea2b40e5f621482d714fdd7cb05bbc592fc550b/lib/std/zig/system/macos.zig#L459
fn macosSdkDir(b: *std.Builder) ![]u8 {
    var str = try b.exec(&[_][]const u8{ "xcrun", "--show-sdk-path" });
    const strip_newline = std.mem.lastIndexOf(u8, str, "\n");
    if (strip_newline) |index| {
        str = str[0..index];
    }
    //const frameworks_dir = try std.mem.concat(b.allocator, u8, &[_][]const u8{ str, "/System/Library/Frameworks" });
    return str;
}
