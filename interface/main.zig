const std = @import("std");

const NeuralNetwork = @import("NeuralNetwork.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("GPA allocator: Memory leak detected", .{}),
        }
    }

    // Standard neural network
    // ============================================
    var neural_network = try NeuralNetwork.init(3, allocator);
    defer neural_network.deinit(allocator);

    // Serialize the neural network
    const serialized_neural_network = try std.json.stringifyAlloc(allocator, neural_network, .{});
    defer allocator.free(serialized_neural_network);
    std.log.debug("serialized_neural_network: {s}", .{serialized_neural_network});

    // Deserialize the neural network
    const parsed_nn = try std.json.parseFromSlice(
        NeuralNetwork,
        allocator,
        serialized_neural_network,
        .{},
    );
    defer parsed_nn.deinit();
    var deserialized_neural_network = parsed_nn.value;
    defer deserialized_neural_network.deinit(allocator);
    std.log.debug("deserialized_neural_network: {any}", .{deserialized_neural_network});
}
