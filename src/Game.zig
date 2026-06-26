const std = @import("std");
const builtin = @import("builtin");
const rl = @import("raylib");
const rg = @import("raygui");

const helpers = @import("helpers.zig");
const v2 = helpers.v2;
const toI = helpers.toI;
const arena = @import("arena.zig");
const Player = @import("Player.zig");
const Animal = @import("Animal.zig");
const shop = @import("shop.zig");

const Game = @This();

pub const screen_width = 1000;
pub const screen_height = 600;
pub const title = "Wild Circus";

// load sound files into static mem because they can be big
const maintheme_extension = ".ogg";
const maintheme_path = "./embed_resources/maintheme" ++ maintheme_extension;
const maintheme_data = @embedFile(maintheme_path);
const starttheme_extension = ".ogg";
const starttheme_path = "./embed_resources/starttheme" ++ starttheme_extension;
const starttheme_data = @embedFile(starttheme_path);
const gameovertheme_extension = ".ogg";
const gameovertheme_path = "./embed_resources/gameovertheme" ++ gameovertheme_extension;
const gameovertheme_data = @embedFile(gameovertheme_path);
const shoptheme_extension = ".ogg";
const shoptheme_path = "./embed_resources/shoptheme" ++ shoptheme_extension;
const shoptheme_data = @embedFile(shoptheme_path);
const killsoundeffect_path = "./resources/killsound.ogg";
const cardtexture_path = "./resources/card.png";

// Player
player: *Player,
// Animals
animals_beaten: u32,
animals: std.ArrayList(Animal),
animal_last_spawned: f64 = 0,
animal_spawn_rate: f32 = 2.5,
animal_beaten_for_shop: u32 = 10,
last_animals_beaten_before_shop: u32 = 0,
// IO + more
allocator: std.mem.Allocator,
io: std.Io,
// game running stuff
camera: rl.Camera2D,
game_running_for: f64 = 0,
level: i32 = 1,
current_shop_items: [2]ItemType = [2]ItemType{ ItemType.weapon_range, ItemType.weapon_range },
// scene management
scene: Scene = .startmenu,
mainsound: ?rl.Sound = null,
startsound: ?rl.Sound = null,
gameoversound: ?rl.Sound = null,
shopsound: ?rl.Sound = null,
// other sounds
killsound: ?rl.Sound = null,
// other textures
card_texture: ?rl.Texture = null,

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
    try game.draw_loading_screen();
    try game.initAudio();
    // init textures
    // init player
    try game.player.init(game.io);
    // init arena textures
    arena.ground = try rl.loadTexture("./resources/ground.png");
    arena.circle = try rl.loadTexture("./resources/circle.png");
    game.card_texture = try rl.loadTexture(cardtexture_path);
}

pub fn initAudio(game: *Game) !void {
    if (builtin.os.tag != .emscripten) {
        rl.initAudioDevice();
        var futures: [4]std.Io.Future(@typeInfo(@TypeOf(load_sound)).@"fn".return_type.?) = .{
            game.io.async(load_sound, .{ &game.mainsound, @constCast(maintheme_extension), maintheme_data }),
            game.io.async(load_sound, .{ &game.startsound, @constCast(starttheme_extension), starttheme_data }),
            game.io.async(load_sound, .{ &game.gameoversound, @constCast(gameovertheme_extension), gameovertheme_data }),
            game.io.async(load_sound, .{ &game.shopsound, @constCast(shoptheme_extension), shoptheme_data }),
        };
        for (&futures) |*f| {
            try f.await(game.io);
        }
        var ks_fut = game.io.async(rl.loadSound, .{killsoundeffect_path});
        game.killsound = try ks_fut.await(game.io);
        rl.setSoundVolume(game.startsound.?, 0.5);
        rl.setSoundVolume(game.killsound.?, 0.7);
        rl.playSound(game.startsound.?);
    }
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
        .gameovermenu => try game.update_gameovermenu(delta),
        .shop => try game.update_shop(delta),
    }
}

