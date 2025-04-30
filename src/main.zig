const chunksz = 256;
const keys: [12]Keycodes = .{
    .A,
    .S,
    .D,
    .F,
    .G,
    .H,
    .J,
    .K,
    .L,
    .SEMICOLON,
    .APOSTROPHE,
    .RETURN,
};
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    synth.min_freq = 64;
    synth.max_freq = 256;
    defer synth.deinit();
    try synth.genGroupWithRule(
        &keys,
        advancement,
        0.2,
        1,
        0.2,
        0.01,
        0,
        1.0 / 12.0,
        12,
    );
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.state.advance();
    }
}
fn advancementBass(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    initmul.* += 0.8;
    initamp.* *= 0.4;
    initonset.* += 0;
    initoffset.* += 0;
}
fn advancement(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    initmul.* += 1;
    initamp.* *= 0.5;
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
