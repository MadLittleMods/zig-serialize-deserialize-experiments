const std = @import("std");

// pub const Typetracker = struct {
const Self = @This();

types: []const type = &.{},

pub fn track(comptime self: *Self, comptime TypeToTrack: type) void {
    if (!@inComptime()) @compileError("TyperTracker.track() must be invoked at comptime");

    // Ignore the type if it's already in the list
    for (self.types) |AlreadyTrackedType| {
        if (AlreadyTrackedType == TypeToTrack) {
            return;
        }
    }

    // Add the type to the list of tracked types
    self.types = self.types ++ &[_]type{TypeToTrack};
}

// XXX: This doesn't work because it requires all parameters to be comptime since we
// have a "comptime-only return type"
pub fn getTypeByTypeName(comptime self: *Self, type_name: []const u8) ?type {
    inline for (self.types) |CurrentType| {
        if (std.mem.eql(u8, type_name, @typeName(CurrentType))) {
            return CurrentType;
        }
    }

    return null;
}

test {
    const Type1 = struct {};
    const Type2 = struct {};
    const Type3 = struct {};

    comptime var tracker = Self{};
    comptime tracker.track(Type1);
    comptime tracker.track(Type2);
    comptime tracker.track(Type3);

    const TypeResult = tracker.getTypeByTypeName(@typeName(Type2)) orelse @panic("Type not found");
    try std.testing.expectEqual(Type2, TypeResult);
}
