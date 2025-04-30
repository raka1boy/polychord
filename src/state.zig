pub const InputState = struct {
    mouse_pos: @Vector(2, c_int) = .{ 0, 0 },
    keys_pressed: [*]const u8,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,
    currentEvent: c.SDL_Event = undefined,
    screen_x: c_int = 1920,
    screen_y: c_int = 1080,
    is_playing_mode: bool = true,

    pub fn init() InputState {
        _ = c.SDL_Init(c.SDL_INIT_EVERYTHING);

        const window = c.SDL_CreateWindow("Synthesizer", 100, 100, 1920, 1080, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE).?;
        const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED).?;

        return .{
            .keys_pressed = c.SDL_GetKeyboardState(null),
            .window = window,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *InputState) void {
        c.TTF_CloseFont(self.font);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
    pub fn advance(self: *InputState) void {
        _ = c.SDL_GetMouseState(&self.mouse_pos[0], &self.mouse_pos[1]);
        // for (0..512) |i| {
        //     if (self.keys_pressed[i] != 0) {
        //         std.debug.print("key pressed: {d}\n", .{i});
        //     }
        // }
        _ = c.SDL_PollEvent(&self.currentEvent);
        c.SDL_GetWindowSize(self.window, &self.screen_x, &self.screen_y);
        c.SDL_PumpEvents();
    }
};

const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
