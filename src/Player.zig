const std = @import("std");
const rl = @import("raylib");
const weapons = @import("weapon.zig");
const Weapon = weapons.Weapon;
const arena = @import("arena.zig");

const Player = @This();

pub const radius = 20;
const speed = 300;
const spin_speed = 2;
const two_pi = 2.0 * std.math.pi;

x: f32,
y: f32,
health: i32 = 100,
rotation: f32, // (angle)
weapon: Weapon,

pub fn new(allocator: std.mem.Allocator) !*Player {
    const p = try allocator.create(Player);
    const w = Weapon{ .boomerang = weapons.Boomerang.new(
        &p.x,
        &p.y,
        &p.rotation,
    ) };
    p.* = Player{ .x = 0, .y = 0, .weapon = w, .rotation = 0 };
    return p;
}

pub fn move(p: *Player, delta: f32) void {
    if (rl.isKeyDown(.w)) {
        p.y -= @trunc(speed * delta);
    }
    if (rl.isKeyDown(.s)) {
        p.y += @trunc(speed * delta);
    }
    if (rl.isKeyDown(.a)) {
        p.x -= @trunc(speed * delta);
    }
    if (rl.isKeyDown(.d)) {
        p.x += @trunc(speed * delta);
    }

    p.die_if_hit_firearena();
}

fn die_if_hit_firearena(p: *Player) void {
    const distance = @sqrt(p.x * p.x + p.y * p.y);

    if (distance > arena.arena_radius) {
        p.x = 0;
        p.y = 0;
        p.health = 0;
    }
}

pub fn is_dead(p: Player) bool {
    return p.health <= 0;
}

pub fn take_damage(p: *Player, amount: i32) void {
    p.health -= amount;
}

pub fn update(p: *Player, delta: f32) void {
    p.rotation += spin_speed * delta;
    p.rotation = @mod(p.rotation, two_pi);
    switch (p.weapon) {
        .boomerang => |*b| {
            b.update(delta);
            if (rl.isMouseButtonPressed(.left)) {
                b.shoot();
            }
        },
    }
}

pub fn draw(p: *Player) void {
    rl.drawCircleLines(@intFromFloat(p.x), @intFromFloat(p.y), radius, .black);
    switch (p.weapon) {
        .boomerang => |b| {
            b.draw();
        },
    }
}
