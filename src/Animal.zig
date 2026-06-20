const std = @import("std");
const helpers = @import("helpers.zig");
const toI = helpers.toI;
const v2 = helpers.v2;
const rl = @import("raylib");

const Animal = @This();

const speed = 50;
const hitcooldown = 0.5;

pub const Type = enum { pig, horse };

t: Type,
x: f32,
y: f32,
last_hit: f32 = hitcooldown,
radius: f32 = 15,

pub fn new(x: f32, y: f32, t: Type) Animal {
    return Animal{
        .t = t,
        .x = x,
        .y = y,
    };
}

pub fn draw(a: Animal) void {
    const color: rl.Color = switch (a.t) {
        .pig => .pink,
        .horse => .brown,
    };
    rl.drawCircle(toI(a.x), toI(a.y), a.radius, color);
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
