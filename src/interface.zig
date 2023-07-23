const std = @import("std");
const zware = @import("zware");
const glfw = @import("glfw.zig");

// FIXME: when I uncomment the code that looks up env vars in the doom fork
//        we'll need to add the env var handling wasi functions and import
//        them here
pub fn initHostFunctions(store: *zware.Store) !void {
    try store.exposeHostFunction("wasi_snapshot_preview1", "args_get", zware.wasi.args_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "args_sizes_get", zware.wasi.args_sizes_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "clock_time_get", zware.wasi.clock_time_get, &[_]zware.ValType{ .I32, .I64, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_close", zware.wasi.fd_close, &[_]zware.ValType{.I32}, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_fdstat_get", zware.wasi.fd_fdstat_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_fdstat_set_flags", zware.wasi.fd_fdstat_set_flags, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_filestat_get", zware.wasi.fd_filestat_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_prestat_get", zware.wasi.fd_prestat_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_prestat_dir_name", zware.wasi.fd_prestat_dir_name, &[_]zware.ValType{ .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_read", zware.wasi.fd_read, &[_]zware.ValType{ .I32, .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_seek", zware.wasi.fd_seek, &[_]zware.ValType{ .I32, .I64, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "fd_write", zware.wasi.fd_write, &[_]zware.ValType{ .I32, .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "path_create_directory", zware.wasi.path_create_directory, &[_]zware.ValType{ .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "path_filestat_get", zware.wasi.path_filestat_get, &[_]zware.ValType{ .I32, .I32, .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "path_open", zware.wasi.path_open, &[_]zware.ValType{ .I32, .I32, .I32, .I32, .I32, .I64, .I64, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "poll_oneoff", zware.wasi.poll_oneoff, &[_]zware.ValType{ .I32, .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("wasi_snapshot_preview1", "proc_exit", zware.wasi.proc_exit, &[_]zware.ValType{.I32}, &[_]zware.ValType{});
    try store.exposeHostFunction("wasi_snapshot_preview1", "random_get", zware.wasi.random_get, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("env", "ZwareDoomNextEvent", ZwareDoomNextEvent, &[_]zware.ValType{ .I32, .I32, .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("env", "ZwareDoomPendingEvent", ZwareDoomPendingEvent, &[_]zware.ValType{}, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("env", "ZwareDoomRenderFrame", ZwareDoomRenderFrame, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("env", "ZwareDoomOpenWindow", ZwareDoomOpenWindow, &[_]zware.ValType{}, &[_]zware.ValType{.I32});
    try store.exposeHostFunction("env", "ZwareDoomSetPalette", ZwareDoomSetPalette, &[_]zware.ValType{ .I32, .I32 }, &[_]zware.ValType{});
}

const WIDTH = 320;
const HEIGHT = 200;
var palette_loc: i32 = undefined;

pub fn ZwareDoomOpenWindow(vm: *zware.VirtualMachine) zware.WasmError!void {
    glfw.newWindow(WIDTH, HEIGHT);

    try vm.pushOperand(u64, 0);
}

pub fn ZwareDoomRenderFrame(vm: *zware.VirtualMachine) zware.WasmError!void {
    const screen_len = vm.popOperand(u32);
    const screen_ptr = vm.popOperand(u32);

    const memory = try vm.inst.getMemory(0);
    const data = memory.memory();
    const screen = data[screen_ptr .. screen_ptr + screen_len];

    glfw.renderFrame(screen);

    try vm.pushOperand(u64, 0);
}

var pressed_key: ?i32 = null;

pub fn ZwareDoomPendingEvent(vm: *zware.VirtualMachine) zware.WasmError!void {
    if (glfw.pendingEvents()) {
        try vm.pushOperand(i32, 1);
    } else {
        try vm.pushOperand(i32, 0);
    }
}

// FIXME: support the E key...I can't open the doors yet :facepalm:
pub fn ZwareDoomNextEvent(vm: *zware.VirtualMachine) zware.WasmError!void {
    const data3_ptr = vm.popOperand(u32);
    _ = data3_ptr;
    const data2_ptr = vm.popOperand(u32);
    _ = data2_ptr;
    const data1_ptr = vm.popOperand(u32);
    const event_type_ptr = vm.popOperand(u32);

    const event = glfw.nextEvent();

    const memory = try vm.inst.getMemory(0);
    switch (event.type) {
        .keydown => {
            try memory.write(u32, event_type_ptr, 0, 0);
        },
        .keyup => {
            try memory.write(u32, event_type_ptr, 0, 1);
        },
    }
    try memory.write(i32, data1_ptr, 0, event.scancode); // FIXME: use glfw enum, not scancode

    try vm.pushOperand(u64, 0);
}

pub fn ZwareDoomSetPalette(vm: *zware.VirtualMachine) zware.WasmError!void {
    const palette_len = vm.popOperand(u32); // The palette length in bytes. The actual number of colors is this length / 4
    const palette_ptr = vm.popOperand(u32); // Our palette data will be at this address

    const memory = try vm.inst.getMemory(0);
    const data = memory.memory();
    const palette = data[palette_ptr .. palette_ptr + palette_len];
    std.debug.assert(palette.len / 4 == 256);

    glfw.setPalette(palette);
}

pub const Api = struct {
    instance: *zware.Instance,

    const Self = @This();

    pub fn init(instance: *zware.Instance) Self {
        return .{ .instance = instance };
    }

    pub fn _start(self: *Self) !void {
        var in = [_]u64{};
        var out = [_]u64{};
        try self.instance.invoke("_start", in[0..], out[0..], .{});
    }
};
