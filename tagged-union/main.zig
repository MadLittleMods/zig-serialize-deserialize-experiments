const std = @import("std");

const FooCopter = struct {
    speed: u32,
    pub fn fly(self: @This()) void {
        std.log.info("FooCopter is flying at {d}", .{self.speed});
    }
};

const BarCopter = struct {
    speed: u32,
    pub fn fly(self: @This()) void {
        std.log.info("BarCopter is flying at {d}", .{self.speed});
    }
};

pub const Helicopter = union(enum) {
    foo_copter: FooCopter,
    bar_copter: BarCopter,

    pub fn fly(self: @This()) void {
        return switch (self) {
            inline else => |case| case.fly(),
        };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        switch (gpa.deinit()) {
            .ok => {},
            .leak => std.log.err("GPA allocator: Memory leak detected", .{}),
        }
    }

    const helicopter = Helicopter{ .foo_copter = FooCopter{ .speed = 5 } };

    const stringified = try std.json.stringifyAlloc(
        allocator,
        helicopter,
        .{},
    );
    defer allocator.free(stringified);
    std.log.debug("stringified: {s}", .{stringified});

    const deserialized = try std.json.parseFromSlice(
        Helicopter,
        allocator,
        stringified,
        .{},
    );
    defer deserialized.deinit();
    std.log.debug("deserialized: {any}", .{deserialized.value});
}
