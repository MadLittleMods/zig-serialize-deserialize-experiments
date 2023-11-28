const std = @import("std");

const NeuralNetwork = @import("NeuralNetwork.zig");
const Layer = @import("Layer.zig");
const DenseLayer = @import("DenseLayer.zig");
const ActivationLayer = @import("ActivationLayer.zig");
const CustomDropoutLayer = @import("CustomDropoutLayer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("GPA allocator: Memory leak detected", .{}),
        }
    }

    // Custom neural network
    // ============================================
    // Setup the layers we'll be using in our custom neural network
    var dense_layer1 = try DenseLayer.init(2, 3, allocator);
    var activation_layer2 = try ActivationLayer.init(.sigmoid, allocator);
    var dropout_layer3 = try CustomDropoutLayer.init(0.2, allocator);
    var layers = [_]Layer{
        dense_layer1.layer(),
        activation_layer2.layer(),
        dropout_layer3.layer(),
    };
    defer {
        for (layers) |layer| {
            layer.deinit(allocator);
        }
    }

    // Create the neural network
    var custom_neural_network = try NeuralNetwork.initFromLayers(
        &layers,
    );
    defer custom_neural_network.deinit(allocator);

    // // Serialize the neural network
    // const serialized_custom_neural_network = try custom_neural_network.serialize(allocator);
    // defer allocator.free(serialized_custom_neural_network);
    // std.log.debug("serialized_custom_neural_network: {s}", .{serialized_custom_neural_network});

    // // Deserialize the neural network
    // var deserialized_custom_neural_network = try allocator.create(NeuralNetwork);
    // defer allocator.destroy(deserialized_custom_neural_network);
    // const parsed_custom_nn = try std.json.parseFromSlice(
    //     std.json.Value,
    //     allocator,
    //     serialized_custom_neural_network,
    //     .{},
    // );
    // defer parsed_custom_nn.deinit();
    // try deserialized_custom_neural_network.deserialize(parsed_custom_nn.value, allocator);
    // defer deserialized_custom_neural_network.deinit(allocator);
    // std.log.debug("deserialized_custom_neural_network: {any}", .{deserialized_custom_neural_network});
}
