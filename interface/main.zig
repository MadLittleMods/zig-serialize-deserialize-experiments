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

    var neural_network = try NeuralNetwork.init(5, allocator);
    const serialized_neural_network = try neural_network.serialize(allocator);
    std.log.debug("serialized_neural_network: {}", .{serialized_neural_network});

    var deserialized_neural_network = try allocator.create(NeuralNetwork);
    deserialized_neural_network.deserialize(serialized_neural_network, allocator);

    std.log.debug("deserialized_neural_network: {}", .{deserialized_neural_network});
}
