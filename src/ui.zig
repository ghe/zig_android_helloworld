const std = @import("std");
const jni = @import("jni.zig");
const log = @import("log.zig");
const c = @cImport({
    @cInclude("jni.h");
});

pub const Layout = struct {
    text: []const u8,
};

pub fn loadLayout(xml_path: []const u8) Layout {
    _ = xml_path;
    // In future, this would parse the XML file and extract layout info
    return Layout{ .text = "Hello from Zig UI!" };
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

    // Set content view using object-oriented interface
    const activityWrapper = jniWrapper.createActivity(methods, activity);
    activityWrapper.setContentView(&textView);

    l.info("TextView created and set!");
}

