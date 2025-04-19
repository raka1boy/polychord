const Harmonic = struct {
    amp: f16,
    freq: u16,
    phase: f16,
};
const Synthesizer = struct {
    harmonics: std.ArrayList(Harmonic),
    sample_rate: u32,
    global_smoothing: f16,
    global_amp: f16,

    pub fn init(
        alloc: std.mem.Allocator,
        sample_rate: u32,
        global_smoothing: f16,
        global_amp: f16,
    ) !Synthesizer {
        return .{
            .harmonics = try .init(alloc),
            .sample_rate = sample_rate,
            .global_smoothing = global_smoothing,
            .global_amp = global_amp,
        };
    }
    pub fn deinit(self: *Synthesizer) void {
        self.harmonics.deinit();
    }
    pub fn initDefault(alloc: std.mem.Allocator) !Synthesizer {
        return try init(alloc, 48000, 0, 1);
    }
};
const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
