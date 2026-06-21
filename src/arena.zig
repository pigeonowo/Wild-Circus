const rl = @import("raylib");
pub const arena_radius = 700;

pub var ground: ?rl.Texture = null;
pub var circle: ?rl.Texture = null;
const circle_text_scale = 2.1;

pub fn draw() void {
    if (ground) |g| {
        const source = rl.Rectangle.init(0, 0, 1000, 1000);
        const dest = rl.Rectangle.init(0, 0, 2400, 2400);
        rl.drawTexturePro(g, source, dest, rl.Vector2.init(1200, 1200), 0, .white);
    }
    if (circle) |c| {
        const source = rl.Rectangle.init(0, 0, 750, 750);
        const height = 750 * circle_text_scale;
        const width = 750 * circle_text_scale;
        const dest = rl.Rectangle.init(0, 0, width, height);
        rl.drawTexturePro(c, source, dest, rl.Vector2.init(@divTrunc(width, 2), @divTrunc(width, 2)), 0, .white);
    }
    rl.drawCircleLines(0, 0, arena_radius, .red);
}
