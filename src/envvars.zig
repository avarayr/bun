//! Unified module for controlling and managing environment variables in Bun.

// Keep this list alphabetically sorted.
pub const bun_debug = new(.string, "BUN_DEBUG", .{});
pub const bun_inspect = new(.string, "BUN_INSPECT", .{});
pub const bun_install = new(.string, "BUN_INSTALL", .{});
pub const bun_install_bin = new(.string, "BUN_INSTALL_BIN", .{});
pub const bun_install_global_dir = new(.string, "BUN_INSTALL_GLOBAL_DIR", .{});
pub const bun_tmpdir = new(.string, "BUN_TMPDIR", .{});
pub const ci = new(.boolean, "CI", .{ .default = false });
pub const colorterm = new(.string, "COLORTERM", .{});
pub const force_color = new(.string, "FORCE_COLOR", .{});
pub const github_actions = new(.boolean, "GITHUB_ACTIONS", .{ .default = false });
pub const home = platformSpecificNew(.string, "HOME", "USERPROFILE", .{});
pub const no_color = new(.boolean, "NO_COLOR", .{ .default = false });
pub const path = new(.string, "PATH", .{});
pub const shell = platformSpecificNew(.string, "SHELL", null, .{});
pub const system_root = platformSpecificNew(.string, null, "SystemRoot", .{ .default = "C:\\Windows" });
pub const temp = platformSpecificNew(.string, null, "TEMP", .{});
pub const term = new(.string, "TERM", .{});
pub const term_program = new(.string, "TERM_PROGRAM", .{});
pub const tmp = platformSpecificNew(.string, null, "TMP", .{});
pub const tmpdir = platformSpecificNew(.string, "TMPDIR", null, .{});
pub const user = platformSpecificNew(.string, "USER", "USERNAME", .{});
pub const windir = platformSpecificNew(.string, null, "windir", .{});
pub const xdg_cache_home = platformSpecificNew(.string, "XDG_CACHE_HOME", null, .{});
pub const xdg_config_home = platformSpecificNew(.string, "XDG_CONFIG_HOME", null, .{});

// Feature flags, keep sorted alphabetically.
pub const FeatureFlag = struct {
    pub const assume_perfect_incremental = newFeatureFlag("BUN_ASSUME_PERFECT_INCREMENTAL");
    pub const be_bun = newFeatureFlag("BUN_BE_BUN");
    pub const debug_no_dump = newFeatureFlag("BUN_DEBUG_NO_DUMP");
    pub const destruct_vm_on_exit = newFeatureFlag("BUN_DESTRUCT_VM_ON_EXIT");
    pub const disable_addrconfig = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_ADDRCONFIG");
    pub const disable_async_transpiler = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_ASYNC_TRANSPILER");
    pub const disable_dns_cache = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_DNS_CACHE");
    pub const disable_dns_cache_libinfo = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_DNS_CACHE_LIBINFO");
    pub const disable_install_index = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_INSTALL_INDEX");
    pub const disable_io_pool = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_IO_POOL");
    pub const disable_ipv4 = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_IPV4");
    pub const disable_ipv6 = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_IPV6");
    pub const disable_redis_auto_pipelining = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_REDIS_AUTO_PIPELINING");
    pub const disable_rwf_nonblock = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_RWF_NONBLOCK");
    pub const disable_slow_lifecycle_script_logging = newFeatureFlag("BUN_DISABLE_SLOW_LIFECYCLE_SCRIPT_LOGGING");
    pub const disable_source_code_preview = newFeatureFlag("BUN_DISABLE_SOURCE_CODE_PREVIEW");
    pub const disable_source_maps = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_SOURCE_MAPS");
    pub const disable_spawnsync_fast_path = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_SPAWNSYNC_FAST_PATH");
    pub const disable_sql_auto_pipelining = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_SQL_AUTO_PIPELINING");
    pub const disable_transpiled_source_code_preview = newFeatureFlag("BUN_DISABLE_TRANSPILED_SOURCE_CODE_PREVIEW");
    pub const disable_uv_fs_copyfile = newFeatureFlag("BUN_FEATURE_FLAG_DISABLE_UV_FS_COPYFILE");
    pub const dump_state_on_crash = newFeatureFlag("BUN_DUMP_STATE_ON_CRASH");
    pub const enable_experimental_shell_builtins = newFeatureFlag("BUN_ENABLE_EXPERIMENTAL_SHELL_BUILTINS");
    pub const experimental_bake = newFeatureFlag("BUN_FEATURE_FLAG_EXPERIMENTAL_BAKE");
    pub const force_io_pool = newFeatureFlag("BUN_FEATURE_FLAG_FORCE_IO_POOL");
    pub const force_windows_junctions = newFeatureFlag("BUN_FEATURE_FLAG_FORCE_WINDOWS_JUNCTIONS");
    pub const instruments = newFeatureFlag("BUN_INSTRUMENTS");
    pub const internal_bunx_install = newFeatureFlag("BUN_INTERNAL_BUNX_INSTALL");
    pub const internal_suppress_crash_in_bun_run = newFeatureFlag("BUN_INTERNAL_SUPPRESS_CRASH_IN_BUN_RUN");
    pub const internal_suppress_crash_on_napi_abort = newFeatureFlag("BUN_INTERNAL_SUPPRESS_CRASH_ON_NAPI_ABORT");
    pub const internal_suppress_crash_on_process_kill_self = newFeatureFlag("BUN_INTERNAL_SUPPRESS_CRASH_ON_PROCESS_KILL_SELF");
    pub const internal_suppress_crash_on_uv_stub = newFeatureFlag("BUN_INTERNAL_SUPPRESS_CRASH_ON_UV_STUB");
    pub const last_modified_pretend_304 = newFeatureFlag("BUN_FEATURE_FLAG_LAST_MODIFIED_PRETEND_304");
    pub const no_codesign_macho_binary = newFeatureFlag("BUN_NO_CODESIGN_MACHO_BINARY");
    pub const no_libdeflate = newFeatureFlag("BUN_FEATURE_FLAG_NO_LIBDEFLATE");
    pub const node_no_warnings = newFeatureFlag("NODE_NO_WARNINGS");
    pub const trace = newFeatureFlag("BUN_TRACE");
};

