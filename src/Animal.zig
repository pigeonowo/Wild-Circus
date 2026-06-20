const std = @import("std");
const helpers = @import("helpers.zig");
const toI = helpers.toI;
const rl = @import("raylib");

const Animal = @This();

pub const Type = enum { pig, horse };

t: Type,
x: f32,
y: f32,
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

pub fn update(a: *Animal) void {
    _ = a;
}
