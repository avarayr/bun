//! Unified module for controlling and managing environment variables in Bun.

// Keep this list alphabetically sorted.
pub const bun_install = new("bun_install", "BUN_INSTALL", "BUN_INSTALL", .{});
pub const home = new("home", "HOME", "USERPROFILE", .{});
pub const path = new("path", "PATH", "PATH", .{});
pub const xdg_cache_home = new("xdg_cache_home", "XDG_CACHE_HOME", null, .{});
pub const xdg_config_home = new("xdg_config_home", "XDG_CONFIG_HOME", null, .{});

/// Create a new envionment variable definition.
///
/// The resulting type has methods for interacting with the environment variable.
///
/// Technically, none of the operations here are thread-safe, so writing to environment variables
/// does not guarantee that other threads will see the changes. You should avoid writing to
/// environment variables.
fn new(
    comptime name: []const u8,
    comptime posix_key: ?[:0]const u8,
    comptime windows_key: ?[:0]const u8,
    comptime opts: EnvVarOpts,
) type {
    if (posix_key == null and windows_key == null) {
        @compileError("Environment variable " ++ name ++ " has no keys for POSIX nor Windows " ++
            "specified. Provide a key for either POSIX or Windows.");
    }

    return struct {
        const PtrType = ?[*]const u8;
        const LengthType = u64;

        /// Indicates an environment variable hasn't been loaded yet.
        const undefined_sentinel: LengthType = std.math.maxInt(LengthType);

        /// Indicates an environment variable isn't set from the outside.
        var value: std.atomic.Value(PtrType) = std.atomic.Value(PtrType).init(null);
        var value_len: std.atomic.Value(u64) = .init(std.math.maxInt(LengthType));

        /// Attempt to retrieve the value of the environment variable for the current platform, if
        /// the current platform has a supported definition. Returns null otherwise, unlike the
        /// other methods which will fail at compile time if the platform is unsupported.
        pub fn platformGet() ?[]const u8 {
            if (bun.Environment.isPosix) {
                if (posix_key == null) return null;
            }

            if (bun.Environment.isWindows) {
                if (windows_key == null) return null;
            }

            return get();
        }

        /// Retrieve the key of the environment variable for the current platform.
        pub fn key() [:0]const u8 {
            assertPlatformSupported();

            return platformKey().?;
        }

        /// Retrieve the key of the environment variable for the current platform, if any.
        pub fn platformKey() ?[:0]const u8 {
            if (bun.Environment.isPosix) {
                return posix_key;
            }

            if (bun.Environment.isWindows) {
                return windows_key;
            }

            return null;
        }

        /// Retrieve the value of the environment variable, loading it if necessary.
        /// Fails if the current platform is unsupported.
        pub fn get() ?[]const u8 {
            assertPlatformSupported();

            const len = value_len.load(.monotonic);
            if (len == undefined_sentinel) {
                return getForceReload();
            }

            const v: PtrType = value.load(.monotonic);

            return (v orelse return null)[0..len];
        }

        /// Retrieve the value of the environment variable, reloading it from the environment.
        /// Fails if the current platform is unsupported.
        pub fn getForceReload() ?[]const u8 {
            assertPlatformSupported();

            const env_var = bun.getenvZ(key());

            if (env_var) |ev| {
                value.store(ev.ptr, .monotonic);
                value_len.store(ev.len, .monotonic);
            } else {
                value.store(null, .monotonic);
                value_len.store(0, .monotonic);
            }

            return env_var;
        }

        /// Fetch the default value of this environment variable, if any.
        ///
        /// It is safe to compare the result of .get() to the result of .default() to determine if
        /// the variable is set to its default value, if .default() does not return null.
        pub fn default() ?[]const u8 {
            return opts.default;
        }

        fn assertPlatformSupported() void {
            const missing_key_fmt = "Cannot retrieve the value of " ++ name ++ " for {s} " ++
                "since no {s} key is associated with it.";
            if (comptime bun.Environment.isWindows and windows_key == null) {
                @compileError(std.fmt.comptimePrint(missing_key_fmt, .{ "Windows", "Windows" }));
            } else if (posix_key == null) {
                @compileError(std.fmt.comptimePrint(missing_key_fmt, .{ "POSIX", "POSIX" }));
            }
        }
    };
}

const EnvVarOpts = struct {};

const bun = @import("bun");
const std = @import("std");
