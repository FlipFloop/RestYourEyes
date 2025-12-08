const std = @import("std");

pub const Preset = struct {
    work_duration: i64,
    break_duration: i64,
    name: []const u8,
};

pub const PRESETS = [_]Preset{
    .{ .work_duration = 20 * 60, .break_duration = 20, .name = "20-20" },
    .{ .work_duration = 10 * 60, .break_duration = 10, .name = "10-10" },
    .{ .work_duration = 25 * 60, .break_duration = 5 * 60, .name = "Pomodoro" },
};

pub const State = enum {
    Work,
    Break,
};

pub const AppState = struct {
    mutex: std.Thread.Mutex,
    current_preset: usize,
    state: State,
    time_remaining: i64,
    running: bool,

    pub fn init() AppState {
        return .{
            .mutex = .{},
            .current_preset = 0, // Default to 20-20 (index 0)
            .state = .Work,
            .time_remaining = PRESETS[0].work_duration,
            .running = true,
        };
    }

    // Returns true if the state changed in a way that requires showing/hiding break screen (i.e. Work <-> Break transition)
    // or resetting the view significantly.
    pub fn snooze(self: *AppState) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state == .Break) {
            self.state = .Work;
            self.time_remaining = 2 * 60;
            return true; // Switched to work, hide break screen
        } else {
            self.time_remaining += 2 * 60;
            return false; // Stayed in work, just updated time
        }
    }

    // Returns true if mode changed (Work <-> Break)
    pub fn skip(self: *AppState) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.state == .Break) {
            self.startWork();
        } else {
            self.startBreak();
        }
        return true;
    }

    pub fn setPreset(self: *AppState, id: usize) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (id < PRESETS.len) {
            self.current_preset = id;
            self.startWork();
            return true; // Reset to work mode
        }
        return false;
    }

    // Internal helper, assumes lock held
    fn startWork(self: *AppState) void {
        self.state = .Work;
        self.time_remaining = PRESETS[self.current_preset].work_duration;
    }

    // Internal helper, assumes lock held
    fn startBreak(self: *AppState) void {
        self.state = .Break;
        self.time_remaining = PRESETS[self.current_preset].break_duration;
    }

    // Returns true if state switched (e.g. Work -> Break or Break -> Work)
    pub fn tick(self: *AppState) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (!self.running) return false;

        if (self.time_remaining > 0) {
            self.time_remaining -= 1;
            return false;
        } else {
            if (self.state == .Work) {
                self.startBreak();
            } else {
                self.startWork();
            }
            return true;
        }
    }
};

test "AppState initialization" {
    const state = AppState.init();
    try std.testing.expectEqual(State.Work, state.state);
    try std.testing.expectEqual(PRESETS[0].work_duration, state.time_remaining);
    try std.testing.expect(state.running);
}

test "AppState skip toggles state" {
    var state = AppState.init();
    // Start at Work
    try std.testing.expectEqual(State.Work, state.state);

    // Skip -> Break
    const changed = state.skip();
    try std.testing.expect(changed);
    try std.testing.expectEqual(State.Break, state.state);
    try std.testing.expectEqual(PRESETS[0].break_duration, state.time_remaining);

    // Skip -> Work
    const changed2 = state.skip();
    try std.testing.expect(changed2);
    try std.testing.expectEqual(State.Work, state.state);
    try std.testing.expectEqual(PRESETS[0].work_duration, state.time_remaining);
}

test "AppState snooze behavior" {
    var state = AppState.init();

    // Snooze during Work adds time
    const initial_time = state.time_remaining;
    const changed = state.snooze();
    try std.testing.expect(!changed);
    try std.testing.expectEqual(State.Work, state.state);
    try std.testing.expectEqual(initial_time + 120, state.time_remaining);

    // Switch to Break
    _ = state.skip();
    try std.testing.expectEqual(State.Break, state.state);

    // Snooze during Break switches to Work
    const changed2 = state.snooze();
    try std.testing.expect(changed2);
    try std.testing.expectEqual(State.Work, state.state);
    try std.testing.expectEqual(120, state.time_remaining);
}

test "AppState tick transitions" {
    var state = AppState.init();
    // Force time to 0 to test transition
    state.time_remaining = 0;

    const changed = state.tick();
    try std.testing.expect(changed);
    try std.testing.expectEqual(State.Break, state.state);
    try std.testing.expectEqual(PRESETS[0].break_duration, state.time_remaining);
}
