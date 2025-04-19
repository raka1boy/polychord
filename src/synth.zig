pub const Harmonic = struct {
    multiplier: f16,
    amp: f16 = 1,
    freq: u16 = 0,
    phase: f16 = 0,

    pub fn init(mul: f16) Harmonic {
        return .{ .multiplier = mul };
    }
};
pub const HarmonicGroup = struct {
    harmonics: std.ArrayList(Harmonic),
    key: i32,
};
pub const Synthesizer = struct {
    groups: std.ArrayList(HarmonicGroup),
    stream: ?*c.PaStream = undefined,
    sample_rate: u32,
    global_smoothing: f16,
    global_amp: f16,
    is_playing: bool = false,

    pub fn init(
        alloc: std.mem.Allocator,
        sample_rate: u32,
        global_smoothing: f16,
        global_amp: f16,
    ) !Synthesizer {
        c.Pa_Initialize();

        return .{
            .groups = try .initCapacity(alloc, 1), //[0] is a group of ungrouped harmonics.
            .sample_rate = sample_rate,
            .global_smoothing = global_smoothing,
            .global_amp = global_amp,
        };
    }
    pub fn deinit(self: *Synthesizer) void {
        c.Pa_StopStream(@ptrCast(self.stream));
        c.Pa_Terminate();
        self.harmonics.deinit();
    }
    pub fn initDefault(alloc: std.mem.Allocator) !Synthesizer {
        return try init(alloc, 48000, 0, 1);
    }
    pub fn init_stream(self: *Synthesizer) void {
        try handleError(c.Pa_OpenDefaultStream(
            &self.stream,
            0,
            1,
            c.paFloat32,
            48000,
            256,
            callback,
            &self.harmonic,
        ));
    }
    pub fn play(self: *Synthesizer) void {
        c.Pa_StartStream(self.stream);
    }
};

export fn callback(
    input: ?*const anyopaque,
    output: ?*anyopaque,
    framesPerBuf: c_ulong,
    timeInfo: [*c]const c.PaStreamCallbackTimeInfo,
    statusFlags: c.PaStreamCallbackFlags,
    userData: ?*anyopaque,
) callconv(.c) c_int {
    var pos: @Vector(2, u16) = .{ 0, 0 };
    _ = .{ input, statusFlags };
    const now = timeInfo.currentTime;
    const data: []HarmonicGroup = @alignCast(@ptrCast(userData));
    var buffer: [*c]f32 = @alignCast(@ptrCast(output));
    var i: usize = 0;
    for (0..framesPerBuf) |_| {
        buffer[i] = data.phase;
        i += 1;
        data.phase += 0.0005;
        if (data.phase >= 0.5) data.phase = -0.5;
    }
    return 0;
}

const callbackFnSignature = fn (
    input: ?*const anyopaque,
    output: ?*anyopaque,
    framesPerBuf: c_ulong,
    timeInfo: [*c]const c.PaStreamCallbackTimeInfo,
    statusFlags: c.PaStreamCallbackFlags,
    userData: ?*anyopaque,
) c_int;

//i proudly stole this from github.com/fjebaker/zaudio
fn handleError(err: c_int) !void {
    switch (err) {
        c.paNoError => return,
        else => {
            std.debug.print(
                "Unhandled error: {d} {s}\n",
                .{ err, c.Pa_GetErrorText(err) },
            );
            return error.UnknownError;
        },
    }
}

const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
