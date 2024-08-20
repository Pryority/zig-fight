const c = @cImport({
    @cInclude("raylib.h");
});

pub const Window = struct {
    pub const width = 800;
    pub const height =  450;
    pub fn init() void {
        c.InitWindow(width, height, "Zig Fight ⚡️");
    }
};
