//! "Dense" just means that every input is connected to every output. This is a "normal"
//! neural network layer. After each `DenseLayer`, the idiomatic thing to do is to add
//! an `ActivationLayer` to introduce non-linearity (can curve around the data to
//! classify things accurately).
//!
//! (inherits from `Layer`)
const std = @import("std");
const log = std.log.scoped(.zig_neural_networks);

const Layer = @import("Layer.zig");

// pub const DenseLayer = struct {
const Self = @This();

pub const Parameters = struct {
    num_input_nodes: usize,
    num_output_nodes: usize,
    weights: []f64,
    biases: []f64,
};

parameters: Parameters,

/// Store the cost gradients for each weight and bias. These are used to update
/// the weights and biases after each training batch.
cost_gradient_weights: []f64,
cost_gradient_biases: []f64,

pub fn init(
    num_input_nodes: usize,
    num_output_nodes: usize,
    allocator: std.mem.Allocator,
) !Self {
    // Initialize the weights
    const weights: []f64 = try allocator.alloc(f64, num_input_nodes * num_output_nodes);
    @memset(weights, 0);
    const biases: []f64 = try allocator.alloc(f64, num_output_nodes);
    @memset(biases, 0);

    // Create the cost gradients and initialize the values to 0
    const cost_gradient_weights: []f64 = try allocator.alloc(f64, num_input_nodes * num_output_nodes);
    @memset(cost_gradient_weights, 0);
    const cost_gradient_biases: []f64 = try allocator.alloc(f64, num_output_nodes);
    @memset(cost_gradient_biases, 0);

    return Self{
        .parameters = .{
            .num_input_nodes = num_input_nodes,
            .num_output_nodes = num_output_nodes,
            .weights = weights,
            .biases = biases,
        },
        .cost_gradient_weights = cost_gradient_weights,
        .cost_gradient_biases = cost_gradient_biases,
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    // For Debugging: Print the unique test weight
    std.log.debug("Deinitializing DenseLayer -> For Debugging: Print the unique test weight {d}", .{self.parameters.weights[0]});

    allocator.free(self.parameters.weights);
    allocator.free(self.parameters.biases);
    allocator.free(self.cost_gradient_weights);
    allocator.free(self.cost_gradient_biases);

    // This isn't strictly necessary but it marks the memory as dirty (010101...) in
    // safe modes (https://zig.news/kristoff/what-s-undefined-in-zig-9h)
    self.* = undefined;
}

// XXX: Forward method
// XXX: Backward method

/// Helper to create a generic `Layer` that we can use in a `NeuralNetwork`
pub fn layer(self: *@This()) Layer {
    return Layer.init(self);
}

/// Serialize the layer to JSON (using the `std.json` library).
pub fn jsonStringify(self: @This(), jws: anytype) !void {
    // What we output here, aligns with `Layer.SerializedLayer`. It's easier to use an
    // anonymous struct here instead of the `Layer.SerializedLayer` type because we know
    // the concrete type of the parameters here vs the generic `std.json.Value` from
    // `Layer.SerializedLayer`. Plus it's just more boilerplate for us to get
    // `self.parameters` into `std.json.Value` if we went that route.
    try jws.write(.{
        .serialized_type_name = @typeName(Self),
        .parameters = self.parameters,
    });
}

/// Deserialize the layer from JSON (using the `std.json` library).
pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const json_value = try std.json.parseFromTokenSourceLeaky(std.json.Value, allocator, source, options);
    return try jsonParseFromValue(allocator, json_value, options);
}

/// Deserialize the layer from a parsed JSON value. (using the `std.json` library).
pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !@This() {
    const parsed_parameters = try std.json.parseFromValue(
        Parameters,
        allocator,
        source,
        options,
    );
    defer parsed_parameters.deinit();
    const parameters = parsed_parameters.value;

    const dense_layer = try init(
        parameters.num_input_nodes,
        parameters.num_output_nodes,
        allocator,
    );
    @memcpy(dense_layer.parameters.weights, parameters.weights);
    @memcpy(dense_layer.parameters.biases, parameters.biases);

    return dense_layer;
}
