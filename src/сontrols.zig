pub const Action = enum([]InputCommand) { //starts with Keycodes.C
    new = .{ .Key.N, .Num, .Num, .Num, .Num, .Num }, //mul, amp, onset, offset, snap-rule.
    //If some params are skipped, default is set instead
    addWithRule = .{ .Key.R, .Multiple, .Str },
    //String with code.
    //Code looks like this: "*2 | +1 | +0.1 | +0 | 5"
    //params go like this: multiplier, amplitude, onset smooth, offset smooth, how much harmonics. Snapping is derived from base.
    //This takes all the specified harmonics, and adds another harmonics to its group based on some rule.
    delete = .{ .Key.D, .Multiple }, //delete by ids
    edit = .{ .Key.E, .Multiple, .Num }, //Edit one or more params by id.
    //If param requires an integer but float is provided, rounds to smallest int.

};

pub fn takeInput(state: *State) Action {
    var act: Action = undefined;
    var inputs: [10]Keycodes = undefined;
    while (act == undefined) {
        state.advance();
        keyDetection: for (state.keys_pressed, 0..512) |key, i| {
            if (key == 1) {
                for (&inputs) |v| {
                    if (v == undefined) {
                        v = @enumFromInt(i);
                        break :keyDetection;
                    }
                }
            }
        }
    }
}
const InputCommand = union(enum) {
    Key: Keycodes,
    Num: f64,
    Range: .{ usize, usize },
    Multiple: []usize,
    Str: []u8,
};
const State = @import("state.zig").InputState;
const Keycodes = @import("sdl_keycodes.zig").SdlKeycodes;
