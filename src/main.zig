const std = @import("std");
const c = @cImport({
    @cInclude("jni.h");
    @cInclude("android/log.h");
});

const app = @import("app.zig");
const ui = @import("ui.zig");

// Main entry point from Java
export fn Java_com_zig_helloworld_MainActivity_initializeFromNative(env: *c.JNIEnv, activity: c.jobject) void {
    // Log that we're starting
    _ = c.__android_log_print(c.ANDROID_LOG_INFO, "ZigHelloWorld", "initializeFromNative called!");
    
    // Initialize our app
    app.init();
    
    // Load UI layout and create views
    const layout = ui.loadLayout("src/ui.xml");
    ui.setContentView(env, activity, layout);
    
    _ = c.__android_log_print(c.ANDROID_LOG_INFO, "ZigHelloWorld", "UI setup complete!");
}