#import "HideToolbar.h"
#import "Patches/CommandBar/Tabs.h"

// From the top edge: the gap is where the pointer finds the menu bar. The page starts after the gap and a thin band, while the
// toolbar opens when the pointer is in the taller zone below the gap, which reaches over the top of the page.
static const CGFloat DPGapHeight = 8, DPBandHeight = 16, DPActivationHeight = 24;
// Opening is quick; closing waits longer, so the toolbar doesn't flicker as the pointer passes.
static const NSTimeInterval DPOpenDelay = 0.04, DPCloseDelay = 0.2;

double DPMenuBarInset(NSWindow *window);  // The menu bar and the window buttons' strip, while they're down in full screen.

static NSUserDefaults *DPMinimalDefaults(void) { return [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; }
// The shortcut swaps the strip for no bar at all, and back, without turning the tweak off.
static BOOL DPMinimalPaused(void) { return [DPMinimalDefaults() boolForKey:@"minimalToolbarPaused"]; }
static NSDictionary *DPDefaultMinimalShortcut(void) { return @{ @"keyCode" : @2, @"modifiers" : @(NSEventModifierFlagCommand | NSEventModifierFlagShift), @"key" : @"D" }; }

static BOOL DPMinimalWanted(NSView *pane) {
    NSWindow *window = pane.window;
    return DPMinimalToolbar.on && !DPMinimalPaused() && DPHideToolbar.on && window && DPSubview(pane, DPDiaToolbar);
}

// How much of the minimal bar there is right now: eased in and out as it's turned on or off.
static CGFloat DPFactor(NSView *pane) { return [DPToolbarHover forPane:pane].minimalProgress; }

// The gap closes as the toolbar opens, so it sits flush to the top, or just below the menu bar while that's down.
CGFloat DPMinimalGap(NSView *pane) {
    CGFloat factor = DPFactor(pane);
    if (factor <= 0) return 0;
    CGFloat open = [DPToolbarHover forPane:pane].inPlaceProgress;
    return (DPGapHeight * (1 - open) + ceil(DPMenuBarInset(pane.window)) * open) * factor;
}

CGFloat DPMinimalStripHeight(NSView *pane) { return DPBandHeight * DPFactor(pane); }

static BOOL DPPointerInStrip(NSView *strip) {
    NSWindow *window = strip.window;
    NSPoint point = [strip convertPoint:[window convertPointFromScreen:NSEvent.mouseLocation] fromView:nil];
    return NSMouseInRect(point, strip.bounds, strip.isFlipped);
}

static NSString *DPActiveSite(NSWindow *window) {
    id tab = [DPScriptWindow(window) valueForKey:@"activeTab"];
    NSString *address = [[tab valueForKey:@"URL"] description];
    NSString *host = address.length ? [NSURL URLWithString:address].host : nil;
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    return host.length ? host : (address.length ? address : @"New Tab");
}

// The site's name, with no background. The view also watches for the pointer and lets every click through to the toolbar under it.
@interface DPMinimalStrip : NSView
@property (nonatomic, weak) NSView *pane;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, strong) NSTimer *refresh;
@property (nonatomic, copy) NSString *seenTitle;
@property (nonatomic) BOOL siteSoon;
@property (nonatomic, strong) NSTrackingArea *area;
@property (nonatomic, strong) NSTimer *openTimer;
@end

@implementation DPMinimalStrip

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    _label.textColor = NSColor.secondaryLabelColor;
    _label.alignment = NSTextAlignmentCenter;
    _label.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self addSubview:_label];
    __weak DPMinimalStrip *weak = self;
    _refresh = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        if (!weak.superview) return [timer invalidate];
        [weak update];
    }];
    return self;
}

- (void)dealloc { [_refresh invalidate]; }

- (void)update {
    // Dia picks the toolbar's light or dark look to suit the page; the address follows it.
    NSView *bar = DPSubview(self.pane, DPDiaToolbar);
    if (bar && self.appearance != bar.effectiveAppearance) self.appearance = bar.effectiveAppearance;
    // Asking Dia for the active tab takes ~20 ms, so only when the window's title says the page may have changed, and a
    // moment later, so a quick run of changes, like a new tab opening, is asked about once, after it's over.
    NSWindow *window = self.pane.window;
    NSString *title = window.title ?: @"";
    if ((self.label.stringValue.length && [title isEqual:self.seenTitle]) || self.siteSoon) return;
    self.siteSoon = YES;
    __weak DPMinimalStrip *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DPMinimalStrip *strip = weak;
        NSWindow *window = strip.pane.window;
        strip.siteSoon = NO;
        if (!strip || !window) return;
        strip.seenTitle = window.title ?: @"";
        NSString *site = DPActiveSite(window);
        if (![strip.label.stringValue isEqual:site]) strip.label.stringValue = site;
    });
}

