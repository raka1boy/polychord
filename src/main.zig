const chunksz = 512;
const bass_keycodes: [12]Keycodes = .{
    Keycodes.KP_7,
    Keycodes.KP_8,
    Keycodes.KP_9,
    Keycodes.KP_4,
    Keycodes.KP_5,
    Keycodes.KP_6,
    Keycodes.KP_1,
    Keycodes.KP_2,
    Keycodes.KP_3,
    Keycodes.KP_0,
    Keycodes.KP_PERIOD,
    Keycodes.KP_ENTER,
};
const keycodes: [48]Keycodes = .{
    Keycodes.Num1,
    Keycodes.Q,
    Keycodes.A,
    Keycodes.Z,
    Keycodes.Num2,
    Keycodes.W,
    Keycodes.S,
    Keycodes.X,
    Keycodes.Num3,
    Keycodes.E,
    Keycodes.D,
    Keycodes.C,
    Keycodes.Num4,
    Keycodes.R,
    Keycodes.F,
    Keycodes.V,
    Keycodes.Num5,
    Keycodes.T,
    Keycodes.G,
    Keycodes.B,
    Keycodes.Num6,
    Keycodes.Y,
    Keycodes.H,
    Keycodes.N,
    Keycodes.Num7,
    Keycodes.U,
    Keycodes.J,
    Keycodes.M,
    Keycodes.Num8,
    Keycodes.I,
    Keycodes.K,
    Keycodes.COMMA,
    Keycodes.Num9,
    Keycodes.O,
    Keycodes.L,
    Keycodes.PERIOD,
    Keycodes.Num0,
    Keycodes.P,
    Keycodes.SEMICOLON,
    Keycodes.SLASH,
    Keycodes.MINUS,
    Keycodes.LEFTBRACKET,
    Keycodes.APOSTROPHE,
    Keycodes.RSHIFT,
    Keycodes.EQUALS,
    Keycodes.RIGHTBRACKET,
    Keycodes.RETURN,
    Keycodes.BACKSLASH,
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    synth.min_freq = 65;
    synth.max_freq = 1047;
    defer synth.deinit();
    try synth.genGroupWithRule(Keycodes.A, advancement, 1, 1, 0.2, 0.01, 12, 6);
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.state.advance();
    }
}
fn advancement(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    initmul.* += 1;
    initamp.* *= 0.2;
    initonset.* += 0;
    initoffset.* += 0;
}
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
