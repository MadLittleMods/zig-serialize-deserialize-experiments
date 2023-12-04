const std = @import("std");
const json = @import("json.zig");
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

// The layer types that are known to the library
const possible_layer_types = [_]type{
    DenseLayer,
    ActivationLayer,
};

const SerializedLayer = struct {
    serialized_type_name: []const u8,
    parameters: std.json.Value,
};

const Context = union(enum) {
    generic_type_map: json.GenericTypeMap,
    // To let people avoid the hassle of creating a `GenericTypeMap` if they're
    // only using the built-in layer types, we can just let them pass in `void`
    void: void,
};

pub fn jsonParse(
    allocator: std.mem.Allocator,
    source: anytype,
    context: Context,
    options: std.json.ParseOptions,
) !@This() {
    const json_value = try std.json.parseFromTokenSourceLeaky(std.json.Value, allocator, source, options);
    return try jsonParseFromValue(allocator, json_value, context, options);
}

pub fn jsonParseFromValue(
    allocator: std.mem.Allocator,
    source: std.json.Value,
    context: Context,
    options: std.json.ParseOptions,
) !@This() {
    const parsed_serialized_layer = try std.json.parseFromValue(
        SerializedLayer,
        allocator,
        source,
        options,
    );
    defer parsed_serialized_layer.deinit();
    const serialized_layer = parsed_serialized_layer.value;

    // Find the specific layer type that we're trying to deserialize into
    //
    // TODO: We should probably just align the built-in layers pattern with the way we
    // do things for the GenericTypeMap below
    inline for (possible_layer_types) |LayerType| {
        if (std.mem.eql(u8, serialized_layer.serialized_type_name, @typeName(LayerType))) {
            var parsed_specific_layer_instance = try std.json.parseFromValue(
                LayerType,
                allocator,
                serialized_layer.parameters,
                .{},
            );

            // Return a generic `Layer` instance
            return parsed_specific_layer_instance.value.layer();
        }
    } else {
        switch (context) {
            .generic_type_map => {
                const layer_type_map = context.get(@typeName(Self)) orelse {
                    std.log.err("Unknown serialized_type_name {s} and we we're " ++
                        "unable to find the Layer TypeMap in the GenericTypeMap context", .{
                        serialized_layer.serialized_type_name,
                    });
                    return std.json.ParseFromValueError.UnknownField;
                };
                const deserializeFn = layer_type_map.get(serialized_layer.serialized_type_name) orelse {
                    std.log.err("Unable to find serialized_type_name {s} in Layer TypeMap", .{
                        serialized_layer.serialized_type_name,
                    });
                    return std.json.ParseFromValueError.UnknownField;
                };

                const layer = @as(*Self, @ptrCast(@alignCast(
                    try deserializeFn(
                        allocator,
                        serialized_layer.parameters,
                    ),
                )));

                return layer;
            },
            else => {
                std.log.err("Unknown serialized_type_name {s} (does not match any known layer types)", .{
                    serialized_layer.serialized_type_name,
                });
                return std.json.ParseFromValueError.UnknownField;
            },
        }
    }

    @panic("Something went wrong in our layer deserialization and we reached a spot that should be unreachable");
}