fn update_playing(game: *Game, delta: f32) !void {
    game.game_running_for += delta;
    game.handle_difficulty();
    try game.handle_shop();
    // player updates
    game.player.move(delta);
    game.player.update(delta);
    if (game.player.is_dead()) {
        game.switch_scene(.gameovermenu);
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
                    if (game.killsound) |ks| {
                        rl.playSound(ks);
                    }
                }
            }
        },
    }
    game.animals.orderedRemoveMany(hitqueue.items);

    // add animals into arena
    if (game.animal_last_spawned > game.animal_spawn_rate) {
        const point = gen_rand_point(game.io, arena.arena_radius);
        // TODO: Random animal
        var animal = Animal.new(point.x, point.y, .pig);
        try animal.init(game.allocator);
        try game.animals.append(game.allocator, animal);
        game.animal_last_spawned = 0;
    }
    game.animal_last_spawned += delta;

    // update animals +
    // make animals follow player
    // std.debug.print("Following player to position: {d},{d}\n", .{ game.player.x, game.player.y });
    for (game.animals.items) |*a| {
        a.update(delta);
        a.follow_player(v2(game.player.x, game.player.y), delta);
    }
}

fn update_startmenu(game: *Game, delta: f32) !void {
    _ = delta;
    if (game.startsound) |startsound| {
        if (!rl.isSoundPlaying(startsound)) {
            rl.playSound(startsound);
        }
    }
}

fn update_gameovermenu(game: *Game, delta: f32) !void {
    _ = game;
    _ = delta;
    // TODO: implement (if needed, if its not handled by UI)
}

fn update_shop(game: *Game, delta: f32) !void {
    _ = delta;
    // sound
    if (game.mainsound) |mainsound| {
        if (rl.isSoundPlaying(mainsound)) {
            rl.stopSound(mainsound);
        }
    }
    if (game.shopsound) |shopsound| {
        if (!rl.isSoundPlaying(shopsound)) {
            rl.playSound(shopsound);
        }
    }
}

pub fn draw(game: *Game) !void {
    rl.clearBackground(.white);
    switch (game.scene) {
        .startmenu => try game.draw_startmenu(),
        .playing => try game.draw_playing(),
        .gameovermenu => try game.draw_gameovermenu(),
        .shop => try game.draw_shop(),
    }
}

fn draw_playing(game: *Game) !void {
    {
        rl.beginMode2D(game.camera);
        defer rl.endMode2D();

        arena.draw();
        game.player.draw();
        for (game.animals.items) |*a| {
            a.draw();
        }
    }
    // draw score
    const score = try std.fmt.allocPrintSentinel(game.allocator, "Score: {d}", .{game.animals_beaten}, 0);
    defer game.allocator.free(score);
    const score_fontsize = 32;
    rl.drawText(score, screen_width / 2 - @divTrunc(rl.measureText(score, score_fontsize), 2), 15, score_fontsize, .white);
    // draw health
    const health = try std.fmt.allocPrintSentinel(game.allocator, "Health: {d}", .{game.player.health}, 0);
    defer game.allocator.free(health);
    const health_fontsize = 32;
    rl.drawText(health, 15, 10, health_fontsize, .white);
    // level round
    const level = try std.fmt.allocPrintSentinel(game.allocator, "Level: {d}", .{game.level}, 0);
    defer game.allocator.free(level);
    const level_fontsize = 32;
    rl.drawText(level, 15, 100, level_fontsize, .white);
    // line until next shop
    const percent: f32 = (@as(f32, (@floatFromInt(game.animals_beaten))) - @as(f32, @floatFromInt(game.last_animals_beaten_before_shop))) / @as(f32, @floatFromInt(game.animal_beaten_for_shop));
    // left rectangle
    rl.drawRectangle(0, 0, toI(screen_width * percent), 10, .green);
    // rigfht rectanlge
    rl.drawRectangle(toI(screen_width * percent), 0, toI(screen_width * (1 - percent)), 10, .black);
}

fn draw_startmenu(game: *Game) !void {
    arena.draw();
    const titlefontsize = 32;
    const textstart = screen_width / 2 - @divTrunc(rl.measureText(title, titlefontsize), 2);
    rl.drawText(title, textstart, 200, titlefontsize, .green);

    const buttonrect = rl.Rectangle.init(screen_width / 2 - 75, 250, 150, 40);
    if (rg.button(buttonrect, "Start Game")) {
        game.switch_scene(.playing);
    }
}

fn draw_gameovermenu(game: *Game) !void {
    try game.draw_playing();
    const textfontsize = 32;
    const text = "The animals got you!";
    const textstart = screen_width / 2 - @divTrunc(rl.measureText(text, textfontsize), 2);
    rl.drawText(text, textstart, 200, textfontsize, .green);

    const buttonrect = rl.Rectangle.init(screen_width / 2 - 75, 250, 150, 40);
    if (rg.button(buttonrect, "Play again")) {
        game.switch_scene(.playing);
    }
}

