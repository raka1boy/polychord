pub fn closestETFreq(notes_in_octave: f64, hertz: f64) f64 {
    if (hertz <= 0.0) return 0.0;
    const reference_freq = 440.0; // A4
    const steps = notes_in_octave * math.log2(hertz / reference_freq);
    const rounded_steps = @round(steps);
    return reference_freq * math.pow(f64, 2.0, rounded_steps / notes_in_octave);
}

pub fn logScale(cursor_x: f32, screen_width: f32, min_freq: f32, max_freq: f32) f32 {
    const clamped_x = @min(@max(cursor_x, 0), screen_width);
    const normalized = clamped_x / screen_width;
    const log_min = @log(min_freq);
    const log_max = @log(max_freq);
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

pub fn midiNoteToString(note: i32) [*:0]const u8 {
    const names = [_][]const u8{ "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
    return names[@intCast(@mod(note, 12))];
}
const math = std.math;
const std = @import("std");
