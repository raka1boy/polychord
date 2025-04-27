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

const math = std.math;
const std = @import("std");
