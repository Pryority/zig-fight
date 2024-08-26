const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Direction = @import("common.zig").Direction;
const Hitbox = @import("common.zig").Hitbox;
// const ATTACK_COOLDOWN = 0.25; // 500ms
// const JUMP_SPEED = 1000.0;

// const PLAYER_WIDTH = 20;
// const PLAYER_HEIGHT = 60;
pub const Player = struct {
    pub const WIDTH = 20;
    pub const HEIGHT = 60;
    pub const ATTACK_COOLDOWN = 0.25; // 500ms
    pub const JUMP_SPEED = 1000.0;
    position: c.Vector2,
    rect: c.Rectangle,
    speed: f32,
    canJump: bool,
    canCrouch: bool,
    canAttack: bool,
    attackCooldown: f32,
    movingDirection: Direction,
    attackDirection: Direction,
    punchHitbox: Hitbox,

    pub fn init() Player {
        const SCREEN_CENTER_X = @as(f32, @floatFromInt(@divExact(c.GetScreenWidth(), 2)));
        const SCREEN_BOTTOM_CENTER_Y = @as(f32, @floatFromInt(@divExact(c.GetScreenHeight(), 2)));
        const playerRect = c.Rectangle{ .x = SCREEN_CENTER_X, .y = SCREEN_BOTTOM_CENTER_Y, .width = WIDTH, .height = HEIGHT };

        return Player{
            .position = c.Vector2{ .x = 40, .y = 40 },
            .rect = playerRect,
            .speed = 0,
            .canJump = false,
            .canCrouch = false,
            .canAttack = true,
            .attackCooldown = Player.ATTACK_COOLDOWN,
            .movingDirection = Direction.NEUTRAL,
            .attackDirection = Direction.NEUTRAL,
            .punchHitbox = Hitbox{
                .x = 0,
                .y = 0,
                .width = Player.WIDTH,
                .height = Player.HEIGHT,
            },
        };
    }

    pub fn attack(self: *Player) void {
        if (self.attackCooldown <= 0 and self.canAttack) {
            self.canAttack = false;
            self.attackCooldown = ATTACK_COOLDOWN;

            switch (self.attackDirection) {
                Direction.LEFT => {
                    self.punchHitbox =
                        Hitbox{
                        .x = self.position.x - 50,
                        .y = self.position.y,
                        .width = 50,
                        .height = self.rect.height,
                    };
                },
                Direction.RIGHT => {
                    self.punchHitbox =
                        Hitbox{
                        .x = self.position.x + self.rect.width,
                        .y = self.position.y,
                        .width = 50,
                        .height = self.rect.height,
                    };
                },
                Direction.UP => {
                    self.punchHitbox =
                        Hitbox{
                        .x = self.position.x,
                        .y = self.position.y - 50,
                        .width = self.rect.width,
                        .height = 50,
                    };
                },
                Direction.DOWN => {
                    self.punchHitbox =
                        Hitbox{
                        .x = self.position.x,
                        .y = self.position.y + self.rect.height,
                        .width = self.rect.width,
                        .height = 50,
                    };
                },
                else => {
                    self.punchHitbox =
                        Hitbox{
                        .x = self.position.x - 25,
                        .y = self.position.y - 25,
                        .width = self.rect.width + 50,
                        .height = self.rect.height + 50,
                    };
                },
            }

            c.DrawRectangleRec(self.punchHitbox, c.YELLOW);

            if (self.attackCooldown <= 0) {
                self.canAttack = true;
            }
        }
    }

    pub fn move(self: *Player, pos: c.Vector2) void {
        self.rect.x = pos.x;
        self.rect.y = pos.y + 0.0001;
    }

    pub fn handleJump(self: *Player) void {
        if (c.IsKeyDown(c.KEY_W) and self.canJump) {
            self.movingDirection = Direction.UP;
            self.speed = -JUMP_SPEED;
            self.canJump = false;
        }
    }

    pub fn handleCrouch(self: *Player) void {
        if (c.IsKeyDown(c.KEY_S) and self.canCrouch) {
            self.movingDirection = Direction.DOWN;
            if (self.rect.height == HEIGHT) { // Assuming 60 is the original height
                self.rect.height = HEIGHT / 2; // Halve the height (or set to the desired crouch height)
                self.position.y += HEIGHT / 2; // Adjust position to keep bottom of player consistent
            }
        } else if (self.rect.height != HEIGHT) { // If the player is currently crouched and KEY_S is not down
            self.position.y -= HEIGHT / 2; // Adjust position before restoring height
            self.rect.height = HEIGHT; // Restore original height
        }
    }

    pub fn handleAttack(self: *Player) void {
        if (c.IsKeyPressed(c.KEY_SPACE) and self.canAttack) {
            self.attackCooldown = ATTACK_COOLDOWN;

            // Determine the attack direction based on the player's movement
            if (c.IsKeyDown(c.KEY_A)) {
                self.attackDirection = Direction.LEFT;
            } else if (c.IsKeyDown(c.KEY_D)) {
                self.attackDirection = Direction.RIGHT;
            } else if (c.IsKeyDown(c.KEY_W)) {
                self.attackDirection = Direction.UP;
            } else if (c.IsKeyDown(c.KEY_S)) {
                self.attackDirection = Direction.DOWN;
            } else {
                self.attackDirection = Direction.NEUTRAL;
            }

            self.attack();
            std.debug.print("Attacking {}\n", .{self.attackDirection});
        }
    }
};
