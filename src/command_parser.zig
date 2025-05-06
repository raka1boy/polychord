// command_parser.zig
const std = @import("std");
const Action = @import("main.zig").Action;
const InputCommand = @import("main.zig").InputCommand;
const Synthesizer = @import("synthes.zig").Synthesizer;
const HarmonicGroup = @import("synthes.zig").HarmonicGroup;

pub fn parseCommand(
    alloc: std.mem.Allocator,
    synth: *Synthesizer,
    command: []const InputCommand,
) !void {
    if (command.len == 0) return;

    // Example: New command
    if (std.mem.eql(InputCommand, command[0], .{ .Key = .N })) {
        try handleNewCommand(alloc, synth, command[1..]);
        return;
    }

    // Add other command handlers here...

    return error.UnknownCommand;
}

fn handleNewCommand(
    alloc: std.mem.Allocator,
    synth: *Synthesizer,
    args: []const InputCommand,
) !void {
    const defaults = .{ 1.0, 1.0, 0.1, 0.05, 0 };
    var params: [5]f32 = defaults;

    // Parse numerical arguments
    for (args, 0..) |arg, i| {
        if (i >= 5) break;
        if (arg == .Num) params[i] = @floatCast(arg.Num);
    }

    // Generate unique key (example using mouse position)
    const key: c_int = @intCast(synth.state.mouse_pos[0] + synth.state.mouse_pos[1]);

    // Create new group
    var group = HarmonicGroup(synth.chunk_size).init(alloc, key);
    try group.addHarmonic(.{
        .multiplier = params[0],
        .global_amp = params[1],
        .onset_amp_smooth = params[2],
        .offset_amp_smooth = params[3],
        .snap = @intFromFloat(params[4]),
    });

    try synth.groups.append(group);
}
