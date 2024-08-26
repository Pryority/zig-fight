const c = @cImport({
    @cInclude("raylib.h");
});
const Player = @import("player.zig").Player;
const EnvItem = @import("game.zig").EnvItem;

pub const Camera = struct {
    camera: c.Camera2D,
    player: *Player,
    width: i32,
    height: i32,

    pub fn init(player: *Player, width: i32, height: i32) Camera {
        return Camera{ .camera = c.Camera2D{ .offset = c.Vector2{ .x = @floatFromInt(@divExact(width, 2)), .y = @floatFromInt(@divExact(height, 2)) }, .target = player.position, .rotation = 0.0, .zoom = 1.0 }, .player = player, .width = width, .height = height };
    }

    pub fn updateCenter(self: *Camera) void {
        self.camera.offset = c.Vector2{ .x = @floatFromInt(@divExact(self.width, 2)), .y = @floatFromInt(@divExact(self.height, 2)) };
        self.camera.target = self.player.position;
    }
};
