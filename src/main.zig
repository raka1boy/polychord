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
    try synth.groups.append(harmonicgroup);

    // var harmonicgroup2: synthes.HarmonicGroup(chunksz) = .init(alloc, 22);
    // defer harmonicgroup2.deinit();
    // const harmonic2: synthes.Harmonic(chunksz) = .init(2);
    // try harmonicgroup2.addHarmonic(harmonic2);
    // try synth.groups.append(harmonicgroup2);

    // var harmonicgroup3: synthes.HarmonicGroup(chunksz) = .init(alloc, 7);
    // defer harmonicgroup3.deinit();
    // const harmonic3: synthes.Harmonic(chunksz) = .init(4);
    // try harmonicgroup3.addHarmonic(harmonic3);
    // try synth.groups.append(harmonicgroup3);
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
