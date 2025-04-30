// texture_manager.zig
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const TextureManager = struct {
    textures: [12]*c.SDL_Texture, // C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    renderer: *c.SDL_Renderer,

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
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *TextureManager) void {
        for (self.textures) |tex| {
            c.SDL_DestroyTexture(tex);
        }
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
