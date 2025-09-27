//! OS-level functionality.
//! Designed to be slightly higher level than sys.zig

/// Opaque type representing the user ID.
pub const Uid = struct {
    const Self = @This();

    _underlying: std.c.uid_t,

    pub fn queryEffective() Self {
        // TODO(markovejnovic): Unfortunately, geteuid is not available in Zig's stdlib at the
        //                      moment, so we need to use @cImport above.
        return .{ ._underlying = bun.c.geteuid() };
    }

    pub fn queryReal() Self {
        // TODO(markovejnovic): Unfortunately, getuid is not available in Zig's stdlib at the
        //                      moment, so we need to use @cImport above.
        return .{ ._underlying = bun.c.getuid() };
    }

    /// Falls back to queryEffective.
    pub fn queryCurrent() Self {
        return queryEffective();
    }
};

/// Utilities for fetching and interacting with the current system home directory.
pub const HomeDir = struct {
    pub const QueryOpts = struct {
        user: ?[]const u8 = null,
    };

    const Self = @This();

    path: pathlib.AutoAbsPath,

    pub fn slice(self: *const Self) []const u8 {
        return self.path.slice();
    }

    pub fn deinit(self: *const Self) void {
        self.path.deinit();
    }

    pub const QueryError = error{
        FailedToFindHomeDir,
        OutOfMemory,
        TryAgainLater,
    };

    /// Deduces the current user's home directory.
    ///
    /// Has multiple strategies depending on the platform and environment. Mostly compliant with
    /// the POSIX standard for POSIX systems.
    ///
    /// No compliance claims are made for Windows.
    pub fn query(allocator: std.mem.Allocator, opts: QueryOpts) QueryError!Self {
        if (opts.user != null) {
            // There is actually a reasonable desire to be able to query other users' home
            // directories. However, we don't have a need to do that at this moment. See
            // doi:10.1109/IEEESTD.2018.8277153 2.6.1 for further details.
            @panic("Not implemented");
        }

        return if (bun.Environment.isWindows)
            queryWin(allocator, opts)
        else
            queryPosix(allocator, opts);
    }

    /// Try to fetch the HomeDir from the environment.
    fn fromEnv(env_var: ?[]const u8) QueryError!Self {
        if (env_var) |e| {
            if (std.fs.path.isAbsolute(e)) {
                var path = pathlib.AutoAbsPath.init();
                path.append(e);
                return .{ .path = path };
            }
        }

        return error.FailedToFindHomeDir;
    }

    /// Deduces the current user's home directory on POSIX systems.
    ///
    /// Whichever of the following returns a value is returned.
    /// - Per doi:10.1109/IEEESTD.2018.8277153, the `$HOME` variable.
    /// - The `getpwuid_r` function.
    fn queryPosix(allocator: std.mem.Allocator, opts: QueryOpts) QueryError!Self {
        const Heuristics = struct {
            pub fn getpwuidr(alloc: std.mem.Allocator) QueryError!Self {
                // The maximum total number of attempts we will have at reading getpwuid_r before
                // giving up. There are a few cases which benefit from re-attempting a read.
                const max_attempts = 8;

                // TODO(markovejnovic): std.c does not expose c._SC_GETPW_R_SIZE_MAX at the moment,
                //                      so we need to use @cImport above.
                const initial_buf_size: usize = @intCast(std.c.sysconf(bun.c._SC_GETPW_R_SIZE_MAX));
                const buf_size_gain = 4;

                var buffer_size: usize = initial_buf_size;
                var temp_buf = try alloc.alloc(u8, buffer_size);
                defer alloc.free(temp_buf);

                for (0..max_attempts) |_| {
                    var passwd: bun.c.struct_passwd = undefined;
                    var result: *bun.c.struct_passwd = undefined;

                    // TODO(markovejnovic): Unfortunately, at the time of writing, Zig's
                    //                      std.c.getpwuid_r aliases to openBSD's getpwuid_r, which
                    //                      doesn't work. Consequently, we need to use @cImport
                    //                      above.
                    // TODO(markovejnovic): This could be its own utility, perhaps?
                    const rc = bun.c.getpwuid_r(
                        Uid.queryCurrent()._underlying,
                        &passwd,
                        temp_buf.ptr,
                        temp_buf.len,
                        @ptrCast(&result),
                    );
                    if (rc == 0) {
                        // Great, we found a password entry, with a home directory.
                        if (result.pw_dir == null) {
                            return error.FailedToFindHomeDir;
                        }

                        const dir_slice = std.mem.sliceTo(result.pw_dir, 0);
                        var path = pathlib.AutoAbsPath.init();
                        path.append(dir_slice);
                        return .{ .path = path };
                    }

                    switch (std.posix.errno(rc)) {
                        .INTR => {
                            // We got hit by a signal, let's just try again.
                            continue;
                        },
                        .IO => {
                            // I/O error.
                            //
                            // Perhaps trying again later will work?
                            return error.TryAgainLater;
                        },
                        .MFILE => {
                            // The maximum number (OPEN_MAX) of files was open already in the
                            // calling process.
                            //
                            // Perhaps trying again later will work?
                            return error.TryAgainLater;
                        },
                        .NFILE => {
                            // The maximum number of files was open already in the system.
                            //
                            // Perhaps trying again later will work?
                            return error.TryAgainLater;
                        },
                        .NOMEM, .RANGE => {
                            // ENOMEM -- Insufficient memory to allocate passwd structure.
                            // ERANGE -- Insufficient buffer space supplied.
                            buffer_size *= buf_size_gain;
                            temp_buf = try alloc.realloc(temp_buf, buffer_size);
                            continue;
                        },
                        else => {
                            // 0 or ENOENT or ESRCH or EBADF or EPERM or ... The given name or uid
                            // was not found -- there's really no point in trying again.
                            break;
                        },
                    }
                }

                return error.FailedToFindHomeDir;
            }
        };

        if (bun.Environment.isWindows) {
            @compileError("You cannot call queryPosix on Windows");
        }

        if (opts.user != null) {
            // There is actually a reasonable desire to be able to query other users' home
            // directories. However, we don't have a need to do that. See
            // doi:10.1109/IEEESTD.2018.8277153 2.2.6.1 for further details.
            @panic("Not implemented");
        }

        var result = fromEnv(bun.EnvVar.home.get());
        if (result != error.FailedToFindHomeDir) {
            return result;
        }

        result = Heuristics.getpwuidr(allocator);
        if (result != error.FailedToFindHomeDir) {
            return result;
        }

        return error.FailedToFindHomeDir;
    }

    /// Deduces the current user's home directory on Windows systems.
    ///
    /// Exactly matches the behavior of uv_os_homedir.
    fn queryWin(allocator: std.mem.Allocator, opts: QueryOpts) QueryError!Self {
        _ = allocator;
        const Heuristics = struct {
            pub fn getUserProfileDirectoryW() QueryError!Self {
                const win32 = bun.windows;

                var proc_token: win32.HANDLE = undefined;
                defer _ = win32.CloseHandle(proc_token);
                const proc_hndl = win32.GetCurrentProcess();
                var rc = win32.OpenProcessToken(proc_hndl, win32.TOKEN_QUERY, &proc_token);
                if (rc == win32.FALSE) {
                    return error.FailedToFindHomeDir;
                }

                // We're a little bit more clever than libuv, trading off memory usage for speed.
                // They first query the system (with a syscall) for the required buffer size, and
                // then allocate. We just allocate a reasonably sized buffer and pray that works,
                // which avoids an extra syscall in the common case.
                const initial_buf_size_wchar: usize = win32.MAX_PATH;

                var wchar_buf_storage: [win32.MAX_PATH]u16 = undefined;
                var wchar_buf: []u16 = wchar_buf_storage[0..];
                var path_size: win32.DWORD = initial_buf_size_wchar;

                rc = win32.GetUserProfileDirectoryW(proc_token, @ptrCast(wchar_buf.ptr), &path_size);

                // If buffer was insufficient, allocate dynamically
                var heap_buf: ?[]u16 = null;
                defer if (heap_buf) |buf| bun.default_allocator.free(buf);

                if (rc == win32.FALSE and win32.GetLastError() == .INSUFFICIENT_BUFFER) {
                    heap_buf = try bun.default_allocator.alloc(u16, path_size);
                    wchar_buf = heap_buf.?;
                    rc = win32.GetUserProfileDirectoryW(proc_token, @ptrCast(wchar_buf.ptr), &path_size);
                }

                if (rc == win32.FALSE) {
                    return error.FailedToFindHomeDir;
                }

                // Convert from null-terminated WCHAR to slice
                const wchar_slice = std.mem.sliceTo(@as([*:0]u16, @ptrCast(wchar_buf.ptr)), 0);

                // Create path - the Path type will handle the UTF-16 to UTF-8 conversion internally
                var path = pathlib.AutoAbsPath.init();
                path.append(wchar_slice);
                return .{ .path = path };
            }
        };

        if (!bun.Environment.isWindows) {
            @compileError("You cannot call queryWin on POSIX");
        }

        if (opts.user != null) {
            // There is actually a reasonable desire to be able to query other users' home
            // directories. However, we don't have a need to do that. See
            // doi:10.1109/IEEESTD.2018.8277153 2.6.1 for further details.
            @panic("Not implemented");
        }

        var result = fromEnv(bun.EnvVar.home.get());
        if (result != error.FailedToFindHomeDir) {
            return result;
        }

        result = Heuristics.getUserProfileDirectoryW();
        if (result != error.FailedToFindHomeDir) {
            return result;
        }

        return error.FailedToFindHomeDir;
    }
};

const bun = @import("bun");
const pathlib = @import("./paths/Path.zig");
const std = @import("std");
