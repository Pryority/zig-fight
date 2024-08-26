const c = @cImport({
    @cInclude("raylib.h");
});
pub const Direction = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    NEUTRAL
};
pub const Hitbox = c.Rectangle;
