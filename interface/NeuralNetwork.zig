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

pub const SerializedNeuralNetwork = struct {
    timestamp: i64,
    layers: []std.json.ObjectMap,
};

pub fn jsonStringify(self: *@This(), jws: anytype) !void {
    try jws.write(.{
        .timestamp = std.time.timestamp(),
        .layers = self.layers,
    });
}

// @typeInfo(DefaultLayers).Union.tag_type
const possible_layer_types = [_]type{
    DenseLayer,
    ActivationLayer,
};

fn deserialize(serialized_neural_network: SerializedNeuralNetwork, allocator: std.mem.Allocator) !@This() {
    const layers = try allocator.alloc(
        Layer,
        serialized_neural_network.layers.len,
    );

    for (serialized_neural_network.layers, layers) |serialized_layer, *layer| {
        const serialized_type_name = serialized_layer.get("serialized_type_name") orelse std.json.Value{ .null = void{} };

        switch (serialized_type_name) {
            .string => |serialized_type_name_string| {
                inline for (possible_layer_types) |LayerType| {
                    if (std.mem.eql(u8, serialized_type_name_string, @typeName(LayerType))) {
                        if (serialized_layer.get("parameters")) |parameters_json_value| {
                            var parsed_specific_layer_instance = try std.json.parseFromValue(
                                LayerType,
                                allocator,
                                parameters_json_value,
                                .{},
                            );

                            layer.* = parsed_specific_layer_instance.value.layer();
                        }
                    } else {
                        std.log.err("Unknown serialized_type_name {s}", .{
                            serialized_type_name_string,
                        });
                        //return error.UnknownSerializedTypeName;
                        return std.json.ParseFromValueError.UnknownField;
                    }
                }
            },
            else => {
                std.log.err("Expected string for layer.serialized_type_name but saw {s}: {any}", .{
                    @tagName(serialized_type_name),
                    serialized_type_name,
                });
                //return error.InvalidSerializedNeuralNetworkLayer;
                return std.json.ParseFromValueError.UnknownField;
            },
        }
    }

    return .{
        .layers = layers,
        .layers_to_free = .{
            .layers = layers,
        },
    };
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const parsed_serialized_neural_network = try std.json.parseFromTokenSource(
        SerializedNeuralNetwork,
        allocator,
        source,
        options,
    );
    defer parsed_serialized_neural_network.deinit();
    const serialized_neural_network = parsed_serialized_neural_network.value;

    return try deserialize(serialized_neural_network, allocator);
}

pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !@This() {
    const parsed_serialized_neural_network = try std.json.parseFromValue(
        SerializedNeuralNetwork,
        allocator,
        source,
        options,
    );
    defer parsed_serialized_neural_network.deinit();
    const serialized_neural_network = parsed_serialized_neural_network.value;

    return try deserialize(serialized_neural_network, allocator);
}
