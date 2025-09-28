const c = @cImport({
    @cInclude("android/log.h");
});

pub const AndroidLogger = struct {
    tag: [*:0]const u8,

    pub fn init(tag: [*:0]const u8) AndroidLogger {
        return AndroidLogger{ .tag = tag };
    }

    pub fn verbose(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_VERBOSE, self.tag, "%s", message);
    }

    pub fn debug(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_DEBUG, self.tag, "%s", message);
    }

    pub fn info(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_INFO, self.tag, "%s", message);
    }

    pub fn warn(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_WARN, self.tag, "%s", message);
    }

    pub fn err(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_ERROR, self.tag, "%s", message);
    }

    pub fn fatal(self: *const AndroidLogger, message: [*:0]const u8) void {
        _ = c.__android_log_print(c.ANDROID_LOG_FATAL, self.tag, "%s", message);
    }

    // Formatted logging functions
    pub fn infof(self: *const AndroidLogger, comptime format: [*:0]const u8, args: anytype) void {
        _ = @call(.auto, c.__android_log_print, .{c.ANDROID_LOG_INFO, self.tag, format} ++ args);
    }

    pub fn debugf(self: *const AndroidLogger, comptime format: [*:0]const u8, args: anytype) void {
        _ = @call(.auto, c.__android_log_print, .{c.ANDROID_LOG_DEBUG, self.tag, format} ++ args);
    }

    pub fn errf(self: *const AndroidLogger, comptime format: [*:0]const u8, args: anytype) void {
        _ = @call(.auto, c.__android_log_print, .{c.ANDROID_LOG_ERROR, self.tag, format} ++ args);
    }

    pub fn warnf(self: *const AndroidLogger, comptime format: [*:0]const u8, args: anytype) void {
        _ = @call(.auto, c.__android_log_print, .{c.ANDROID_LOG_WARN, self.tag, format} ++ args);
    }
};

// Global logger instance - can be initialized once and reused
var default_logger: ?AndroidLogger = null;

pub fn init(tag: [*:0]const u8) void {
    default_logger = AndroidLogger.init(tag);
}

// Convenience functions for global logger
pub fn verbose(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.verbose(message);
}

pub fn debug(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.debug(message);
}

pub fn info(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.info(message);
}

pub fn warn(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.warn(message);
}

pub fn err(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.err(message);
}

pub fn fatal(message: [*:0]const u8) void {
    if (default_logger) |logger| logger.fatal(message);
}

// Formatted logging for global logger
pub fn infof(comptime format: [*:0]const u8, args: anytype) void {
    if (default_logger) |logger| logger.infof(format, args);
}

pub fn debugf(comptime format: [*:0]const u8, args: anytype) void {
    if (default_logger) |logger| logger.debugf(format, args);
}

pub fn errf(comptime format: [*:0]const u8, args: anytype) void {
    if (default_logger) |logger| logger.errf(format, args);
}

pub fn warnf(comptime format: [*:0]const u8, args: anytype) void {
    if (default_logger) |logger| logger.warnf(format, args);
}