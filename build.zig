const std = @import("std");

const AndroidConfig = struct {
    sdk_path: []const u8,
    ndk_path: []const u8,
    build_tools_version: []const u8,
    api_level: u8,
    min_sdk: u8,
    target_sdk: u8,
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Generate build number
    const build_number_step = generateBuildNumber(b);

    // Android configuration
    const android_config = AndroidConfig{
        .sdk_path = b.option([]const u8, "android-sdk", "Android SDK path") orelse getEnvOrDefault(b.allocator, "ANDROID_SDK_ROOT", "/opt/android-sdk"),
        .ndk_path = b.option([]const u8, "android-ndk", "Android NDK path") orelse getEnvOrDefault(b.allocator, "ANDROID_NDK_ROOT", "/opt/android-ndk"),
        .build_tools_version = b.option([]const u8, "build-tools", "Build tools version") orelse "35.0.0",
        .api_level = b.option(u8, "api-level", "API level") orelse 35,
        .min_sdk = b.option(u8, "min-sdk", "Minimum SDK") orelse 26,
        .target_sdk = b.option(u8, "target-sdk", "Target SDK") orelse 35,
    };

    // Prerequisite checks
    const check_step = b.step("check", "Check prerequisites");
    const check_cmd = b.addSystemCommand(&.{"echo", "Checking prerequisites..."});
    check_step.dependOn(&check_cmd.step);
    
    addPrerequisiteChecks(b, check_step, android_config);

    // Native library
    const target_query = std.Target.Query{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
        .abi = .android,
        .cpu_features_add = std.Target.aarch64.featureSet(&.{.v8a}),
    };
    const resolved_target = b.resolveTargetQuery(target_query);

    const lib = b.addLibrary(.{
        .name = "helloworld",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = resolved_target,
            .optimize = optimize,
        }),
    });

    // Make sure build number is generated before library compilation
    lib.step.dependOn(&build_number_step.step);

    // Use custom Android libc configuration
    lib.setLibCFile(.{ .cwd_relative = "android-libc.conf" });
    
    // Add Android NDK include directories for JNI headers
    const ndk_include = b.fmt("{s}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include", .{android_config.ndk_path});
    lib.addIncludePath(.{ .cwd_relative = ndk_include });
    
    // Add library search paths for Android libraries
    const ndk_lib_path = b.fmt("{s}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/21", .{android_config.ndk_path});
    lib.addLibraryPath(.{ .cwd_relative = ndk_lib_path });
    
    // Link against Android system libraries using proper API level
    // Update to API 35 to match the device for better compatibility
    const api_35_lib_path = b.fmt("{s}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/35", .{android_config.ndk_path});
    lib.addLibraryPath(.{ .cwd_relative = api_35_lib_path });
    
    // Link system libraries - libc should provide getauxval
    lib.linkSystemLibrary("c");
    lib.linkSystemLibrary("android");
    lib.linkSystemLibrary("log");

    // Java compilation
    const java_step = b.step("java", "Compile Java sources");
    const java_compile = addJavaCompilation(b, android_config);
    java_step.dependOn(&java_compile.step);

    // Resources
    const res_step = b.step("resources", "Compile resources");
    const res_compile = addResourceCompilation(b, android_config);
    res_step.dependOn(&res_compile.step);

    // DEX compilation
    const dex_step = b.step("dex", "Compile to DEX");
    const dex_compile = addDexCompilation(b, android_config);
    dex_compile.step.dependOn(java_step);
    dex_step.dependOn(&dex_compile.step);

    // APK packaging
    const apk_step = b.step("apk", "Build APK");
    const apk_build = addApkPackaging(b, android_config, res_compile, dex_compile);
    apk_build.step.dependOn(&lib.step);
    apk_build.step.dependOn(&res_compile.step);
    apk_build.step.dependOn(&dex_compile.step);
    apk_step.dependOn(&apk_build.step);

    // APK signing
    const sign_step = b.step("sign", "Sign APK");
    const sign_apk = addApkSigning(b, android_config, apk_build);
    sign_step.dependOn(&sign_apk.step);

    // Health checks
    const test_step = b.step("test", "Run health checks");
    const health_checks = addHealthChecks(b, android_config);
    health_checks.step.dependOn(sign_step);
    test_step.dependOn(&health_checks.step);

    // Deploy
    const deploy_step = b.step("deploy", "Install APK to device");
    const install_apk = addApkInstall(b, android_config);
    install_apk.step.dependOn(sign_step);
    deploy_step.dependOn(&install_apk.step);

    // Library-only step for testing
    const lib_step = b.step("lib", "Build native library only");
    lib_step.dependOn(&lib.step);
    
    // Note: Test can be run manually with `zig test src/build_info.zig`

    // Default build target
    b.default_step.dependOn(sign_step);
    
    // Install the library for APK packaging
    b.installArtifact(lib);
}

