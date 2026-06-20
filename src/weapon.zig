pub const Boomerang = @import("Boomerang.zig");

pub const Weapon = union(enum) { boomerang: Boomerang };
