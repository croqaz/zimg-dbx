const std = @import("std");

const CFlags = &.{
    "-std=c99",
    "-Wall",
    "-Wextra",
    "-fno-exceptions",
    "-fno-sanitize=undefined",
    // "-O2",
    // "-O0",
    // "-g",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zimg",
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.addIncludePath(b.path("./vendor"));
    exe.addCSourceFiles(.{
        .files = &[_][]const u8{"./c/image_impl.c"},
        .flags = CFlags,
    });

    b.installArtifact(exe);
}
