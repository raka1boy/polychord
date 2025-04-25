const chunksz = 256;
const keycodes: [12]Keycodes = .{
    Keycodes.Num1,
    Keycodes.Num2,
    Keycodes.Num3,
    Keycodes.Num4,
    Keycodes.Num5,
    Keycodes.Num6,
    Keycodes.Num7,
    Keycodes.Num8,
    Keycodes.Num9,
    Keycodes.Num0,
    Keycodes.MINUS,
    Keycodes.EQUALS,
};
fn appendNthHarmonics(hgroup: *synthes.HarmonicGroup(chunksz), how_much: usize, initial: f64, step: f64) !void {
    var accum = initial;
    for (0..how_much) |_| {
        accum = accum * step;
        const harmonic: synthes.Harmonic(chunksz) = .init(@floatCast(accum));
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
    for (keycodes) |keycode| {
        var group: synthes.HarmonicGroup(chunksz) = .init(alloc, @intFromEnum(keycode));
        try appendNthHarmonics(&group, 2, mul, 1.2);
        try synth.groups.append(group);
        mul += 0.08333;
    }
    synth.state.advance();
    synth.initStream();
    while (true) {
        synth.state.advance();
    }
}
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
