#import "StdPatch/StdPatch.h"

extern DPPatch DPHideFullScreenPrompt;

// Dia's toasts each get a small window of their own; this is the text inside one.
#define DPDiaToastText "_TtC11DiaToastsV213ToastTextView"
static char DPHiddenKey;

static BOOL DPIsExitPrompt(NSView *text) {
    NSString *string = [text respondsToSelector:@selector(string)] ? [(NSTextView *)text string] : text.accessibilityLabel;
    string = string.lowercaseString;
    return [string containsString:@"exit fullscreen"] || [string containsString:@"exit full screen"];
}

// The toast's window stays, so other toasts can reuse it; only this one's contents go unseen.
static void DPCheckToast(NSView *text) {
    NSWindow *window = text.window;
    if (!window) return;
    BOOL hide = DPHideFullScreenPrompt.on && DPIsExitPrompt(text);
    if (hide) {
        DPSet(window, &DPHiddenKey, @YES);
        window.alphaValue = 0;
        window.ignoresMouseEvents = YES;
        window.contentView.hidden = YES;
    } else if (DPGet(window, &DPHiddenKey)) {
        DPSet(window, &DPHiddenKey, nil);
        window.alphaValue = 1;
        window.ignoresMouseEvents = NO;
        window.contentView.hidden = NO;
    }
}

static void DPToastText_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPToastText_viewDidMoveToWindow, self);
    DPCheckToast(self);
    // The text can arrive just after the view does.
    __weak NSView *weak = self;
    dispatch_async(dispatch_get_main_queue(), ^{ if (weak) DPCheckToast(weak); });
}

static void DPInstallHideFullScreenPrompt(void) {
    DPHook(DPDiaToastText, @selector(viewDidMoveToWindow), (IMP)DPToastText_viewDidMoveToWindow);
}

DP_PATCH(DPHideFullScreenPrompt) {
    .key = @"hideFullScreenPrompt",
    .order = 97,
    .title = @"Hide Full Screen Exit Prompt",
    .detail = @"Stop the “To exit fullscreen, press Escape” message from showing when a window or a page goes full screen.",
    .symbol = @"escape",
    .tint = @"systemBrownColor",
    .section = @"Window",
    .classes = DPClasses(DPDiaToastText),
    .install = DPInstallHideFullScreenPrompt,
};
