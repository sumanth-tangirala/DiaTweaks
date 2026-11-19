#import "StdPatch/StdPatch.h"
#import "Patches/HideToolbar/HideToolbar.h"

extern DPPatch DPMenuBarWithoutSidebar;

// Dia slides the sidebar in as far as this says the menu bar has come down; the menu bar itself is macOS's.
#define DPMenuBarReveal "_TtC6WindowP33_AF99D7BC382DAD29E4F0826583F4711D44MenuBarRevealTrackingAccessoryViewController"

// With the sidebar kept away, the window buttons come down under the menu bar in a strip of their own, as in other apps.
static const CGFloat DPLightsHeight = 28;
static char DPRevealKey, DPLightsKey;

static BOOL DPFullScreen(NSWindow *window) { return (window.styleMask & NSWindowStyleMaskFullScreen) != 0; }

// The accessory lives in the titlebar, which full screen moves to a window of its own, so find the Dia window it belongs to.
static NSWindow *DPDiaWindowFor(NSViewController *accessory) {
    NSWindow *host = accessory.viewIfLoaded.window;
    if (DPIsKind(host, DPDiaWindow)) return host;
    for (NSWindow *window in NSApp.windows)
        if (DPIsKind(window, DPDiaWindow) && DPFullScreen(window) && (!host || window.screen == host.screen)) return window;
    return nil;
}

// How far down the menu bar is over this window, in points. Dia may report a fraction or points, so both are read.
static double DPRevealPoints(NSWindow *window) {
    double raw = [DPGet(window, &DPRevealKey) doubleValue];
    CGFloat height = NSApp.mainMenu.menuBarHeight ?: 24;
    return raw <= 1 ? raw * height : MIN(raw, height);
}

static BOOL DPShowsLights(NSWindow *window) { return DPMenuBarWithoutSidebar.on && DPFullScreen(window) && DPRevealPoints(window) > 0.5; }

// What sits over the top of the page while the menu bar is down: the menu bar and the strip with the window buttons.
double DPMenuBarInset(NSWindow *window) {
    if (!DPFullScreen(window)) return 0;
    double points = DPRevealPoints(window);
    CGFloat height = NSApp.mainMenu.menuBarHeight ?: 24;
    return points + (DPShowsLights(window) ? DPLightsHeight * MIN(1, points / height) : 0);
}

@interface DPLightsStrip : NSView
@property (nonatomic, strong) NSArray<NSButton *> *buttons;
@property (nonatomic) BOOL hovering;
@end

@implementation DPLightsStrip

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    NSVisualEffectView *background = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    background.material = NSVisualEffectMaterialTitlebar;
    background.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    background.state = NSVisualEffectStateActive;
    background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:background];
    NSWindowStyleMask mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    NSButton *close = [NSWindow standardWindowButton:NSWindowCloseButton forStyleMask:mask];
    NSButton *minimize = [NSWindow standardWindowButton:NSWindowMiniaturizeButton forStyleMask:mask];
    NSButton *zoom = [NSWindow standardWindowButton:NSWindowZoomButton forStyleMask:mask];
    close.target = self;
    close.action = @selector(closeWindow:);
    minimize.enabled = NO;  // A full screen window can't be minimised.
    zoom.target = self;
    zoom.action = @selector(leaveFullScreen:);
    _buttons = @[close, minimize, zoom];
    for (NSButton *button in _buttons) [self addSubview:button];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)layout {
    [super layout];
    CGFloat x = 12;
    for (NSButton *button in self.buttons) {
        NSSize size = button.frame.size;
        button.frame = NSMakeRect(x, round((NSHeight(self.bounds) - size.height) / 2), size.width, size.height);
        x += 20;
    }
}

- (void)closeWindow:(id)sender { [self.window performClose:sender]; }
- (void)leaveFullScreen:(id)sender { [self.window toggleFullScreen:sender]; }

// AppKit asks the buttons' container whether to draw their symbols.
- (BOOL)_mouseInGroup:(NSButton *)button { return self.hovering; }

- (void)setHovering:(BOOL)hovering {
    _hovering = hovering;
    for (NSButton *button in self.buttons) button.needsDisplay = YES;
}

- (void)mouseEntered:(NSEvent *)event { self.hovering = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovering = NO; }

@end

static void DPUpdateLights(NSWindow *window) {
    DPLightsStrip *strip = DPGet(window, &DPLightsKey);
    if (!DPShowsLights(window)) {
        strip.hidden = YES;
        return;
    }
    NSView *host = window.contentView;
    if (!strip) {
        strip = [[DPLightsStrip alloc] initWithFrame:NSZeroRect];
        DPSet(window, &DPLightsKey, strip);
    }
    if (strip.superview != host || host.subviews.lastObject != strip) [host addSubview:strip positioned:NSWindowAbove relativeTo:nil];
    strip.autoresizingMask = NSViewWidthSizable | (host.isFlipped ? NSViewMaxYMargin : NSViewMinYMargin);  // Follows the window to another display.
    double points = DPRevealPoints(window);
    CGFloat height = NSApp.mainMenu.menuBarHeight ?: 24;
    NSRect frame = NSMakeRect(0, host.isFlipped ? points : NSHeight(host.bounds) - points - DPLightsHeight, NSWidth(host.bounds), DPLightsHeight);
    if (!NSEqualRects(strip.frame, frame)) strip.frame = frame;
    strip.hidden = NO;
    strip.alphaValue = MIN(1, points / height);
}

