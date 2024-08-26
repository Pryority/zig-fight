// main.zig (hot-reloading)
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const GameState = @import("game.zig").GameState;
const Player = @import("game.zig").Player;
const Window = @import("window.zig").Window;
const TARGET_FPS = 60;

// The main exe doesn't know anything about the GameState structure
// because that information exists inside the DLL, but it doesn't
// need to care. All main cares about is where it exists in memory
// so *anyopaque is just a pointer to a place in memory.
const GameStatePtr = *GameState;

// TODO: point these the relevant functions inside the game DLL.
// var gameInit: *const fn() GameStatePtr = undefined;
var gameReload: *const fn(GameStatePtr) void = undefined;
var gameTick: *const fn(GameStatePtr) void = undefined;
var gameDraw: *const fn(GameStatePtr) void = undefined;

pub fn main() !void {
    while(true) {
        try runGame();

        if (!shouldRestart()) {
            break;
        }
    }
}

fn runGame() !void {
    loadGameLib() catch @panic("Failed to load libzigfight.dylib");
    defer unloadGameLib() catch unreachable;

    const game_state = GameState.init();
    // Align the pointer to the correct alignment for `GameState`
    // Access the allocator from the aligned `GameState`
    const allocator = game_state.allocator;

    Window.init();
    defer c.CloseWindow();
    c.SetTargetFPS(TARGET_FPS);

    while (!c.WindowShouldClose()) {
        // Unload, Recompile and Reload Game Lib
        if (c.IsKeyPressed(c.KEY_R)) {
            unloadGameLib() catch unreachable;
            recompileGameLib(allocator) catch {
                std.debug.print("Failed to recompile libzigfight.dylib\n", .{});
            };
            loadGameLib() catch @panic("Failed to load libzigfight.dylib");
            gameReload(game_state);
            return;
        }

        // Tick for State Transition
        gameTick(game_state);

        // Draw Graphics
        c.BeginDrawing();
        gameDraw(game_state);
        c.EndDrawing();
    }
}

var game_dyn_lib: ?std.DynLib = null;
fn loadGameLib() !void {
    if (game_dyn_lib != null) return error.AlreadyLoaded;
    var dyn_lib = std.DynLib.open("zig-out/lib/libzigfight.dylib") catch {
        return error.OpenFail;
    };
    game_dyn_lib = dyn_lib;
    gameReload = dyn_lib.lookup(@TypeOf(gameReload), "gameReload") orelse return error.LookupFail;
    gameTick = dyn_lib.lookup(@TypeOf(gameTick), "gameTick") orelse return error.LookupFail;
    gameDraw = dyn_lib.lookup(@TypeOf(gameDraw), "gameDraw") orelse return error.LookupFail;
    std.debug.print("Loaded libzigfight.dylib\n", .{});
}

fn unloadGameLib() !void {
    if (game_dyn_lib) |*dyn_lib| {
        dyn_lib.close();
        game_dyn_lib = null;
    } else {
        return error.AlreadyUnloaded;
    }
}

fn recompileGameLib(allocator: std.mem.Allocator) !void {
    const process_args = [_][]const u8{
        "zig",
        "build",
        "-Dgame_only=true",
        "--search-prefix",
        "zig-out"
    };
    var build_process = std.process.Child.init(&process_args, allocator);
    try build_process.spawn();
    const term = try build_process.wait();
    switch (term) {
        .Exited => |exited| {
            if (exited == 2) return error.RecompileFail;
        },
        else => return
    }
}

fn shouldRestart() bool {
    return c.IsKeyPressed(c.KEY_R);
}
