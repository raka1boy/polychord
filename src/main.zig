pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const chunksz = 16;
    const synthh = try synthes.Synthesizer(48000, chunksz);
    var synth = try synthh.init(alloc);
    defer synth.deinit();
    var harmonicgroup: synthes.HarmonicGroup(chunksz) = .init(alloc, 4);
    defer harmonicgroup.deinit();
    const harmonic: synthes.Harmonic(chunksz) = .init(1);
    try harmonicgroup.addHarmonic(harmonic);
    // const harmonic2: synthes.Harmonic(chunksz) = .init(1.2);
    // try harmonicgroup.addHarmonic(harmonic2);
    // const harmonic3: synthes.Harmonic(chunksz) = .init(1.4);
    // try harmonicgroup.addHarmonic(harmonic3);
    try synth.groups.append(harmonicgroup);
    synth.state.advance();
    synth.initStream();
    while (true) {
        synth.state.advance();
    }
}

const State = @import("state.zig").InputState;
const synthes = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
