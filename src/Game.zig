const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");

const helpers = @import("helpers.zig");
const v2 = helpers.v2;
const arena = @import("arena.zig");
const Player = @import("Player.zig");
const Animal = @import("Animal.zig");

const Game = @This();

pub const screen_width = 1000;
pub const screen_height = 600;
pub const title = "Wild Circus";
const animal_spawn_rate = 1.5;

player: *Player,
animals_beaten: u32,
animals: std.ArrayList(Animal),
animal_last_spawned: f64 = 0,
allocator: std.mem.Allocator,
io: std.Io,
camera: rl.Camera2D,
mainsound: ?rl.Sound = null,

pub fn new(io: std.Io, allocator: std.mem.Allocator) !Game {
    const player = try Player.new(allocator);
    const cam = rl.Camera2D{
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .zoom = 1,
        .rotation = 0,
        .offset = rl.Vector2{ .x = screen_width / 2, .y = screen_height / 2 },
    };

    return Game{
        .player = player,
        .allocator = allocator,
        .animals_beaten = 0,
        .animals = .empty,
        .camera = cam,
        .io = io,
    };
}

pub fn startup(game: *Game) anyerror!void {
    rl.initAudioDevice();
    if (builtin.mode != .Debug) {
        game.mainsound = try rl.loadSound("./resources/maintheme.mp3");
        rl.playSound(game.mainsound.?);
    }
}

pub fn deinit(game: *Game) void {
    game.allocator.destroy(game.player);
    game.animals.deinit(game.allocator);
}

pub fn update(game: *Game) !void {
    const delta = rl.getFrameTime();
    // player updates
    game.player.move(delta);
    game.player.update(delta);
    if (game.player.is_dead()) {
        std.debug.print("You died!\n", .{});
        // TODO: endscreen
        game.player.health = 100;
        game.player.x = 0;
        game.player.y = 0;
    }
    // if player collides with animal, take 10 damage
    for (game.animals.items) |*a| {
        if (rl.checkCollisionCircles(v2(game.player.x, game.player.y), Player.radius, v2(a.x, a.y), a.radius) and a.can_hit()) {
            game.player.take_damage(10);
            a.reset_hit_cooldown();
        }
    }
    // camera
    game.camera.target = v2(game.player.x, game.player.y);
    // sound
    if (builtin.mode != .Debug) {
        if (!rl.isSoundPlaying(game.mainsound.?)) {
            rl.playSound(game.mainsound.?);
        }
    }
    // hitting stuff with weapon
    var hitqueue = std.ArrayList(usize).empty;
    defer hitqueue.deinit(game.allocator);
    switch (game.player.weapon) {
        .boomerang => |*b| {
            for (game.animals.items, 0..) |a, i| {
                if (b.shooting and b.hits(a.x, a.y, a.radius)) {
                    try hitqueue.append(game.allocator, i);
                    game.animals_beaten += 1;
                }
            }
        },
    }
    game.animals.orderedRemoveMany(hitqueue.items);

    // add animals into arena
    if (game.animal_last_spawned > animal_spawn_rate) {
        const point = gen_rand_point(game.io, arena.arena_radius);
        try game.animals.append(game.allocator, Animal.new(point.x, point.y, .pig));
        game.animal_last_spawned = 0;
    }
    game.animal_last_spawned += delta;

    // update animals +
    // make animals follow player
    std.debug.print("Following player to position: {d},{d}\n", .{ game.player.x, game.player.y });
    for (game.animals.items) |*a| {
        a.update(delta);
        a.follow_player(v2(game.player.x, game.player.y), delta);
    }
}

pub fn draw(game: *Game) !void {
    rl.clearBackground(.white);
    rl.beginMode2D(game.camera);
    defer rl.endMode2D();

    game.player.draw();
    for (game.animals.items) |*a| {
        a.draw();
    }
    arena.draw();
}

fn gen_rand_point(io: std.Io, radius: f32) rl.Vector2 {
    var defrand = std.Random.DefaultPrng.init(@intCast(@abs(std.Io.Timestamp.now(io, .real).toMilliseconds())));
    var rand = defrand.random();

    // Generate a random point in the circle
    // Using the "inverse transform sampling" method
    const r = radius * std.math.sqrt(rand.float(f32));
    const theta = 2.0 * std.math.pi * rand.float(f32);
    const x = r * std.math.cos(theta);
    const y = r * std.math.sin(theta);

    return v2(x, y);
}
