// main.zig (hot-reloading)
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const GameState = @import("game.zig").GameState;

const screen_w = 400;
const screen_h = 200;

// The main exe doesn't know anything about the GameState structure
// because that information exists inside the DLL, but it doesn't
// need to care. All main cares about is where it exists in memory
// so *anyopaque is just a pointer to a place in memory.
const GameStatePtr = *anyopaque;

// TODO: point these the relevant functions inside the game DLL.
var gameInit: *const fn() GameStatePtr = undefined;
var gameReload: *const fn(GameStatePtr) void = undefined;
var gameTick: *const fn(GameStatePtr) void = undefined;
var gameDraw: *const fn(GameStatePtr) void = undefined;

pub fn main() !void {
    loadGameLib() catch @panic("Failed to load libzigfight.dylib");
    const game_state = gameInit();
    // Align the pointer to the correct alignment for `GameState`
    const aligned_game_state = @as(*GameState,  @alignCast(@ptrCast(game_state)));

    // Access the allocator from the aligned `GameState`
    const allocator = aligned_game_state.allocator;

    c.InitWindow(screen_w, screen_h, "Zig Hot-Reload");
    c.SetTargetFPS(60);
    while (!c.WindowShouldClose()) {
        if (c.IsKeyPressed(c.KEY_R)) {
            unloadGameLib() catch unreachable;
            recompileGameLib(allocator) catch {
                std.debug.print("Failed to recompile libzigfight.dylib\n", .{});
            };
            loadGameLib() catch @panic("Failed to load libzigfight.dylib");
            gameReload(game_state);
        }
        gameTick(game_state);
        c.BeginDrawing();
        gameDraw(game_state);
        c.EndDrawing();
    }
    c.CloseWindow();
}

var game_dyn_lib: ?std.DynLib = null;
fn loadGameLib() !void {
    if (game_dyn_lib != null) return error.AlreadyLoaded;
    var dyn_lib = std.DynLib.open("zig-out/lib/libzigfight.dylib") catch {
        return error.OpenFail;
    };
    game_dyn_lib = dyn_lib;
    gameInit = dyn_lib.lookup(@TypeOf(gameInit), "gameInit") orelse return error.LookupFail;
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
