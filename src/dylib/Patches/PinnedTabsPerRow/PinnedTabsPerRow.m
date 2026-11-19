#import "StdPatch/StdPatch.h"
#import <objc/runtime.h>

extern DPPatch DPPinnedTabsPerRow;

// The icon row at the top of the sidebar: Dia calls it the tab dock, and sets its row length from these limits.
#define DPDiaTabDock "_TtC10TabSurface11TabDockView"
static char DPOriginalKey;

static NSInteger DPWantedPerRow(void) { return DPPinnedTabsPerRow.on ? DPChoice(&DPPinnedTabsPerRow).integerValue : 0; }

static NSMenu *DPPerRowChoices(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Per Row"];
    for (NSInteger count = 3; count <= 12; count++)
        [menu addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)count] action:nil keyEquivalent:@""].representedObject = [NSString stringWithFormat:@"%ld", (long)count];
    return menu;
}

#define DPDiaTabList "_TtC7TabList11TabListView"

// Dia fits as many icons as its minimum width allows. Sizing that minimum to the row makes exactly `count` fit, and Dia's own
// layout spreads them across the width. The maximum items per row is an optional Swift Int, so it's left alone.
// Returns whether the minimum changed, so whoever reserved the row's height measures it again.
static BOOL DPSizeDock(NSView *dock, CGFloat width) {
    double *minWidth = DPIvar(dock, "minimumItemWidth"), *spacing = DPIvar(dock, "interItemSpacing"), *insets = DPIvar(dock, "contentInsets");
    if (!minWidth || !spacing || !insets) return NO;
    NSNumber *original = DPGet(dock, &DPOriginalKey);
    if (!original) DPSet(dock, &DPOriginalKey, original = @(*minWidth));
    NSInteger count = DPWantedPerRow();
    double available = width - insets[1] - insets[3];  // left and right of NSEdgeInsets
    double want = count > 0 && available > 0 ? MAX(8, floor((available - (count - 1) * *spacing) / count) - 0.5) : original.doubleValue;
    if (fabs(*minWidth - want) < 0.01) return NO;
    *minWidth = want;
    return YES;
}

static NSView *DPDockIn(NSView *list) {
    return DPFindView(list, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabDock); });
}

// The tab list reserves room for the icon rows before they lay out, so it must see the new size first and measure again.
static void DPRemeasure(NSView *list) {
    if (!list) return;
    NSCollectionView *collection = (NSCollectionView *)DPFindView(list, ^BOOL(NSView *view) { return [view isKindOfClass:NSCollectionView.class]; });
    [collection.collectionViewLayout invalidateLayout];
    list.needsLayout = YES;
}

static void DPList_layout(NSView *self, SEL _cmd) {
    NSView *dock = DPDockIn(self);
    if (dock) DPSizeDock(dock, NSWidth(dock.bounds) > 0 ? NSWidth(dock.bounds) : NSWidth(self.bounds));
    DPCallOriginal(DPList_layout, self);
}

static void DPDock_layout(NSView *self, SEL _cmd) {
    if (DPSizeDock(self, NSWidth(self.bounds))) {
        NSView *list = self.superview;
        while (list && !DPIsKind(list, DPDiaTabList)) list = list.superview;
        dispatch_async(dispatch_get_main_queue(), ^{ DPRemeasure(list); });
    }
    DPCallOriginal(DPDock_layout, self);
}

static void DPApplyPinnedTabsPerRow(DPPatch *patch) {
    for (NSView *list in DPFindViews(DPDiaTabList)) {
        NSView *dock = DPDockIn(list);
        if (dock) DPSizeDock(dock, NSWidth(dock.bounds));
        dock.needsLayout = YES;
        DPRemeasure(list);
    }
}

static NSString *DPVerifyPinnedTabsPerRow(DPPatch *patch) {
    for (NSView *dock in DPFindViews(DPDiaTabDock)) {
        double *minWidth = DPIvar(dock, "minimumItemWidth"), *spacing = DPIvar(dock, "interItemSpacing"), *insets = DPIvar(dock, "contentInsets");
        if (!minWidth || !spacing || !insets) return @"the pinned tabs row has no size limits to set";
        double available = NSWidth(dock.bounds) - insets[1] - insets[3];
        NSInteger count = DPWantedPerRow();
        if (count > 0 && available > 0 && *minWidth * count + (count - 1) * *spacing > available) return @"fewer icons fit per row than chosen";
    }
    return nil;
}

static void DPInstallPinnedTabsPerRow(void) {
    DPHook(DPDiaTabDock, @selector(layout), (IMP)DPDock_layout);
    DPHook(DPDiaTabList, @selector(layout), (IMP)DPList_layout);
}

DP_PATCH(DPPinnedTabsPerRow) {
    .key = @"pinnedTabsPerRow",
    .order = 79,
    .title = @"Pinned Tabs per Row",
    .detail = @"Choose how many icons sit in each row of the pinned tabs at the top of the sidebar.",
    .symbol = @"square.grid.3x1.below.line.grid.1x2",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses(DPDiaTabDock, DPDiaTabList),
    .choice = @"pinnedTabsPerRowChoice",
    .defaultChoice = @"6",
    .choices = DPPerRowChoices,
    .install = DPInstallPinnedTabsPerRow,
    .apply = DPApplyPinnedTabsPerRow,
    .verify = DPVerifyPinnedTabsPerRow,
};
