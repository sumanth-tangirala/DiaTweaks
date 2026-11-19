#import "SharedPins.h"

#define DPDiaTabList "_TtC7TabList11TabListView"
#define DPDiaTabDock "_TtC10TabSurface11TabDockView"

// A drag that never happened: just what Dia's tab list reads from one.
@interface DPReplayedDrag : NSObject <NSDraggingInfo>
@property (nonatomic, strong) NSPasteboard *pasteboard;
@property (nonatomic, weak) NSWindow *window;
@property (nonatomic) NSPoint location;
@property NSDraggingFormation draggingFormation;
@property BOOL animatesToDestination;
@property NSInteger numberOfValidItemsForDrop;
@end

@implementation DPReplayedDrag
@synthesize draggingFormation, animatesToDestination, numberOfValidItemsForDrop;
- (NSWindow *)draggingDestinationWindow { return self.window; }
- (NSDragOperation)draggingSourceOperationMask { return NSDragOperationCopy | NSDragOperationMove; }
- (NSPoint)draggingLocation { return self.location; }
- (NSPoint)draggedImageLocation { return self.location; }
- (NSImage *)draggedImage { return nil; }
- (NSPasteboard *)draggingPasteboard { return self.pasteboard; }
- (id)draggingSource { return nil; }
- (NSInteger)draggingSequenceNumber { return 0x5eed; }
- (void)slideDraggedImageTo:(NSPoint)screenPoint {}
- (NSArray<NSString *> *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination { return nil; }
- (void)enumerateDraggingItemsWithOptions:(NSDraggingItemEnumerationOptions)options forView:(NSView *)view classes:(NSArray<Class> *)classes searchOptions:(NSDictionary *)search usingBlock:(void (^)(NSDraggingItem *, NSInteger, BOOL *))block {}
- (NSSpringLoadingHighlight)springLoadingHighlight { return NSSpringLoadingHighlightNone; }
- (void)resetSpringLoading {}
@end

// Right after a space switch the window can hold the last space's list too. The shown one is the list whose own page
// isn't hidden within the sidebar, even while the whole sidebar is hidden.
static BOOL DPShownPage(NSView *list) {
    for (NSView *view = list; view; view = view.superview) {
        if ([NSStringFromClass(view.class) containsString:@"SidebarContainerRootView"]) return YES;
        if (view.hidden || view.alphaValue < 0.01) return NO;
    }
    return NO;
}

static NSView *DPTabList(NSWindow *window) {
    NSView *shown = nil;
    for (NSView *list in DPFindViews(DPDiaTabList)) {
        if (list.window != window || !DPShownPage(list)) continue;
        if (shown) return nil;  // Two candidates: better to do nothing than drop into the wrong space.
        shown = list;
    }
    return shown;
}

NSView *DPVisibleDock(NSWindow *window) {
    NSView *list = DPTabList(window);
    return list ? DPFindView(list, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaTabDock); }) : nil;
}

NSString *DPMirrorText(id object, NSString *path);

NSString *DPShownSpaceID(NSWindow *window) {
    return DPMirrorText(DPTabList(window), @"viewModel.delegate.spaceID.rawValue").uppercaseString;
}

// The Chromium profile folder of the space on screen, as Dia's own sidebar for it knows it. Only answers when that
// sidebar is the space the scripting says is shown.
NSString *DPShownProfile(NSWindow *window, NSString *spaceKey) {
    NSView *list = DPTabList(window);
    NSString *space = DPMirrorText(list, @"viewModel.delegate.spaceID.rawValue");
    if (!space || [space caseInsensitiveCompare:spaceKey] != NSOrderedSame) return nil;
    return DPMirrorText(list, @"viewModel.delegate.browserID.contextID.profileID.directoryBasename");
}