fn getEnvOrDefault(allocator: std.mem.Allocator, env_var: []const u8, default: []const u8) []const u8 {
    return std.process.getEnvVarOwned(allocator, env_var) catch default;
}

fn addPrerequisiteChecks(b: *std.Build, step: *std.Build.Step, config: AndroidConfig) void {
    // Check Android SDK
    const check_sdk = b.addSystemCommand(&.{"sh", "-c"});
    check_sdk.addArg(b.fmt("test -d '{s}' || (echo 'Error: Android SDK not found at {s}' >&2 && exit 1)", .{ config.sdk_path, config.sdk_path }));
    step.dependOn(&check_sdk.step);

    // Check Android NDK
    const check_ndk = b.addSystemCommand(&.{"sh", "-c"});
    check_ndk.addArg(b.fmt("test -d '{s}' || (echo 'Error: Android NDK not found at {s}' >&2 && exit 1)", .{ config.ndk_path, config.ndk_path }));
    step.dependOn(&check_ndk.step);

    // Check build tools
    const build_tools_path = b.fmt("{s}/build-tools/{s}", .{ config.sdk_path, config.build_tools_version });
    const check_build_tools = b.addSystemCommand(&.{"sh", "-c"});
    check_build_tools.addArg(b.fmt("test -d '{s}' || (echo 'Error: Android build tools {s} not found at {s}' >&2 && exit 1)", .{ build_tools_path, config.build_tools_version, build_tools_path }));
    step.dependOn(&check_build_tools.step);

    // Check android.jar
    const android_jar = b.fmt("{s}/platforms/android-{d}/android.jar", .{ config.sdk_path, config.api_level });
    const check_android_jar = b.addSystemCommand(&.{"sh", "-c"});
    check_android_jar.addArg(b.fmt("test -f '{s}' || (echo 'Error: android.jar not found for API level {d} at {s}' >&2 && exit 1)", .{ android_jar, config.api_level, android_jar }));
    step.dependOn(&check_android_jar.step);

    // Check debug keystore exists or can be created
    const check_keystore = b.addSystemCommand(&.{"sh", "-c"});
    check_keystore.addArg(b.fmt("test -f '{s}/.android/debug.keystore' || (echo 'Info: Debug keystore will be created automatically' && mkdir -p '{s}/.android')", .{ getHomeDir(b.allocator), getHomeDir(b.allocator) }));
    step.dependOn(&check_keystore.step);
}

fn addJavaCompilation(b: *std.Build, config: AndroidConfig) *std.Build.Step.Run {
    const android_jar = b.fmt("{s}/platforms/android-{d}/android.jar", .{ config.sdk_path, config.api_level });
    
    const javac = b.addSystemCommand(&.{
        "javac",
        "-d", "build/classes",
        "-cp", android_jar,
        "-sourcepath", "android",
        "-Xlint:-options",
        "-source", "11",
        "-target", "11",
        "android/MainActivity.java"
    });
    
    const mkdir = b.addSystemCommand(&.{"mkdir", "-p", "build/classes"});
    javac.step.dependOn(&mkdir.step);
    
    return javac;
}

