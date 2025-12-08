const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rest_your_eyes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add Objective-C file
    exe.addCSourceFile(.{
        .file = b.path("src/macos_ui.m"),
        .flags = &.{"-fobjc-arc"},
    });

    // Include directories
    exe.addIncludePath(b.path("src"));

    // Link frameworks and libraries
    exe.linkLibC();
    exe.linkSystemLibrary("objc");
    exe.linkFramework("Cocoa");

    // Define App Bundle paths
    const app_name = "RestYourEyes.app";
    const contents_path = b.fmt("{s}/Contents", .{app_name});
    const macos_path = b.fmt("{s}/MacOS", .{contents_path});
    const resources_path = b.fmt("{s}/Resources", .{contents_path});

    // 1. Install the executable into MacOS folder
    const install_exe = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = macos_path } },
    });

    // 2. Install Info.plist
    const install_plist = b.addInstallFile(b.path("Info.plist"), b.fmt("{s}/Info.plist", .{contents_path}));

    // 3. Install status bar icon
    const install_status_icon = b.addInstallFile(b.path("images/icon.png"), b.fmt("{s}/icon.png", .{resources_path}));

    // 4. Generate and install AppIcon.icns
    // We'll create a script to handle the complex icon generation to keep build.zig cleanish
    // or just run a series of commands. Let's do a custom step that runs a shell script string.

    const icon_cmd_str =
        \\mkdir -p zig-out/tmp.iconset &&
        \\cp images/icons/icon_16.png zig-out/tmp.iconset/icon_16x16.png &&
        \\cp images/icons/icon_16@2x.png zig-out/tmp.iconset/icon_16x16@2x.png &&
        \\cp images/icons/icon_32.png zig-out/tmp.iconset/icon_32x32.png &&
        \\cp images/icons/icon_32@2x.png zig-out/tmp.iconset/icon_32x32@2x.png &&
        \\cp images/icons/icon_128.png zig-out/tmp.iconset/icon_128x128.png &&
        \\cp images/icons/icon_128@2x.png zig-out/tmp.iconset/icon_128x128@2x.png &&
        \\cp images/icons/icon_256.png zig-out/tmp.iconset/icon_256x256.png &&
        \\cp images/icons/icon_256@2x.png zig-out/tmp.iconset/icon_256x256@2x.png &&
        \\cp images/icons/icon_512.png zig-out/tmp.iconset/icon_512x512.png &&
        \\cp images/icons/icon_512@2x.png zig-out/tmp.iconset/icon_512x512@2x.png &&
        \\mkdir -p zig-out/RestYourEyes.app/Contents/Resources &&
        \\iconutil -c icns zig-out/tmp.iconset -o zig-out/RestYourEyes.app/Contents/Resources/AppIcon.icns &&
        \\rm -rf zig-out/tmp.iconset
    ;

    const icon_step = b.addSystemCommand(&.{ "sh", "-c", icon_cmd_str });

    // Make sure basic install steps happen before we try to put the icon in
    // Actually iconutil writes directly to the path, so we just need the dir to exist.
    // The mkdir in the script handles it, but let's depend on install_exe just in case.
    icon_step.step.dependOn(&install_exe.step);

    // Main install step depends on everything
    b.getInstallStep().dependOn(&install_exe.step);
    b.getInstallStep().dependOn(&install_plist.step);
    b.getInstallStep().dependOn(&install_status_icon.step);
    b.getInstallStep().dependOn(&icon_step.step);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
