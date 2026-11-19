#import "Patches/UnloadTab/Recent.h"

static NSMapTable<NSWindow *, NSMutableArray<NSString *> *> *DPRecent;

static void DPNoteFront(NSWindow *window) {
    NSString *active = window && DPUnloadTab.on ? DPActiveTabID(window) : nil;
    if (!active) return;
    NSMutableArray *recent = [DPRecent objectForKey:window];
    if (!recent) [DPRecent setObject:(recent = [NSMutableArray array]) forKey:window];
    [recent removeObject:active];
    [recent addObject:active];
    if (recent.count > 20) [recent removeObjectAtIndex:0];
}

static char DPPendingKey;

// Reading the tabs takes Dia ~20 ms, too long to do while it switches tabs, so the front tab is noted just after, once
// for a burst of switches; anything that needs the order takes a note still owed first.
static void DPNoteFrontSoon(NSWindow *window) {
    if (!window || DPGet(window, &DPPendingKey)) return;
    DPSet(window, &DPPendingKey, @YES);
    __weak NSWindow *weak = window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSWindow *window = weak;
        if (!window || !DPGet(window, &DPPendingKey)) return;
        DPSet(window, &DPPendingKey, nil);
        DPNoteFront(window);
    });
}

static void DPNoteFrontOwed(NSWindow *window) {
    if (!DPGet(window, &DPPendingKey)) return;
    DPSet(window, &DPPendingKey, nil);
    DPNoteFront(window);
}

id DPTabBefore(NSWindow *window) {
    DPTabsMemoScope;
    DPNoteFrontOwed(window);
    NSString *active = DPActiveTabID(window);
    NSArray *tabs = [DPScriptWindow(window) valueForKey:@"appleScriptTabs"];
    NSArray<NSString *> *ids = [tabs valueForKey:@"tabId"];
    for (NSString *tabID in [DPRecent objectForKey:window].reverseObjectEnumerator) {
        NSUInteger i = [tabID isEqual:active] ? NSNotFound : [ids indexOfObject:tabID];
        if (i != NSNotFound) return tabs[i];
    }
    NSUInteger i = active ? [ids indexOfObject:active] : NSNotFound;
    if (i == NSNotFound) return nil;
    return i + 1 < tabs.count ? tabs[i + 1] : i > 0 ? tabs[i - 1] : nil;
}

void DPForgetFrontTab(NSWindow *window) {
    DPTabsMemoScope;
    DPNoteFrontOwed(window);
    NSString *active = DPActiveTabID(window);
    if (active) [[DPRecent objectForKey:window] removeObject:active];
}

static void DPContentPane_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContentPane_viewDidMoveToWindow, self);
    DPNoteFrontSoon(self.window);
}

void DPWatchFrontTabs(void) {
    DPRecent = [NSMapTable weakToStrongObjectsMapTable];
    DPHook(DPDiaContentPane, @selector(viewDidMoveToWindow), (IMP)DPContentPane_viewDidMoveToWindow);
}
