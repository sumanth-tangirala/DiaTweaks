#import "StdPatch/StdPatch.h"

extern DPPatch DPDockClickCycle;

// Oldest window first, so the order stays put while focus moves around.
static NSArray<NSWindow *> *DPCycleWindows(void) {
    NSMutableArray<NSWindow *> *windows = [NSMutableArray array];
    for (NSWindow *window in NSApp.windows)
        if (DPIsKind(window, DPDiaWindow) && window.visible && !window.miniaturized && window.level == NSNormalWindowLevel) [windows addObject:window];
    return [windows sortedArrayUsingComparator:^NSComparisonResult(NSWindow *a, NSWindow *b) {
        return [@(a.windowNumber) compare:@(b.windowNumber)];
    }];
}

static BOOL DPApp_shouldHandleReopen(id self, SEL _cmd, NSApplication *app, BOOL hasVisibleWindows) {
    NSArray<NSWindow *> *windows = DPDockClickCycle.on && hasVisibleWindows ? DPCycleWindows() : nil;
    if (windows.count < 2) return DPCallOriginal(DPApp_shouldHandleReopen, self, app, hasVisibleWindows);
    NSWindow *current = NSApp.keyWindow ?: NSApp.mainWindow;
    NSUInteger at = [windows indexOfObject:current];
    NSWindow *next = windows[at == NSNotFound ? 0 : (at + 1) % windows.count];
    [NSApp activateIgnoringOtherApps:YES];
    [next makeKeyAndOrderFront:nil];
    return NO;
}

static void DPInstallDockClickCycle(void) {
    DPHook(DPDiaAppDelegate, @selector(applicationShouldHandleReopen:hasVisibleWindows:), (IMP)DPApp_shouldHandleReopen);
}

DP_PATCH(DPDockClickCycle) {
    .key = @"dockClickCycle",
    .order = 99,
    .title = @"Dock Click Cycles Windows",
    .detail = @"Each click on Dia’s Dock icon brings the next Dia window to the front, in the order the windows were opened.",
    .symbol = @"rectangle.stack.fill",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaAppDelegate, DPDiaWindow),
    .install = DPInstallDockClickCycle,
};
