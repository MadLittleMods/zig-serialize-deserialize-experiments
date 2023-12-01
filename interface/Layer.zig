const std = @import("std");
const DenseLayer = @import("./DenseLayer.zig");
const ActivationLayer = @import("./ActivationLayer.zig");

const Self = @This();

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
// serializeFn: *const fn (
//     ptr: *anyopaque,
//     allocator: std.mem.Allocator,
// ) anyerror![]const u8,
// deserializeFn: *const fn (
//     ptr: *anyopaque,
//     json: std.json.Value,
//     allocator: std.mem.Allocator,
// ) anyerror!void,
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
        // pub fn serialize(
        //     pointer: *anyopaque,
        //     allocator: std.mem.Allocator,
        // ) anyerror![]const u8 {
        //     const self: T = @ptrCast(@alignCast(pointer));
        //     return try ptr_info.Pointer.child.serialize(self, allocator);
        // }
        // pub fn deserialize(
        //     pointer: *anyopaque,
        //     json: std.json.Value,
        //     allocator: std.mem.Allocator,
        // ) !void {
        //     const self: T = @ptrCast(@alignCast(pointer));
        //     try ptr_info.Pointer.child.deserialize(self, json, allocator);
        // }
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
        // .serializeFn = gen.serialize,
        // .deserializeFn = gen.deserialize,
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

// /// Serialize the layer to JSON.
// pub fn serialize(self: @This(), allocator: std.mem.Allocator) ![]const u8 {
//     return try self.serializeFn(self.ptr, allocator);
// }

// /// Deserialize the layer from JSON.
// pub fn deserialize(self: @This(), json: std.json.Value, allocator: std.mem.Allocator) !void {
//     try self.deserializeFn(self.ptr, json, allocator);
// }

const possible_layer_types = [_]type{
    DenseLayer,
    ActivationLayer,
};

const SerializedLayer = struct {
    serialized_type_name: []const u8,
    parameters: std.json.Value,
};

fn deserialize(serialized_layer: SerializedLayer, allocator: std.mem.Allocator) !@This() {
    inline for (possible_layer_types) |LayerType| {
        if (std.mem.eql(u8, serialized_layer.serialized_type_name, @typeName(LayerType))) {
            var parsed_specific_layer_instance = try std.json.parseFromValue(
                LayerType,
                allocator,
                serialized_layer.parameters,
                .{},
            );

            return parsed_specific_layer_instance.value.layer();
        }
    } else {
        std.log.err("Unknown serialized_type_name {s} (does not match any known layer types)", .{
            serialized_layer.serialized_type_name,
        });
        return std.json.ParseFromValueError.UnknownField;
    }

    @panic("Something went wrong in our layer deserialization and we reached a spot that should be unreachable");
}

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

    return try deserialize(serialized_layer, allocator);
}
