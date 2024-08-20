// game.zig
const std = @import("std");

pub const GameState = struct {
    allocator: std.mem.Allocator,
};

export fn gameInit() *anyopaque {
    var allocator = std.heap.c_allocator;
    const game_state = allocator.create(GameState) catch @panic("Out of memory.");
    game_state.* = GameState{
        .allocator = allocator,
    };
    return game_state;
}

export fn gameReload(game_state_ptr: *anyopaque) void {
    // TODO: implement
    _ = game_state_ptr;
}

export fn gameTick(game_state_ptr: *anyopaque) void {
    // TODO: implement
    _ = game_state_ptr;
}

export fn gameDraw(game_state_ptr: *anyopaque) void {
    // TODO: implement
    _ = game_state_ptr;
}
