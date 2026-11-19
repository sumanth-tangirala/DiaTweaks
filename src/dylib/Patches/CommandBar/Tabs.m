#import "Patches/CommandBar/Tabs.h"

// Dia builds a fresh scripting copy of every window, and all its tabs, each time it's asked: about 20 ms with a few dozen
// tabs. Code that asks several times in a row inside a memo scope gets the first copy again, until it focuses or closes a
// tab, or the scope ends.
static NSInteger DPMemoDepth;
static id DPMemoScripted;
static __weak NSWindow *DPMemoWindow;

void DPBeginTabsMemo(void) { DPMemoDepth++; }

static void DPForgetTabsMemo(void) {
    DPMemoScripted = nil;
    DPMemoWindow = nil;
}

void DPEndTabsMemo(void) {
    if (--DPMemoDepth > 0) return;
    DPMemoDepth = 0;
    DPForgetTabsMemo();
}

id DPScriptWindow(NSWindow *window) {
    if (DPMemoDepth && DPMemoScripted && window && DPMemoWindow == window) return DPMemoScripted;
    id found = nil;
    for (id scripted in [(id)NSApp.delegate valueForKey:@"appleScriptWindows"])
        if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) {
            found = scripted;
            break;
        }
    if (DPMemoDepth && found) {
        DPMemoScripted = found;
        DPMemoWindow = window;
    }
    return found;
}

id DPScriptTab(NSWindow *window, NSString *tabID) {
    for (id tab in [DPScriptWindow(window) valueForKey:@"appleScriptTabs"])
        if ([[tab valueForKey:@"tabId"] isEqual:tabID]) return tab;
    return nil;
}

NSString *DPTabID(id tab) { return [tab valueForKey:@"tabId"]; }
NSString *DPActiveTabID(NSWindow *window) { return DPTabID([DPScriptWindow(window) valueForKey:@"activeTab"]); }

void DPFocusTab(id tab) {
    [tab performSelector:@selector(focus:) withObject:nil];
    DPForgetTabsMemo();
}

static NSInteger DPOwnCloses;
static CFTimeInterval DPOwnClosesLapse;

void DPMarkOwnClose(void) {
    DPOwnCloses++;
    DPOwnClosesLapse = CACurrentMediaTime() + 1;
}

BOOL DPTakeOwnClose(void) {
    if (CACurrentMediaTime() > DPOwnClosesLapse) DPOwnCloses = 0;
    if (DPOwnCloses <= 0) return NO;
    DPOwnCloses--;
    return YES;
}

void DPCloseTab(id tab) {
    if (!tab) return;
    DPMarkOwnClose();
    [tab performSelector:@selector(close:) withObject:nil];
    DPForgetTabsMemo();
}
