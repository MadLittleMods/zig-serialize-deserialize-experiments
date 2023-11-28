const std = @import("std");
const Layer = @import("./Layer.zig");
const DenseLayer = @import("./DenseLayer.zig");
const ActivationLayer = @import("./ActivationLayer.zig");

// pub const NeuralNetwork = struct {
const Self = @This();

/// The layers of the neural network.
layers: []Layer,

/// Keep track of any layers we specifically create in the NeuralNetwork from
/// functions like `initFromLayerSizes()` so we can free them when we `deinit`.
layers_to_free: struct {
    layers: ?[]Layer = null,
    dense_layers: ?[]DenseLayer = null,
    activation_layers: ?[]ActivationLayer = null,
},

pub fn init(
    num_layers: usize,
    allocator: std.mem.Allocator,
) !Self {
    // We need to keep track of the specific layer types so they can live past
    // this stack context and so we can free them later on `deinit`.
    const dense_layers = try allocator.alloc(DenseLayer, num_layers);
    const activation_layers = try allocator.alloc(ActivationLayer, num_layers);

    const layers = try allocator.alloc(Layer, 2 * num_layers);
    for (dense_layers, activation_layers, 0..) |*dense_layer, *activation_layer, dense_layer_index| {
        dense_layer.* = try DenseLayer.init(
            dense_layer_index + 1,
            dense_layer_index + 2,
            allocator,
        );
        activation_layer.* = try ActivationLayer.init(
            ActivationLayer.ActivationFunction.relu,
            allocator,
        );

        // Keep track of the generic layers
        const layer_index = 2 * dense_layer_index;
        layers[layer_index] = dense_layer.layer();
        layers[layer_index + 1] = activation_layer.layer();
    }

    return .{
        .layers = layers,
        .layers_to_free = .{
            .layers = layers,
            .dense_layers = dense_layers,
            .activation_layers = activation_layers,
        },
    };
}

pub fn initFromLayers(
    layers: []Layer,
    // TODO
    // options: struct {
    //     layer_lookup_map: std.StringHashMap(Layer),
    // },
) !Self {
    return Self{
        .layers = layers,
        // We don't need to free any layers because it's the callers
        // responsibility to free them since they created them.
        .layers_to_free = .{},
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if (self.layers_to_free.layers) |layers| {
        for (layers) |*layer| {
            layer.deinit(allocator);
        }
        allocator.free(layers);
    }

    if (self.layers_to_free.dense_layers) |dense_layers| {
        allocator.free(dense_layers);
    }

    if (self.layers_to_free.activation_layers) |activation_layers| {
        allocator.free(activation_layers);
    }

    // This isn't strictly necessary but it marks the memory as dirty (010101...) in
    // safe modes (https://zig.news/kristoff/what-s-undefined-in-zig-9h)
    self.* = undefined;
}

// via https://www.aolium.com/karlseguin/46252c5b-587a-c419-be96-a0ccc2f11de4
pub const RawJsonValue = struct {
    value: ?[]const u8,

    pub fn init(value: ?[]const u8) @This() {
        return .{ .value = value };
    }

    pub fn jsonStringify(self: @This(), out: anytype) !void {
        const json = if (self.value) |value| value else "null";
        return out.print("{s}", .{json});
    }
};

pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
    const serialized_layers = try allocator.alloc(RawJsonValue, self.layers.len);
    for (self.layers, serialized_layers) |layer, *serialized_layer| {
        serialized_layer.* = RawJsonValue.init(try layer.serialize(allocator));
    }
    defer {
        for (serialized_layers) |serialized_layer| {
            if (serialized_layer.value) |value| {
                allocator.free(value);
            }
        }
        allocator.free(serialized_layers);
    }

    const json_text = try std.json.stringifyAlloc(allocator, .{
        .timestamp = std.time.timestamp(),
        .layers = serialized_layers,
    }, .{
        .whitespace = .indent_2,
    });

    return json_text;
}

pub fn deserialize(
    self: *Self,
    json: std.json.Value,
    allocator: std.mem.Allocator,
) !void {
    _ = json;
    // TODO
    self.* = .{
        .layers = try allocator.alloc(Layer, 0),
        // We don't need to free any layers because it's the callers
        // responsibility to free them since they created them.
        .layers_to_free = .{},
    };
}
