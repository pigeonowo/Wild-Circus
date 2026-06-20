const rl = @import("raylib");

pub fn v2(x: f32, y: f32) rl.Vector2 {
    return .{ .x = x, .y = y };
}

pub fn toI(f: f32) i32 {
    return @intFromFloat(f);
}

pub fn go_to(source: rl.Vector2, dest: rl.Vector2, by: f32) rl.Vector2 {
    const added = source.subtract(dest);
    const normalized = rl.math.vector2Normalize(added);
    var result = source;
    result.x -= (by * normalized.x);
    result.y -= (by * normalized.y);
    return result;
}
