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

    // Log the actual text being displayed
    l.info("Setting TextView text:");
    // Convert to null-terminated string for logging
    const null_term_text = std.heap.c_allocator.dupeZ(u8, layout.text) catch "Failed to allocate for logging";
    defer if (!std.mem.eql(u8, null_term_text, "Failed to allocate for logging")) std.heap.c_allocator.free(null_term_text);
    l.info(null_term_text);

    try textView.setText(layout.text);
    l.info("TextView text set successfully");

    textView.setTextSize(24.0);
    l.info("TextView text size set to 24.0");

    // Set layout parameters: MATCH_PARENT width, WRAP_CONTENT height
    try textView.setLayoutParams(-1, -2);
    l.info("TextView layout parameters set");

    // Center the text (Gravity.CENTER = 17)
    textView.setGravity(17);
    l.info("TextView gravity set to center");

    // Set explicit black text color (-16777216 is 0xFF000000 as signed i32)
    textView.setTextColor(-16777216);
    l.info("TextView text color set to black");

    // Set content view using object-oriented interface
    l.info("About to call setContentView");
    const activityWrapper = jniWrapper.createActivity(methods, activity);
    activityWrapper.setContentView(&textView);
    l.info("setContentView called successfully");

    l.info("TextView created and set!");
}

