//! A layer that randomly drops nodes in the layer
//!
//! (inherits from `Layer`)
const std = @import("std");
const log = std.log.scoped(.zig_neural_networks);

const Layer = @import("Layer.zig");

// pub const DropoutLayer = struct {
const Self = @This();

pub const Parameters = struct {
    dropout_rate: f64,
};

parameters: Parameters,

pub fn init(
    /// A value between 0 and 1 that represents the probability of a node being dropped
    dropout_rate: f64,
    allocator: std.mem.Allocator,
) !Self {
    _ = allocator;
    return Self{
        .parameters = .{
            .dropout_rate = dropout_rate,
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

pub fn jsonStringify(self: @This(), jws: anytype) !void {
    try jws.write(.{
        .serialized_type_name = @typeName(Self),
        .parameters = self.parameters,
    });
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const json_value = try std.json.parseFromTokenSourceLeaky(std.json.Value, allocator, source, options);
    return try jsonParseFromValue(allocator, json_value, options);
}

pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !@This() {
    const parsed_parameters = try std.json.parseFromValue(
        Parameters,
        allocator,
        source,
        options,
    );
    defer parsed_parameters.deinit();
    const parameters = parsed_parameters.value;

    const dropout_layer = try init(
        parameters.dropout_rate,
        allocator,
    );

    return dropout_layer;
}