fn addResourceCompilation(b: *std.Build, config: AndroidConfig) *std.Build.Step.Run {
    const aapt2 = b.fmt("{s}/build-tools/{s}/aapt2", .{ config.sdk_path, config.build_tools_version });
    
    // Create resources directory structure
    const mkdir_res = b.addSystemCommand(&.{"mkdir", "-p", "build/res/layout", "build/res/values"});
    
    // Copy layout file
    const copy_layout = b.addSystemCommand(&.{"cp", "src/ui.xml", "build/res/layout/activity_main.xml"});
    copy_layout.step.dependOn(&mkdir_res.step);
    
    // Create strings.xml
    const strings_xml = b.addSystemCommand(&.{"sh", "-c", 
        \\echo '<?xml version="1.0" encoding="utf-8"?><resources><string name="app_name">Zig Hello World</string></resources>' > build/res/values/strings.xml
    });
    strings_xml.step.dependOn(&mkdir_res.step);
    
    // Compile resources
    const aapt_compile = b.addSystemCommand(&.{
        aapt2, "compile",
        "--dir", "build/res",
        "-o", "build/compiled_res.zip"
    });
    aapt_compile.step.dependOn(&copy_layout.step);
    aapt_compile.step.dependOn(&strings_xml.step);
    
    // Link resources
    const android_jar = b.fmt("{s}/platforms/android-{d}/android.jar", .{ config.sdk_path, config.api_level });
    const aapt_link = b.addSystemCommand(&.{
        aapt2, "link",
        "-I", android_jar,
        "-o", "build/resources.apk",
        "--manifest", "android/Manifest.xml",
        "--min-sdk-version", b.fmt("{d}", .{config.min_sdk}),
        "--target-sdk-version", b.fmt("{d}", .{config.target_sdk}),
        "build/compiled_res.zip"
    });
    aapt_link.step.dependOn(&aapt_compile.step);
    
    return aapt_link;
}

fn addDexCompilation(b: *std.Build, config: AndroidConfig) *std.Build.Step.Run {
    const d8 = b.fmt("{s}/build-tools/{s}/d8", .{ config.sdk_path, config.build_tools_version });
    
    const dex_cmd = b.addSystemCommand(&.{
        d8,
        "--output", "build/",
        "build/classes/com/zig/helloworld/MainActivity.class"
    });
    
    return dex_cmd;
}

fn addApkPackaging(b: *std.Build, config: AndroidConfig, res_step: *std.Build.Step.Run, dex_step: *std.Build.Step.Run) *std.Build.Step.Run {
    _ = config;
    
    // Create APK directory structure
    const mkdir = b.addSystemCommand(&.{"mkdir", "-p", "build/apk/lib/arm64-v8a"});
    
    // Copy native library
    const copy_lib = b.addSystemCommand(&.{"cp", "zig-out/lib/libhelloworld.so", "build/apk/lib/arm64-v8a/"});
    copy_lib.step.dependOn(&mkdir.step);
    
    // Extract resources (depends on resources step)
    const extract_res = b.addSystemCommand(&.{"unzip", "-o", "build/resources.apk", "-d", "build/apk/"});
    extract_res.step.dependOn(&mkdir.step);
    extract_res.step.dependOn(&res_step.step);
    
    // Copy DEX (depends on dex step)
    const copy_dex = b.addSystemCommand(&.{"cp", "build/classes.dex", "build/apk/"});
    copy_dex.step.dependOn(&extract_res.step);
    copy_dex.step.dependOn(&dex_step.step);
    
    // Package APK with uncompressed resources.arsc for Android R+ compatibility
    const zip_apk = b.addSystemCommand(&.{"sh", "-c", "cd build/apk && zip -r ../helloworld-unsigned.apk . -0 resources.arsc"});
    zip_apk.step.dependOn(&copy_lib.step);
    zip_apk.step.dependOn(&copy_dex.step);
    
    return zip_apk;
}

