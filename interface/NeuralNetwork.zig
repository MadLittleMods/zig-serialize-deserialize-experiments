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
    const layers = allocator.alloc(Layer, num_layers);
    for (layers, 0..) |*layer, layer_index| {
        const dense_layer = try DenseLayer.init(
            allocator,
            .{
                .input_size = layer_index,
                .output_size = layer_index + 1,
            },
        );

        layer.* = dense_layer.layer();
    }

    return .{
        .layers = layers,
    };
}

pub fn serialize(self: *Self, allocator: std.mem.Allocator) ![]const u8 {
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
