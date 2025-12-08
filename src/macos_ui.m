#import <Cocoa/Cocoa.h>
#include <mach-o/dyld.h>
#include "c_interface.h"

static struct AppCallbacks g_callbacks;
static NSStatusItem* g_statusItem;
static NSWindow* g_overlayWindow;
static NSImage* g_logoImage = nil;
static BOOL g_showTimer = NO;

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {}
@end

@interface OverlayController : NSObject
- (void)snoozeClicked:(id)sender;
- (void)skipClicked:(id)sender;
@end

@implementation OverlayController
- (void)snoozeClicked:(id)sender {
    if (g_callbacks.on_snooze) g_callbacks.on_snooze();
}
- (void)skipClicked:(id)sender {
    if (g_callbacks.on_skip) g_callbacks.on_skip();
}
@end

static OverlayController* g_overlayController;

@interface MenuHandler : NSObject
- (void)presetSelected:(NSMenuItem*)sender;
- (void)toggleTimerDisplay:(NSMenuItem*)sender;
- (void)quitSelected:(id)sender;
@end

static NSMenu* g_mainMenu;

@implementation MenuHandler
- (void)presetSelected:(NSMenuItem*)sender {
    // Uncheck all preset items
    for (NSMenuItem *item in g_mainMenu.itemArray) {
        if (item.action == @selector(presetSelected:)) {
            [item setState:NSControlStateValueOff];
        }
    }
    // Check the selected item
    [sender setState:NSControlStateValueOn];
    
    if (g_callbacks.on_preset) g_callbacks.on_preset((int)sender.tag);
}

- (void)toggleTimerDisplay:(NSMenuItem*)sender {
    g_showTimer = !g_showTimer;
    [sender setState:g_showTimer ? NSControlStateValueOn : NSControlStateValueOff];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_statusItem && g_logoImage) {
            NSButton *button = g_statusItem.button;
            button.image = g_logoImage;
            button.imagePosition = NSImageLeading;
            
            // Just toggle title visibility
            if (!g_showTimer) {
                button.title = @"";
            }
            // Force length update
            g_statusItem.length = NSVariableStatusItemLength;
        }
    });
}

- (void)quitSelected:(id)sender {
    if (g_callbacks.on_quit) g_callbacks.on_quit();
    [NSApp terminate:nil];
}
@end

static MenuHandler* g_menuHandler;

