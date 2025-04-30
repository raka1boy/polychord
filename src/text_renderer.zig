// text_renderer.zig
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const BitmapFont = struct {
    const CharWidth = 5;
    const CharHeight = 7;
    const Spacing = 1;

    // Bitmaps for C, C#, D, D#, E, F, F#, G, G#, A, A#, B
    const NoteBitmaps = [12][CharHeight]u5{
        // C
        .{ 0b01110, 0b10001, 0b10000, 0b10000, 0b10001, 0b01110, 0b00000 },
        // C#
        .{ 0b01110, 0b10001, 0b10101, 0b10001, 0b10101, 0b01110, 0b00100 },
        // D
        .{ 0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110, 0b00000 },
        // D#
        .{ 0b11110, 0b10001, 0b10101, 0b10001, 0b10101, 0b11110, 0b00100 },
        // E
        .{ 0b11111, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111, 0b00000 },
        // F
        .{ 0b11111, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000, 0b00000 },
        // F#
        .{ 0b11111, 0b10000, 0b11110, 0b10100, 0b10000, 0b11111, 0b00100 },
        // G
        .{ 0b01110, 0b10001, 0b10000, 0b10011, 0b10001, 0b01110, 0b00000 },
        // G#
        .{ 0b01110, 0b10001, 0b10000, 0b10011, 0b10101, 0b01110, 0b00100 },
        // A
        .{ 0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b00000 },
        // A#
        .{ 0b01110, 0b10001, 0b10101, 0b11111, 0b10101, 0b10001, 0b00100 },
        // B
        .{ 0b11110, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110, 0b00000 },
    };

    pub fn renderNote(
        self: *const BitmapFont,
        renderer: *c.SDL_Renderer,
        note: u4, // 0-11 (C to B)
        x: c_int,
        y: c_int,
        color: c.SDL_Color,
    ) void {
        _ = self; // Unused
        const bitmap = NoteBitmaps[note];
        _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);

        for (0..CharHeight) |row| {
            const row_bits = bitmap[row];
            for (0..CharWidth) |col| {
                if (row_bits & (@as(u5, 1) << @intCast(CharWidth - 1 - col)) != 0) {
                    _ = c.SDL_RenderDrawPoint(renderer, x + @as(c_int, @intCast(col)), y + @as(c_int, @intCast(row)));
                }
            }
        }
    }
};
