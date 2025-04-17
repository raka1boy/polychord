const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});

pub fn main() !void {
    std.debug.print("{any}", .{c.Pa_GetVersionText().*});
}
