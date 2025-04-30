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
        // Note: We're embedding BMP data directly (converted from PNGs)
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
        freq: f32,
        min_freq: f32,
        max_freq: f32,
        y: c_int,
        size: c_int,
        color: c.SDL_Color,
    ) void {
        _ = c.SDL_SetTextureColorMod(self.dot_texture, color.r, color.g, color.b);
        _ = c.SDL_SetTextureAlphaMod(self.dot_texture, color.a);

        // Calculate screen position using logarithmic scaling

        const screen_width = 1920.0; // Or pass this as a parameter
        const x_pos = frequencyToScreenPosition(
            freq,
            min_freq,
            max_freq,
            screen_width,
        );
        std.debug.print("x = {d}\n", .{x_pos});
        const dest_rect = c.SDL_Rect{
            .x = @intFromFloat(@mod(@max(1, screen_width - x_pos - @as(f64, @floatFromInt(size)) / 2.0), screen_width)), // Center the dot
            .y = y,
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

        const dest_rect = c.SDL_Rect{
            .x = x,
            .y = y,
            .w = width,
            .h = height,
        };
        _ = c.SDL_RenderCopy(self.renderer, texture, null, &dest_rect);
    }
};

pub fn frequencyToScreenPosition(
    freq: f32,
    min_freq: f32,
    max_freq: f32,
    screen_width: f32,
) f32 {
    std.debug.assert(min_freq > 0.0);
    std.debug.assert(max_freq > min_freq);
    std.debug.assert(freq >= min_freq and freq <= max_freq);

    const log_min = std.math.log10(min_freq);
    const log_max = std.math.log10(max_freq);
    const log_freq = std.math.log10(freq);

    // Normalize to [0, 1] range on logarithmic scale
    const normalized = (log_freq - log_min) / (log_max - log_min);

    // Map to screen coordinates (from right to left, based on your formula)
    return screen_width * (1.0 - normalized);
}