const EnvVarType = enum { string, boolean };

/// Create a new envionment variable definition.
///
/// The resulting type has methods for interacting with the environment variable.
///
/// Technically, none of the operations here are thread-safe, so writing to environment variables
/// does not guarantee that other threads will see the changes. You should avoid writing to
/// environment variables.
fn new(comptime T: EnvVarType, comptime key: [:0]const u8, comptime opts: EnvVarOpts(T)) type {
    return platformSpecificNew(T, key, key, opts);
}

/// Identical to new, except it allows you to specify different keys for POSIX and Windows.
///
/// If the current platform does not have a key specified, all methods that attempt to read the
/// environment variable will fail at compile time, except for `platformGet` and `platformKey`,
/// which will return null instead.
fn platformSpecificNew(
    comptime T: EnvVarType,
    comptime posix_key: ?[:0]const u8,
    comptime windows_key: ?[:0]const u8,
    comptime opts: EnvVarOpts(T),
) type {
    const comptime_key: []const u8 =
        if (posix_key) |pk| pk else if (windows_key) |wk| wk else "<undefined>";

    if (posix_key == null and windows_key == null) {
        @compileError("Environment variable " ++ comptime_key ++ " has no keys for POSIX " ++
            "nor Windows specified. Provide a key for either POSIX or Windows.");
    }

    const KeyType = [:0]const u8;
    // Represents the return type of public methods, ignoring the optionality.
    const NonOptionalReturnType = comptime switch (T) {
        .string => []const u8,
        .boolean => bool,
    };

    // The actual return type of public methods.
    const ReturnType = if (opts.default != null) NonOptionalReturnType else ?NonOptionalReturnType;

    // Type used to communicate between the Cache and the public interface of this env var.
    const CachedInterface = union(enum) {
        /// The environment variable hasn't been loaded yet.
        undefined: void,
        /// The environment variable has been loaded but its not set.
        not_set: void,
        /// The environment variable is set to a value.
        value: NonOptionalReturnType,
    };

    const Cache = switch (T) {
        .string => struct {
            const PtrType = ?[*]const u8;
            const LengthType = u64;

            /// Indicates an environment variable hasn't been loaded yet.
            const undefined_sentinel: LengthType = std.math.maxInt(LengthType);

            /// Indicates an environment variable isn't set from the outside.
            var value: std.atomic.Value(PtrType) = std.atomic.Value(PtrType).init(null);
            var value_len: std.atomic.Value(u64) = .init(std.math.maxInt(LengthType));

            /// Get the cached value.
            pub inline fn getCached() CachedInterface {
                const len = value_len.load(.monotonic);
                if (len == undefined_sentinel) {
                    return .{ .undefined = {} };
                }

                const v: PtrType = value.load(.monotonic);

                return if (v) |ptr| .{ .value = ptr[0..len] } else .{ .not_set = {} };
            }

            pub inline fn reload(raw_env: ?[]const u8) ?NonOptionalReturnType {
                if (raw_env) |ev| {
                    value.store(ev.ptr, .monotonic);
                    value_len.store(ev.len, .monotonic);
                } else {
                    value.store(null, .monotonic);
                    value_len.store(0, .monotonic);
                }

                return raw_env;
            }
        },
        .boolean => struct {
            const ValueType = enum(u8) { undefined, not_set, no, yes };

            var value = std.atomic.Value(ValueType).init(undefined);

            pub inline fn getCached() CachedInterface {
                return switch (value.load(.monotonic)) {
                    .undefined => return .{ .undefined = {} },
                    .not_set => return .{ .not_set = {} },
                    .no => return .{ .value = false },
                    .yes => return .{ .value = true },
                };
            }

            pub inline fn reload(raw_env: ?[]const u8) ?NonOptionalReturnType {
                if (raw_env == null) {
                    value.store(.not_set, .monotonic);
                    return null;
                }

                const true_values = .{
                    "1",
                    "true",
                    "TRUE",
                    "yes",
                    "YES",
                    "on",
                    "ON",
                };

                const env_str = raw_env.?;

                inline for (true_values) |tv| {
                    if (std.mem.eql(u8, env_str, tv)) {
                        value.store(.yes, .monotonic);
                        return true;
                    }
                }

                value.store(.no, .monotonic);
                return false;
            }
        },
    };

    return struct {
        const Self = @This();

        /// Attempt to retrieve the value of the environment variable for the current platform, if
        /// the current platform has a supported definition. Returns null otherwise, unlike the
        /// other methods which will fail at compile time if the platform is unsupported.
        pub fn platformGet() ReturnType {
            if (bun.Environment.isPosix) {
                if (posix_key == null) return null;
            }

            if (bun.Environment.isWindows) {
                if (windows_key == null) return null;
            }

            return get();
        }

        /// Retrieve the key of the environment variable for the current platform.
        pub fn key() KeyType {
            assertPlatformSupported();
            return Self.platformKey().?;
        }

        /// Retrieve the key of the environment variable for the current platform, if any.
        pub fn platformKey() ?KeyType {
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
        pub fn get() ReturnType {
            assertPlatformSupported();

            switch (Cache.getCached()) {
                .undefined => return getForceReload(),
                .not_set => {
                    if (opts.default != null) return default();
                    return null;
                },
                .value => |v| return v,
            }
        }

        /// Retrieve the value of the environment variable, reloading it from the environment.
        /// Fails if the current platform is unsupported.
        pub fn getForceReload() ReturnType {
            assertPlatformSupported();
            const env_var = bun.getenvZ(key());
            const maybe_reloaded = Cache.reload(env_var);

            if (maybe_reloaded) |v| return v;
            if (opts.default != null) return default();

            return null;
        }

        /// Fetch the default value of this environment variable, if any.
        ///
        /// It is safe to compare the result of .get() to the result of .default() to determine if
        /// the variable is set to its default value, if .default() does not return null.
        pub fn default() ReturnType {
            if (comptime opts.default == null) {
                @compileError("Environment variable " ++ comptime_key ++ " has no default " ++
                    "value specified. It is illegal to call .default() on it.");
            }

            return opts.default.?;
        }

        fn assertPlatformSupported() void {
            const missing_key_fmt = "Cannot retrieve the value of " ++ comptime_key ++
                " for {s} since no {s} key is associated with it.";
            if (comptime bun.Environment.isWindows and windows_key == null) {
                @compileError(std.fmt.comptimePrint(missing_key_fmt, .{ "Windows", "Windows" }));
            } else if (posix_key == null) {
                @compileError(std.fmt.comptimePrint(missing_key_fmt, .{ "POSIX", "POSIX" }));
            }
        }
    };
}

pub fn EnvVarOpts(comptime T: EnvVarType) type {
    return switch (T) {
        .string => struct {
            /// The default value of this environment variable, if any.
            default: ?[]const u8 = null,
        },
        .boolean => struct {
            /// The default value of this environment variable, if any.
            default: ?bool = null,
        },
    };
}

pub fn newFeatureFlag(comptime env_var: [:0]const u8) type {
    return new(.boolean, env_var, .{ .default = false });
}

const bun = @import("bun");
const std = @import("std");
