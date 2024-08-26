const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Direction = @import("common.zig").Direction;
const Hitbox = @import("common.zig").Hitbox;

pub const Player = struct {
    pub const WIDTH = 20;
    pub const HEIGHT = 60;
    pub const ATTACK_COOLDOWN = 0.25; // 500ms
    pub const JUMP_SPEED = 1000.0;
    pub const ATTACK_DURATION = 0.20;
    pub const INITIAL_HEALTH = 100;
    health: i32,
    position: c.Vector2,
    rect: c.Rectangle,
    speed: f32,
    canJump: bool,
    isCrouching: bool,
    canAttack: bool,
    isAttacking: bool,
    currentAttackTime: f32,
    attackCooldown: f32,
    movingDirection: Direction,
    attackDirection: Direction,
    punchHitbox: Hitbox,
    currentHitbox: ?Hitbox,

    pub fn init() Player {
        const SCREEN_CENTER_X = @as(f32, @floatFromInt(@divExact(c.GetScreenWidth(), 2)));
        const SCREEN_BOTTOM_CENTER_Y = @as(f32, @floatFromInt(@divExact(c.GetScreenHeight(), 2)));
        const rect = c.Rectangle{ .x = SCREEN_CENTER_X, .y = SCREEN_BOTTOM_CENTER_Y, .width = WIDTH, .height = HEIGHT };

        return Player{ .health = INITIAL_HEALTH, .position = c.Vector2{ .x = 40, .y = 40 }, .rect = rect, .speed = 0, .canJump = false, .isCrouching = false, .canAttack = true, .isAttacking = false, .currentAttackTime = 0, .attackCooldown = Player.ATTACK_COOLDOWN, .movingDirection = Direction.NEUTRAL, .attackDirection = Direction.NEUTRAL, .punchHitbox = Hitbox{
            .x = 0,
            .y = 0,
            .width = Player.WIDTH,
            .height = Player.HEIGHT,
        }, .currentHitbox = null };
    }

    pub fn attack(self: *Player) void {
        if (self.isAttacking) {
            const progress = self.currentAttackTime / ATTACK_DURATION;
            const size = 50 * progress;
            self.currentHitbox = switch (self.attackDirection) {
                Direction.LEFT => if (self.isCrouching)
                    // std.debug.print("Crouch Attack LEFT", .{});
                    Hitbox{
                        .x = self.position.x - size,
                        .y = self.position.y + self.rect.height / 2,
                        .width = size,
                        .height = self.rect.height / 2,
                    }
                else
                    Hitbox{
                        .x = self.position.x - size,
                        .y = self.position.y,
                        .width = size,
                        .height = self.rect.height / 2,
                    },
                Direction.RIGHT => if (self.isCrouching)
                    Hitbox{
                        .x = self.position.x + self.rect.width,
                        .y = self.position.y + self.rect.height / 2,
                        .width = size,
                        .height = self.rect.height / 2,
                    }
                else
                    Hitbox{
                        .x = self.position.x + self.rect.width,
                        .y = self.position.y,
                        .width = size,
                        .height = self.rect.height / 2,
                    },
                Direction.UP => if (self.isCrouching)
                    Hitbox{
                        .x = self.position.x,
                        .y = self.position.y - size / 2,
                        .width = self.rect.width,
                        .height = size / 2,
                    }
                else
                    Hitbox{
                        .x = self.position.x,
                        .y = self.position.y - size,
                        .width = self.rect.width,
                        .height = size,
                    },
                Direction.DOWN => if (self.isCrouching)
                    Hitbox{
                        .x = self.position.x,
                        .y = self.position.y + self.rect.height,
                        .width = self.rect.width,
                        .height = size / 2,
                    }
                else
                    Hitbox{
                        .x = self.position.x,
                        .y = self.position.y + self.rect.height,
                        .width = self.rect.width,
                        .height = size,
                    },
                else => Hitbox{
                    .x = self.position.x - 25,
                    .y = self.position.y - 25,
                    .width = self.rect.width + 50,
                    .height = self.rect.height + 50,
                },
            };
        } else {
            self.currentHitbox = null;
        }

        // if (self.attackCooldown <= 0) {
        //     self.canAttack = true;
        // }
        // }
    }

    pub fn handleAttack(self: *Player, delta: f32) void {
        if (c.IsKeyPressed(c.KEY_SPACE) and self.canAttack) {
            self.isAttacking = true;
            self.currentAttackTime = 0;
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

        if (self.isAttacking) {
            self.currentAttackTime += delta;
            if (self.currentAttackTime >= ATTACK_DURATION) {
                self.isAttacking = false;
                self.currentAttackTime = 0;
            }
            self.attack();
        }

        if (self.attackCooldown > 0) {
            self.attackCooldown -= delta;
            if (self.attackCooldown <= 0) {
                self.canAttack = true;
            }
        }
    }

    pub fn move(self: *Player, pos: c.Vector2) void {
        self.rect.x = pos.x;
        self.rect.y = pos.y + 0.0001;
    }

    pub fn draw(self: *const Player) void {
        c.DrawRectangleRec(self.rect, c.RED);

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

    pub fn handleJump(self: *Player) void {
        if (c.IsKeyDown(c.KEY_J) and self.canJump) {
            self.movingDirection = Direction.UP;
            self.speed = -JUMP_SPEED;
            self.canJump = false;
        }
    }

    pub fn handleCrouch(self: *Player) void {
        if (c.IsKeyDown(c.KEY_S)) {
            self.isCrouching = true;
            self.movingDirection = Direction.DOWN;
            if (self.rect.height == HEIGHT and self.isCrouching) { // Assuming 60 is the original height
                self.rect.height = HEIGHT / 2; // Halve the height (or set to the desired crouch height)
                self.position.y += HEIGHT / 2; // Adjust position to keep bottom of player consistent
            }
            // self.isCrouching = true;
        } else if (self.rect.height != HEIGHT) { // If the player is currently crouched and KEY_S is not down
            self.position.y -= HEIGHT / 2; // Adjust position before restoring height
            self.rect.height = HEIGHT; // Restore original height
        } else {
            self.isCrouching = false;
        }
    }
};