fn draw_shop(game: *Game) !void {
    // playing game in background
    try game.draw_playing();
    // TODO: alpha black plane infront so its dimmed
    rl.drawRectangle(0, 0, screen_width, screen_height, .init(0, 0, 0, 150));
    // TODO: menu
    if (card(200, 100, game.current_shop_items[0], game.card_texture)) {
        apply_item(game.current_shop_items[0], game);
        game.switch_scene(.playing);
    }
    if (card(600, 100, game.current_shop_items[1], game.card_texture)) {
        apply_item(game.current_shop_items[1], game);
        game.switch_scene(.playing);
    }
    // skip button
    if (shop.skip_button(screen_width / 2 - 50, 400)) {
        game.switch_scene(.playing);
    }
}

fn draw_loading_screen(game: *Game) !void {
    _ = game;
    rl.beginDrawing();
    defer rl.endDrawing();
    rl.clearBackground(.gray);
    if (arena.ground) |g| {
        rl.drawTexture(g, 0, 0, .white);
    }
    if (arena.circle) |c| {
        rl.drawTexture(c, 0, 0, .white);
    }
    const textfontsize = 32;
    const text = "Loading...";
    const textstart = screen_width / 2 - @divTrunc(rl.measureText(text, textfontsize), 2);
    rl.drawText(text, textstart, 200, textfontsize, .green);
    rl.drawText(text, textstart, 200, textfontsize, .green);
}

const Scene = enum { startmenu, playing, gameovermenu, shop };