// The icon row's items in reading order.
static NSArray<NSView *> *DPDockItems(NSView *dock) {
    NSMutableArray<NSView *> *items = [NSMutableArray array];
    for (NSView *view in dock.subviews) if (DPIsKind(view, DPDiaPinnedTab) && !view.hidden) [items addObject:view];
    [items sortUsingComparator:^NSComparisonResult(NSView *a, NSView *b) {
        CGFloat ay = dock.isFlipped ? NSMinY(a.frame) : -NSMaxY(a.frame), by = dock.isFlipped ? NSMinY(b.frame) : -NSMaxY(b.frame);
        if (fabs(ay - by) > 2) return ay < by ? NSOrderedAscending : NSOrderedDescending;
        return NSMinX(a.frame) < NSMinX(b.frame) ? NSOrderedAscending : NSOrderedDescending;
    }];
    return items;
}

NSArray<NSString *> *DPVisibleDockIDs(NSWindow *window) {
    NSView *dock = DPVisibleDock(window);
    if (!dock) return nil;
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (NSView *item in DPDockItems(dock)) {
        NSString *tabID = DPUUIDsIn(DPMirrorText(item, @"viewModel.delegate.itemID")).firstObject;
        if (!tabID) return nil;
        [ids addObject:tabID];
    }
    return ids;
}

BOOL DPDropTab(NSWindow *window, NSString *tabID, NSString *profileID, NSInteger index, NSUInteger expected) {
    NSView *list = DPTabList(window), *dock = DPVisibleDock(window);
    if (!list || !dock || !tabID.length) return NO;
    NSArray<NSView *> *items = DPDockItems(dock);
    if (items.count != expected) return NO;
    NSPoint point;
    if (index >= 0 && index < (NSInteger)items.count) {
        NSRect item = items[index].frame;  // Its leading edge: in front of it.
        point = [dock convertPoint:NSMakePoint(NSMinX(item) + 3, NSMidY(item)) toView:nil];
    } else {
        point = [dock convertPoint:NSMakePoint(NSMaxX(dock.bounds) - 12, dock.isFlipped ? NSMaxY(dock.bounds) - 20 : 20) toView:nil];
    }
    NSPasteboard *pasteboard = [NSPasteboard pasteboardWithUniqueName];
    [pasteboard declareTypes:@[@"company.thebrowser.BrowserContextID", @"company.thebrowser.TabID"] owner:nil];
    [pasteboard setString:[NSString stringWithFormat:@"{\"type\":{\"normal\":{}},\"profileID\":\"%@\"}", profileID ?: @"Default"] forType:@"company.thebrowser.BrowserContextID"];
    [pasteboard setString:tabID forType:@"company.thebrowser.TabID"];
    DPReplayedDrag *drag = [DPReplayedDrag new];
    drag.pasteboard = pasteboard;
    drag.window = window;
    drag.location = point;
    drag.numberOfValidItemsForDrop = 1;
    id<NSDraggingDestination> destination = (id<NSDraggingDestination>)list;
    BOOL ok = NO;
    if ([destination draggingEntered:drag] != NSDragOperationNone) {
        [destination draggingUpdated:drag];
        ok = [destination draggingUpdated:drag] != NSDragOperationNone && [destination prepareForDragOperation:drag] && [destination performDragOperation:drag];
        if (ok && [destination respondsToSelector:@selector(concludeDragOperation:)]) [destination concludeDragOperation:drag];
    }
    if ([destination respondsToSelector:@selector(draggingEnded:)]) [destination draggingEnded:drag];
    pasteboard = nil;
    return ok;
}

BOOL DPUnpinDockItem(NSWindow *window, NSInteger index, NSUInteger expected) {
    NSArray<NSView *> *items = DPDockItems(DPVisibleDock(window));
    if (items.count != expected || index < 0 || index >= (NSInteger)items.count) return NO;
    NSView *item = items[index];
    NSPoint point = [item convertPoint:NSMakePoint(NSMidX(item.bounds), NSMidY(item.bounds)) toView:nil];
    NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                    windowNumber:window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSMenu *menu __attribute__((objc_precise_lifetime)) = [item menuForEvent:click];
    NSMenuItem *unpin = [menu itemWithTitle:@"Unpin"];
    if (!unpin || unpin.hidden || !unpin.enabled) return NO;
    [menu performActionForItemAtIndex:[menu indexOfItem:unpin]];
    return YES;
}
