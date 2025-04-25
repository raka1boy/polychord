pub const InputState = struct {
    mouse_pos: @Vector(2, c_int) = .{ 0, 0 }, //x,y
    keys_pressed: [*]const u8,
    window: *c.SDL_Window = undefined,
    screen_x: c_int = 1920,
    screen_y: c_int = 1080,
    pub fn init() InputState {
        _ = c.SDL_Init(c.SDL_INIT_EVENTS | c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO);

        return .{ .keys_pressed = c.SDL_GetKeyboardState(null), .window = c.SDL_CreateWindow("govno 2", 100, 100, 1920, 1080, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE).? };
    }
    pub fn deinit(self: *InputState) void {
        _ = self;
        c.SDL_Quit();
    }
    pub fn advance(self: *InputState) void {
        _ = c.SDL_GetMouseState(&self.mouse_pos[0], &self.mouse_pos[1]);
        c.SDL_GetWindowSize(self.window, &self.screen_x, &self.screen_y);
        c.SDL_PumpEvents();
    }
};

//const sdl = @import("SDL2");
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("portaudio.h");
});
