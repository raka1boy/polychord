pub fn Harmonic(chunk_size: comptime_int) type {
    return struct {
        const This = @This();
        multiplier: f32,
        amp: f64 = 0.0, // Changed to f64
        global_amp: f32 = 1.0,
        phase: f64 = 0.0,
        onset_amp_smooth: f32 = 0.1,
        offset_amp_smooth: f32 = 1,
        is_active: bool = false,
        last_active_frequency: f64 = 0.0,
        current_frequency: f64 = 0.0,
        snap: u8 = 0, //if 0 then no snapping

        pub fn init(mul: f32, amp: f64) This {
            var xoro = std.Random.Xoroshiro128.init(@intCast(std.time.microTimestamp()));
            const rand = xoro.random();
            return .{
                .multiplier = mul,
                .amp = amp,
                .phase = std.math.pi * 2.0 * rand.float(f32), // Random phase
            };
        }

        pub fn setActive(self: *This, active: bool) void {
            self.is_active = active;
        }

        pub fn generateSineWave(self: *This, buffer: *[chunk_size]f32, initial_frequency: u16, external_amp: f64, sample_rate: usize) void {
            var actual_freq: f64 = 0;
            if (self.snap != 0) {
                actual_freq = hz_stuff.closestETFreq(@floatFromInt(self.snap), @as(f64, @floatFromInt(initial_frequency)) * self.multiplier);
            } else {
                actual_freq = @as(f64, @floatFromInt(initial_frequency)) * self.multiplier;
            }

            if (self.is_active) {
                self.current_frequency = actual_freq;
            }
            const target_amp = if (self.is_active)
                @min(1.0, self.amp + self.onset_amp_smooth)
            else
                @max(0.0, self.amp - self.offset_amp_smooth);

            if (self.is_active) std.debug.print("generating {d} frequency\n", .{actual_freq});
            const amp_increment = (target_amp - self.amp) / @as(f64, @floatFromInt(chunk_size));

            const angular_freq = 2.0 * std.math.pi * self.current_frequency;
            const sample_rate_f64 = @as(f64, @floatFromInt(sample_rate));
            const phase_inc = angular_freq / sample_rate_f64;

            for (0..chunk_size) |i| {
                const current_amp = self.amp + amp_increment * @as(f64, @floatFromInt(i));
                const phase = self.phase + phase_inc * @as(f64, @floatFromInt(i));
                buffer[i] = @floatCast(external_amp * (self.global_amp * (current_amp * std.math.sin(phase))));
            }

            self.phase += phase_inc * @as(f64, @floatFromInt(chunk_size));
            self.phase = @mod(self.phase, 2.0 * std.math.pi);
            self.amp = target_amp;

            // Clamp near-zero amplitudes to prevent denormals
            if (self.amp < 1e-6) {
                self.amp = 0.0;
            }
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
        texture_manager: TextureManager,
        min_freq: u16 = 131,
        max_freq: u16 = 2094,

        pub fn init(alloc: std.mem.Allocator) !This {
            const state = StateManager.init();
            const texture_manager = try TextureManager.init(state.renderer);
            return .{
                .groups = try std.ArrayList(HarmonicGroup(chunk_size)).initCapacity(alloc, 1),
                .allocator = alloc,
                .state = state,
                .texture_manager = texture_manager,
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
        pub fn genGroupWithRule(
            self: *This,
            trigger_keys: []const SdlKeycodes,
            advancementFunc: fn (initmul: *f32, initamp: *f32, initonset: *f32, initoffset: *f32) void,
            initMul: f32,
            initAmp: f32,
            onsetSmoothInit: f32,
            offsetSmoothInit: f32,
            snapRule: u8,
            multiplierAdvanceBetweenKeys: f32,
            count: usize,
        ) !void {
            var mulAdvAccum: f32 = 0;
            for (trigger_keys) |key| {
                var group = HarmonicGroup(chunk_size).init(self.allocator, @intFromEnum(key));
                var ampAccum = initAmp;
                var mulAccum: f32 = initMul + initMul * mulAdvAccum;
                var onsetAccum = onsetSmoothInit;
                var offsetAccum = offsetSmoothInit;
                for (0..count) |_| {
                    const harmonic = Harmonic(chunk_size){
                        .multiplier = mulAccum,
                        .global_amp = ampAccum,
                        .onset_amp_smooth = onsetAccum,
                        .offset_amp_smooth = offsetAccum,
                        .snap = snapRule,
                    };
                    try group.harmonics.append(harmonic);
                    advancementFunc(&mulAccum, &ampAccum, &onsetAccum, &offsetAccum);
                }
                try self.groups.append(group);
                mulAdvAccum += multiplierAdvanceBetweenKeys;
            }
        }

        pub fn renderGuidelines(self: *This) void {
            const state = &self.state;
            const screen_width = state.screen_x;
            const screen_height = state.screen_y;

            _ = c.SDL_SetRenderDrawColor(state.renderer, 0, 0, 0, 255);
            _ = c.SDL_RenderClear(state.renderer);

            _ = c.SDL_SetRenderDrawColor(state.renderer, 255, 255, 255, 100);

            const min_midi = hz_stuff.freqToMidi(@floatFromInt(self.min_freq));
            const max_midi = hz_stuff.freqToMidi(@floatFromInt(self.max_freq));

            var midi_note: i32 = min_midi;
            while (midi_note <= max_midi) : (midi_note += 1) {
                const freq = hz_stuff.midiToFreq(midi_note);
                const x_pos = hz_stuff.freqToScreenX(freq, self.min_freq, self.max_freq, screen_width);

                // Draw vertical line
                _ = c.SDL_RenderDrawLine(state.renderer, x_pos, 0, x_pos, screen_height);
                const note_index = @as(u4, @intCast(@mod(midi_note - 2, 12)));
                self.texture_manager.renderNote(
                    note_index,
                    x_pos + 5,
                    10,
                    20, // width
                    20, // height
                );
            }

            c.SDL_RenderPresent(state.renderer);
        }
        pub fn deinit(self: *This) void {
            self.texture_manager.deinit();
            c.SDL_CloseAudioDevice(self.device);
            self.groups.deinit();
        }

        pub fn audioCallback(userdata: ?*anyopaque, output_buf: [*c]u8, len: c_int) callconv(.c) void {
            _ = len;
            var output: [*]f32 = @ptrCast(@alignCast(output_buf));
            const self: *This = @ptrCast(@alignCast(userdata.?));
            if (!self.state.is_playing_mode) return;
            self.state.advance();

            const mouse_x = @as(f32, @floatFromInt(self.state.mouse_pos[0]));
            const mouse_y: f64 = @floatFromInt(self.state.mouse_pos[1]);
            const base_amp: f64 = 1 - (mouse_y / @as(f64, @floatFromInt(self.state.screen_y)));

            const base_frequency = hz_stuff.logScale(mouse_x, 1920, @floatFromInt(self.min_freq), @floatFromInt(self.max_freq));

            @memset(output[0..chunk_size], 0.0);
            var temp_buffer: [chunk_size]f32 = undefined; // Moved outside the loop

            for (self.groups.items) |*group| {
                const is_group_active = self.state.keys_pressed[@intCast(group.key)] != 0;
                for (group.harmonics.items) |*harmonic| {
                    harmonic.setActive(is_group_active);
                    harmonic.generateSineWave(&temp_buffer, @intFromFloat(base_frequency), base_amp / 2, sample_rate);
                    for (0..chunk_size) |i| {
                        output[i] += temp_buffer[i];
                    }
                }
            }
        }
    };
}
const TextureManager = @import("texture_manager.zig").TextureManager;
const text_renderer = @import("text_renderer.zig");
const SdlKeycodes = @import("sdl_keycodes.zig").SdlKeycodes;
const hz_stuff = @import("freq_stuff.zig");
const StateManager = @import("state.zig").InputState;
const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});
