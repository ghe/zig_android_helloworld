const std = @import("std");
const c = @cImport({
    @cInclude("jni.h");
});

pub const JNIError = error{
    ClassNotFound,
    MethodNotFound,
    ObjectCreationFailed,
    StringCreationFailed,
    OutOfMemory,
};

pub const AndroidMethods = struct {
    textview_class: c.jclass,
    textview_init: c.jmethodID,
    textview_setText: c.jmethodID,
    textview_setTextSize: c.jmethodID,
    textview_setGravity: c.jmethodID,
    textview_setTextColor: c.jmethodID,
    activity_setContentView: c.jmethodID,

    pub fn init(jni: *const JNI, activity: c.jobject) JNIError!AndroidMethods {
        const textview_class = try jni.findClass("android/widget/TextView");

        return AndroidMethods{
            .textview_class = textview_class,
            .textview_init = try jni.getMethodID(textview_class, "<init>", "(Landroid/content/Context;)V"),
            .textview_setText = try jni.getMethodID(textview_class, "setText", "(Ljava/lang/CharSequence;)V"),
            .textview_setTextSize = try jni.getMethodID(textview_class, "setTextSize", "(F)V"),
            .textview_setGravity = try jni.getMethodID(textview_class, "setGravity", "(I)V"),
            .textview_setTextColor = try jni.getMethodID(textview_class, "setTextColor", "(I)V"),
            .activity_setContentView = try jni.getMethodIDForObject(activity, "setContentView", "(Landroid/view/View;)V"),
        };
    }
};

pub const JNI = struct {
    env: *c.JNIEnv,
    funcs: *const c.JNINativeInterface,

    pub fn init(env: *c.JNIEnv) JNI {
        return JNI{
            .env = env,
            .funcs = env.*,
        };
    }

    pub fn findClass(self: *const JNI, name: [*:0]const u8) JNIError!c.jclass {
        const func = self.funcs.FindClass orelse return JNIError.ClassNotFound;
        return func(self.env, name) orelse JNIError.ClassNotFound;
    }

    pub fn getMethodID(self: *const JNI, class: c.jclass, name: [*:0]const u8, sig: [*:0]const u8) JNIError!c.jmethodID {
        const func = self.funcs.GetMethodID orelse return JNIError.MethodNotFound;
        return func(self.env, class, name, sig) orelse JNIError.MethodNotFound;
    }

    pub fn getMethodIDForObject(self: *const JNI, obj: c.jobject, name: [*:0]const u8, sig: [*:0]const u8) JNIError!c.jmethodID {
        const class = try self.getObjectClass(obj);
        return self.getMethodID(class, name, sig);
    }

    pub fn getObjectClass(self: *const JNI, obj: c.jobject) JNIError!c.jclass {
        const func = self.funcs.GetObjectClass orelse return JNIError.ClassNotFound;
        return func(self.env, obj) orelse JNIError.ClassNotFound;
    }

    pub fn newObject(self: *const JNI, class: c.jclass, method: c.jmethodID, args: anytype) JNIError!c.jobject {
        const func = self.funcs.NewObject orelse return JNIError.ObjectCreationFailed;
        return @call(.auto, func, .{self.env, class, method} ++ args) orelse JNIError.ObjectCreationFailed;
    }

    pub fn callVoidMethod(self: *const JNI, obj: c.jobject, method: c.jmethodID, args: anytype) void {
        if (self.funcs.CallVoidMethod) |func| {
            @call(.auto, func, .{self.env, obj, method} ++ args);
        }
    }

    pub fn newStringUTF(self: *const JNI, str: [*:0]const u8) JNIError!c.jstring {
        const func = self.funcs.NewStringUTF orelse return JNIError.StringCreationFailed;
        return func(self.env, str) orelse JNIError.StringCreationFailed;
    }

    pub fn createTextView(self: *const JNI, methods: *const AndroidMethods, context: c.jobject) JNIError!TextView {
        const obj = try self.newObject(methods.textview_class, methods.textview_init, .{context});
        return TextView{
            .jni = self,
            .methods = methods,
            .obj = obj,
        };
    }

    pub fn createActivity(self: *const JNI, methods: *const AndroidMethods, obj: c.jobject) Activity {
        return Activity{
            .jni = self,
            .methods = methods,
            .obj = obj,
        };
    }
};

pub const TextView = struct {
    jni: *const JNI,
    methods: *const AndroidMethods,
    obj: c.jobject,

    pub fn setText(self: *const TextView, text: []const u8) JNIError!void {
        // Create null-terminated string using dupeZ
        const null_terminated = try std.heap.c_allocator.dupeZ(u8, text);
        defer std.heap.c_allocator.free(null_terminated);

        const javaText = try self.jni.newStringUTF(null_terminated.ptr);
        self.jni.callVoidMethod(self.obj, self.methods.textview_setText, .{javaText});
    }

    pub fn setTextSize(self: *const TextView, size: f32) void {
        self.jni.callVoidMethod(self.obj, self.methods.textview_setTextSize, .{size});
    }


    pub fn setGravity(self: *const TextView, gravity: i32) void {
        self.jni.callVoidMethod(self.obj, self.methods.textview_setGravity, .{gravity});
    }

    pub fn setTextColor(self: *const TextView, color: i32) void {
        self.jni.callVoidMethod(self.obj, self.methods.textview_setTextColor, .{color});
    }
};

pub const Activity = struct {
    jni: *const JNI,
    methods: *const AndroidMethods,
    obj: c.jobject,

    pub fn setContentView(self: *const Activity, view: *const TextView) void {
        self.jni.callVoidMethod(self.obj, self.methods.activity_setContentView, .{view.obj});
    }
};