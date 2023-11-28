//! A layer that applies an activation function to its inputs. The idiomatic way to use
//! these is to place them between every `DenseLayer`.
//!
//! (inherits from `Layer`)
const std = @import("std");
const log = std.log.scoped(.zig_neural_networks);

const Layer = @import("Layer.zig");

pub const ActivationFunction = enum {
    sigmoid,
    relu,
    leaky_relu,
};

// pub const ActivationLayer = struct {
const Self = @This();

pub const Parameters = struct {
    serialized_name: []const u8 = "ActivationLayer",
    activation_function: ActivationFunction,
};

parameters: Parameters,

pub fn init(
    activation_function: ActivationFunction,
    allocator: std.mem.Allocator,
) !Self {
    _ = allocator;
    return Self{
        .parameters = .{
            .activation_function = activation_function,
        },
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    _ = allocator;
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

/// Turn some serialized parameters back into a `ActivationLayer`.
pub fn deserialize(self: *@This(), json: std.json.Value, allocator: std.mem.Allocator) !void {
    const parsed_parameters = try std.json.parseFromValue(
        Parameters,
        allocator,
        json,
        .{},
    );
    defer parsed_parameters.deinit();
    const parameters = parsed_parameters.value;

    const activation_layer = try init(
        parameters.activation_function,
        allocator,
    );

    self.* = activation_layer;
}
