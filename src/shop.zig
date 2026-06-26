const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const helpers = @import("helpers.zig");
const toI = helpers.toI;

pub fn skip_button(x: f32, y: f32) bool {
    return rg.button(
        .init(x, y, 100, 50),
        "Skip",
    );
}
