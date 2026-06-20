const rl = @import("raylib");

pub fn v2(x: f32, y: f32) rl.Vector2 {
    return .{ .x = x, .y = y };
}

pub fn toI(f: f32) i32 {
    return @intFromFloat(f);
}
