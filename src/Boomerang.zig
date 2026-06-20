// this is a weapon
const rl = @import("raylib");
const rm = @import("raymath");
const std = @import("std");
const builtin = @import("builtin");
const helpers = @import("helpers.zig");
const v2 = helpers.v2;
const toI = helpers.toI;

const Boomerang = @This();

const radius = 15;
const weapon_offset_x = radius;
const weapon_offset_y = radius;
const max_range = 175;
const shoot_speed = 450;

player_x: *f32,
player_y: *f32,
last_player_x: f32,
last_player_y: f32,
player_rotation: *f32,
x: f32,
y: f32,
shooting: bool = false,
returning: bool = false,
target_x: f32 = 0,
target_y: f32 = 0,

pub fn new(player_x: *f32, player_y: *f32, player_rotation: *f32) Boomerang {
    return Boomerang{
        .player_x = player_x,
        .player_y = player_y,
        .player_rotation = player_rotation,
        .last_player_x = player_x.*,
        .last_player_y = player_y.*,
        .x = player_x.*,
        .y = player_y.*,
    };
}

pub fn update(b: *Boomerang, delta: f32) void {
    if (!b.shooting) {
        const offset = rl.Vector2{ .x = weapon_offset_x, .y = weapon_offset_y };
        const rotated_offset = rl.math.vector2Rotate(offset, b.player_rotation.*);
        b.x = b.player_x.* + rotated_offset.x;
        b.y = b.player_y.* + rotated_offset.y;
        return;
    }
    // TODO: use rotation to figure out where to throw
    if (b.returning) {
        const by = (shoot_speed * delta);
        b.go_to(b.player_x.*, b.player_y.*, by);
    } else {
        const by = (shoot_speed * delta);
        b.go_to(b.target_x, b.target_y, by);
    }
    if (b.reached_target()) {
        // std.debug.print("Reached max range. Returning.\n", .{});
        b.returning = true;
    }
    // approximate it being back at player to disable shooting
    if (b.returning and @abs(b.x - b.player_x.*) < 20 and @abs(b.y - b.player_y.*) < 20) {
        b.shooting = false;
        b.returning = false;
    }
    b.last_player_x = b.player_x.*;
    b.last_player_y = b.player_y.*;
}

pub fn draw(b: Boomerang) void {
    rl.drawCircle(@intFromFloat(b.x), @intFromFloat(b.y), radius, .red);
    if (builtin.mode == .Debug) {
        rl.drawCircle(toI(b.target_x), toI(b.target_y), 2, .red);
        const direction = rl.Vector2{
            .x = @cos(b.player_rotation.*),
            .y = @sin(b.player_rotation.*),
        };
        rl.drawLine(
            toI(b.player_x.* + direction.x * max_range),
            toI(b.player_y.* + direction.y * max_range),
            toI(b.player_x.*),
            toI(b.player_y.*),
            .green,
        );
    }
}

pub fn shoot(b: *Boomerang) void {
    if (b.shooting) return;
    b.shooting = true;
    const direction = rl.Vector2{
        .x = @cos(b.player_rotation.*),
        .y = @sin(b.player_rotation.*),
    };
    b.target_x = b.player_x.* + direction.x * max_range;
    b.target_y = b.player_y.* + direction.y * max_range;
}

// does the projectile hit an enemy?
pub fn hits(b: Boomerang, enemyx: f32, enemyy: f32, enemyradius: f32) bool {
    return rl.checkCollisionCircles(v2(b.x, b.y), radius, v2(enemyx, enemyy), enemyradius);
}

fn go_to(b: *Boomerang, destx: f32, desty: f32, by: f32) void {
    const added = v2(b.x - destx, b.y - desty);
    const normalized = rl.math.vector2Normalize(added);
    b.x -= @ceil(by * normalized.x);
    b.y -= @ceil(by * normalized.y);
}

fn reached_target(b: Boomerang) bool {
    return @abs(b.x - b.target_x) < 10 and @abs(b.y - b.target_y) < 10;
}
