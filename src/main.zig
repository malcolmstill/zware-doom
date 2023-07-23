const std = @import("std");
const os = std.os;
const fs = std.fs;
const zware = @import("zware");
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const doom = @import("interface.zig");

var gpa = GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const @"doom.wasm" = @embedFile("doom.wasm");

    var store = zware.Store.init(alloc);
    defer store.deinit();

    var module = zware.Module.init(alloc, @"doom.wasm");
    defer module.deinit();
    try module.decode();

    try doom.initHostFunctions(&store);

    var instance = zware.Instance.init(alloc, &store, module);
    try instance.instantiate();
    defer instance.deinit();

    var api = doom.Api.init(&instance);

    const cwd = try fs.cwd().openDir("./", .{});

    try instance.addWasiPreopen(0, "stdin", os.STDIN_FILENO);
    try instance.addWasiPreopen(1, "stdout", os.STDOUT_FILENO);
    try instance.addWasiPreopen(2, "stderr", os.STDERR_FILENO);
    try instance.addWasiPreopen(3, "./", cwd.fd);

    const args = try instance.forwardArgs(alloc);
    defer std.process.argsFree(alloc, args);

    _ = try api._start();
}
