const std = @import("std");

pub fn init() void {
    std.log.info("Hello World app initialized", .{});
}

pub fn getMessage() []const u8 {
    return "Hello from Zig Android App!";
}