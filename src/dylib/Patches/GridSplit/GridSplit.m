#import "StdPatch/StdPatch.h"

extern DPPatch DPGridSplit;

// Dia lays a split's panes out in one row (or one column). With four panes this puts them in a 2×2 grid, and with three
// gives one pane a whole column or row and stacks the other two beside it. Dia still owns the panes; this only moves them
// after each of its layouts.
#define DPDiaSplitController "_TtC5ARCUI19SplitViewController"
#define DPDiaSplitPaneView "_TtC5ARCUI24SplitViewContentPaneView"

static char DPHiddenHandlesKey, DPOrderKey, DPGapKey;

static NSMenu *DPGridChoices(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Three Panes"];
    for (NSArray *item in @[ @[ @"One Column on the Left", @"left" ], @[ @"One Column on the Right", @"right" ], @[ @"One Row on Top", @"top" ],
                             @[ @"One Row at the Bottom", @"bottom" ], @[ @"Side by Side, as Dia Does", @"row" ] ]) {
        NSMenuItem *entry = [[NSMenuItem alloc] initWithTitle:item[0] action:nil keyEquivalent:@""];
        entry.representedObject = item[1];
        [menu addItem:entry];
    }
    return menu;
}

// The panes in Dia's order, which is the order it lays them out in.
static NSArray<NSView *> *DPPanes(NSView *view) {
    NSMutableArray<NSView *> *panes = [NSMutableArray array];
    for (NSView *sub in view.subviews) if (DPIsKind(sub, DPDiaSplitPaneView) && !sub.hidden) [panes addObject:sub];
    return panes;
}

static NSArray<NSValue *> *DPGridFrames(NSRect area, CGFloat gap, NSUInteger count, NSString *three, BOOL flipped) {
    CGFloat halfW = floor((NSWidth(area) - gap) / 2), halfH = floor((NSHeight(area) - gap) / 2);
    CGFloat left = NSMinX(area), right = NSMinX(area) + halfW + gap, rightW = NSWidth(area) - halfW - gap;
    // Top and bottom in the view's own terms.
    CGFloat topY = flipped ? NSMinY(area) : NSMaxY(area) - halfH, bottomY = flipped ? NSMinY(area) + halfH + gap : NSMinY(area);
    CGFloat bottomH = NSHeight(area) - halfH - gap;
    NSRect tl = NSMakeRect(left, topY, halfW, halfH), tr = NSMakeRect(right, topY, rightW, halfH);
    NSRect bl = NSMakeRect(left, bottomY, halfW, bottomH), br = NSMakeRect(right, bottomY, rightW, bottomH);
    if (!flipped) {
        // Unflipped, the top row is the higher one: it takes the rounding's leftover height.
        tl.size.height = tr.size.height = NSHeight(area) - halfH - gap;
        tl.origin.y = tr.origin.y = NSMaxY(area) - tl.size.height;
        bl.size.height = br.size.height = halfH;
    }
    NSRect leftColumn = NSMakeRect(left, NSMinY(area), halfW, NSHeight(area)), rightColumn = NSMakeRect(right, NSMinY(area), rightW, NSHeight(area));
    NSRect topRow = NSMakeRect(left, NSMinY(tl), NSWidth(area), NSHeight(tl)), bottomRow = NSMakeRect(left, NSMinY(bl), NSWidth(area), NSHeight(bl));
    NSArray<NSValue *> *(^frames)(NSRect, NSRect, NSRect) = ^(NSRect a, NSRect b, NSRect c) {
        return @[ [NSValue valueWithRect:a], [NSValue valueWithRect:b], [NSValue valueWithRect:c] ];
    };
    if (count == 4) return @[ [NSValue valueWithRect:tl], [NSValue valueWithRect:tr], [NSValue valueWithRect:bl], [NSValue valueWithRect:br] ];
    if ([three isEqual:@"left"]) return frames(leftColumn, tr, br);
    if ([three isEqual:@"right"]) return frames(tl, bl, rightColumn);
    if ([three isEqual:@"top"]) return frames(topRow, bl, br);
    if ([three isEqual:@"bottom"]) return frames(tl, tr, bottomRow);
    return nil;
}

// Dia's handles for dragging a pane's width sit between the panes in a row, which a grid doesn't have: hidden, so they
// can't be seen or grabbed.
static void DPShowHandles(NSView *view, BOOL show) {
    NSHashTable *hidden = DPGet(view, &DPHiddenHandlesKey);
    if (show) {
        for (NSView *handle in hidden) handle.hidden = NO;
        return DPSet(view, &DPHiddenHandlesKey, nil);
    }
    if (!hidden) DPSet(view, &DPHiddenHandlesKey, hidden = [NSHashTable weakObjectsHashTable]);
    for (NSView *sub in view.subviews) {
        if (DPIsKind(sub, DPDiaSplitPaneView) || ![NSStringFromClass(sub.class) containsString:@"Dragger"] || sub.hidden) continue;
        sub.hidden = YES;
        [hidden addObject:sub];
    }
}

