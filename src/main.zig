const rl = @import("raylib");
const std = @import("std");
const Game = @import("Game.zig");

pub fn main(init: std.process.Init) anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var game = try Game.new(init.io, init.gpa);
    defer game.deinit();

    rl.initWindow(Game.screen_width, Game.screen_height, Game.title);
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // run game startup code once
    try game.startup();
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        game.update() catch |err| {
            std.log.err("an error occured in update loop: {s}", .{@errorName(err)});
            return err;
        };
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        game.draw() catch |err| {
            std.log.err("an error occured while drawing: {s}", .{@errorName(err)});
            return err;
        };
        //----------------------------------------------------------------------------------
    }
}
