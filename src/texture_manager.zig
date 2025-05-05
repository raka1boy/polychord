// texture_manager.zig
const std = @import("std");
const freqstuff = @import("freq_stuff.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const TextureManager = struct {
    textures: [12]*c.SDL_Texture, // C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    renderer: *c.SDL_Renderer,
    dot_texture: *c.SDL_Texture,

    pub fn init(renderer: *c.SDL_Renderer) !TextureManager {
        const note_bmps = [_][]const u8{
            @embedFile("assets/C.bmp"),
            @embedFile("assets/C#.bmp"),
            @embedFile("assets/D.bmp"),
            @embedFile("assets/D#.bmp"),
            @embedFile("assets/E.bmp"),
            @embedFile("assets/F.bmp"),
            @embedFile("assets/F#.bmp"),
            @embedFile("assets/G.bmp"),
            @embedFile("assets/G#.bmp"),
            @embedFile("assets/A.bmp"),
            @embedFile("assets/A#.bmp"),
            @embedFile("assets/B.bmp"),
        };

        const dot_size = 8;
        const dot_surface = c.SDL_CreateRGBSurface(0, dot_size, dot_size, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000) orelse return error.SurfaceCreationFailed;
        defer c.SDL_FreeSurface(dot_surface);

        // Fill with white
        _ = c.SDL_FillRect(dot_surface, null, c.SDL_MapRGBA(dot_surface.*.format, 255, 255, 255, 255));

        const dot_texture = c.SDL_CreateTextureFromSurface(renderer, dot_surface) orelse
            return error.TextureCreationFailed;

        var textures: [12]*c.SDL_Texture = undefined;

        for (note_bmps, 0..) |bmp_data, i| {
            const rw = c.SDL_RWFromConstMem(bmp_data.ptr, @intCast(bmp_data.len)) orelse
                return error.TextureLoadFailed;
            errdefer _ = c.SDL_RWclose(rw);

            const surface = c.SDL_LoadBMP_RW(rw, 1) orelse
                return error.TextureLoadFailed;
            errdefer c.SDL_FreeSurface(surface);

            // Convert to texture
            textures[i] = c.SDL_CreateTextureFromSurface(renderer, surface) orelse
                return error.TextureLoadFailed;
        }

        return TextureManager{
            .textures = textures,
            .dot_texture = dot_texture,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *TextureManager) void {
        for (self.textures) |tex| {
            c.SDL_DestroyTexture(tex);
        }
    }

    pub fn renderDot(
        self: *TextureManager,
        max_screen_x: u32,
        freq: u15,
        min_freq: u15,
        max_freq: u15,
        amp: f32,
        size: comptime_int,
        color: c.SDL_Color,
    ) void {
        _ = c.SDL_SetTextureColorMod(self.dot_texture, color.r, color.g, color.b);
        _ = c.SDL_SetTextureAlphaMod(self.dot_texture, color.a);
        const x_pos = frequencyToScreenPosition(
            @floatFromInt(freq),
            @floatFromInt(min_freq),
            @floatFromInt(max_freq),
            max_screen_x,
        );
        const dest_rect = c.SDL_Rect{
            .x = @intCast(@mod(max_screen_x - x_pos -| size / 2, max_screen_x)), // Center the dot
            .y = @intFromFloat(amp),
            .w = size,
            .h = size,
        };
        _ = c.SDL_RenderCopy(self.renderer, self.dot_texture, null, &dest_rect);
    }
    pub fn renderNote(
        self: *TextureManager,
        note: u4, // 0-11 (C to B)
        x: c_int,
        y: c_int,
        width: c_int,
        height: c_int,
    ) void {
        const texture = self.textures[note];

        var dest_rect = c.SDL_Rect{
            .x = x,
            .y = y,
            .w = width,
            .h = height,
        };
        for (0..6) |i| {
            _ = c.SDL_RenderCopy(self.renderer, texture, null, &dest_rect);
            dest_rect.y += @intCast(i + 200);
        }
    }
};

pub fn frequencyToScreenPosition(
    freq: f32,
    min_freq: f32,
    max_freq: f32,
    screen_width: u32,
) u32 {
    const log_min = std.math.log10(min_freq);
    const log_max = std.math.log10(max_freq);
    const log_freq = std.math.log10(freq);
    const normalized = (log_freq - log_min) / (log_max - log_min);
    const res: u32 = @intFromFloat(@mod(@as(f32, @floatFromInt(screen_width)) * (1 - normalized), @as(f32, @floatFromInt(screen_width))));
    return res;
}