// The text is centred across the gap and the band together, which is the strip of window colour you see above the page.
- (void)layout {
    [super layout];
    CGFloat centre = (DPGapHeight + DPBandHeight) / 2 - DPGapHeight;  // from this view's top edge, negative when above it
    // Lowercase text has its weight below the line box's middle, so the box sits a little lower to look centred.
    centre += 2;
    CGFloat top = self.isFlipped ? centre - DPBandHeight / 2 : NSHeight(self.bounds) - centre - DPBandHeight / 2;
    self.label.frame = NSMakeRect(40, top, MAX(0, NSWidth(self.bounds) - 80), DPBandHeight);
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.area) [self removeTrackingArea:self.area];
    self.area = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow owner:self userInfo:nil];
    [self addTrackingArea:self.area];
}

- (void)mouseExited:(NSEvent *)event {
    [self.openTimer invalidate];
    self.openTimer = nil;
}

- (void)mouseEntered:(NSEvent *)event {
    DPToolbarHover *hover = [DPToolbarHover forPane:self.pane];
    if (!DPMinimalToolbar.on || !hover || hover.minimalExpanded || self.openTimer) return;
    __weak DPMinimalStrip *weak = self;
    self.openTimer = [NSTimer scheduledTimerWithTimeInterval:DPOpenDelay repeats:NO block:^(NSTimer *timer) {
        DPMinimalStrip *me = weak;
        me.openTimer = nil;
        if (me && DPPointerInStrip(me)) [me open];
    }];
}

- (void)open {
    DPToolbarHover *hover = [DPToolbarHover forPane:self.pane];
    hover.minimalExpanded = YES;
    DPApplyToolbar(self.pane);
    [hover.collapseTimer invalidate];
    __weak DPToolbarHover *weak = hover;
    __block NSTimeInterval outsideSince = 0;
    hover.collapseTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES block:^(NSTimer *timer) {
        DPToolbarHover *me = weak;
        NSView *pane = me.pane;
        if (!me || !pane.window || !me.minimalExpanded) return [timer invalidate];
        // Anywhere above the toolbar's bottom edge counts as inside, the menu bar's strip too.
        NSRect bars = NSUnionRect(me.bar.frame, me.bookmarks ? me.bookmarks.frame : me.bar.frame);
        NSPoint point = [pane convertPoint:[pane.window convertPointFromScreen:NSEvent.mouseLocation] fromView:nil];
        NSResponder *responder = pane.window.firstResponder;
        if ([responder isKindOfClass:NSTextView.class] && ((NSTextView *)responder).isFieldEditor) responder = (NSResponder *)((NSTextView *)responder).delegate;
        BOOL typing = [responder isKindOfClass:NSView.class] && [(NSView *)responder isDescendantOf:me.bar];
        BOOL inside = DPTop(pane, NSMakeRect(point.x, point.y, 0, 0)) <= DPBottom(pane, bars) + 2;
        if (inside || typing || NSEvent.pressedMouseButtons) {
            outsideSince = 0;
            return;
        }
        NSTimeInterval now = CACurrentMediaTime();
        if (!outsideSince) outsideSince = now;
        if (now - outsideSince < DPCloseDelay) return;
        [timer invalidate];
        me.collapseTimer = nil;
        me.minimalExpanded = NO;
        DPApplyToolbar(pane);
    }];
}

@end

static void DPAnimateMinimal(NSView *pane, DPToolbarHover *hover, BOOL on) {
    [hover.minimalAnimation invalidate];
    CGFloat from = hover.minimalProgress, to = on;
    CFTimeInterval start = CACurrentMediaTime();
    __weak NSView *weakPane = pane;
    hover.minimalAnimation = [NSTimer timerWithTimeInterval:1.0 / 120 repeats:YES block:^(NSTimer *timer) {
        NSView *pane = weakPane;
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        if (!hover) return [timer invalidate];
        CGFloat t = MIN(1, (CACurrentMediaTime() - start) / 0.22);
        hover.minimalProgress = from + (to - from) * t * t * (3 - 2 * t);
        if (t == 1) {
            [timer invalidate];
            hover.minimalAnimation = nil;
        }
        DPApplyToolbar(pane);
    }];
    [NSRunLoop.mainRunLoop addTimer:hover.minimalAnimation forMode:NSRunLoopCommonModes];
}