static void DPSettle(NSWindow *window);

static void DPReveal_setRevealAmount(NSViewController *self, SEL _cmd, double amount) {
    NSWindow *window = DPDiaWindowFor(self);
    BOOL changed = window && amount != [DPGet(window, &DPRevealKey) doubleValue];
    if (window) DPSet(window, &DPRevealKey, @(amount));
    DPCallOriginal(DPReveal_setRevealAmount, self, DPMenuBarWithoutSidebar.on ? 0 : amount);
    if (!changed) return;
    DPUpdateLights(window);
    // A minimal toolbar that's open moves down with the menu bar.
    if (DPMinimalToolbar.on) dispatch_async(dispatch_get_main_queue(), ^{ DPRelayoutPanes(); });
    if (amount > 0) DPSettle(window);
}

// macOS doesn't always say the menu bar has gone back up: leaving the Space or the app with it down leaves Dia's last
// word on it as "down", and the window buttons would stay. So it's taken as gone when any of those happen, or once the
// pointer has been well clear of the top for a moment with no menu open.
static BOOL DPMenuOpen;

static void DPForget(NSWindow *window) {
    if (![DPGet(window, &DPRevealKey) doubleValue]) return;
    DPSet(window, &DPRevealKey, @0);
    DPUpdateLights(window);
    if (DPMinimalToolbar.on) dispatch_async(dispatch_get_main_queue(), ^{ DPRelayoutPanes(); });
}

static void DPForgetAll(void) {
    for (NSWindow *window in NSApp.windows) if (DPIsKind(window, DPDiaWindow)) DPForget(window);
}

static char DPSettleKey;

static void DPSettle(NSWindow *window) {
    if (DPGet(window, &DPSettleKey)) return;
    __weak NSWindow *weak = window;
    __block int clear = 0;
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) {
        NSWindow *window = weak;
        if (!window || ![DPGet(window, &DPRevealKey) doubleValue]) {
            if (window) DPSet(window, &DPSettleKey, nil);
            return [t invalidate];
        }
        CGFloat menuBar = NSApp.mainMenu.menuBarHeight ?: 24, top = NSMaxY(window.screen.frame);
        BOOL away = NSEvent.mouseLocation.y < top - menuBar - DPLightsHeight - 60 && !DPMenuOpen && !NSEvent.pressedMouseButtons;
        clear = away ? clear + 1 : 0;
        if (clear < 3) return;
        DPSet(window, &DPSettleKey, nil);
        [t invalidate];
        DPForget(window);
    }];
    DPSet(window, &DPSettleKey, timer);
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
}

static void DPInstallMenuBarWithoutSidebar(void) {
    DPHook(DPMenuBarReveal, @selector(setRevealAmount:), (IMP)DPReveal_setRevealAmount);
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:NSWorkspaceActiveSpaceDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPForgetAll(); }];
    for (NSNotificationName name in @[ NSApplicationDidResignActiveNotification, NSApplicationDidBecomeActiveNotification, NSWindowDidExitFullScreenNotification ])
        [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPForgetAll(); }];
    [center addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPMenuOpen = YES; }];
    [center addObserverForName:NSMenuDidEndTrackingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { DPMenuOpen = NO; }];
}

static void DPApplyMenuBarWithoutSidebar(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows) if (DPIsKind(window, DPDiaWindow)) DPUpdateLights(window);
}

static NSString *DPVerifyMenuBarWithoutSidebar(DPPatch *patch) {
    Class reveal = objc_getClass(DPMenuBarReveal);
    return [reveal instancesRespondToSelector:@selector(setRevealAmount:)] ? nil : @"Dia's full screen menu bar tracker has no setRevealAmount:";
}

DP_PATCH(DPMenuBarWithoutSidebar) {
    .key = @"menuBarWithoutSidebar",
    .order = 98,
    .title = @"Menu Bar Without Sidebar",
    .detail = @"In full screen, the menu bar still comes down when the pointer reaches the top, but the sidebar no longer slides in with it. The window buttons come down under the menu bar instead.",
    .symbol = @"menubar.rectangle",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPMenuBarReveal),
    .install = DPInstallMenuBarWithoutSidebar,
    .apply = DPApplyMenuBarWithoutSidebar,
    .verify = DPVerifyMenuBarWithoutSidebar,
};
