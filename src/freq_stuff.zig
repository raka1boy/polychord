pub fn closestETFreq(notes_in_octave: anytype, hertz: anytype) u15 {
    if (hertz <= 0) return 0;
    const rounded_steps = notes_in_octave * math.log2(hertz / 440);
    return 440 * math.pow(@TypeOf(hertz), 2, rounded_steps / notes_in_octave);
}

pub fn logScale(cursor_x: anytype, screen_width: anytype, min_freq: anytype, max_freq: anytype) f64 {
    const clamped_x = @min(@max(cursor_x, 0), screen_width);
    const normalized: f32 = @as(f32, @floatFromInt(clamped_x)) / @as(f32, @floatFromInt(screen_width));
    const log_min: f32 = @log(@as(f32, @floatFromInt(min_freq)));
    const log_max: f32 = @log(@as(f32, @floatFromInt(max_freq)));
    const log_freq = log_min + normalized * (log_max - log_min);
    return @exp(log_freq);
}

pub fn freqToMidi(freq: f64) i32 {
    return @intFromFloat(12.0 * (std.math.log2(freq / 440.0)) + 69);
}

pub fn midiToFreq(note: i32) f64 {
    return 440.0 * std.math.pow(f64, 2.0, @as(f64, @floatFromInt(note - 69)) / 12.0);
}

pub fn freqToScreenX(freq: f64, min_freq: u16, max_freq: u16, screen_width: c_int) c_int {
    const log_min = std.math.log2(@as(f64, @floatFromInt(min_freq)));
    const log_max = std.math.log2(@as(f64, @floatFromInt(max_freq)));
    const log_freq = std.math.log2(freq);
    const normalized = (log_freq - log_min) / (log_max - log_min);
    return @intFromFloat(normalized * @as(f64, @floatFromInt(screen_width)));
}

pub fn midiNoteToString(note: usize) []const u8 {
    const names = [_][]const u8{ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
    return names[@mod(note, names.len)];
}
const math = std.math;
const std = @import("std");
const assert = std.testing.expect;
test "snapping" {
    try assert(110 == @round(closestETFreq(12, 109)));
    try assert(220 == @round(closestETFreq(12.0, 219)));
    try assert(440 == @round(closestETFreq(12, 430)));
}

// test "from midi to note" {
//     try assert(std.mem.eql([]u8, midiNoteToString(0), "C"));
//     try assert(std.mem.eql([]u8, midiNoteToString(3), "D#"));
//     try assert(std.mem.eql([]u8, midiNoteToString(11), "B"));
// }
