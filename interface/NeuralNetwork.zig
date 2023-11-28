const std = @import("std");
const Layer = @import("./Layer.zig");
const DenseLayer = @import("./DenseLayer.zig");

// pub const NeuralNetwork = struct {
const Self = @This();

layers: []Layer,

pub fn init(
    num_layers: usize,
    allocator: std.mem.Allocator,
) !Self {
    const layers = try allocator.alloc(Layer, num_layers);
    for (layers, 0..) |*layer, layer_index| {
        var dense_layer = try DenseLayer.init(
            layer_index,
            layer_index + 1,
            allocator,
        );

        layer.* = dense_layer.layer();
    }

    return .{
        .layers = layers,
    };
}

pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    _ = self;
    // TODO
}

pub fn deserialize(
    self: *Self,
    json: std.json.Value,
    allocator: std.mem.Allocator,
) !void {
    _ = allocator;
    _ = json;
    _ = self;
    // TODO
}
