const SCREEN_X = 1920;
const SCREEN_Y = 1080;
pub fn Harmonic(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        multiplier: f32,
        amp: f32 = 1,
        phase: f64 = 0,
        smoothing: f32 = 0.0,
        pub fn init(mul: f32) This {
            return .{ .multiplier = mul };
        }

        pub fn generateSineWave(self: *This, buffer: *[chunk_size]u16, initial_frequency: u16, sample_rate: usize) void {
            const actual_freq = @as(f64, @floatFromInt(initial_frequency)) * self.multiplier;
            const angular_freq = 2 * std.math.pi * actual_freq;
            const sample_rate_f64 = @as(f64, @floatFromInt(sample_rate));
            const phase_increment = angular_freq * @as(f64, @floatFromInt(chunk_size)) / sample_rate_f64;
            if (self.phase > 1e8) { // Wrap well before f64 limits (~1e308)
                self.phase = @mod(self.phase, 2 * std.math.pi);
            }

            // Generate samples
            for (0..chunk_size) |i| {
                const t = @as(f64, @floatFromInt(i)) / sample_rate_f64;
                const phase_offset = angular_freq * t + self.phase;
                const sine_value = self.amp * std.math.sin(phase_offset);

                buffer[i] = @intFromFloat(@round((sine_value + 1.0) * 32767.5));
            }
            self.phase += phase_increment;
        }
    };
}
pub fn HarmonicGroup(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        harmonics: std.ArrayList(Harmonic(chunk_size)),
        key: u8,
        pub fn init(alloc: std.mem.Allocator, key: u8) This {
            return .{ .harmonics = std.ArrayList(Harmonic(chunk_size)).init(alloc), .key = key };
        }
        pub fn addHarmonic(self: *This, h: Harmonic(chunk_size)) !void {
            try self.harmonics.append(h);
        }
        pub fn deleteHarmonicAt(self: *This, i: usize) void {
            self.harmonics.orderedRemove(i);
        }
        pub fn deinit(self: *This) void {
            self.harmonics.deinit();
        }
    };
}
pub fn Synthesizer(sample_rate: comptime_int, chunk_size: comptime_int) !type {
    if (sample_rate < chunk_size) @compileError("Chunk size can't be bigger than sample rate");
    return struct {
        const This = @This();
        allocator: std.mem.Allocator,
        state: StateManager,
        groups: std.ArrayList(HarmonicGroup(chunk_size)),
        global_smoothing: f16 = 0,
        device: c.SDL_AudioDeviceID = undefined,
        global_amp: f16 = 1,
        min_freq: u16 = 128,
        max_freq: u16 = 8000,

        pub fn init(alloc: std.mem.Allocator) !This {
            return .{
                .groups = try .initCapacity(alloc, 1), //[0] is a group of ungrouped harmonics.
                .allocator = alloc,
                .state = .init(),
            };
        }
        pub fn initStream(this: *This) void {
            var want: c.SDL_AudioSpec = .{
                .freq = @intCast(sample_rate),
                .format = c.AUDIO_U16SYS,
                .channels = 1,
                .samples = chunk_size,
                .padding = 0,
                .callback = audioCallback,
                .userdata = @ptrCast(this),
            };
            this.device = c.SDL_OpenAudioDevice(null, 0, &want, null, 0);
            c.SDL_PauseAudioDevice(this.device, 0);
        }
        pub fn deinit(self: *This) void {
            c.SDL_CloseAudio();
            self.groups.deinit();
        }

        pub fn audioCallback(userdata: ?*anyopaque, output_buf: [*c]u8, len: c_int) callconv(.c) void {
            _ = len;
            var output: [*]u16 = @ptrCast(@alignCast(output_buf));
            const self: *This = @ptrCast(@alignCast(userdata.?));
            self.state.advance();
            const harmonic_groups = self.groups.items;
            const mouse_x = @as(f16, @floatFromInt(self.state.mouse_pos[0]));
            const base_frequency = linearToLogScale(mouse_x, @floatFromInt(self.min_freq), @floatFromInt(self.max_freq));
            for (0..chunk_size) |i| {
                output[i] = 0;
            }

            for (harmonic_groups) |harmonic_group| {
                if (self.state.keys_pressed[harmonic_group.key] != 0) {
                    for (harmonic_group.harmonics.items) |*harmonic| {
                        var temp_buffer: [chunk_size]u16 = undefined;
                        harmonic.generateSineWave(&temp_buffer, @intFromFloat(base_frequency), sample_rate);
                        for (0..chunk_size) |i| {
                            const sum = @as(u32, output[i]) + temp_buffer[i];
                            output[i] = if (sum > 65535) 65535 else @intCast(sum);
                        }
                    }
                }
            }
        }
    };
}
pub fn ln_f16(x: f16) f16 {
    if (x <= 0.0) return -std.math.inf(f16);
    if (x == 1.0) return 0.0;
    const bits: u16 = @bitCast(x);
    const exponent: i16 = @as(i16, @intCast((bits >> 10) & 0x1F)) - 15;
    const mantissa: f16 = @as(f16, @floatFromInt(bits & 0x3FF)) / 1024.0;
    return 0.693147 * @as(f16, @floatFromInt(exponent)) +
        (mantissa - mantissa * mantissa / 2.0 + mantissa * mantissa * mantissa / 3.0);
}

fn logScale(value: f16, min: f16, max: f16) f16 {
    const log_min = ln_f16(min);
    const log_max = ln_f16(max);
    const scale = (log_max - log_min) / SCREEN_X;
    return std.math.exp(log_min + (value * scale));
}

fn linearToLogScale(value: f16, min: f16, max: f16) f16 {
    const normalized = value / SCREEN_X;
    const log_min = ln_f16(min);
    const log_max = ln_f16(max);
    const log_value = log_min + normalized * (log_max - log_min);
    return std.math.exp(log_value);
}

const StateManager = @import("state.zig").InputState;
const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
    @cInclude("SDL2/SDL.h");
});
