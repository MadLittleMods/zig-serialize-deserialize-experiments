const std = @import("std");
const json = @import("json.zig");

const Layer = @import("Layer.zig");
const CustomDropoutLayer = @import("CustomDropoutLayer.zig");

const CustomDropoutLayerDeserializer = struct {
    pub fn deserialize(allocator: std.mem.Allocator, source: std.json.Value) !*anyopaque {
        _ = source;
        // XXX: This leaks memory. Need to figure out how to structure `deserialize` better.
        var custom_dropout_layer = try allocator.create(CustomDropoutLayer);
        custom_dropout_layer.* = .{
            .parameters = .{
                .dropout_rate = 0.5,
            },
        };

        const layer = try allocator.create(Layer);
        layer.* = custom_dropout_layer.layer();

        return @ptrCast(layer);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("GPA allocator: Memory leak detected", .{}),
        }
    }

    // Create a map that tracks the various interface types (like Layers)
    var generic_type_map = json.GenericTypeMap.init(allocator);
    defer generic_type_map.deinit();

    // Create a map that tracks the various Layer types
    var layer_type_map = json.TypeMap.init(allocator);
    defer layer_type_map.deinit();
    // Keep track of the Layer type map in our generic type map
    try generic_type_map.put(@typeName(Layer), &layer_type_map);
    // Fill out the Layer type map
    try layer_type_map.put(@typeName(CustomDropoutLayer), CustomDropoutLayerDeserializer.deserialize);

    // Try to use the type map
    try tryToUseTypeMap(generic_type_map, allocator);
}

fn tryToUseTypeMap(generic_type_map: json.GenericTypeMap, allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const layer_type_map = generic_type_map.get(@typeName(Layer)) orelse @panic("Layer type map not found");
    const deserializeFn = layer_type_map.get(@typeName(CustomDropoutLayer)) orelse @panic("CustomDropoutLayer deserialize function not found");
    const specific_layer = @as(*Layer, @ptrCast(@alignCast(
        try deserializeFn(
            arena_allocator,
            // serialized_data,
        ),
    )));
    defer specific_layer.deinit(allocator);

    std.log.debug("specific_layer {any},", .{specific_layer});
}
