#import "StdPatch/StdPatch.h"

extern DPPatch DPSharedPins;

// One space's pinned tabs, in order: each is @{id, url, title}.
typedef NSArray<NSDictionary<NSString *, NSString *> *> DPPinList;

// Replays the drop Dia handles when a tab is dragged into the icon row; `index` is where it lands.
static const NSInteger DPDropAtEnd = -1;
// Both first check the shown icon row holds `expected` icons, so they never act on another space's row.
BOOL DPDropTab(NSWindow *window, NSString *tabID, NSString *profileID, NSInteger index, NSUInteger expected);
NSView *DPVisibleDock(NSWindow *window);
// The profile folder ("Default", "Profile 1"…) of the space on screen, or nil unless it's surely that space's.
NSString *DPShownProfile(NSWindow *window, NSString *spaceKey);
// The tab ids in the shown icon row, in reading order, as the row itself has them; nil when there's no row or an icon
// can't be read. A second account of the pins, to check the scripting's against.
NSArray<NSString *> *DPVisibleDockIDs(NSWindow *window);
// The id of the space whose sidebar is on screen, read from the sidebar itself, which is quick.
NSString *DPShownSpaceID(NSWindow *window);
// Unpin from the icon at this place in the shown icon row, as its menu would.
BOOL DPUnpinDockItem(NSWindow *window, NSInteger index, NSUInteger expected);

void DPPinsLog(NSString *line);
BOOL DPSharedPinsDryRun(void);
