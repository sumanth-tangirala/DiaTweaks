#import "StdPatch/StdPatch.h"
#import "Patches/CommandBar/Tabs.h"

extern DPPatch DPBackClosesTab;
static char DPStateKey;

@interface DPBackState : NSObject
@property(strong) NSSet<NSString *> *knownIDs;
@property(copy) NSString *lastFrontID;
@property(strong) NSMutableDictionary<NSString *, NSString *> *originOf;
@end

@implementation DPBackState
@end

static NSArray<NSString *> *DPTabIDs(NSWindow *window) {
    return [[DPScriptWindow(window) valueForKey:@"appleScriptTabs"] valueForKey:@"tabId"] ?: @[];
}

// A tab that appears and comes to the front straight from another tab was opened by it.
static void DPNote(NSWindow *window) {
    NSString *active = DPActiveTabID(window);
    NSArray<NSString *> *ids = DPTabIDs(window);
    if (!active || !ids.count) return;
    DPBackState *state = DPGet(window, &DPStateKey);
    NSSet<NSString *> *now = [NSSet setWithArray:ids];
    if (!state) {
        state = [DPBackState new];
        state.originOf = [NSMutableDictionary dictionary];
        DPSet(window, &DPStateKey, state);
    } else if (![active isEqual:state.lastFrontID] && ![state.knownIDs containsObject:active] && [now containsObject:state.lastFrontID]) {
        state.originOf[active] = state.lastFrontID;
    }
    for (NSString *tab in state.originOf.allKeys)
        if (![now containsObject:tab] || ![now containsObject:state.originOf[tab]]) [state.originOf removeObjectForKey:tab];
    state.knownIDs = now;
    state.lastFrontID = active;
}

static NSMenuItem *DPBackItem(void) {
    for (NSMenuItem *top in NSApp.mainMenu.itemArray)
        for (NSMenuItem *item in top.submenu.itemArray)
            if ([item.keyEquivalent isEqualToString:@"["] && (item.keyEquivalentModifierMask & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand) return item;
    return nil;
}

static BOOL DPCanGoBack(NSMenuItem *back) {
    [back.menu update];
    return back.enabled;
}

static void DPContentPane_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContentPane_viewDidMoveToWindow, self);
    if (self.window && DPBackClosesTab.on) DPNote(self.window);
}

static void DPNewTabPage_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPNewTabPage_viewDidMoveToWindow, self);
    if (self.window && DPBackClosesTab.on) DPNote(self.window);
}

static void DPInstallBackClosesTab(void) {
    DPHook(DPDiaContentPane, @selector(viewDidMoveToWindow), (IMP)DPContentPane_viewDidMoveToWindow);
    DPHook(DPDiaNewTabPage, @selector(viewDidMoveToWindow), (IMP)DPNewTabPage_viewDidMoveToWindow);
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        NSWindow *window = event.window;
        if (!DPBackClosesTab.on || event.keyCode != 33 || flags != NSEventModifierFlagCommand || !window) return event;
        NSMenuItem *back = DPBackItem();
        NSString *active = DPActiveTabID(window);
        DPBackState *state = DPGet(window, &DPStateKey);
        id origin = DPScriptTab(window, state.originOf[active]);
        if (!back || !active || !origin || DPCanGoBack(back)) return event;
        id tab = DPScriptTab(window, active);
        if (!tab) return event;
        DPCloseTab(tab);
        DPFocusTab(origin);
        return nil;
    }];
}

static void DPApplyBackClosesTab(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows) {
        DPSet(window, &DPStateKey, nil);
        if (patch->on) DPNote(window);
    }
}

static NSString *DPVerifyBackClosesTab(DPPatch *patch) {
    return patch->on && !DPBackItem() ? @"Dia has no Back menu item on ⌘[" : nil;
}

DP_PATCH(DPBackClosesTab) {
    .key = @"backClosesTab",
    .order = 86,
    .title = @"Back Closes Opened Tabs",
    .detail = @"When a tab was opened from another tab and has nothing to go back to, ⌘[ closes it and returns you to the tab that opened it.",
    .symbol = @"arrow.uturn.backward.square.fill",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaContentPane, DPDiaNewTabPage),
    .install = DPInstallBackClosesTab,
    .apply = DPApplyBackClosesTab,
    .verify = DPVerifyBackClosesTab,
};
