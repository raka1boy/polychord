const std = @import("std");
const c = @cImport({
    @cInclude("portaudio.h");
});
pub fn main() !void {
    _ = try handleError(c.Pa_Initialize());
    std.debug.print("{any}", .{c.Pa_GetVersionText().*});
}

//i proudly stole this from github.com/fjebaker/zaudio
fn handleError(err: c_int) !void {
    const logger = std.log.scoped(.zaudio);
    switch (err) {
        c.paNoError => return,
        else => {
            logger.debug(
                "Unhandled error: {d} {s}\n",
                .{ err, c.Pa_GetErrorText(err) },
            );
            return error.UnknownError;
        },
    }
}
