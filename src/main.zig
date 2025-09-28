const std = @import("std");
const c = @cImport({
    @cInclude("jni.h");
});

const app = @import("app.zig");
const ui = @import("ui.zig");
const log = @import("log.zig");

// Main entry point from Java
export fn Java_com_zig_helloworld_MainActivity_initializeFromNative(env: *c.JNIEnv, activity: c.jobject) void {
    // Initialize logger
    log.init("ZigHelloWorld");

    // Log that we're starting
    log.info("initializeFromNative called!");

    // Initialize our app
    app.init();

    // Load UI layout and create views
    const layout = ui.loadLayout("src/ui.xml");
    ui.setContentView(env, activity, layout) catch {
        log.err("Failed to set content view");
        return;
    };

    log.info("UI setup complete!");
}