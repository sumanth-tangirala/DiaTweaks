#import "StdPatch/StdPatch.h"

extern DPPatch DPRestoreFullScreen;

// Dia reopens each window that was in full screen and puts it back in full screen, but macOS takes one window into full
// screen at a time and drops a second request made during the first's animation. So with two full screen windows, the
// second comes back as an ordinary window on the first one's Space. This remembers which windows were in full screen and,
// once Dia has reopened them, puts back any that didn't make it, one after the other.

static NSString *const DPFullScreenKey = @"restoreFullScreenWindows";
static BOOL DPQuitting;
static NSInteger DPMoving;  // windows going into or out of full screen right now
static CFTimeInterval DPMovedAt;

static NSUserDefaults *DPDefaults(void) {
    static NSUserDefaults *defaults;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return defaults;
}

static BOOL DPFull(NSWindow *window) { return (window.styleMask & NSWindowStyleMaskFullScreen) != 0; }

static NSArray<NSWindow *> *DPBrowserWindows(void) {
    NSMutableArray *windows = [NSMutableArray array];
    for (NSWindow *window in NSApp.windows)
        if (DPIsKind(window, DPDiaWindow) && window.visible && window.identifier.length) [windows addObject:window];
    return windows;
}

// Kept up to date as windows go in and out of full screen, but not as Dia quits, when it takes them out to close them.
static void DPRemember(void) {
    if (DPQuitting) return;
    NSMutableArray *full = [NSMutableArray array];
    for (NSWindow *window in DPBrowserWindows()) if (DPFull(window)) [full addObject:window.identifier];
    [DPDefaults() setObject:full forKey:DPFullScreenKey];
}

static void DPPutBack(void) {
    NSArray<NSString *> *wanted = [DPDefaults() arrayForKey:DPFullScreenKey];
    if (!DPRestoreFullScreen.on || !wanted.count) return;
    NSMutableSet *asked = [NSMutableSet set];
    __block int ticks = 0;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) {
        // Dia takes a few seconds to reopen everything; after that, whatever's still out stays out.
        if (++ticks > 40) return [t invalidate];
        // A transition that failed never says it's over.
        if (DPMoving > 0 && CACurrentMediaTime() - DPMovedAt > 3) DPMoving = 0;
        if (DPMoving > 0) return;
        for (NSWindow *window in DPBrowserWindows()) {
            if (DPFull(window) || ![wanted containsObject:window.identifier] || [asked containsObject:window.identifier]) continue;
            [asked addObject:window.identifier];
            [window toggleFullScreen:nil];
            return;  // One at a time.
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

static void DPApp_terminate(NSApplication *self, SEL _cmd, id sender) {
    DPQuitting = YES;
    DPCallOriginal(DPApp_terminate, self, sender);
}

static void DPInstallRestoreFullScreen(void) {
    DPHook("BrowserCrApplication", @selector(terminate:), (IMP)DPApp_terminate);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[ NSWindowWillEnterFullScreenNotification, NSWindowWillExitFullScreenNotification ])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            DPMoving++;
            DPMovedAt = CACurrentMediaTime();
        }];
    for (NSNotificationName name in @[ NSWindowDidEnterFullScreenNotification, NSWindowDidExitFullScreenNotification ])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            DPMoving = MAX(0, DPMoving - 1);
            // A moment later, when a quit would have shown itself: windows gone or going.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSWindow *window = note.object;
                if (window.visible) DPRemember();
            });
        }];
    [center addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *note) { DPQuitting = YES; }];
    // What was remembered last time, read before this launch's windows overwrite it.
    dispatch_async(dispatch_get_main_queue(), ^{ DPPutBack(); });
}

DP_PATCH(DPRestoreFullScreen) {
    .key = @"restoreFullScreen",
    .order = 97,
    .title = @"Reopen Every Window in Full Screen",
    .detail = @"When Dia reopens two or more windows that were in full screen, macOS only takes the first back into full screen, and the others open as ordinary windows on its Space. This puts each back in a full screen of its own.",
    .symbol = @"arrow.up.left.and.arrow.down.right",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .install = DPInstallRestoreFullScreen,
};
