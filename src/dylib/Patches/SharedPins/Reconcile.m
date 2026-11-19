#import "SharedPins.h"
#import "Patches/CommandBar/Tabs.h"
#import <objc/message.h>

void DPSetSharedPinsWorking(BOOL working);
void DPSaveSharedPins(void);
NSArray<NSDictionary *> *DPReadSharedPinSpaces(NSWindow *window, NSString **visibleKey);

// Removals are done a few at a time, and the rest on the next look, so a space never waits long on a big change.
static const NSUInteger DPMostRemovals = 3;
static const NSTimeInterval DPStepDelay = 0.6;

static NSDictionary *DPShownSpace(NSWindow *window, NSString *key) {
    for (NSDictionary *space in DPReadSharedPinSpaces(window, NULL)) if ([space[@"key"] isEqual:key]) return space;
    return nil;
}

static id DPScriptTabWithID(NSDictionary *space, NSString *tabID) {
    for (id tab in [space[@"object"] valueForKey:@"appleScriptTabs"]) if ([[tab valueForKey:@"tabId"] isEqual:tabID]) return tab;
    return nil;
}

// A new tab in the shown space, already on the pin's page. Returns its id. Scripting objects are snapshots, so the
// window is asked afresh before and after.
static NSString *DPMakeTab(NSWindow *window, NSString *url) {
    SEL make = NSSelectorFromString(@"newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:");
    Class tabClass = NSClassFromString(@"DiaAppleScriptTab");
    id scripted = DPScriptWindow(window);
    if (![scripted respondsToSelector:make] || !tabClass || !url.length) return nil;
    NSSet *before = [NSSet setWithArray:[[scripted valueForKey:@"appleScriptTabs"] valueForKey:@"tabId"]];
    ((id (*)(id, SEL, Class, NSString *, id, id))objc_msgSend)(scripted, make, tabClass, @"appleScriptTabs", nil, @{@"URL" : url});
    for (NSString *tabID in [[DPScriptWindow(window) valueForKey:@"appleScriptTabs"] valueForKey:@"tabId"])
        if (![before containsObject:tabID]) return tabID;
    return nil;
}

// The page a copy of a pin opens on. Dia reports the page each copy is on now, so a copy you've browsed in shouldn't decide:
// the page most copies are on wins, then the shortest, which is the likeliest to be the site's front page.
static NSString *DPPinURL(NSDictionary *group, NSArray<NSDictionary *> *spaces) {
    NSCountedSet *urls = [NSCountedSet set];
    NSSet *members = [NSSet setWithArray:[group[@"members"] allValues]];
    for (NSDictionary *space in spaces)
        for (NSDictionary *pin in space[@"pins"]) if ([members containsObject:pin[@"id"]] && [pin[@"url"] length]) [urls addObject:pin[@"url"]];
    if (!urls.count) return group[@"url"];
    NSString *best = nil;
    for (NSString *url in urls) {
        NSUInteger count = [urls countForObject:url], bestCount = best ? [urls countForObject:best] : 0;
        if (count > bestCount || (count == bestCount && url.length < best.length)) best = url;
    }
    return best;
}

// A pin that couldn't be added is tried twice per space, not on every tick.
static NSMutableDictionary<NSString *, NSNumber *> *DPFailures;

static void DPRunSteps(NSMutableArray<dispatch_block_t> *steps, dispatch_block_t done) {
    if (!steps.count) return done();
    dispatch_block_t step = steps.firstObject;
    [steps removeObjectAtIndex:0];
    step();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(DPStepDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ DPRunSteps(steps, done); });
}

