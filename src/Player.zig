const std = @import("std");
const rl = @import("raylib");
const weapons = @import("weapon.zig");
const Weapon = weapons.Weapon;
const arena = @import("arena.zig");
const helpers = @import("helpers.zig");
const toI = helpers.toI;
const v2 = helpers.v2;

const Player = @This();

pub const radius = 20;
const speed = 300;
const spin_speed = 100;
const circlemaster_sprite_path = "./resources/circlemaster.png";
const texture_scale = 0.05;

x: f32,
y: f32,
health: i32 = 100,
rotation: f32, // (angle)
weapon: Weapon,
sprite: ?rl.Texture = null,

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

// init after raylib has init
pub fn init(p: *Player) !void {
    if (p.sprite == null) {
        p.sprite = try rl.loadTexture(circlemaster_sprite_path);
    }
    switch (p.weapon) {
        .boomerang => |*b| {
            try b.init();
        },
    }
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
    // std.debug.print("p.health: {d}\n", .{p.health});
    p.rotation += spin_speed * delta;
    p.rotation = @mod(p.rotation, 360);
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
    const height: f32 = @as(f32, @floatFromInt(p.sprite.?.height)) * texture_scale;
    const width: f32 = @as(f32, @floatFromInt(p.sprite.?.width)) * texture_scale;
    const source = rl.Rectangle.init(0, 0, @floatFromInt(p.sprite.?.width), @floatFromInt(p.sprite.?.height));
    const dest = rl.Rectangle.init(p.x, p.y, width, height);
    rl.drawTexturePro(p.sprite.?, source, dest, .init(width / 2, height / 2), p.rotation, .white);
    // rl.drawCircleLines(@intFromFloat(p.x), @intFromFloat(p.y), radius, .black);
    switch (p.weapon) {
        .boomerang => |b| {
            b.draw();
        },
    }
}
