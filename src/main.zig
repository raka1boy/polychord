const chunksz = std.math.pow(i32, 2, 9);

const keys: [53]Keycodes = .{
    .GRAVE,
    .TAB,
    .CAPSLOCK,
    .LSHIFT,
    .Num1,
    .Q,
    .A,
    .Z,
    .Num2,
    .W,
    .S,
    .X,
    .Num3,
    .E,
    .D,
    .C,
    .Num4,
    .R,
    .F,
    .V,
    .Num5,
    .T,
    .G,
    .B,
    .Num6,
    .Y,
    .H,
    .N,
    .Num7,
    .U,
    .J,
    .M,
    .Num8,
    .I,
    .K,
    .COMMA,
    .Num9,
    .O,
    .L,
    .PERIOD,
    .Num0,
    .P,
    .SEMICOLON,
    .SLASH,
    .MINUS,
    .LEFTBRACKET,
    .APOSTROPHE,
    .RSHIFT,
    .EQUALS,
    .RIGHTBRACKET,
    .RETURN,
    .BACKSLASH,
    .BACKSPACE,
};
pub fn main() !void {
    std.debug.print("chunks : {d}", .{chunksz});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    synth.min_freq = noteC(3);
    synth.max_freq = noteC(5);
    defer synth.deinit();

    const TARGET_FPS = 60;
    const frame_delay = 1000 / TARGET_FPS;
    var frame_start: u32 = c.SDL_GetTicks();

    try synth.genGroupWithRule(
        &keys,
        advancement,
        1,
        1,
        0.1,
        0.05,
        0,
        1.0 / 48.0,
        10,
    );
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.renderGuidelines();
        synth.state.advance();
        //synth.state.is_playing_mode = !synth.state.is_playing_mode;
        const should_pause = !synth.state.is_playing_mode;
        c.SDL_PauseAudioDevice(synth.device, @intFromBool(should_pause));
        const frame_time = c.SDL_GetTicks() - frame_start;
        if (frame_time < frame_delay) {
            c.SDL_Delay(frame_delay - frame_time);
        }
        frame_start = c.SDL_GetTicks();
    }
}
fn noteC(octave: usize) u15 {
    var c_accum: f64 = 32.703;
    for (0..octave) |_| {
        c_accum *= 2;
    }
    return @intFromFloat(c_accum);
}
fn advancement(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    var xoro = std.Random.Xoroshiro128.init(@intCast(std.time.microTimestamp()));
    const rand = xoro.random();
    _ = rand;
    initmul.* *= 1.5;
    initamp.* *= 0.2;
    initonset.* = 0.6;
    initoffset.* = 0.02;
}
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
