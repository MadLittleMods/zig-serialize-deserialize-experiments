const std = @import("std");
const DenseLayer = @import("./DenseLayer.zig");
const ActivationLayer = @import("./ActivationLayer.zig");

const Self = @This();

const JsonDeserializeFn = *const fn (allocator: std.mem.Allocator, source: std.json.Value) anyerror!Self;
// The custom layer types that people can register
pub var type_name_to_deserialize_layer_fn_map: std.StringHashMapUnmanaged(JsonDeserializeFn) = .{};
// The layers already known to the library
pub const builtin_type_name_to_deserialize_layer_fn_map = std.ComptimeStringMap(JsonDeserializeFn, .{
    .{ @typeName(DenseLayer), deserializeFnFromLayer(DenseLayer) },
    .{ @typeName(ActivationLayer), deserializeFnFromLayer(ActivationLayer) },
});

// Just trying to copy whatever `std.json.stringifyAlloc` does because we can't use
// `anytype` in a function pointer definition
const WriteStream = std.json.WriteStream(
    std.ArrayList(u8).Writer,
    .{ .checked_to_arbitrary_depth = {} },
);

// Interface implementation based off of https://www.openmymind.net/Zig-Interfaces/
// pub const Layer = struct {
ptr: *anyopaque,
jsonStringifyFn: *const fn (
    ptr: *anyopaque,
    jws: *WriteStream,
) error{OutOfMemory}!void,
deinitFn: *const fn (
    ptr: *anyopaque,
    allocator: std.mem.Allocator,
) void,

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
        pub fn jsonStringify(pointer: *anyopaque, jws: *WriteStream) error{OutOfMemory}!void {
            const self: T = @ptrCast(@alignCast(pointer));
            return try ptr_info.Pointer.child.jsonStringify(self.*, jws);
        }
        pub fn deinit(
            pointer: *anyopaque,
            allocator: std.mem.Allocator,
        ) void {
            const self: T = @ptrCast(@alignCast(pointer));
            ptr_info.Pointer.child.deinit(self, allocator);
        }
    };

    return .{
        .ptr = ptr,
        .jsonStringifyFn = gen.jsonStringify,
        .deinitFn = gen.deinit,
    };
}
/// Used to clean-up any allocated resources used in the layer.
pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
    return self.deinitFn(self.ptr, allocator);
}

pub fn jsonStringify(self: @This(), jws: *WriteStream) !void {
    return try self.jsonStringifyFn(self.ptr, jws);
}

const SerializedLayer = struct {
    serialized_type_name: []const u8,
    parameters: std.json.Value,
};

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const json_value = try std.json.parseFromTokenSourceLeaky(std.json.Value, allocator, source, options);
    return try jsonParseFromValue(allocator, json_value, options);
}

pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !@This() {
    const parsed_serialized_layer = try std.json.parseFromValue(
        SerializedLayer,
        allocator,
        source,
        options,
    );
    defer parsed_serialized_layer.deinit();
    const serialized_layer = parsed_serialized_layer.value;

    const deserializeFn =
        // First check the built-in types since those are probably the most common
        // anyway and since we're using a `std.ComptimeStringMap`, should have a faster lookup
        builtin_type_name_to_deserialize_layer_fn_map.get(serialized_layer.serialized_type_name) orelse
        // Then check the custom layer types that people can register
        type_name_to_deserialize_layer_fn_map.get(serialized_layer.serialized_type_name) orelse {
        std.log.err("Unknown serialized_type_name {s} (does not match any known layer types). " ++
            "Try adding it to `Layer.type_name_to_deserialize_layer_fn_map`", .{
            serialized_layer.serialized_type_name,
        });
        return std.json.ParseFromValueError.UnknownField;
    };
    const generic_layer = deserializeFn(
        allocator,
        serialized_layer.parameters,
    ) catch |err| {
        // We use a `catch` here because `jsonParseFromValue()` has to return a certain
        // error set and we can't directly return the unknown error that can come from
        // `deserializeFn()` because it probably doesn't match that error set.
        std.log.err("Unable to deserialize {s}: {any}", .{
            serialized_layer.serialized_type_name,
            err,
        });
        return std.json.ParseFromValueError.UnknownField;
    };

    return generic_layer;
}

// Helper to create a `JsonDeserializeFn` for a specific layer type
pub fn deserializeFnFromLayer(comptime T: type) JsonDeserializeFn {
    const gen = struct {
        pub fn deserialize(allocator: std.mem.Allocator, source: std.json.Value) !Self {
            var specific_layer = try T.jsonParseFromValue(allocator, source, .{});
            return specific_layer.layer();
        }
    };

    return gen.deserialize;
}