// only switches, if it actually can. You cant switch from startmenu to gameovermenu for example
// also dose some resetting if needed
fn switch_scene(game: *Game, scene: Scene) void {
    switch (scene) {
        .startmenu => {
            if (game.scene == .gameovermenu) {
                if (game.gameoversound) |gameoversound| {
                    if (rl.isSoundPlaying(gameoversound)) {
                        rl.stopSound(gameoversound);
                    }
                }
                game.scene = .startmenu;
            }
        },
        .playing => {
            if (game.scene == .startmenu or game.scene == .gameovermenu) {
                if (game.gameoversound) |gameoversound| {
                    if (rl.isSoundPlaying(gameoversound)) {
                        rl.stopSound(gameoversound);
                    }
                }
                if (game.startsound) |startsound| {
                    if (rl.isSoundPlaying(startsound)) {
                        rl.stopSound(startsound);
                    }
                }
                game.reset();
                game.scene = .playing;
            } else if (game.scene == .shop) {
                if (game.shopsound) |shopsound| {
                    if (rl.isSoundPlaying(shopsound)) {
                        rl.stopSound(shopsound);
                    }
                }
                if (game.mainsound) |mainsound| {
                    rl.resumeSound(mainsound);
                }
                // dont reset game here
                game.scene = .playing;
            }
        },
        .gameovermenu => {
            if (game.scene == .playing) {
                if (game.mainsound) |mainsound| {
                    if (rl.isSoundPlaying(mainsound)) {
                        rl.stopSound(mainsound);
                    }
                }
                if (game.gameoversound) |gameoversound| {
                    rl.playSound(gameoversound);
                }
                game.scene = .gameovermenu;
            }
        },
        .shop => {
            if (game.scene == .playing) {
                if (game.mainsound) |mainsound| {
                    if (rl.isSoundPlaying(mainsound)) {
                        rl.pauseSound(mainsound);
                    }
                }
                game.scene = .shop;
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
    game.game_running_for = 0;
    game.animal_spawn_rate = 2.5;
    game.animals.clearRetainingCapacity();
    game.animal_beaten_for_shop = 10;
    game.last_animals_beaten_before_shop = 0;
}

fn handle_difficulty(game: *Game) void {
    // define levels by how much the game has been going on for
    const level2 = game.game_running_for > 45;
    const level3 = game.game_running_for > 120;
    const level4 = game.game_running_for > 210;
    const level5 = game.game_running_for > 340;
    if (level5 and game.level == 4) {
        game.level = 5;
        game.player.spin_speed += 100;
        game.animal_spawn_rate -= 0.3;
    } else if (level4 and game.level == 3) {
        game.level = 4;
        game.player.spin_speed += 90;
        game.animal_spawn_rate -= 0.4;
        game.animal_beaten_for_shop = 20;
    } else if (level3 and game.level == 2) {
        game.level = 3;
        game.player.spin_speed += 30;
        game.animal_spawn_rate -= 0.5;
        game.animal_beaten_for_shop = 15;
    } else if (level2 and game.level == 1) {
        game.level = 2;
        game.player.spin_speed += 40;
        game.animal_spawn_rate -= 0.7;
        game.animal_beaten_for_shop = 12;
    }
}

fn handle_shop(game: *Game) !void {
    // switch to shop logic
    if (game.animals_beaten - game.last_animals_beaten_before_shop >= game.animal_beaten_for_shop) {
        game.last_animals_beaten_before_shop = game.animals_beaten;
        // switch to shop
        game.switch_scene(.shop);
        try game.set_shop_items();
        return;
    }
}

fn set_shop_items(game: *Game) !void {
    const seed1: u64 = @intCast(@abs(
        std.Io.Timestamp.now(game.io, .real).toMilliseconds(),
    ));
    var seed2: u64 = seed1 + 1236489;
    const r1 = ItemType.select_random(seed1);
    var r2 = ItemType.select_random(seed2);
    while (r2 == r1) {
        seed2 += 2341352;
        r2 = ItemType.select_random(seed2);
    }
    game.current_shop_items = .{ r1, r2 };
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

// sets sound
fn load_sound(sound: *?rl.Sound, fileformat: [:0]u8, data: []const u8) !void {
    const wave = try rl.loadWaveFromMemory(fileformat, data);
    sound.* = rl.loadSoundFromWave(wave);
}

// items

pub const ItemType = enum {
    weapon_size,
    weapon_range,
    weapon_speed,
    healing,
    nuke,

    pub fn select_random(seed: u64) ItemType {
        var defrand = std.Random.DefaultPrng.init(seed);
        var rand = defrand.random();
        return rand.enumValue(ItemType);
    }

    pub fn name(i: ItemType) []u8 {
        return @constCast(switch (i) {
            .weapon_size => "Weapon Size",
            .weapon_range => "Weapon Range",
            .healing => "Healing",
            .nuke => "Nuke",
            .weapon_speed => "Weapon Speed",
        });
    }
};

pub fn apply_item(t: ItemType, game: *Game) void {
    switch (t) {
        .weapon_size => {
            switch (game.player.weapon) {
                .boomerang => |*b| {
                    b.scale += 0.025;
                },
            }
        },
        .weapon_range => {
            switch (game.player.weapon) {
                .boomerang => |*b| {
                    b.max_range += 50;
                },
            }
        },
        .weapon_speed => {
            switch (game.player.weapon) {
                .boomerang => |*b| {
                    b.shoot_speed += 50;
                },
            }
        },
        .healing => {
            game.player.health += 40;
        },
        .nuke => {
            game.animals_beaten += @intCast(game.animals.items.len);
            game.animals.clearRetainingCapacity();
        },
    }
}

pub fn card(
    x: f32,
    y: f32,
    i: ItemType,
    texture: ?rl.Texture,
) bool {
    const rect: rl.Rectangle = .init(x, y, 200, 250);
    const mouse_pressed = rl.isMouseButtonPressed(.left);
    const mousepos = rl.getMousePosition();
    const namebuf: [200:0]u8 = @splat(0);
    const n = i.name();
    const name = std.fmt.bufPrintSentinel(@constCast(&namebuf), "{s}", .{n}, 0) catch {
        @panic("Names should not be over 200 chars long");
    };
    const textsize = 22;
    const posx: i32 = toI(x + @divTrunc(rect.width, 2)) - @divTrunc(rl.measureText(name, textsize), 2);
    const posy = y + rect.height / 2 - 20;

    if (texture) |t| {
        rl.drawTexture(t, toI(x), toI(y), .white);
        rl.drawRectangle(posx - 10, toI(posy - 10), rl.measureText(name, textsize) + 20, 40, .init(0, 0, 0, 150));
    } else {
        rl.drawRectangle(toI(x), toI(y), toI(rect.width), toI(rect.height), .black);
    }
    rl.drawText(name, posx, toI(posy), textsize, .white);

    return mouse_pressed and rl.checkCollisionPointRec(mousepos, rect);
}