BOOL DPReconcile(NSMutableDictionary *state, NSDictionary *space, NSWindow *window, NSString *profileID) {
    NSString *key = space[@"key"];
    NSMutableDictionary *groups = state[@"groups"];
    NSArray<NSString *> *now = [space[@"pins"] valueForKey:@"id"];
    NSMutableArray<NSString *> *wanted = [NSMutableArray array], *removals = [NSMutableArray array], *additions = [NSMutableArray array];
    for (NSString *gid in state[@"order"]) if (![groups[gid][@"deleted"] boolValue]) [wanted addObject:gid];
    if (!DPFailures) DPFailures = [NSMutableDictionary dictionary];
    // A pin removed elsewhere was dropped from its group there; this space's copy is still a member here.
    for (NSString *gid in groups) {
        if (![groups[gid][@"deleted"] boolValue]) continue;
        NSString *member = groups[gid][@"members"][key];
        BOOL gaveUp = [DPFailures[[key stringByAppendingString:member ?: @""]] integerValue] >= 2;
        if (member && [now containsObject:member] && ![removals containsObject:member] && !gaveUp) [removals addObject:member];
    }
    for (NSString *gid in wanted) {
        NSString *member = groups[gid][@"members"][key];
        BOOL gaveUp = [DPFailures[[key stringByAppendingString:gid]] integerValue] >= 2;
        if ((!member || ![now containsObject:member]) && !gaveUp) [additions addObject:gid];
    }
    NSMutableArray<NSString *> *wantedIDs = [NSMutableArray array];
    for (NSString *gid in wanted) if (groups[gid][@"members"][key]) [wantedIDs addObject:groups[gid][@"members"][key]];
    // Only pins that belong to a group have a place to be in.
    NSMutableArray<NSString *> *kept = [NSMutableArray array];
    for (NSString *tabID in now) if ([wantedIDs containsObject:tabID]) [kept addObject:tabID];
    NSMutableArray<NSString *> *placed = [NSMutableArray array];
    for (NSString *tabID in wantedIDs) if ([now containsObject:tabID]) [placed addObject:tabID];
    BOOL reorder = ![kept isEqual:placed];
    if (!removals.count && !additions.count && !reorder) return NO;

    NSMutableArray *titles = [NSMutableArray array];
    for (NSString *gid in additions) [titles addObject:groups[gid][@"title"] ?: @"?"];
    NSString *plan = [NSString stringWithFormat:@"%@ in %@: unpin %lu, add %@, reorder %d", DPSharedPinsDryRun() ? @"would" : @"will", space[@"name"],
                                                (unsigned long)removals.count, [titles componentsJoinedByString:@" / "], reorder];
    static NSString *lastPlan;
    if (![plan isEqual:lastPlan]) DPPinsLog(plan);
    lastPlan = plan;
    if (DPSharedPinsDryRun()) return NO;
    if (removals.count > DPMostRemovals) [removals removeObjectsInRange:NSMakeRange(DPMostRemovals, removals.count - DPMostRemovals)];

    DPSetSharedPinsWorking(YES);
    id scripted = DPScriptWindow(window);
    NSString *wasActive = [[scripted valueForKey:@"activeTab"] valueForKey:@"tabId"];
    NSMutableArray<dispatch_block_t> *steps = [NSMutableArray array];
    // Unpinned as its menu would, which leaves an ordinary tab; that copy then closes.
    for (NSString *tabID in removals) {
        [steps addObject:^{
            NSDictionary *shown = DPShownSpace(window, key);
            NSUInteger index = [[shown[@"pins"] valueForKey:@"id"] indexOfObject:tabID];
            BOOL ok = index != NSNotFound && DPUnpinDockItem(window, (NSInteger)index, [shown[@"pins"] count]);
            DPPinsLog([NSString stringWithFormat:@"unpin %@: %d", tabID, ok]);
            NSString *failure = [key stringByAppendingString:tabID];
            if (!ok) DPFailures[failure] = @([DPFailures[failure] integerValue] + 1);
            else for (NSString *gid in groups) if ([groups[gid][@"members"][key] isEqual:tabID]) [groups[gid][@"members"] removeObjectForKey:key];
        }];
        [steps addObject:^{
            id tab = DPScriptTabWithID(DPShownSpace(window, key) ?: space, tabID);
            if (tab && ![[tab valueForKey:@"isPinned"] boolValue]) DPCloseTab(tab);
            DPPinsLog([NSString stringWithFormat:@"close %@: %d", tabID, tab != nil]);
        }];
    }
    for (NSString *gid in additions) [steps addObject:^{
        NSString *url = DPPinURL(groups[gid], DPReadSharedPinSpaces(window, NULL));
        NSString *tabID = DPMakeTab(window, url);
        BOOL ok = tabID && DPDropTab(window, tabID, profileID, DPDropAtEnd, [DPShownSpace(window, key)[@"pins"] count]);
        DPPinsLog([NSString stringWithFormat:@"add %@ (%@): made %@, pinned %d", groups[gid][@"title"], url, tabID ?: @"nothing", ok]);
        if (ok) groups[gid][@"members"][key] = tabID;
        else DPFailures[[key stringByAppendingString:gid]] = @([DPFailures[[key stringByAppendingString:gid]] integerValue] + 1);
    }];
    // One drop per misplaced pin, each read afresh; it gives up rather than shuffle forever.
    for (NSUInteger round = 0; (reorder || additions.count) && round < wanted.count; round++) [steps addObject:^{
        NSDictionary *shown = DPShownSpace(window, key);
        NSArray<NSString *> *order = [shown[@"pins"] valueForKey:@"id"];
        for (NSUInteger i = 0; i < wanted.count && i < order.count; i++) {
            NSString *target = groups[wanted[i]][@"members"][key];
            if (!target || [order[i] isEqual:target]) continue;
            BOOL ok = DPDropTab(window, target, profileID, (NSInteger)i, order.count);
            DPPinsLog([NSString stringWithFormat:@"move %@ to %lu: %d", groups[wanted[i]][@"title"], (unsigned long)i, ok]);
            return;
        }
    }];
    DPRunSteps(steps, ^{
        NSDictionary *shown = DPShownSpace(window, key);
        state[@"seen"][key] = [shown[@"pins"] valueForKey:@"id"] ?: @[];
        for (NSString *gid in [groups allKeys])
            if ([groups[gid][@"deleted"] boolValue] && ![groups[gid][@"members"] count]) [groups removeObjectForKey:gid];
        id previous = DPScriptTabWithID(shown ?: space, wasActive);
        if (previous) DPFocusTab(previous);
        DPSaveSharedPins();
        DPSetSharedPinsWorking(NO);
        DPPinsLog([NSString stringWithFormat:@"%@ in step: %@", space[@"name"], [[shown[@"pins"] valueForKey:@"title"] componentsJoinedByString:@" | "]]);
    });
    return YES;
}
