const std = @import("std");
const helpers = @import("helpers.zig");
const toI = helpers.toI;
const v2 = helpers.v2;
const rl = @import("raylib");

const Animal = @This();

const speed = 50;
const hitcooldown = 0.5;
const pig_sprite_path = "./resources/pig.png";
const sprite_scale = 0.06;

var loadedSprites: std.AutoHashMap(Type, ?rl.Texture).Unmanaged = .empty;
pub const Type = enum { pig, horse };

t: Type,
x: f32,
y: f32,
last_hit: f32 = hitcooldown,
radius: f32 = 20,
sprite: ?rl.Texture = null,

pub fn new(x: f32, y: f32, t: Type) Animal {
    return Animal{
        .t = t,
        .x = x,
        .y = y,
    };
}

pub fn init(a: *Animal, allocator: std.mem.Allocator) !void {
    switch (a.t) {
        .pig => {
            if (loadedSprites.get(.pig)) |s| {
                a.sprite = s;
            } else {
                const sprite = try rl.loadTexture(pig_sprite_path);
                try loadedSprites.put(allocator, .pig, sprite);
                a.sprite = sprite;
            }
        },
        else => {},
    }
}

// should be called after game ends
pub fn deinitAnimalSprites(allocator: std.mem.Allocator) void {
    loadedSprites.deinit(allocator);
}

pub fn draw(a: Animal) void {
    if (a.sprite) |s| {
        const s_width: f32 = @floatFromInt(s.width);
        const s_height: f32 = @floatFromInt(s.height);
        const source = rl.Rectangle.init(0, 0, s_width, s_height);
        const dest = rl.Rectangle.init(a.x, a.y, s_width * sprite_scale, s_height * sprite_scale);
        const origin = rl.Vector2.init(@divTrunc(s_width * sprite_scale, 2), @divTrunc(s_height * sprite_scale, 2));
        rl.drawTexturePro(s, source, dest, origin, 0, .white);
    } else {
        const color: rl.Color = switch (a.t) {
            .pig => .pink,
            .horse => .brown,
        };
        rl.drawCircle(toI(a.x), toI(a.y), a.radius, color);
    }
}

pub fn can_hit(a: Animal) bool {
    return a.last_hit >= hitcooldown;
}

pub fn update(a: *Animal, delta: f32) void {
    a.last_hit += delta;
}

pub fn reset_hit_cooldown(a: *Animal) void {
    a.last_hit = 0;
}

pub fn follow_player(a: *Animal, player_pos: rl.Vector2, delta: f32) void {
    const by = speed * delta;
    const new_pos = helpers.go_to(v2(a.x, a.y), player_pos, by);
    a.x = new_pos.x;
    a.y = new_pos.y;
}
