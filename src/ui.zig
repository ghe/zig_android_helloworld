const std = @import("std");
const jni = @import("jni.zig");
const log = @import("log.zig");
const build_info = @import("build_info.zig");
const c = @cImport({
    @cInclude("jni.h");
});

pub const Layout = struct {
    text: []const u8,
};

pub fn loadLayout(xml_path: []const u8) Layout {
    _ = xml_path;
    // Create text with build info
    const build_text = std.fmt.allocPrint(std.heap.c_allocator,
        "Hello from Zig UI!\n\n{f}", .{build_info.current_build}
    ) catch "Hello from Zig UI!\nBuild info unavailable";

    return Layout{ .text = build_text };
}

var android_methods: ?jni.AndroidMethods = null;
var logger: ?log.AndroidLogger = null;

pub fn setContentView(env: *c.JNIEnv, activity: c.jobject, layout: Layout) !void {
    // Initialize logger on first use
    if (logger == null) {
        logger = log.AndroidLogger.init("ZigHelloWorld");
    }
    const l = &logger.?;

    l.info("Creating TextView with JNI...");

    const jniWrapper = jni.JNI.init(env);

    // Initialize methods cache on first use
    if (android_methods == null) {
        android_methods = jni.AndroidMethods.init(&jniWrapper, activity) catch |err| {
            l.err("Failed to initialize Android methods");
            return err;
        };
    }

    const methods = &android_methods.?;

    // Create TextView using object-oriented interface
    const textView = try jniWrapper.createTextView(methods, activity);

    try textView.setText(layout.text);
    textView.setTextSize(24.0);
    textView.setGravity(17); // Center the text
    textView.setTextColor(-16777216); // Black text for API 35 compatibility

    // Set content view
    const activityWrapper = jniWrapper.createActivity(methods, activity);
    activityWrapper.setContentView(&textView);

    l.info("TextView created and set!");
}

