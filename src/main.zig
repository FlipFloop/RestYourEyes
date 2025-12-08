const std = @import("std");
const root = @import("root.zig");
const c = @cImport({
    @cInclude("c_interface.h");
});

var app_state = root.AppState.init();

// Callbacks exposed to C
export fn on_snooze_cb() void {
    if (app_state.snooze()) {
        c.show_break_screen(false);
    }
    update_ui();
}

export fn on_skip_cb() void {
    _ = app_state.skip();
    update_screen_visibility();
    update_ui();
}

export fn on_preset_cb(id: c_int) void {
    if (id >= 0) {
        if (app_state.setPreset(@intCast(id))) {
            c.show_break_screen(false);
        }
        update_ui();
    }
}

export fn on_quit_cb() void {
    app_state.mutex.lock();
    app_state.running = false;
    app_state.mutex.unlock();
}

fn update_screen_visibility() void {
    app_state.mutex.lock();
    const is_break = (app_state.state == .Break);
    app_state.mutex.unlock();
    c.show_break_screen(is_break);
}

fn update_ui() void {
    var buf: [64]u8 = undefined;

    app_state.mutex.lock();
    const time = app_state.time_remaining;
    app_state.mutex.unlock();

    const m = @divTrunc(time, 60);
    const s = @rem(time, 60);

    const text = std.fmt.bufPrintZ(&buf, "{d:0>2}:{d:0>2}", .{ m, s }) catch "Err";

    c.update_timer_display(text.ptr);
}

fn timer_loop() void {
    var tick: usize = 0;
    while (true) {
        // Check running state
        {
            app_state.mutex.lock();
            if (!app_state.running) {
                app_state.mutex.unlock();
                break;
            }
            app_state.mutex.unlock();
        }

        if (app_state.tick()) {
            update_screen_visibility();
        }
        update_ui();

        // Log every 10 seconds to show it's alive
        // if (tick % 10 == 0) {
        //     app_state.mutex.lock();
        //     const time = app_state.time_remaining;
        //     app_state.mutex.unlock();
        //     std.debug.print("Timer tick: {d}s remaining\n", .{time});
        // }
        tick += 1;

        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

pub fn main() !void {
    // Define C structs for callbacks
    const callbacks = c.AppCallbacks{
        .on_snooze = on_snooze_cb,
        .on_skip = on_skip_cb,
        .on_preset = on_preset_cb,
        .on_quit = on_quit_cb,
    };

    // Initialize UI
    std.debug.print("Initializing UI...\n", .{});
    c.init_ui(callbacks);

    // Start timer thread
    const thread = try std.Thread.spawn(.{}, timer_loop, .{});
    thread.detach();

    // Run main loop (blocks)
    std.debug.print("Running app loop... (Check menu bar for RestYourEyes icon)\n", .{});
    c.run_app();
}