fn addApkSigning(b: *std.Build, config: AndroidConfig, apk_step: *std.Build.Step.Run) *std.Build.Step.Run {
    const zipalign = b.fmt("{s}/build-tools/{s}/zipalign", .{ config.sdk_path, config.build_tools_version });
    const apksigner = b.fmt("{s}/build-tools/{s}/apksigner", .{ config.sdk_path, config.build_tools_version });
    const home_dir = getHomeDir(b.allocator);
    const keystore_path = b.fmt("{s}/.android/debug.keystore", .{home_dir});
    
    // Align APK (depends on APK packaging completing)
    const align_cmd = b.addSystemCommand(&.{
        zipalign, "-f", "4",
        "build/helloworld-unsigned.apk",
        "build/helloworld-aligned.apk"
    });
    align_cmd.step.dependOn(&apk_step.step);
    
    // Create keystore if it doesn't exist
    const create_keystore = b.addSystemCommand(&.{"sh", "-c"});
    create_keystore.addArg(b.fmt(
        \\test -f '{s}' || keytool -genkey -v -keystore '{s}' -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
    , .{ keystore_path, keystore_path }));
    
    // Sign APK (debug key)
    const sign_cmd = b.addSystemCommand(&.{
        apksigner, "sign",
        "--ks-type", "jks",
        "--ks", keystore_path,
        "--ks-pass", "pass:android",
        "--key-pass", "pass:android",
        "--out", "build/helloworld.apk",
        "build/helloworld-aligned.apk"
    });
    sign_cmd.step.dependOn(&align_cmd.step);
    sign_cmd.step.dependOn(&create_keystore.step);
    
    return sign_cmd;
}

fn addHealthChecks(b: *std.Build, config: AndroidConfig) *std.Build.Step.Run {
    const aapt = b.fmt("{s}/build-tools/{s}/aapt", .{ config.sdk_path, config.build_tools_version });
    
    // Check APK exists
    const check_apk = b.addSystemCommand(&.{"sh", "-c"});
    check_apk.addArg("test -f build/helloworld.apk || (echo 'Error: Signed APK not found' >&2 && exit 1)");
    
    // Verify APK structure
    const verify_cmd = b.addSystemCommand(&.{
        aapt, "dump", "badging", "build/helloworld.apk"
    });
    verify_cmd.step.dependOn(&check_apk.step);
    
    // Check APK signature
    const verify_sig = b.addSystemCommand(&.{
        b.fmt("{s}/build-tools/{s}/apksigner", .{ config.sdk_path, config.build_tools_version }),
        "verify", "build/helloworld.apk"
    });
    verify_sig.step.dependOn(&verify_cmd.step);
    
    // Check APK contents
    const check_contents = b.addSystemCommand(&.{"sh", "-c"});
    check_contents.addArg("unzip -l build/helloworld.apk | grep -E '(classes.dex|libhelloworld.so|AndroidManifest.xml)' | wc -l | grep -q '^3$' || (echo 'Error: APK missing required components' >&2 && exit 1)");
    check_contents.step.dependOn(&verify_sig.step);
    
    return check_contents;
}

fn addApkInstall(b: *std.Build, config: AndroidConfig) *std.Build.Step.Run {
    const adb = b.fmt("{s}/platform-tools/adb", .{config.sdk_path});
    
    const install_cmd = b.addSystemCommand(&.{
        adb, "install", "-r", "build/helloworld.apk"
    });
    
    return install_cmd;
}

fn getHomeDir(allocator: std.mem.Allocator) []const u8 {
    return std.process.getEnvVarOwned(allocator, "HOME") catch "/home/user";
}

fn generateBuildNumber(b: *std.Build) *std.Build.Step.Run {
    // Import build_info functions
    const build_info = @import("src/build_info.zig");

    const build_number = build_info.readBuildNumber(b.allocator) catch 1;
    const new_build_number = build_number + 1;

    // Write the new build number back to file
    build_info.writeBuildNumber(b.allocator, new_build_number) catch {};

    // Get current timestamp and format it
    const timestamp = std.time.timestamp();
    const formatted_date = build_info.formatTimestamp(b.allocator, timestamp);

    // Create the build_number.zig file content directly in source directory
    const build_content = b.fmt(
        \\pub const build_number: u32 = {d};
        \\pub const build_date: []const u8 = "{s}";
        \\pub const build_timestamp: i64 = {d};
        \\
    , .{ new_build_number, formatted_date, timestamp });

    // Write directly to src/build_number.zig using Zig's file system
    const cwd = std.fs.cwd();
    const file = cwd.createFile("src/build_number.zig", .{}) catch |err| {
        std.debug.print("Failed to create build_number.zig: {}\n", .{err});
        return b.addSystemCommand(&.{"echo", "Build number generation failed"});
    };
    defer file.close();

    file.writeAll(build_content) catch |err| {
        std.debug.print("Failed to write to build_number.zig: {}\n", .{err});
    };

    // Return a no-op command since we've already written the file
    return b.addSystemCommand(&.{"echo", "Build number generated"});
}