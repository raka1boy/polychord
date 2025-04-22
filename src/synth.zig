const SCREEN_X = 1920;
const SCREEN_Y = 1080;
pub fn Harmonic(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        multiplier: f32,
        amp: f64 = 0.0, // Changed to f64
        phase: f64 = 0.0,
        onset_amp_smooth: f32 = 0.05,
        offset_amp_smooth: f32 = 0.0001,
        is_active: bool = false,
        last_active_frequency: f64 = 0.0,
        current_frequency: f64 = 0.0,
        sample_rate: usize = 0,
        ramp_step: f64 = 0.0, // Changed to f64

        pub fn init(mul: f32) This {
            var xoro = std.Random.Xoroshiro128.init(@intCast(std.time.microTimestamp()));
            const rand = xoro.random();
            return .{
                .multiplier = mul,
                .phase = std.math.pi * 2.0 * rand.float(f32), // Random phase
            };
        }

        pub fn setActive(self: *This, active: bool) void {
            self.is_active = active;
            //self.target_amp = if (active) 1.0 else 0.0;

            // const smoothing_time = if (active) self.onset_amp_smooth else self.offset_amp_smooth;
            // // Use f64 for sample_rate to prevent precision loss
            // self.ramp_step = 1.0 / (smoothing_time * @as(f64, @floatFromInt(sample_rate)));
        }

        pub fn generateSineWave(self: *This, buffer: *[chunk_size]f32, initial_frequency: u16, sample_rate: usize) void {
            const actual_freq = @as(f64, @floatFromInt(initial_frequency)) * self.multiplier;
            if (self.is_active) {
                self.current_frequency = actual_freq;
                self.amp = @min(1, self.amp + self.onset_amp_smooth);
            } else {
                self.current_frequency = self.last_active_frequency;
                self.amp = @max(0, self.amp - self.offset_amp_smooth);
            }
            std.debug.print("amp: {d}\n", .{self.amp});
            const angular_freq = 2.0 * std.math.pi * self.current_frequency;
            const sample_rate_f64 = @as(f64, @floatFromInt(sample_rate));
            const phase_inc = angular_freq / sample_rate_f64;

            for (0..chunk_size) |i| {
                const phase = self.phase + phase_inc * @as(f64, @floatFromInt(i));
                buffer[i] = @floatCast(self.amp * std.math.sin(phase)); // Cast f64 to f32
            }

            self.phase += phase_inc * @as(f64, @floatFromInt(chunk_size));
            self.phase = @mod(self.phase, 2.0 * std.math.pi);

            if (!self.is_active and self.amp <= 0.0) {
                self.phase = 0.0;
                self.current_frequency = 0.0;
            }
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
        global_smoothing: f32 = 0.0,
        device: c.SDL_AudioDeviceID = undefined,
        min_freq: u16 = 256,
        max_freq: u16 = 512,
        dc_blocker: struct { x1: f32 = 0.0, y1: f32 = 0.0 } = .{},

        pub fn init(alloc: std.mem.Allocator) !This {
            return .{
                .groups = try std.ArrayList(HarmonicGroup(chunk_size)).initCapacity(alloc, 1),
                .allocator = alloc,
                .state = .init(),
            };
        }

        pub fn initStream(this: *This) void {
            var want: c.SDL_AudioSpec = .{
                .freq = @intCast(sample_rate),
                .format = c.AUDIO_F32SYS,
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
            c.SDL_CloseAudioDevice(self.device);
            self.groups.deinit();
        }

        pub fn audioCallback(userdata: ?*anyopaque, output_buf: [*c]u8, len: c_int) callconv(.c) void {
            _ = len;
            var output: [*]f32 = @ptrCast(@alignCast(output_buf));
            const self: *This = @ptrCast(@alignCast(userdata.?));
            self.state.advance();

            const mouse_x = @as(f32, @floatFromInt(self.state.mouse_pos[0]));
            const base_frequency = logScale(mouse_x, 1920, @floatFromInt(self.min_freq), @floatFromInt(self.max_freq));
            //std.debug.print("freq: {d}\n", .{base_frequency});

            @memset(output[0..chunk_size], 0.0);
            for (self.groups.items) |*group| {
                const is_group_active = self.state.keys_pressed[group.key] != 0;
                var group_buffer: [chunk_size]f32 = undefined;
                @memset(&group_buffer, 0.0);
                for (group.harmonics.items) |*harmonic| {
                    harmonic.setActive(is_group_active);
                    var temp_buffer: [chunk_size]f32 = undefined;
                    harmonic.generateSineWave(&temp_buffer, @intFromFloat(base_frequency), sample_rate);
                    for (0..chunk_size) |i| {
                        group_buffer[i] += temp_buffer[i];
                    }
                }

                for (0..chunk_size) |i| {
                    output[i] += group_buffer[i];
                }
            }
            for (0..chunk_size) |i| {
                output[i] = std.math.tanh(output[i]);
            }
        }
    };
}
pub fn logScale(cursor_x: f32, screen_width: f32, min_freq: f32, max_freq: f32) f32 {
    // Clamp cursor_x to avoid out-of-bounds
    const clamped_x = @min(@max(cursor_x, 0), screen_width);

    // Normalize to [0, 1]
    const normalized = clamped_x / screen_width;

    // Logarithmic scaling (frequency perception is logarithmic)
    const log_min = @log(min_freq);
    const log_max = @log(max_freq);
    const log_freq = log_min + normalized * (log_max - log_min);

    // Convert back to linear frequency
    return @exp(log_freq);
}

const StateManager = @import("state.zig").InputState;
const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("portaudio.h");
    @cInclude("SDL2/SDL.h");
});
