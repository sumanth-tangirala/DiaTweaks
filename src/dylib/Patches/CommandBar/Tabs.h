#import "StdPatch/StdPatch.h"

id DPScriptWindow(NSWindow *window);
id DPScriptTab(NSWindow *window, NSString *tabID);
NSString *DPTabID(id tab);
NSString *DPActiveTabID(NSWindow *window);
void DPFocusTab(id tab);
void DPCloseTab(id tab);
// Dia doesn't say who closes a page: DPCloseTab marks its own close, DPMarkOwnClose one made another way, and the closing page takes the mark.
void DPMarkOwnClose(void);
BOOL DPTakeOwnClose(void);

// Asking Dia for a window's tabs costs ~20 ms. Within a memo scope the first answer is reused until a tab is focused or
// closed through these helpers. Open one only where nothing else can change the tabs: after a hook's call into Dia, not
// around it. DPTabsMemoScope opens one that ends with the enclosing block.
void DPBeginTabsMemo(void);
void DPEndTabsMemo(void);
static inline void DPEndTabsMemoAtExit(int *unused) { DPEndTabsMemo(); }
#define DPTabsMemoScope __attribute__((cleanup(DPEndTabsMemoAtExit), unused)) int DPTabsMemoToken = (DPBeginTabsMemo(), 0)