void DPUpdateMinimalStrip(NSView *pane, DPToolbarHover *hover) {
    BOOL wanted = DPMinimalWanted(pane);
    if (hover.minimalTarget != wanted) {
        BOOL first = hover.minimalTarget < 0;
        hover.minimalTarget = wanted;
        if (first || !pane.window) {
            [hover.minimalAnimation invalidate];
            hover.minimalAnimation = nil;
            hover.minimalProgress = wanted;
        } else {
            DPAnimateMinimal(pane, hover, wanted);
        }
    }
    CGFloat height = DPMinimalStripHeight(pane);
    DPMinimalStrip *strip = (DPMinimalStrip *)hover.strip;
    if (!height) {
        [strip removeFromSuperview];
        hover.strip = nil;
        if (hover.minimalExpanded) {
            hover.minimalExpanded = NO;
            [hover.collapseTimer invalidate];
        }
        return;
    }
    if (!strip) {
        strip = [[DPMinimalStrip alloc] initWithFrame:NSZeroRect];
        strip.pane = pane;
        hover.strip = strip;
        [strip update];
    }
    if (strip.superview != pane || pane.subviews.lastObject != strip) [pane addSubview:strip positioned:NSWindowAbove relativeTo:nil];
    NSRect frame = NSMakeRect(0, pane.isFlipped ? DPGapHeight : NSHeight(pane.bounds) - DPGapHeight - DPActivationHeight, NSWidth(pane.bounds), DPActivationHeight);
    if (!NSEqualRects(strip.frame, frame)) strip.frame = frame;
    strip.hidden = hover.inPlaceProgress > 0;
    strip.alphaValue = hover.minimalProgress;
}

static NSString *DPVerifyMinimal(DPPatch *patch) {  // The strip shows wherever Hide Toolbar does, in a window or in full screen.
    for (NSView *pane in DPFindViews(DPDiaContentPane)) {
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        if (hover.minimalAnimation) continue;
        BOOL expect = DPMinimalWanted(pane);
        if (expect != (hover.strip != nil)) return expect ? @"no minimal bar shows" : @"a minimal bar shows while it's off";
    }
    return nil;
}

// Leaving the window, or Dia, closes an open toolbar even if the address field still has focus.
static void DPCollapseOpen(NSWindow *window) {
    for (NSView *pane in DPPanes.allObjects) {
        DPToolbarHover *hover = [DPToolbarHover forPane:pane];
        if (!hover.minimalExpanded || (window && pane.window != window)) continue;
        [hover.collapseTimer invalidate];
        hover.collapseTimer = nil;
        hover.minimalExpanded = NO;
        DPApplyToolbar(pane);
    }
}

static void DPInstallMinimal(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidResignKeyNotification object:nil queue:nil usingBlock:^(NSNotification *note) { DPCollapseOpen(note.object); }];
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) { DPCollapseOpen(nil); }];
    NSArray<NSNotificationName> *names = @[NSWindowDidEnterFullScreenNotification, NSWindowDidExitFullScreenNotification];
    for (NSNotificationName name in names)
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) { DPRelayoutPanes(); }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (!DPMinimalToolbar.on || !DPShortcutMatches(event, &DPMinimalToolbar)) return event;
        if (!event.isARepeat) {
            [DPMinimalDefaults() setBool:!DPMinimalPaused() forKey:@"minimalToolbarPaused"];
            DPRelayoutPanes();
        }
        return nil;
    }];
}

DP_PATCH(DPMinimalToolbar) {
    .key = @"minimalToolbar",
    .order = 45,
    .title = @"Minimal Address Bar",
    .detail = @"Show the site’s name in a thin band at the top, under a small gap where the menu bar still comes down in full screen, and open the toolbar in place when you point just below it, pushing the page down. ⇧⌘D, unless you set another, swaps this for no bar at all and back.",
    .symbol = @"capsule.fill",
    .tint = @"systemIndigoColor",
    .requires = @"hideToolbar",
    .section = @"Showing the Toolbar",
    .install = DPInstallMinimal,
    .shortcut = @"minimalToolbarShortcut",
    .defaultShortcut = DPDefaultMinimalShortcut,
    .apply = DPApplyRelayoutPanes,
    .verify = DPVerifyMinimal,
};
