#import "SharedPins.h"
#import "Patches/CommandBar/Tabs.h"
#import <objc/message.h>

// Each pin belongs to a group with one tab per space, so a pin is the same pin wherever it is, even after you browse in it.
// Edits made in the space you're in change the group's list; any other space catches up when it's next shown, since only
// the shown space's icon row can take a drop. Spaces only share with spaces of the same profile. State, per profile:
//   profile   spaces: [space id]   order: [group id]   groups: {group id: {url, title, members: {space: tab id}, deleted}}
//   seen: {space: [tab id]}

static NSMutableDictionary *DPState;
static BOOL DPWorking;
static NSMutableSet<NSString *> *DPLogged;

static NSUserDefaults *DPDefaults(void) {
    static NSUserDefaults *defaults;
    if (!defaults) defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    return defaults;
}

// Hidden switches for checking what it does: sharedPinsDryRun plans without acting, sharedPinsLog writes /tmp/dia-pins.log.
BOOL DPSharedPinsDryRun(void) { return [DPDefaults() boolForKey:@"sharedPinsDryRun"]; }

void DPPinsLog(NSString *line) {
    if (![DPDefaults() boolForKey:@"sharedPinsLog"]) return;
    NSString *path = @"/tmp/dia-pins.log";
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) {
        [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
        file = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [file seekToEndOfFile];
    NSString *stamped = [NSString stringWithFormat:@"%@ %@\n", [NSDate.date descriptionWithLocale:nil], line];
    [file writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
}

static void DPLogOnce(NSString *line) {
    if ([DPLogged containsObject:line]) return;
    [DPLogged addObject:line];
    DPPinsLog(line);
}

static void DPSave(void) { [DPDefaults() setObject:DPState forKey:@"sharedPinsState"]; }

static NSMutableDictionary *DPDeepMutable(id value) {
    return (__bridge_transfer NSMutableDictionary *)CFPropertyListCreateDeepCopy(NULL, (__bridge CFPropertyListRef)value, kCFPropertyListMutableContainersAndLeaves);
}

static NSString *DPText(id value) { return [value isKindOfClass:NSString.class] ? value : [value description]; }

static NSWindow *DPMainWindow(void) {
    NSWindow *key = NSApp.keyWindow;
    if (DPIsKind(key, DPDiaWindow)) return key;
    for (NSWindow *window in NSApp.orderedWindows) if (DPIsKind(window, DPDiaWindow) && window.visible) return window;
    return nil;
}

static NSArray<NSDictionary *> *DPReadSpaces(NSWindow *window, NSString **visibleKey) {
    id scripted = DPScriptWindow(window), active = [scripted valueForKey:@"activeProfile"];
    NSString *activeSpace = DPText(DPSwiftValue(active, @"spaceID")), *activeName = [active valueForKey:@"name"];
    NSMutableArray *spaces = [NSMutableArray array];
    for (id profile in [scripted valueForKey:@"appleScriptProfiles"]) {
        NSString *name = [profile valueForKey:@"name"] ?: @"", *spaceID = DPText(DPSwiftValue(profile, @"spaceID"));
        NSString *key = spaceID.length ? spaceID : name;
        NSMutableArray *pins = [NSMutableArray array];
        for (id tab in [profile valueForKey:@"appleScriptTabs"]) {
            if (![[tab valueForKey:@"isPinned"] boolValue]) continue;
            [pins addObject:@{@"id" : [tab valueForKey:@"tabId"] ?: @"", @"url" : DPText([tab valueForKey:@"URL"]) ?: @"", @"title" : [tab valueForKey:@"title"] ?: @""}];
        }
        [spaces addObject:@{@"key" : key, @"name" : name, @"profile" : DPText(DPSwiftValue(profile, @"profileName")) ?: @"", @"pins" : pins, @"object" : profile}];
        BOOL isActive = activeSpace.length ? [spaceID isEqual:activeSpace] : [name isEqual:activeName];
        if (isActive && visibleKey) *visibleKey = key;
    }
    return spaces;
}

static NSArray<NSString *> *DPIDs(NSDictionary *space) { return [space[@"pins"] valueForKey:@"id"]; }

static NSString *DPNormal(NSString *url) {
    NSURLComponents *parts = [NSURLComponents componentsWithString:url ?: @""];
    NSString *host = parts.host.lowercaseString ?: @"";
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    NSString *path = parts.path ?: @"";
    while ([path hasSuffix:@"/"]) path = [path substringToIndex:path.length - 1];
    return host.length ? [host stringByAppendingString:path] : @"";
}

// Dia reports the page a pin is on now, which changes as you browse in it, so pins are also told apart by site alone.
static NSString *DPSite(NSString *url) {
    NSString *host = [NSURLComponents componentsWithString:url ?: @""].host.lowercaseString ?: @"";
    return [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
}

static NSString *DPGroupFor(NSDictionary *state, NSString *space, NSString *tabID) {
    NSDictionary *groups = state[@"groups"];
    for (NSString *gid in groups) if ([groups[gid][@"members"][space] isEqual:tabID]) return gid;
    return nil;
}

static NSMutableDictionary *DPNewGroup(NSDictionary *pin, NSString *space) {
    return [@{@"url" : pin[@"url"], @"title" : pin[@"title"], @"members" : [@{space : pin[@"id"]} mutableCopy]} mutableCopy];
}

// Pairs a space's pins with groups: the same page first, then the same site, for a pin that's been browsed in.
static void DPPair(NSArray<NSDictionary *> *pins, NSArray<NSString *> *order, NSDictionary *groups, void (^pair)(NSDictionary *pin, NSString *gid)) {
    NSMutableSet *used = [NSMutableSet set], *paired = [NSMutableSet set];
    NSString *(*keys[])(NSString *) = {DPNormal, DPSite};
    for (size_t k = 0; k < 2; k++) {
        NSString *(*key)(NSString *) = keys[k];
        for (NSDictionary *pin in pins) {
            if ([paired containsObject:pin[@"id"]]) continue;
            NSString *mine = key(pin[@"url"]);
            for (NSString *gid in order) {
                NSDictionary *group = groups[gid];
                BOOL same = mine.length ? [mine isEqual:key(group[@"url"])] : [pin[@"title"] isEqual:group[@"title"]];
                if ([used containsObject:gid] || !same) continue;
                pair(pin, gid);
                [used addObject:gid];
                [paired addObject:pin[@"id"]];
                break;
            }
        }
    }
}

// What changed in the shown space since it was last read is the user's doing.
static void DPLearnEdits(NSMutableDictionary *state, NSDictionary *space) {
    NSString *key = space[@"key"];
    NSArray<NSString *> *now = DPIDs(space), *before = state[@"seen"][key] ?: now;
    if ([now isEqual:before]) return;
    NSMutableDictionary *groups = state[@"groups"];
    NSMutableArray *order = state[@"order"];
    for (NSString *tabID in before) {
        if ([now containsObject:tabID]) continue;
        NSString *gid = DPGroupFor(state, key, tabID);
        if (!gid) continue;
        groups[gid][@"deleted"] = @YES;
        [groups[gid][@"members"] removeObjectForKey:key];
        [order removeObject:gid];
        DPPinsLog([NSString stringWithFormat:@"edit in %@: removed %@", space[@"name"], groups[gid][@"title"]]);
    }
    NSMutableArray *mine = [NSMutableArray array];
    for (NSDictionary *pin in space[@"pins"]) {
        NSString *gid = DPGroupFor(state, key, pin[@"id"]);
        if (!gid) {
            gid = NSUUID.UUID.UUIDString;
            groups[gid] = DPNewGroup(pin, key);
            DPPinsLog([NSString stringWithFormat:@"edit in %@: added %@", space[@"name"], pin[@"title"]]);
        }
        [mine addObject:gid];
    }
    // This space's order wins; pins it doesn't have yet keep their place after it.
    NSMutableArray *rest = [order mutableCopy];
    [rest removeObjectsInArray:mine];
    state[@"order"] = [[mine arrayByAddingObjectsFromArray:rest] mutableCopy];
    state[@"seen"][key] = now;
}

BOOL DPReconcile(NSMutableDictionary *state, NSDictionary *space, NSWindow *window, NSString *profileID);

// Spaces share pins with the other spaces of their profile, which Dia's sidebar for the shown space knows.
static NSString *DPGroupKeyFor(NSString *spaceKey) {
    for (NSString *groupKey in DPState) if ([DPState[groupKey][@"spaces"] containsObject:spaceKey]) return groupKey;
    return nil;
}

static NSString *DPGroupKeyForProfile(NSString *profile) {
    NSString *best = nil;
    for (NSString *groupKey in DPState) {
        if (![DPState[groupKey][@"profile"] isEqual:profile]) continue;
        if (!best || [DPState[groupKey][@"spaces"] count] > [DPState[best][@"spaces"] count]) best = groupKey;
    }
    return best;
}

// A space first seen in its profile brings its pins along: those the profile already shares are paired with theirs,
// and the rest become shared too, so nothing is lost. A new, empty space just gets the profile's pins.
static void DPJoin(NSMutableDictionary *state, NSDictionary *space) {
    NSString *key = space[@"key"];
    NSMutableDictionary *groups = state[@"groups"];
    NSMutableSet *paired = [NSMutableSet set];
    DPPair(space[@"pins"], state[@"order"], groups, ^(NSDictionary *pin, NSString *gid) {
        groups[gid][@"members"][key] = pin[@"id"];
        [paired addObject:pin[@"id"]];
    });
    for (NSDictionary *pin in space[@"pins"]) {
        if ([paired containsObject:pin[@"id"]]) continue;
        NSString *gid = NSUUID.UUID.UUIDString;
        groups[gid] = DPNewGroup(pin, key);
        [state[@"order"] addObject:gid];
    }
    [state[@"spaces"] addObject:key];
    state[@"seen"][key] = DPIDs(space);
    DPPinsLog([NSString stringWithFormat:@"%@ joined profile %@ (%lu spaces)", space[@"name"], state[@"profile"], (unsigned long)[state[@"spaces"] count]]);
}

// A space found in another profile's group (from before spaces were told apart by profile) leaves it untouched.
static void DPLeave(NSString *groupKey, NSDictionary *space) {
    NSMutableDictionary *state = DPState[groupKey];
    NSString *key = space[@"key"];
    [state[@"spaces"] removeObject:key];
    [state[@"seen"] removeObjectForKey:key];
    NSMutableDictionary *groups = state[@"groups"];
    for (NSString *gid in groups.allKeys) {
        [groups[gid][@"members"] removeObjectForKey:key];
        if ([groups[gid][@"members"] count]) continue;
        [groups removeObjectForKey:gid];
        [state[@"order"] removeObject:gid];
    }
    if (![state[@"spaces"] count]) [DPState removeObjectForKey:groupKey];
    DPPinsLog([NSString stringWithFormat:@"%@ isn't in profile %@; left its group", space[@"name"], state[@"profile"]]);
}

static void DPTickOnce(void) {
    if (!DPSharedPins.on || DPWorking || NSEvent.pressedMouseButtons) return;
    NSWindow *window = DPMainWindow();
    if (!window) return;
    // Reading the spaces through Dia's scripting takes ~20 ms, so a look that would find the same shown space and icon
    // row as the last one that found nothing to do is skipped; the row and space are cheap to read from the sidebar.
    static NSString *idlePrint;
    NSArray<NSString *> *cheapRow = DPVisibleDockIDs(window);
    NSString *shownID = DPShownSpaceID(window);
    NSString *print = shownID && cheapRow ? [NSString stringWithFormat:@"%p|%@|%@", window, shownID, [cheapRow componentsJoinedByString:@","]] : nil;
    if (print && [print isEqual:idlePrint]) return;
    idlePrint = nil;
    NSString *visibleKey = nil;
    NSDictionary *visible = nil;
    for (NSDictionary *space in DPReadSpaces(window, &visibleKey)) if ([space[@"key"] isEqual:visibleKey]) visible = space;
    if (!visible) return DPLogOnce(@"no shown space found; doing nothing");
    NSString *profile = DPShownProfile(window, visibleKey);
    if (!profile.length) return DPLogOnce([NSString stringWithFormat:@"can't tell %@'s profile; doing nothing", visible[@"name"]]);
    // A misread could look like pins being removed, and that would spread, so nothing is learnt or done unless the
    // icon row itself shows the same pins in the same order, and showed them on the last look too.
    static NSString *lastSpace;
    static NSArray<NSString *> *lastRow;
    NSArray<NSString *> *row = DPVisibleDockIDs(window) ?: @[];
    BOOL agrees = [row isEqual:DPIDs(visible)], steady = agrees && [lastSpace isEqual:visibleKey] && [lastRow isEqual:row];
    lastSpace = agrees ? visibleKey : nil;
    lastRow = row;
    if (!agrees)
        return DPLogOnce([NSString stringWithFormat:@"%@: the icon row shows %lu pins, the scripting %lu; waiting", visible[@"name"], (unsigned long)row.count, (unsigned long)DPIDs(visible).count]);
    if (!steady) return;
    NSString *groupKey = DPGroupKeyFor(visibleKey);
    if (groupKey && !DPState[groupKey][@"profile"]) DPState[groupKey][@"profile"] = profile;
    if (groupKey && ![DPState[groupKey][@"profile"] isEqual:profile]) {
        DPLeave(groupKey, visible);
        groupKey = nil;
    }
    if (!groupKey) {
        groupKey = DPGroupKeyForProfile(profile);
        if (!groupKey) {
            groupKey = NSUUID.UUID.UUIDString;
            DPState[groupKey] = [@{@"profile" : profile, @"spaces" : [NSMutableArray array], @"order" : [NSMutableArray array],
                                   @"groups" : [NSMutableDictionary dictionary], @"seen" : [NSMutableDictionary dictionary]} mutableCopy];
        }
        DPJoin(DPState[groupKey], visible);
    }
    NSMutableDictionary *state = DPState[groupKey];
    DPLearnEdits(state, visible);
    DPSave();
    BOOL acting = [state[@"spaces"] count] >= 2 && DPReconcile(state, visible, window, profile);
    if (!acting) idlePrint = print;
}

static void DPInstallSharedPins(void) {
    DPLogged = [NSMutableSet set];
    DPState = DPDeepMutable([DPDefaults() objectForKey:@"sharedPinsState"] ?: @{});
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) { DPTickOnce(); }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSDefaultRunLoopMode];
}

void DPSetSharedPinsWorking(BOOL working) { DPWorking = working; }
NSMutableDictionary *DPSharedPinsState(void) { return DPState; }
void DPSaveSharedPins(void) { DPSave(); }
NSArray<NSDictionary *> *DPReadSharedPinSpaces(NSWindow *window, NSString **visibleKey) { return DPReadSpaces(window, visibleKey); }

DP_PATCH(DPSharedPins) {
    .key = @"sharedPins",
    .order = 80,
    .title = @"Share Pinned Tabs Across Spaces",
    .detail = @"Keep the pinned tabs at the top of the sidebar the same in every space of a profile. Pin, unpin or reorder in one space, and the others catch up when you next go to them. Spaces of other profiles keep their own. Experimental.",
    .symbol = @"pin.square.fill",
    .tint = @"systemTealColor",
    .section = @"Sidebar & Tab Bar",
    .classes = DPClasses("_TtC7TabList11TabListView", "_TtC10TabSurface11TabDockView"),
    .install = DPInstallSharedPins,
};
