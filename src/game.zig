// game.zig
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Window = @import("window.zig").Window;
const Camera = @import("camera.zig").Camera;
const PLAYER_HOR_SPD = 200.0;
const PLAYER_JUMP_SPD = 1000.0;
const GRAVITY = 3000.0;

pub const EnvItem = struct {
    rect: c.Rectangle,
    blocking: bool,
    color: c.Color,
};

const MovingDirection = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    NEUTRAL
};

pub const Player = struct {
    position: c.Vector2,
    rect: c.Rectangle,
    speed: f32,
    canJump: bool,
    canCrouch: bool,
    movingDirection: MovingDirection
};

const UpdateCameraFunction = *const fn (*Camera) void;

pub const CameraUpdateFunction = fn(*c.Camera2D, *Player, []const EnvItem, i32, f32, i32, i32) void;

pub const GameState = struct {
    allocator: std.mem.Allocator,
    player: Player,
    time: f32,
    camera: *Camera,
    updateCamera: UpdateCameraFunction,
    // cameraUpdaters: *const fn (*c.Camera2D, *Player, []const EnvItem, i32, f32, i32, i3) void,
    cameraOption: i32,
    cameraDescriptions: []const []const u8,
    envItems: []const EnvItem
};

export fn gameInit() *anyopaque {
    var allocator = std.heap.c_allocator;
    var player = Player{
        .position = c.Vector2{ .x = 40, .y = 40 },
        .rect = c.Rectangle{ .x = @floatFromInt(@divExact(c.GetScreenWidth(), 2)), .y = @floatFromInt(@divExact(c.GetScreenHeight(), 2)), .width = 20, .height = 60 },
        .speed = 0,
        .canJump = false,
        .canCrouch = false,
        .movingDirection = MovingDirection.NEUTRAL
    };
    var camera2D = c.Camera2D{
        .offset = c.Vector2{ .x = @floatFromInt(@divExact(c.GetScreenWidth(), 2)), .y = @floatFromInt(@divExact(c.GetScreenHeight(), 2))},
        .target = player.position,
        .rotation = 0.0,
        .zoom = 1.0
    };
    var camera = Camera.init(&camera2D, &player, Window.width, Window.height);
    // const cameraUpdaters = &[_]CameraUpdateFunction{
    //     Camera.updateCenter,
        // updateCameraCenterInsideMap,
        // updateCameraCenterSmoothFollow,
        // updateCameraEvenOutOnLanding,
        // updateCameraPlayerBoundsPush
    // };
    const cameraDescriptions = &[_][]const u8{
        "Follow player center",
        "Follow player center, but clamp to map edges",
        "Follow player center; smoothed",
        "Follow player center horizontally; update player center vertically after landing",
        "Player push camera on getting too close to screen edge",
    };
    const envItems = [_]EnvItem{
        // .{ .rect = .{ .x = 0, .y = 0, .width = 1000, .height = 400 }, .blocking = false, .color = c.LIGHTGRAY },
        .{ .rect = .{ .x = 0, .y = 400, .width = 1000, .height = 200 }, .blocking = true, .color = c.GRAY },
        .{ .rect = .{ .x = 300, .y = 200, .width = 400, .height = 10 }, .blocking = true, .color = c.GRAY },
        .{ .rect = .{ .x = 250, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = c.GRAY },
        .{ .rect = .{ .x = 650, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = c.GRAY },
    };
    const game_state = allocator.create(GameState) catch @panic("Out of memory.");
    game_state.* = GameState{
        .allocator = allocator,
        .player = player,
        .time = 0,
        .camera = &camera,
        .updateCamera = Camera.updateCenter,
        // .cameraUpdaters = cameraUpdaters,
        .cameraOption = 0,
        .cameraDescriptions = cameraDescriptions,
        .envItems = &envItems,
    };
    return game_state;
}

export fn gameReload(game_state_ptr: *anyopaque) void {
    // TODO: implement
    _ = game_state_ptr;
}

export fn gameTick(state_ptr: *anyopaque) void {
    var state = @as(*GameState, @ptrCast(@alignCast(state_ptr)));
    const delta = c.GetFrameTime();

    state.time += delta;
    updatePlayer(&state.player, delta, state.envItems);
}

export fn gameDraw(state_ptr: *anyopaque) void {
    const state = @as(*GameState, @ptrCast(@alignCast(state_ptr)));
    const envItems = state.envItems;
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

fn updatePlayer(player: *Player, delta: f32, envItems: []const EnvItem) void {
    // Horizontal movement
    if (c.IsKeyDown(c.KEY_A)) player.position.x -= PLAYER_HOR_SPD * delta;
    if (c.IsKeyDown(c.KEY_D)) player.position.x += PLAYER_HOR_SPD * delta;

    // Jump
    if (c.IsKeyDown(c.KEY_W) and player.canJump) {
        player.speed = -PLAYER_JUMP_SPD;
        player.canJump = false;
    }

    // Crouch
    if (c.IsKeyDown(c.KEY_S) and player.canCrouch) {
        if (player.rect.height == 60) { // Assuming 60 is the original height
            player.rect.height = 30;    // Halve the height (or set to the desired crouch height)
            player.position.y += 30;    // Adjust position to keep bottom of player consistent
        }
    } else if (player.rect.height != 60) { // If the player is currently crouched and KEY_S is not down
        player.position.y -= 30; // Adjust position before restoring height
        player.rect.height = 60; // Restore original height
    }

    // Apply gravity
    player.position.y += player.speed * delta;
    player.speed += GRAVITY * delta;

    var onGround = false;

    // Collision detection
    for (envItems) |envItem| {
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

    // Update player's rectangle position
    player.rect.x = player.position.x;
    player.rect.y = player.position.y + 1;
}
