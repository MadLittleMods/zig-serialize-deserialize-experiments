const std = @import("std");

const Self = @This();

// Interface implementation based off of https://www.openmymind.net/Zig-Interfaces/
// pub const Layer = struct {
ptr: *anyopaque,
serializeFn: *const fn (
    ptr: *anyopaque,
    allocator: std.mem.Allocator,
) anyerror![]const u8,
deserializeFn: *const fn (
    ptr: *anyopaque,
    json: std.json.Value,
    allocator: std.mem.Allocator,
) anyerror!void,
deinitFn: *const fn (
    ptr: *anyopaque,
    allocator: std.mem.Allocator,
) void,
forwardFn: *const fn (
    ptr: *anyopaque,
    inputs: []const f64,
    allocator: std.mem.Allocator,
) anyerror![]f64,

/// A generic constructor that any sub-classes can use to create a `Layer`.
//
// All of this complexity here allows the sub-classes to stand on their own instead
// of having to deal with awkward member functions that take `ptr: *anyopaque` which
// we can't call directly. See the "Making it Prettier" section in
// https://www.openmymind.net/Zig-Interfaces/.
pub fn init(
    /// Because of the `anytype` here, all of this runs at comptime
    ptr: anytype,
) Self {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    if (ptr_info != .Pointer) @compileError("ptr must be a pointer");
    if (ptr_info.Pointer.size != .One) @compileError("ptr must be a single item pointer");

    const gen = struct {
        pub fn serialize(
            pointer: *anyopaque,
            allocator: std.mem.Allocator,
        ) anyerror![]const u8 {
            const self: T = @ptrCast(@alignCast(pointer));
            return try ptr_info.Pointer.child.serialize(self, allocator);
        }
        pub fn deserialize(
            pointer: *anyopaque,
            json: std.json.Value,
            allocator: std.mem.Allocator,
        ) !void {
            const self: T = @ptrCast(@alignCast(pointer));
            try ptr_info.Pointer.child.deserialize(self, json, allocator);
        }
        pub fn deinit(
            pointer: *anyopaque,
            allocator: std.mem.Allocator,
        ) void {
            const self: T = @ptrCast(@alignCast(pointer));
            ptr_info.Pointer.child.deinit(self, allocator);
        }
        pub fn forward(
            pointer: *anyopaque,
            inputs: []const f64,
            allocator: std.mem.Allocator,
        ) anyerror![]f64 {
            const self: T = @ptrCast(@alignCast(pointer));
            // We could alternatively use `@call(.always_inline,
            // ptr_info.Pointer.child.forward, .{ self, inputs, allocator });` for
            // any of these functions calls. It would be best to test if this has a
            // performance impact before making our code more complex though. Using
            // this also has the benefit of cleaning up the call-stack.
            return ptr_info.Pointer.child.forward(self, inputs, allocator);
        }
    };

    return .{
        .ptr = ptr,
        .serializeFn = gen.serialize,
        .deserializeFn = gen.deserialize,
        .deinitFn = gen.deinit,
        .forwardFn = gen.forward,
    };
}

/// Serialize the layer to JSON.
pub fn serialize(self: @This(), allocator: std.mem.Allocator) ![]const u8 {
    return try self.serializeFn(self.ptr, allocator);
}

/// Deserialize the layer from JSON.
pub fn deserialize(self: @This(), json: std.json.Value, allocator: std.mem.Allocator) !void {
    try self.deserializeFn(self.ptr, json, allocator);
}

/// Used to clean-up any allocated resources used in the layer.
pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
    return self.deinitFn(self.ptr, allocator);
}

/// Run the given `inputs` through a layer of the neural network and return the outputs.
pub fn forward(
    self: @This(),
    inputs: []const f64,
    allocator: std.mem.Allocator,
) ![]f64 {
    return self.forwardFn(self.ptr, inputs, allocator);
}
