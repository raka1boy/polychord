const chunksz = 512;
const keys: [48]Keycodes = .{
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
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    synth.min_freq = 512;
    synth.max_freq = 1024;
    defer synth.deinit();
    // trigger_keys: []const SdlKeycodes,
    // advancementFunc: fn (initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void,
    // initMul: f32,
    // initAmp: f32,
    // onsetSmoothInit: f32,
    // offsetSmoothInit: f32,
    // snapRule: u8,
    // multiplierAdvanceBetweenKeys: f32,
    //count: usize,
    try synth.genGroupWithRule(&.{Keycodes.A}, advancement, 1, 1, 0.5, 0.1, 0, 1.0 / 12.0, 3);
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.renderGuidelines(); // Draw guidelines
        synth.state.advance();
    }
}

fn advancement(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    initmul.* += 0.1;
    initamp.* *= 0.5;
    initonset.* += 0;
    initoffset.* += 0.3;
}
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
