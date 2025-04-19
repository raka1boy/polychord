pub fn main() !void {}

const synth = @import("synth.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
