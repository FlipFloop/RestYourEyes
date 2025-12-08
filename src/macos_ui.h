#import <Cocoa/Cocoa.h>
#include <stdint.h>
#include <stdbool.h>

// Callbacks to Zig
typedef void (*SnoozeCallback)(void);
typedef void (*SkipCallback)(void);
typedef void (*PresetCallback)(int preset_id);
typedef void (*QuitCallback)(void);

struct AppCallbacks {
    SnoozeCallback on_snooze;
    SkipCallback on_skip;
    PresetCallback on_preset;
    QuitCallback on_quit;
};

void init_ui(struct AppCallbacks callbacks);
void run_app(void);
void show_break_screen(bool visible);
void update_timer_display(const char* text);

