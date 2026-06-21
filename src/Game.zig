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

// Player
player: *Player,
// Animals
animals_beaten: u32,
animals: std.ArrayList(Animal),
animal_last_spawned: f64 = 0,
// IO + more
allocator: std.mem.Allocator,
io: std.Io,
// game running stuff
camera: rl.Camera2D,
mainsound: ?rl.Sound = null,
// scene management
scene: Scene = .startmenu,

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
    // if (builtin.mode != .Debug) {
    game.mainsound = try rl.loadSound("./resources/maintheme.mp3");
    rl.setSoundVolume(game.mainsound.?, 0.5);
    rl.playSound(game.mainsound.?);
    // }

    // init textures
    // init player
    try game.player.init();
    // init arena textures
    arena.ground = try rl.loadTexture("./resources/ground.png");
    arena.circle = try rl.loadTexture("./resources/circle.png");
}

pub fn deinit(game: *Game) void {
    game.allocator.destroy(game.player);
    game.animals.deinit(game.allocator);
    Animal.deinitAnimalSprites(game.allocator);
}

pub fn update(game: *Game) !void {
    const delta = rl.getFrameTime();
    switch (game.scene) {
        .playing => try game.update_playing(delta),
        .startmenu => try game.update_startmenu(delta),
        .deathmenu => try game.update_deathmenu(delta),
    }
}

fn update_playing(game: *Game, delta: f32) !void {
    // player updates
    game.player.move(delta);
    game.player.update(delta);
    if (game.player.is_dead()) {
        std.debug.print("You died!\n", .{});
        game.switch_scene(.deathmenu);
        return;
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
    // if (builtin.mode != .Debug) {
    if (game.mainsound) |mainsound| {
        if (!rl.isSoundPlaying(mainsound)) {
            rl.playSound(mainsound);
        }
    }
    // }
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
        var animal = Animal.new(point.x, point.y, .pig);
        try animal.init(game.allocator);
        try game.animals.append(game.allocator, animal);
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

fn update_startmenu(game: *Game, delta: f32) !void {
    _ = game;
    _ = delta;
    // TODO: implement (if needed, if its not handled by UI)
}

fn update_deathmenu(game: *Game, delta: f32) !void {
    _ = game;
    _ = delta;
    // TODO: implement (if needed, if its not handled by UI)
}

pub fn draw(game: *Game) !void {
    rl.clearBackground(.white);
    switch (game.scene) {
        .startmenu => try game.draw_startmenu(),
        .playing => try game.draw_playing(),
        .deathmenu => try game.draw_deathmenu(),
    }
}

fn draw_playing(game: *Game) !void {
    rl.beginMode2D(game.camera);
    defer rl.endMode2D();

    arena.draw();
    game.player.draw();
    for (game.animals.items) |*a| {
        a.draw();
    }
}

fn draw_startmenu(game: *Game) !void {
    const titlefontsize = 32;
    const textstart = screen_width / 2 - @divTrunc(rl.measureText(title, titlefontsize), 2);
    rl.drawText(title, textstart, 200, titlefontsize, .green);

    const buttonrect = rl.Rectangle.init(screen_width / 2 - 75, 250, 150, 40);
    if (rg.button(buttonrect, "Start Game")) {
        game.switch_scene(.playing);
    }
}

fn draw_deathmenu(game: *Game) !void {
    const textfontsize = 32;
    const text = "The animals got you!";
    const textstart = screen_width / 2 - @divTrunc(rl.measureText(text, textfontsize), 2);
    rl.drawText(text, textstart, 200, textfontsize, .green);

    const buttonrect = rl.Rectangle.init(screen_width / 2 - 75, 250, 150, 40);
    if (rg.button(buttonrect, "Play again")) {
        game.switch_scene(.playing);
    }
}

const Scene = enum { startmenu, playing, deathmenu };
// only switches, if it actually can. You cant switch from startmenu to deathmenu for example
// also dose some resetting if needed
fn switch_scene(game: *Game, scene: Scene) void {
    switch (scene) {
        .startmenu => {
            if (game.scene == .deathmenu) {
                game.scene = .startmenu;
            }
        },
        .playing => {
            game.reset();
            if (game.scene == .startmenu or game.scene == .deathmenu) {
                game.scene = .playing;
            }
        },
        .deathmenu => {
            if (game.scene == .playing) {
                game.scene = .deathmenu;
            }
        },
    }
}

fn reset(game: *Game) void {
    game.player.health = 100;
    game.player.x = 0;
    game.player.y = 0;
    game.animals_beaten = 0;
    game.animal_last_spawned = 0;
    game.animals.clearRetainingCapacity();
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
