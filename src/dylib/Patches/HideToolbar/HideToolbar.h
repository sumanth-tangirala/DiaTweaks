#import "StdPatch/StdPatch.h"
#include <simd/simd.h>

extern DPPatch DPMinimalToolbar, DPHideToolbar, DPRevealToolbarOnHover, DPShowToolbarWithSidebar, DPShowToolbarOnNewTab, DPShowToolbarWithTopTabs, DPPlainSelectedTab;
extern DPPatch DPShowLoadingProgress;
extern NSHashTable<NSView *> *DPPanes;

@interface DPToolbarHover : NSObject
@property (nonatomic, weak) NSView *pane, *bar, *bookmarks;
@property (nonatomic, strong) NSTrackingArea *tracking;
@property (nonatomic, strong) NSTimer *animation, *hideTimer, *inPlaceAnimation;
@property (nonatomic) BOOL revealed, inPlace, minimalExpanded;
@property (nonatomic, strong) NSView *strip;
@property (nonatomic, strong) NSTimer *collapseTimer, *minimalAnimation;
@property (nonatomic) CGFloat minimalProgress;  // 0 with no minimal bar, 1 with it; eased between
@property (nonatomic) NSInteger minimalTarget;  // -1 until the first layout
@property (nonatomic) CGFloat progress, inPlaceProgress;
+ (DPToolbarHover *)forPane:(NSView *)pane;
+ (DPToolbarHover *)attachToPane:(NSView *)pane;
- (void)updateForBar:(NSView *)bar bookmarks:(NSView *)bookmarks;
@end

NSRect DPLaidOutFrame(NSView *view);
CGFloat DPTop(NSView *pane, NSRect r);
CGFloat DPBottom(NSView *pane, NSRect r);
NSView *DPBookmarksUnder(NSView *pane, NSView *bar);
BOOL DPKeptInPlace(NSView *pane);
CGFloat DPMinimalGap(NSView *pane);
CGFloat DPMinimalStripHeight(NSView *pane);
void DPUpdateMinimalStrip(NSView *pane, DPToolbarHover *hover);
NSString *DPVerifyKeptInPlace(DPPatch *patch);
void DPApplyToolbar(NSView *pane);
void DPApplyToolbarOpacity(DPToolbarHover *hover);
void DPRelayoutPanes(void);
void DPApplyRelayoutPanes(DPPatch *patch);
void DPRepaintTabs(NSWindow *window);

void DPShowCopyToast(NSView *pane, NSString *message);

void DPShowProgressLine(NSView *pane, CGFloat fraction);
void DPFinishProgressLine(NSView *pane);
void DPRemoveProgressLine(NSView *pane);
BOOL DPShowsProgressLine(NSView *pane);

CAMetalLayer *DPProgressShaderLayer(void);
void DPDrawProgressShader(CAMetalLayer *layer, CGFloat progress, CGFloat cycle, simd_float3 primary, simd_float3 secondary);
BOOL DPProgressColorSlots(NSUInteger slots[2]);

NSMenu *DPProgressColorChoices(void);
void DPProgressColors(NSView *pane, NSString *choice, simd_float3 *primary, simd_float3 *secondary);
void DPInstallProgressColors(void);
