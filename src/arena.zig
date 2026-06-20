const rl = @import("raylib");
pub const arena_radius = 700;

pub fn draw() void {
    rl.drawCircleLines(0, 0, arena_radius, .red);
}
