const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Hitbox = @import("common.zig").Hitbox;
const Direction = @import("common.zig").Direction;

pub const Dummy = struct {
    position: c.Vector2,
    rect: c.Rectangle,
    health: i32,
    movingDirection: Direction,
    canJump: bool,
    speed: f32,

    pub const WIDTH = 20;
    pub const HEIGHT = 60;
    pub const INITIAL_HEALTH = 100;

    pub fn init(x: f32, y: f32) Dummy {
        return Dummy{ .position = c.Vector2{ .x = x, .y = y }, .rect = c.Rectangle{ .x = x, .y = y, .width = WIDTH, .height = HEIGHT }, .health = INITIAL_HEALTH, .movingDirection = Direction.NEUTRAL, .canJump = false, .speed = 0 };
    }

    pub fn move(self: *Dummy, pos: c.Vector2) void {
        self.rect.x = pos.x;
        self.rect.y = pos.y + 0.0001;
    }

    pub fn draw(self: *const Dummy) void {
        c.DrawRectangleRec(self.rect, c.BLUE);

        // Draw health bar
        const healthBarWidth = @as(f32, @floatFromInt(self.health)) / @as(f32, @floatFromInt(INITIAL_HEALTH)) * WIDTH;
        const healthBarRect = c.Rectangle{
            .x = self.position.x,
            .y = self.position.y - 10,
            .width = healthBarWidth,
            .height = 5,
        };
        c.DrawRectangleRec(healthBarRect, c.GREEN);
    }

    pub fn takeDamage(self: *Dummy, amount: i32) void {
        self.health -= amount;
        if (self.health < 0) {
            self.health = 0;
        }
    }

    pub fn isHit(self: *const Dummy, hitbox: Hitbox) bool {
        return c.CheckCollisionRecs(self.rect, hitbox);
    }
};
