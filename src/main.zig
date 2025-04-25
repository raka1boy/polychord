const chunksz = 1024;
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
fn appendNthHarmonics(hgroup: *synthes.HarmonicGroup(chunksz), how_much: usize, initial: f64, step: f64, amp_step_mul: f64) !void {
    var accum = initial;
    var amp: f64 = 1;
    for (0..how_much) |_| {
        accum *= step;
        const harmonic: synthes.Harmonic(chunksz) = .init(@floatCast(accum), amp);
        amp *= amp_step_mul;
        _ = try hgroup.*.addHarmonic(harmonic);
    }
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    defer synth.deinit();
    var mul: f64 = 1;
    const adv = 0.020833333333333332;
    for (keycodes) |keycode| {
        var group: synthes.HarmonicGroup(chunksz) = .init(alloc, @intFromEnum(keycode));
        try appendNthHarmonics(&group, 1, mul, 1.4, 0.4);
        try synth.groups.append(group);
        mul += adv;
    }

    mul = 1;
    const adv_bass = 0.08333333333333333;
    for (bass_keycodes) |keycode| {
        var group: synthes.HarmonicGroup(chunksz) = .init(alloc, @intFromEnum(keycode));
        try appendNthHarmonics(&group, 2, mul, 0.6, 0.4);
        try synth.groups.append(group);
        mul += adv_bass;
    }
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.state.advance();
    }
}
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
