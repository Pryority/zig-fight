// game.zig
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Window = @import("window.zig").Window;
const Camera = @import("camera.zig").Camera;
const Player = @import("player.zig").Player;
const Direction = @import("common.zig").Direction;
const Hitbox = @import("common.zig").Hitbox;

const PLAYER_HOR_SPD = 200.0;
const GRAVITY = 3000.0;
const ENVIRONMENT_ITEMS = [_]EnvItem{
    // .{ .rect = .{ .x = 0, .y = 0, .width = 1000, .height = 400 }, .blocking = false, .color = c.LIGHTGRAY },
    .{ .rect = .{ .x = 0, .y = 400, .width = 1000, .height = 200 }, .blocking = true, .color = c.GRAY },
    .{ .rect = .{ .x = 300, .y = 200, .width = 400, .height = 10 }, .blocking = true, .color = c.GRAY },
    .{ .rect = .{ .x = 250, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = c.GRAY },
    .{ .rect = .{ .x = 650, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = c.GRAY },
};
const CAMERA_DESCRIPTIONS = &[_][]const u8{
    "Follow player center",
    "Follow player center, but clamp to map edges",
    "Follow player center; smoothed",
    "Follow player center horizontally; update player center vertically after landing",
    "Player push camera on getting too close to screen edge",
};

pub const EnvItem = struct {
    rect: c.Rectangle,
    blocking: bool,
    color: c.Color,
};

pub const GameState = struct {
    allocator: std.mem.Allocator,
    player: Player,
    time: f32,
    camera: *Camera,
    cameraDescriptions: []const []const u8,
    envItems: []const EnvItem,

    pub fn init() *GameState {
        var allocator = std.heap.c_allocator;
        const player = Player.init();
        std.debug.print("Player: {}\n", .{player});

        // Check the alignment of the Player struct
        std.debug.print("Player alignment: {}\n", .{@alignOf(Player)});
        std.debug.print("allocator: {}\n", .{@TypeOf(allocator)});

        var camera = Camera.init(player, @as(i32, c.GetScreenWidth()), @as(i32, c.GetScreenHeight()));
        const game_state = allocator.create(GameState) catch {
            std.debug.print("Failed to allocate GameState\n", .{});
            @panic("Out of memory.");
        };
        std.debug.print("GameState alignment: {}\n", .{@alignOf(GameState)});
        game_state.* = GameState{
            .allocator = allocator,
            .player = player,
            .time = 0,
            .camera = &camera,
            .cameraDescriptions = CAMERA_DESCRIPTIONS,
            .envItems = &ENVIRONMENT_ITEMS,
        };
        return game_state;
    }
};

export fn gameReload(game_state_ptr: *anyopaque) void {
    // TODO: implement
    _ = game_state_ptr;
}

export fn gameTick(state_ptr: *anyopaque) void {
    var state = @as(*GameState, @ptrCast(@alignCast(state_ptr)));
    const delta = c.GetFrameTime();

    state.time += delta;
    updatePlayer(&state.player, delta, &state.envItems);
}

export fn gameDraw(state_ptr: *anyopaque) void {
    const state = @as(*GameState, @ptrCast(@alignCast(state_ptr)));
    const envItems = state.envItems;

    state.camera.updateCenter();

    for (envItems) |envItem| {
        c.DrawRectangleRec(envItem.rect, envItem.color);
    }
    c.ClearBackground(c.RAYWHITE);

    // Draw Player
    c.DrawRectangleRec(state.player.rect, c.RED);

    var time_text: [32]u8 = undefined;
    const time_slice = std.fmt.bufPrintZ(&time_text, "Time: {d:.2}", .{state.time}) catch "Error";
    c.DrawText(time_slice.ptr, 10, 10, 20, c.BLACK);
}

fn updatePlayer(player: *Player, delta: f32, envItems: *[]const EnvItem) void {
    // Horizontal movement
    if (c.IsKeyDown(c.KEY_A)) {
        player.movingDirection = Direction.LEFT;
        player.position.x -= PLAYER_HOR_SPD * delta;
    } else if (c.IsKeyDown(c.KEY_D)) {
        player.movingDirection = Direction.RIGHT;
        player.position.x += PLAYER_HOR_SPD * delta;
    } else {
        player.movingDirection = Direction.NEUTRAL;
    }

    // Jump
    player.handleJump();

    // Crouch
    player.handleCrouch();

    // Attack
    player.handleAttack();

    // Apply gravity
    player.position.y += player.speed * delta;
    player.speed += GRAVITY * delta;

    var onGround = false;

    // Collision detection
    for (envItems.*) |envItem| {
        if (envItem.blocking and c.CheckCollisionRecs(player.rect, envItem.rect)) {
            const playerBottom = player.position.y + player.rect.height;
            const envItemTop = envItem.rect.y;

            if (playerBottom > envItemTop and player.position.y < envItemTop) {
                // Player is landing on the top of the environment item
                player.position.y = envItemTop - player.rect.height;
                player.speed = 0;
                onGround = true;
                player.canJump = true;
                player.canCrouch = true;
            }
        }
    }

    // If not on the ground, player can't jump or crouch
    if (!onGround) {
        player.canJump = false;
        // player.canCrouch = false;
    }

    const newPos = c.Vector2{ .x = player.position.x, .y = player.position.y };

    player.move(newPos);
}
