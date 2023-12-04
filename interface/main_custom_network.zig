const std = @import("std");
const json = @import("json.zig");

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
        // TODO: Possible usage:
        // .{
        //     .layer_lookup_map = {
        //         "CustomDropoutLayer": CustomDropoutLayer
        //     },
        // },
    );
    defer custom_neural_network.deinit(allocator);

    // Serialize the neural network
    const serialized_neural_network = try json.stringifyAlloc(
        allocator,
        custom_neural_network,
        .{},
    );
    defer allocator.free(serialized_neural_network);
    std.log.debug("serialized_neural_network: {s}\n\n", .{serialized_neural_network});

    // Deserialize the neural network
    //
    // XXX: This currently doesn't work because I'm not sure how to make the
    // deserialization aware of the `CustomDropoutLayer` type like it is for the Layer
    // types that are part and known to the library.
    const parsed_nn = try json.parseFromSlice(
        NeuralNetwork,
        allocator,
        serialized_neural_network,
        // TODO
        null,
        .{},
    );
    defer parsed_nn.deinit();
    const deserialized_neural_network = parsed_nn.value;
    // defer deserialized_neural_network.deinit(allocator);
    std.log.debug("deserialized_neural_network: {any}", .{deserialized_neural_network});
}