void init_ui(struct AppCallbacks callbacks) {
    g_callbacks = callbacks;
    
    [NSApplication sharedApplication];
    [NSApp setDelegate:[[AppDelegate alloc] init]];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    g_menuHandler = [[MenuHandler alloc] init];
    g_overlayController = [[OverlayController alloc] init];

    // Create status bar item
    g_statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // Load icon
    NSImage* iconImage = nil;
    
    // 1. Try loading from bundle resources (for .app bundle)
    NSString* resourcePath = [[NSBundle mainBundle] pathForResource:@"icon" ofType:@"png"];
    if (resourcePath) {
        iconImage = [[NSImage alloc] initWithContentsOfFile:resourcePath];
    }
    
    // 2. Fallback to executable relative path (for development)
    if (!iconImage) {
        NSString* exePath = [[NSBundle mainBundle] executablePath];
        if (!exePath || [exePath length] == 0) {
            char path[1024];
            uint32_t size = sizeof(path);
            if (_NSGetExecutablePath(path, &size) == 0) {
                exePath = [NSString stringWithUTF8String:path];
            }
        }
        
        if (exePath) {
            NSString* exeDir = [exePath stringByDeletingLastPathComponent];
            NSString* iconPath = [[exeDir stringByAppendingPathComponent:@"images"] stringByAppendingPathComponent:@"icon.png"];
            iconImage = [[NSImage alloc] initWithContentsOfFile:iconPath];
            
            if (!iconImage) {
                iconPath = [[[exeDir stringByAppendingPathComponent:@"images"] stringByAppendingPathComponent:@"icons"] stringByAppendingPathComponent:@"icon_32.png"];
                iconImage = [[NSImage alloc] initWithContentsOfFile:iconPath];
            }
        }
    }
    
    if (iconImage) {
        [iconImage setTemplate:YES];
            [iconImage setSize:NSMakeSize(18, 18)];
            g_logoImage = iconImage;
            NSButton *button = g_statusItem.button;
            button.buttonType = NSButtonTypeMomentaryPushIn;
            button.imageScaling = NSImageScaleProportionallyDown;
            button.image = g_logoImage;
            // Use NSImageLeading for better compatibility with text
            button.imagePosition = NSImageLeading; 
            if (@available(macOS 10.12, *)) {
                button.imageHugsTitle = YES;
            }
            if (@available(macOS 10.11, *)) {
                button.font = [NSFont monospacedDigitSystemFontOfSize:14.0 weight:NSFontWeightRegular];
            }
        }
    
    g_statusItem.button.title = @"";

    // Create menu
    g_mainMenu = [[NSMenu alloc] init];
    
    // Time mode presets
    NSMenuItem *item20 = [[NSMenuItem alloc] initWithTitle:@"20-20-20 Rule" action:@selector(presetSelected:) keyEquivalent:@""];
    item20.tag = 0;
    item20.target = g_menuHandler;
    item20.state = NSControlStateValueOn; // Will be set by default
    [g_mainMenu addItem:item20];

    NSMenuItem *item10 = [[NSMenuItem alloc] initWithTitle:@"10m - 10s" action:@selector(presetSelected:) keyEquivalent:@""];
    item10.tag = 1;
    item10.target = g_menuHandler;
    item10.state = NSControlStateValueOff; // Default
    [g_mainMenu addItem:item10];

    NSMenuItem *itemPomo = [[NSMenuItem alloc] initWithTitle:@"Pomodoro (25m/5m)" action:@selector(presetSelected:) keyEquivalent:@""];
    itemPomo.tag = 2;
    itemPomo.target = g_menuHandler;
    itemPomo.state = NSControlStateValueOff;
    [g_mainMenu addItem:itemPomo];

    [g_mainMenu addItem:[NSMenuItem separatorItem]];
    
    // Timer display toggle
    NSMenuItem *showTimerItem = [[NSMenuItem alloc] initWithTitle:@"Show Timer" action:@selector(toggleTimerDisplay:) keyEquivalent:@""];
    showTimerItem.target = g_menuHandler;
    showTimerItem.state = NSControlStateValueOff;
    [g_mainMenu addItem:showTimerItem];
    
    [g_mainMenu addItem:[NSMenuItem separatorItem]];

    // Version info (disabled item)
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (!version) version = @"1.0"; // Fallback
    NSString *versionStr = [NSString stringWithFormat:@"Version %@", version];
    NSMenuItem *versionItem = [[NSMenuItem alloc] initWithTitle:versionStr action:nil keyEquivalent:@""];
    [versionItem setEnabled:NO];
    [g_mainMenu addItem:versionItem];
    
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quitSelected:) keyEquivalent:@"q"];
    quitItem.target = g_menuHandler;
    [g_mainMenu addItem:quitItem];
    
    g_statusItem.menu = g_mainMenu;

    // Create Overlay Window
    NSRect screenRect = [[NSScreen mainScreen] frame];
    g_overlayWindow = [[NSWindow alloc] initWithContentRect:screenRect
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    [g_overlayWindow setLevel:NSFloatingWindowLevel]; // Ensures it stays on top
    [g_overlayWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.9]];
    [g_overlayWindow setOpaque:NO];
    [g_overlayWindow setIgnoresMouseEvents:NO];
    
    // Overlay Content
    NSView *contentView = [[NSView alloc] initWithFrame:screenRect];
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(0, screenRect.size.height/2 + 20, screenRect.size.width, 50)];
    [label setStringValue:@"Time to look around! Ideally look at something 20 ft/6m away."];
    [label setFont:[NSFont systemFontOfSize:40 weight:NSFontWeightBold]];
    [label setTextColor:[NSColor whiteColor]];
    [label setAlignment:NSTextAlignmentCenter];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [contentView addSubview:label];
    
    // Button configuration
    const CGFloat buttonWidth = 160;
    const CGFloat buttonHeight = 50;
    const CGFloat buttonSpacing = 20;
    const CGFloat buttonY = screenRect.size.height/2 - 80;
    
    // Center both buttons with spacing
    CGFloat totalWidth = (buttonWidth * 2) + buttonSpacing;
    CGFloat startX = (screenRect.size.width - totalWidth) / 2;
    
    NSButton *snoozeBtn = [NSButton buttonWithTitle:@"Snooze (+2m)" target:g_overlayController action:@selector(snoozeClicked:)];
    [snoozeBtn setFrame:NSMakeRect(startX, buttonY, buttonWidth, buttonHeight)];
    [snoozeBtn setBezelStyle:NSBezelStyleRounded];
    [snoozeBtn setFont:[NSFont systemFontOfSize:16]];
    [snoozeBtn setKeyEquivalent:@"\r"]; // Enter key
    [contentView addSubview:snoozeBtn];
    
    NSButton *skipBtn = [NSButton buttonWithTitle:@"Skip Break" target:g_overlayController action:@selector(skipClicked:)];
    [skipBtn setFrame:NSMakeRect(startX + buttonWidth + buttonSpacing, buttonY, buttonWidth, buttonHeight)];
    [skipBtn setBezelStyle:NSBezelStyleRounded];
    [skipBtn setFont:[NSFont systemFontOfSize:16]];
    [contentView addSubview:skipBtn];

    [g_overlayWindow setContentView:contentView];
}

void run_app(void) {
    [NSApp run];
}

void show_break_screen(bool visible) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (visible) {
            [g_overlayWindow makeKeyAndOrderFront:nil];
        } else {
            [g_overlayWindow orderOut:nil];
        }
    });
}

void update_timer_display(const char* text) {
    if (!text) return;
    NSString *str = [NSString stringWithUTF8String:text];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_statusItem && g_logoImage) {
            NSButton *button = g_statusItem.button;
            
            // Only update image/position if needed (prevents flickering)
            if (button.image != g_logoImage) {
                button.image = g_logoImage;
            }
            if (button.imagePosition != NSImageLeading) {
                button.imagePosition = NSImageLeading;
            }
            
            NSString *newTitle = g_showTimer ? str : @"";
            
            // Only update text/layout if it actually changed
            if (![button.title isEqualToString:newTitle]) {
                button.title = newTitle;
                g_statusItem.length = NSVariableStatusItemLength;
            }
        }
    });
}
