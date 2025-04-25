pub fn Harmonic(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        multiplier: f32,
        amp: f64 = 0.0, // Changed to f64
        phase: f64 = 0.0,
        onset_amp_smooth: f32 = 0.01,
        offset_amp_smooth: f32 = 0.01,
        is_active: bool = false,
        last_active_frequency: f64 = 0.0,
        current_frequency: f64 = 0.0,
        sample_rate: usize = 0,
        snap: ?u8 = null,
        ramp_step: f64 = 1, // Changed to f64

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
        }

        pub fn generateSineWave(self: *This, buffer: *[chunk_size]f32, initial_frequency: u16, external_amp: f64, sample_rate: usize) void {
            var actual_freq: f64 = 0;
            if (self.snap) |snap_val| {
                actual_freq = closestETFreq(@floatFromInt(snap_val), @as(f64, @floatFromInt(initial_frequency)) * self.multiplier);
            } else {
                actual_freq = @as(f64, @floatFromInt(initial_frequency)) * self.multiplier;
            }

            if (self.is_active) {
                self.current_frequency = actual_freq;
                self.amp = @min(1, self.amp + self.onset_amp_smooth);
            } else {
                self.amp = @max(0, self.amp - self.offset_amp_smooth);
            }
            std.debug.print("FREQ: {d}\n", .{self.current_frequency});
            const angular_freq = 2.0 * std.math.pi * self.current_frequency;
            const sample_rate_f64 = @as(f64, @floatFromInt(sample_rate));
            const phase_inc = angular_freq / sample_rate_f64;

            for (0..chunk_size) |i| {
                const phase = self.phase + phase_inc * @as(f64, @floatFromInt(i));
                buffer[i] = @floatCast(external_amp * (self.amp * std.math.sin(phase))); // Cast f64 to f32
            }
            self.phase += phase_inc * @as(f64, @floatFromInt(chunk_size));
            self.phase = @mod(self.phase, 2.0 * std.math.pi);
        }
    };
}

pub fn HarmonicGroup(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        harmonics: std.ArrayList(Harmonic(chunk_size)),
        key: c_int,

        pub fn init(alloc: std.mem.Allocator, key: c_int) This {
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
        max_freq: u16 = 1024,

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
            const mouse_y: f64 = @floatFromInt(self.state.mouse_pos[1]);
            const base_amp: f64 = 1 - (mouse_y / @as(f64, @floatFromInt(self.state.screen_y)));

            const base_frequency = logScale(mouse_x, 1920, @floatFromInt(self.min_freq), @floatFromInt(self.max_freq));

            @memset(output[0..chunk_size], 0.0);
            for (self.groups.items) |*group| {
                const is_group_active = self.state.keys_pressed[@intCast(group.key)] != 0;
                var group_buffer: [chunk_size]f32 = undefined;
                @memset(&group_buffer, 0.0);
                for (group.harmonics.items) |*harmonic| {
                    harmonic.setActive(is_group_active);
                    var temp_buffer: [chunk_size]f32 = undefined;
                    harmonic.generateSineWave(&temp_buffer, @intFromFloat(base_frequency), base_amp, sample_rate);
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

pub fn closestETFreq(notes_in_octave: f64, hertz: f64) f64 {
    if (hertz <= 0.0) return 0.0;
    const reference_freq = 440.0; // A4
    const steps = notes_in_octave * math.log2(hertz / reference_freq);
    const rounded_steps = math.round(steps);
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

const StateManager = @import("state.zig").InputState;
const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("portaudio.h");
    @cInclude("SDL2/SDL.h");
});
