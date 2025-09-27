const std = @import("std");
const c = @cImport({
    @cInclude("jni.h");
    @cInclude("android/log.h");
});

pub const Layout = struct {
    text: []const u8,
};

pub fn loadLayout(xml_path: []const u8) Layout {
    _ = xml_path;
    // In future, this would parse the XML file and extract layout info
    return Layout{ .text = "Hello from Zig UI!" };
}

pub fn setContentView(env: *c.JNIEnv, activity: c.jobject, layout: Layout) void {
    _ = c.__android_log_print(c.ANDROID_LOG_INFO, "ZigHelloWorld", "Creating TextView with JNI...");
    
    // Create TextView via JNI
    const textView = createTextView(env, activity, layout.text);
    
    // Set it as the content view
    callSetContentView(env, activity, textView);
    
    _ = c.__android_log_print(c.ANDROID_LOG_INFO, "ZigHelloWorld", "TextView created and set!");
}

fn createTextView(env: *c.JNIEnv, context: c.jobject, text: []const u8) c.jobject {
    // Find TextView class
    const textViewClass = env.*.*.FindClass.?(env, "android/widget/TextView");
    if (textViewClass == null) {
        _ = c.__android_log_print(c.ANDROID_LOG_ERROR, "ZigHelloWorld", "Failed to find TextView class");
        return null;
    }
    
    // Get constructor method ID
    const constructor = env.*.*.GetMethodID.?(env, textViewClass, "<init>", "(Landroid/content/Context;)V");
    if (constructor == null) {
        _ = c.__android_log_print(c.ANDROID_LOG_ERROR, "ZigHelloWorld", "Failed to get TextView constructor");
        return null;
    }
    
    // Create new TextView instance
    const textView = env.*.*.NewObject.?(env, textViewClass, constructor, context);
    if (textView == null) {
        _ = c.__android_log_print(c.ANDROID_LOG_ERROR, "ZigHelloWorld", "Failed to create TextView instance");
        return null;
    }
    
    // Set text
    const setText = env.*.*.GetMethodID.?(env, textViewClass, "setText", "(Ljava/lang/CharSequence;)V");
    if (setText != null) {
        // Convert Zig string to Java string
        const javaText = env.*.*.NewStringUTF.?(env, text.ptr);
        env.*.*.CallVoidMethod.?(env, textView, setText, javaText);
        
        // Set text size
        const setTextSize = env.*.*.GetMethodID.?(env, textViewClass, "setTextSize", "(F)V");
        if (setTextSize != null) {
            env.*.*.CallVoidMethod.?(env, textView, setTextSize, @as(f32, 24.0));
        }
    }
    
    return textView;
}

fn callSetContentView(env: *c.JNIEnv, activity: c.jobject, view: c.jobject) void {
    const activityClass = env.*.*.GetObjectClass.?(env, activity);
    const setContentViewMethod = env.*.*.GetMethodID.?(env, activityClass, "setContentView", "(Landroid/view/View;)V");
    
    if (setContentViewMethod != null) {
        env.*.*.CallVoidMethod.?(env, activity, setContentViewMethod, view);
        _ = c.__android_log_print(c.ANDROID_LOG_INFO, "ZigHelloWorld", "setContentView called successfully");
    } else {
        _ = c.__android_log_print(c.ANDROID_LOG_ERROR, "ZigHelloWorld", "Failed to find setContentView method");
    }
}