// Dia's order of the panes, read from Dia's own row whenever the panes are in one, and kept while they're in the grid,
// where their places no longer say it.
static NSArray<NSView *> *DPDiaOrder(NSView *view, NSArray<NSView *> *panes, CGFloat *gap) {
    NSRect area = NSZeroRect;
    for (NSView *pane in panes) area = NSIsEmptyRect(area) ? pane.frame : NSUnionRect(area, pane.frame);
    BOOL tall = YES, wide = YES;
    for (NSView *pane in panes) {
        tall = tall && fabs(NSHeight(pane.frame) - NSHeight(area)) < 1;
        wide = wide && fabs(NSWidth(pane.frame) - NSWidth(area)) < 1;
    }
    NSArray<NSView *> *kept = DPGet(view, &DPOrderKey);
    if (!tall && !wide && kept.count == panes.count && [[NSSet setWithArray:kept] isEqualToSet:[NSSet setWithArray:panes]]) {
        *gap = [DPGet(view, &DPGapKey) doubleValue];
        return kept;
    }
    BOOL row = tall || !wide;
    NSArray<NSView *> *ordered = [panes sortedArrayUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        CGFloat pa = row ? NSMinX(a.frame) : (view.isFlipped ? NSMinY(a.frame) : -NSMaxY(a.frame));
        CGFloat pb = row ? NSMinX(b.frame) : (view.isFlipped ? NSMinY(b.frame) : -NSMaxY(b.frame));
        return pa < pb ? NSOrderedAscending : pa > pb ? NSOrderedDescending : NSOrderedSame;
    }];
    CGFloat between = 0;
    if (ordered.count > 1 && (tall || wide)) {
        NSRect a = ordered[0].frame, b = ordered[1].frame;
        between = row ? NSMinX(b) - NSMaxX(a) : (view.isFlipped ? NSMinY(b) - NSMaxY(a) : NSMinY(a) - NSMaxY(b));
    }
    *gap = MAX(0, MIN(between, 24));
    DPSet(view, &DPOrderKey, ordered);
    DPSet(view, &DPGapKey, @(*gap));
    return ordered;
}

static void DPArrange(NSViewController *controller) {
    NSView *view = controller.viewIfLoaded;
    NSArray<NSView *> *panes = DPPanes(view);
    NSString *three = DPChoice(&DPGridSplit);
    BOOL grid = DPGridSplit.on && (panes.count == 4 || (panes.count == 3 && ![three isEqual:@"row"]));
    DPShowHandles(view, !grid);
    if (!grid) return;
    // Dia's row: its outer edges are the grid's, and its gap between panes is the grid's gaps.
    NSRect area = NSZeroRect;
    for (NSView *pane in panes) area = NSIsEmptyRect(area) ? pane.frame : NSUnionRect(area, pane.frame);
    CGFloat gap = 0;
    NSArray<NSView *> *ordered = DPDiaOrder(view, panes, &gap);
    NSArray<NSValue *> *frames = DPGridFrames(area, gap, ordered.count, three, view.isFlipped);
    [ordered enumerateObjectsUsingBlock:^(NSView *pane, NSUInteger i, BOOL *stop) {
        NSRect frame = NSIntegralRect(frames[i].rectValue);
        if (!NSEqualRects(pane.frame, frame) && DPMayAdjust(pane)) pane.frame = frame;
    }];
}

static void DPSplit_viewDidLayout(NSViewController *self, SEL _cmd) {
    DPCallOriginal(DPSplit_viewDidLayout, self);
    DPArrange(self);
}

static void DPInstallGridSplit(void) {
    DPHook(DPDiaSplitController, @selector(viewDidLayout), (IMP)DPSplit_viewDidLayout);
}

static void DPApplyGridSplit(DPPatch *patch) {
    for (NSView *pane in DPFindViews(DPDiaSplitPaneView)) {
        pane.superview.needsLayout = YES;
        if (!patch->on) DPShowHandles(pane.superview, YES);
    }
}

DP_PATCH(DPGridSplit) {
    .key = @"gridSplit",
    .order = 120,
    .title = @"Grid Split View",
    .detail = @"Lay a Split View of four tabs out as a 2×2 grid, and one of three with one tab taking a whole column or row and the other two stacked beside it. Choose which column or row. Two tabs stay side by side.",
    .symbol = @"square.grid.2x2.fill",
    .tint = @"systemIndigoColor",
    .section = @"Split View",
    .classes = DPClasses(DPDiaSplitController, DPDiaSplitPaneView),
    .choice = @"gridSplitThree",
    .defaultChoice = @"left",
    .choices = DPGridChoices,
    .install = DPInstallGridSplit,
    .apply = DPApplyGridSplit,
};
