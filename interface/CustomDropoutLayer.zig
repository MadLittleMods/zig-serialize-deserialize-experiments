//! A layer that randomly drops nodes in the layer
//!
//! (inherits from `Layer`)
const std = @import("std");
const log = std.log.scoped(.zig_neural_networks);

const Layer = @import("Layer.zig");

// pub const CustomDropoutLayer = struct {
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

    // For Debugging: Print the dropout_rate that makes this layer unique
    std.log.debug("Deinitializing CustomDropoutLayer -> For Debugging: Print the dropout_rate {d}", .{self.parameters.dropout_rate});

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

    const dropout_layer = try init(
        parameters.dropout_rate,
        allocator,
    );

    return dropout_layer;
}
