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
    serialized_name: []const u8 = "DenseLayer",
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

pub fn serialize(self: *@This(), allocator: std.mem.Allocator) ![]const u8 {
    const json_text = try std.json.stringifyAlloc(
        allocator,
        self.parameters,
        .{
            .whitespace = .indent_2,
        },
    );
    return json_text;
}

/// Turn some serialized parameters back into a `DenseLayer`.
pub fn deserialize(self: *@This(), json: std.json.Value, allocator: std.mem.Allocator) !void {
    const parsed_parameters = try std.json.parseFromValue(
        Parameters,
        allocator,
        json,
        .{},
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

    self.* = dense_layer;
}
