#import "StdPatch/StdPatch.h"

extern DPPatch DPSiteSearch;

// Type a site's name or address in the command bar and the suggestion for it offers Tab to search that site. Called by the
// command bar whenever what's typed or the suggestions may have changed.
void DPSiteSearchRefresh(NSView *panel, NSTextView *text);
// Tab, Return, Delete and Escape while a site is offered or being searched. YES if it used the key. `open` goes to an
// address the way the bar would.
BOOL DPSiteSearchKey(NSEvent *event, NSView *panel, NSTextView *text, void (^open)(NSString *url));
// The field typed into while a site is being searched, which takes the bar's focus; nil otherwise.
NSView *DPSiteSearchField(NSView *panel);
// Whether a view is part of a site's suggestions, which take clicks as the bar's own parts do.
BOOL DPSiteSearchOwns(NSView *view);
// Puts the bar back as Dia had it, for when the bar closes.
void DPSiteSearchEnd(NSView *panel, NSTextView *text);
