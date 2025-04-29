const chunksz = 512;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const synthh = try synthes.Synthesizer(48000, chunksz);

    var synth = try synthh.init(alloc);
    synth.min_freq = 33;
    synth.max_freq = 110;
    defer synth.deinit();
    try synth.genGroupWithRule(Keycodes.A, advancement, 1, 1, 0.2, 0.01, 0, 5);
    try synth.genGroupWithRule(Keycodes.S, advancement, 2, 1, 0.2, 0.01, 0, 3);
    synth.state.advance();
    synth.initStream();
    while (synth.state.currentEvent.type != c.SDL_QUIT) {
        synth.state.advance();
    }
}
fn advancement(initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void {
    initmul.* += 0.5;
    initamp.* *= 0.8;
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
