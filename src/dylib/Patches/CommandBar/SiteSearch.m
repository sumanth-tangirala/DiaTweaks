#import "Patches/CommandBar/SiteSearch.h"

// Each site: its name, its address, other names people type for it, and its search page with %s for what's searched.
static NSArray<NSDictionary *> *DPSites(void) {
    static NSArray *sites;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sites = @[
            @{@"name" : @"YouTube", @"domain" : @"youtube.com", @"suggest" : @"youtube", @"url" : @"https://www.youtube.com/results?search_query=%s"},
            @{@"name" : @"Google Maps", @"domain" : @"maps.google.com", @"also" : @[ @"maps" ], @"url" : @"https://www.google.com/maps/search/%s"},
            @{@"name" : @"Amazon", @"domain" : @"amazon.com", @"suggest" : @"amazon", @"url" : @"https://www.amazon.com/s?k=%s"},
            @{@"name" : @"Reddit", @"domain" : @"reddit.com", @"url" : @"https://www.reddit.com/search/?q=%s"},
            @{@"name" : @"Wikipedia", @"domain" : @"wikipedia.org", @"suggest" : @"wikipedia", @"url" : @"https://en.wikipedia.org/w/index.php?search=%s"},
            @{@"name" : @"GitHub", @"domain" : @"github.com", @"url" : @"https://github.com/search?q=%s"},
            @{@"name" : @"Google Scholar", @"domain" : @"scholar.google.com", @"also" : @[ @"scholar" ], @"suggest" : @"scholar", @"url" : @"https://scholar.google.com/scholar?q=%s"},
            @{@"name" : @"arXiv", @"domain" : @"arxiv.org", @"url" : @"https://arxiv.org/search/?query=%s&searchtype=all"},
            @{@"name" : @"Semantic Scholar", @"domain" : @"semanticscholar.org", @"url" : @"https://www.semanticscholar.org/search?q=%s"},
            @{@"name" : @"Stack Overflow", @"domain" : @"stackoverflow.com", @"url" : @"https://stackoverflow.com/search?q=%s"},
            @{@"name" : @"Hacker News", @"domain" : @"news.ycombinator.com", @"also" : @[ @"ycombinator.com" ], @"url" : @"https://hn.algolia.com/?q=%s"},
            @{@"name" : @"ChatGPT", @"domain" : @"chatgpt.com", @"url" : @"https://chatgpt.com/?q=%s"},
            @{@"name" : @"Claude", @"domain" : @"claude.ai", @"url" : @"https://claude.ai/new?q=%s"},
            @{@"name" : @"Perplexity", @"domain" : @"perplexity.ai", @"url" : @"https://www.perplexity.ai/search?q=%s"},
            @{@"name" : @"Google Images", @"domain" : @"images.google.com", @"also" : @[ @"images" ], @"url" : @"https://www.google.com/search?tbm=isch&q=%s"},
            @{@"name" : @"Google Flights", @"domain" : @"flights.google.com", @"also" : @[ @"flights" ], @"url" : @"https://www.google.com/travel/flights?q=%s"},
            @{@"name" : @"Google News", @"domain" : @"news.google.com", @"url" : @"https://news.google.com/search?q=%s"},
            @{@"name" : @"Google Translate", @"domain" : @"translate.google.com", @"also" : @[ @"translate" ], @"url" : @"https://translate.google.com/?text=%s"},
            @{@"name" : @"Gmail", @"domain" : @"mail.google.com", @"also" : @[ @"gmail.com" ], @"url" : @"https://mail.google.com/mail/u/0/#search/%s"},
            @{@"name" : @"Google Drive", @"domain" : @"drive.google.com", @"url" : @"https://drive.google.com/drive/search?q=%s"},
            @{@"name" : @"IMDb", @"domain" : @"imdb.com", @"suggest" : @"imdb", @"url" : @"https://www.imdb.com/find/?q=%s"},
            @{@"name" : @"Netflix", @"domain" : @"netflix.com", @"url" : @"https://www.netflix.com/search?q=%s"},
            @{@"name" : @"Spotify", @"domain" : @"open.spotify.com", @"also" : @[ @"spotify.com" ], @"url" : @"https://open.spotify.com/search/%s"},
            @{@"name" : @"Apple Music", @"domain" : @"music.apple.com", @"url" : @"https://music.apple.com/us/search?term=%s"},
            @{@"name" : @"X", @"domain" : @"x.com", @"also" : @[ @"twitter", @"twitter.com" ], @"url" : @"https://x.com/search?q=%s"},
            @{@"name" : @"LinkedIn", @"domain" : @"linkedin.com", @"url" : @"https://www.linkedin.com/search/results/all/?keywords=%s"},
            @{@"name" : @"eBay", @"domain" : @"ebay.com", @"url" : @"https://www.ebay.com/sch/i.html?_nkw=%s"},
            @{@"name" : @"Etsy", @"domain" : @"etsy.com", @"url" : @"https://www.etsy.com/search?q=%s"},
            @{@"name" : @"Walmart", @"domain" : @"walmart.com", @"url" : @"https://www.walmart.com/search?q=%s"},
            @{@"name" : @"Target", @"domain" : @"target.com", @"url" : @"https://www.target.com/s?searchTerm=%s"},
            @{@"name" : @"Best Buy", @"domain" : @"bestbuy.com", @"url" : @"https://www.bestbuy.com/site/searchpage.jsp?st=%s"},
            @{@"name" : @"Yelp", @"domain" : @"yelp.com", @"url" : @"https://www.yelp.com/search?find_desc=%s"},
            @{@"name" : @"Zillow", @"domain" : @"zillow.com", @"url" : @"https://www.zillow.com/homes/%s_rb/"},
            @{@"name" : @"Pinterest", @"domain" : @"pinterest.com", @"url" : @"https://www.pinterest.com/search/pins/?q=%s"},
            @{@"name" : @"Twitch", @"domain" : @"twitch.tv", @"url" : @"https://www.twitch.tv/search?term=%s"},
            @{@"name" : @"Goodreads", @"domain" : @"goodreads.com", @"url" : @"https://www.goodreads.com/search?q=%s"},
            @{@"name" : @"TradingView", @"domain" : @"tradingview.com", @"also" : @[ @"trading view" ], @"suggest" : @"tradingview", @"pickFirst" : @YES,
               @"url" : @"https://www.tradingview.com/chart/?symbol=%s"},
            @{@"name" : @"Wolfram Alpha", @"domain" : @"wolframalpha.com", @"url" : @"https://www.wolframalpha.com/input?i=%s"},
            @{@"name" : @"npm", @"domain" : @"npmjs.com", @"suggest" : @"npm", @"url" : @"https://www.npmjs.com/search?q=%s"},
            @{@"name" : @"PyPI", @"domain" : @"pypi.org", @"url" : @"https://pypi.org/search/?q=%s"},
            @{@"name" : @"MDN", @"domain" : @"developer.mozilla.org", @"url" : @"https://developer.mozilla.org/en-US/search?q=%s"},
        ];
    });
    return sites;
}

static NSString *DPBare(NSString *text) {
    NSString *bare = [text.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSString *prefix in @[ @"https://", @"http://", @"www." ])
        if ([bare hasPrefix:prefix]) bare = [bare substringFromIndex:prefix.length];
    while ([bare hasSuffix:@"/"]) bare = [bare substringToIndex:bare.length - 1];
    return bare;
}

static NSArray<NSString *> *DPKeys(NSDictionary *site) {
    NSString *name = [site[@"name"] lowercaseString];
    NSMutableArray *keys = [NSMutableArray arrayWithObjects:name, [name stringByReplacingOccurrencesOfString:@" " withString:@""], site[@"domain"], nil];
    [keys addObjectsFromArray:site[@"also"] ?: @[]];
    return keys;
}

static NSDictionary *DPSiteNamed(NSString *bare, BOOL prefixes) {
    if (bare.length < 2) return nil;
    for (NSDictionary *site in DPSites())
        for (NSString *key in DPKeys(site)) if ([key isEqual:bare]) return site;
    // A start that's long enough to mean one site; "google" alone doesn't pick one of the Google sites.
    if (!prefixes || bare.length < 4) return nil;
    for (NSDictionary *site in DPSites())
        for (NSString *key in DPKeys(site)) {
            NSRange space = [key rangeOfString:@" "];
            if ([key hasPrefix:bare] && (space.location == NSNotFound || bare.length > space.location)) return site;
        }
    return nil;
}

// What was typed, without the rest of an address Dia has filled in after it (selected, at the end).
static NSString *DPTyped(NSTextView *text) {
    NSString *string = text.string ?: @"";
    NSRange selected = text.selectedRange;
    if (selected.length && NSMaxRange(selected) == string.length) return [string substringToIndex:selected.location];
    return string;
}

// The site what's typed names. When Dia has filled in an address, it's that address's site or none, so that, say, "goo"
// filled in as google.com isn't taken for Goodreads.
static NSDictionary *DPSiteFor(NSTextView *text) {
    NSString *typed = DPTyped(text), *whole = text.string ?: @"";
    if (typed.length == whole.length) return DPSiteNamed(DPBare(typed), YES);
    NSDictionary *site = DPSiteNamed(DPBare(whole), NO) ?: DPSiteNamed(DPBare(typed), NO);
    if (site) return site;
    site = DPSiteNamed(DPBare(typed), YES);
    for (NSString *key in DPKeys(site)) if ([DPBare(whole) hasPrefix:key]) return site;
    return nil;
}

#pragma mark The hint on a suggestion

static char DPHintKey, DPModeKey, DPHiddenKey;

@interface DPSiteHint : NSView
@end

@implementation DPSiteHint

- (instancetype)initWithSite:(NSDictionary *)site {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    NSTextField *label = [NSTextField labelWithString:[@"Search " stringByAppendingString:site[@"name"]]];
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = NSColor.tertiaryLabelColor;
    NSTextField *key = [NSTextField labelWithString:@"tab"];
    key.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    key.textColor = NSColor.secondaryLabelColor;
    key.alignment = NSTextAlignmentCenter;
    NSView *cap = [NSView new];
    cap.wantsLayer = YES;
    cap.layer.cornerRadius = 4;
    cap.layer.borderWidth = 1;
    cap.layer.borderColor = NSColor.tertiaryLabelColor.CGColor;
    [label sizeToFit];
    [key sizeToFit];
    NSSize capSize = NSMakeSize(ceil(NSWidth(key.frame)) + 10, 18);
    CGFloat height = 20, width = ceil(NSWidth(label.frame)) + 8 + capSize.width;
    self.frame = NSMakeRect(0, 0, width, height);
    label.frame = NSMakeRect(0, round((height - NSHeight(label.frame)) / 2), ceil(NSWidth(label.frame)), NSHeight(label.frame));
    cap.frame = NSMakeRect(width - capSize.width, round((height - capSize.height) / 2), capSize.width, capSize.height);
    key.frame = NSMakeRect(0, round((capSize.height - NSHeight(key.frame)) / 2), capSize.width, NSHeight(key.frame));
    [cap addSubview:key];
    [self addSubview:label];
    [self addSubview:cap];
    return self;
}

- (NSView *)hitTest:(NSPoint)point { return nil; }

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        for (NSView *view in self.subviews) view.layer.borderColor = NSColor.tertiaryLabelColor.CGColor;
    }];
}

@end

static NSString *DPRowText(NSView *row) {
    NSMutableString *text = [NSMutableString string];
    DPFindView(row, ^BOOL(NSView *view) {
        if ([view isKindOfClass:NSTextField.class] && !view.hidden && ![view isKindOfClass:DPSiteHint.class]) [text appendFormat:@"%@ ", ((NSTextField *)view).stringValue];
        return NO;
    });
    return text.lowercaseString;
}

static void DPRemoveSiteHint(NSView *panel) {
    DPSiteHint *hint = DPGet(panel, &DPHintKey);
    if (!hint) return;
    DPSet(panel, &DPHintKey, nil);
    NSView *hidden = DPGet(hint, &DPHiddenKey);
    hidden.alphaValue = 1;
    [hint removeFromSuperview];
}

static NSTableView *DPSuggestionTable(NSView *panel) {
    NSView *suggestions = DPFindView(panel, ^BOOL(NSView *view) { return DPIsKind(view, DPDiaCommandBarSuggestions); });
    return (NSTableView *)DPFindView(suggestions, ^BOOL(NSView *view) { return [view isKindOfClass:NSTableView.class]; });
}

// On the suggestion for the site, or the top one if none is, in place of what Dia shows on its right.
static void DPShowSiteHint(NSView *panel, NSDictionary *site) {
    NSTableView *table = DPSuggestionTable(panel);
    NSMutableArray<NSTableRowView *> *rows = [NSMutableArray array];
    [table enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        if (!rowView.hidden && NSHeight(rowView.frame) > 0) [rows addObject:rowView];
    }];
    [rows sortUsingComparator:^NSComparisonResult(NSTableRowView *a, NSTableRowView *b) { return [@([table rowForView:a]) compare:@([table rowForView:b])]; }];
    NSString *name = [site[@"name"] lowercaseString], *domain = site[@"domain"];
    NSTableRowView *target = rows.firstObject;
    for (NSTableRowView *row in rows) {
        NSString *text = DPRowText(row);
        if ([text containsString:domain] || [text containsString:name]) {
            target = row;
            break;
        }
    }
    DPSiteHint *hint = DPGet(panel, &DPHintKey);
    if (!target) return DPRemoveSiteHint(panel);
    if (hint.superview == target && [[hint.subviews.firstObject stringValue] hasSuffix:site[@"name"]]) return;
    DPRemoveSiteHint(panel);
    hint = [[DPSiteHint alloc] initWithSite:site];
    // Faded rather than hidden, so Dia's own showing and hiding of it, as it reuses the row, still holds.
    NSView *arrow = DPFindView(target, ^BOOL(NSView *view) { return [NSStringFromClass(view.class) containsString:@"SuggestionArrowLabelView"]; });
    if (arrow) {
        arrow.alphaValue = 0;
        DPSet(hint, &DPHiddenKey, arrow);
    }
    hint.frame = NSMakeRect(NSWidth(target.bounds) - 20 - NSWidth(hint.frame), round((NSHeight(target.bounds) - NSHeight(hint.frame)) / 2), NSWidth(hint.frame), NSHeight(hint.frame));
    hint.autoresizingMask = NSViewMinXMargin;
    [target addSubview:hint positioned:NSWindowAbove relativeTo:nil];
    DPSet(panel, &DPHintKey, hint);
}

#pragma mark Searching a site

// While a site is being searched, the bar's own text is left empty, so Dia suggests nothing, and in its place there's a
// field of the same look that starts with the site's pill.
@interface DPSiteMode : NSObject
@property(strong) NSDictionary *site;
@property(copy) NSString *typed;
@property(strong) NSView *input;
@property(strong) NSTextField *field;
@property(weak) NSView *dias;  // Dia's own text box, hidden meanwhile
@property(strong) NSView *list;  // the site's suggestions, where Dia's would be
@property(strong) id changes;
@property NSInteger asked;
@property(copy) void (^open)(NSString *url);
@end

@implementation DPSiteMode
@end

static NSString *DPSearchURL(NSDictionary *site, NSString *query) {
    if (!query.length) return [@"https://" stringByAppendingString:site[@"domain"]];
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&=+#?/;:@$,"];
    NSString *escaped = [query stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
    return [site[@"url"] stringByReplacingOccurrencesOfString:@"%s" withString:escaped];
}

#pragma mark The site's suggestions


static NSURLSession *DPSuggestSession(void) {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 3;
        config.HTTPShouldSetCookies = NO;
        config.HTTPAdditionalHeaders = @{@"User-Agent" : @"Mozilla/5.0"};
        session = [NSURLSession sessionWithConfiguration:config];
    });
    return session;
}

static NSArray<NSString *> *DPStrings(id list, NSString *key) {
    NSMutableArray *strings = [NSMutableArray array];
    if (![list isKindOfClass:NSArray.class]) return strings;
    for (id item in list) {
        id value = key ? ([item isKindOfClass:NSDictionary.class] ? [item valueForKeyPath:key] : nil) : item;
        if ([value isKindOfClass:NSString.class] && [value length]) [strings addObject:value];
    }
    return strings;
}

// A line of explanation to show with a suggestion, like a symbol's company name.
static NSMutableDictionary<NSString *, NSString *> *DPDetails;

// What the site itself suggests for `query`, or Google's suggestions for sites with nothing of their own to ask.
static void DPAskSite(NSDictionary *site, NSString *query, BOOL google, void (^done)(NSArray<NSString *> *)) {
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&=+#?/;:@$,"];
    NSString *q = [query stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"", *kind = google ? @"google" : (site[@"suggest"] ?: @"google");
    NSString *address = [NSString stringWithFormat:@"https://suggestqueries.google.com/complete/search?client=firefox&ie=utf-8&oe=utf-8&q=%@", q];
    if ([kind isEqual:@"youtube"]) address = [address stringByAppendingString:@"&ds=yt"];
    if ([kind isEqual:@"amazon"]) address = [NSString stringWithFormat:@"https://completion.amazon.com/api/2017/suggestions?mid=ATVPDKIKX0DER&alias=aps&prefix=%@", q];
    if ([kind isEqual:@"wikipedia"]) address = [NSString stringWithFormat:@"https://en.wikipedia.org/w/api.php?action=opensearch&format=json&limit=8&search=%@", q];
    if ([kind isEqual:@"scholar"]) address = [NSString stringWithFormat:@"https://scholar.google.com/scholar_complete?hl=en&q=%@", q];
    if ([kind isEqual:@"npm"]) address = [NSString stringWithFormat:@"https://registry.npmjs.org/-/v1/search?size=8&text=%@", q];
    if ([kind isEqual:@"imdb"]) {
        NSString *first = query.length ? [query substringToIndex:1].lowercaseString : @"x";
        if (![NSCharacterSet.alphanumericCharacterSet characterIsMember:[first characterAtIndex:0]]) first = @"x";
        address = [NSString stringWithFormat:@"https://v3.sg.media-imdb.com/suggestion/%@/%@.json", first, q];
    }
    if ([kind isEqual:@"tradingview"]) address = [NSString stringWithFormat:@"https://symbol-search.tradingview.com/symbol_search/v3/?text=%@&hl=0&exchange=&lang=en&search_type=undefined&domain=production", q];
    NSURL *url = [NSURL URLWithString:address];
    if (!url) return done(@[]);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    // TradingView only answers its own pages.
    if ([kind isEqual:@"tradingview"]) {
        [request setValue:@"https://www.tradingview.com" forHTTPHeaderField:@"Origin"];
        [request setValue:@"https://www.tradingview.com/" forHTTPHeaderField:@"Referer"];
    }
    [[DPSuggestSession() dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSArray<NSString *> *found = @[];
        if ([kind isEqual:@"amazon"]) found = DPStrings([json isKindOfClass:NSDictionary.class] ? json[@"suggestions"] : nil, @"value");
        else if ([kind isEqual:@"scholar"]) found = DPStrings([json isKindOfClass:NSDictionary.class] ? json[@"l"] : nil, nil);
        else if ([kind isEqual:@"npm"]) found = DPStrings([json isKindOfClass:NSDictionary.class] ? json[@"objects"] : nil, @"package.name");
        else if ([kind isEqual:@"imdb"]) found = DPStrings([json isKindOfClass:NSDictionary.class] ? json[@"d"] : nil, @"l");
        else if ([kind isEqual:@"tradingview"]) {
            // Each as EXCHANGE:SYMBOL, which TradingView opens straight to, with the company's name beside it.
            NSMutableArray *symbols = [NSMutableArray array];
            NSMutableDictionary *details = [NSMutableDictionary dictionary];
            for (NSDictionary *item in [json isKindOfClass:NSDictionary.class] && [json[@"symbols"] isKindOfClass:NSArray.class] ? json[@"symbols"] : @[]) {
                if (![item isKindOfClass:NSDictionary.class] || ![item[@"symbol"] isKindOfClass:NSString.class]) continue;
                NSString *exchange = [item[@"exchange"] isKindOfClass:NSString.class] ? item[@"exchange"] : @"";
                NSString *value = exchange.length ? [NSString stringWithFormat:@"%@:%@", exchange, item[@"symbol"]] : item[@"symbol"];
                if ([symbols containsObject:value]) continue;
                [symbols addObject:value];
                if ([item[@"description"] isKindOfClass:NSString.class]) details[value] = item[@"description"];
            }
            found = symbols;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!DPDetails) DPDetails = [NSMutableDictionary dictionary];
                [DPDetails addEntriesFromDictionary:details];
            });
        }
        else if ([json isKindOfClass:NSArray.class] && [json count] > 1) found = DPStrings(json[1], nil);
        // Scholar sometimes asks a script to prove it's a person; Google's then.
        if (!found.count && !google && ![kind isEqual:@"google"] && ![kind isEqual:@"tradingview"]) return DPAskSite(site, query, YES, done);
        dispatch_async(dispatch_get_main_queue(), ^{ done(found); });
    }] resume];
}

@interface DPSiteRow : NSView
@property(copy) NSString *query;
@property(nonatomic) BOOL selected;
@property(copy) void (^pick)(void);
@property(copy) void (^hover)(void);
@end

@implementation DPSiteRow

- (instancetype)initWithQuery:(NSString *)query icon:(NSImage *)icon {
    if (!(self = [super initWithFrame:NSMakeRect(0, 0, 100, 40)])) return nil;
    _query = [query copy];
    NSImageView *image = [NSImageView imageViewWithImage:icon];
    image.frame = NSMakeRect(22, 12, 16, 16);
    image.contentTintColor = NSColor.secondaryLabelColor;
    image.imageScaling = NSImageScaleProportionallyUpOrDown;
    NSTextField *label = [NSTextField labelWithString:query];
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = NSColor.labelColor;
    NSString *detail = DPDetails[query];
    if (detail.length) {
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:query attributes:@{NSFontAttributeName : label.font, NSForegroundColorAttributeName : NSColor.labelColor}];
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  —  " stringByAppendingString:detail] attributes:@{NSFontAttributeName : label.font, NSForegroundColorAttributeName : NSColor.secondaryLabelColor}]];
        label.attributedStringValue = text;
    }
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.frame = NSMakeRect(48, 12, 100, 16);
    label.autoresizingMask = NSViewWidthSizable;
    [self addSubview:image];
    [self addSubview:label];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
    return self;
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    NSTextField *label = self.subviews.lastObject;
    label.frame = NSMakeRect(48, round((size.height - 16) / 2), MAX(0, size.width - 48 - 24), 16);
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirty {
    if (!self.selected) return;
    [[NSColor.labelColor colorWithAlphaComponent:0.1] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 8, 2) xRadius:8 yRadius:8] fill];
}

- (void)mouseDown:(NSEvent *)event {}
- (void)mouseUp:(NSEvent *)event { if (self.pick) self.pick(); }
- (void)mouseEntered:(NSEvent *)event { if (self.hover) self.hover(); }

@end

// The site's suggestions show in the bar's lower part, where Dia keeps its buttons (not needed while searching a site),
// which grows down to fit them; Dia's own layout isn't asked to make room, as it centres the bar's contents instead.
@interface DPSiteList : NSView
@property(nonatomic) NSInteger selected;
@property(weak) NSView *panel;
@property(strong) NSColor *fill;
@property CGFloat corner;
@end

@implementation DPSiteList

- (BOOL)isFlipped { return YES; }

- (CGFloat)height { return self.subviews.count ? 8 + self.subviews.count * 40 + 8 : 0; }

- (void)layout {
    [super layout];
    CGFloat y = 8;
    for (NSView *row in self.subviews) {
        row.frame = NSMakeRect(0, y, NSWidth(self.bounds), 40);
        y += 40;
    }
}

// Square at the top, where it joins the bar, and rounded like the bar at the bottom.
- (NSBezierPath *)outline {
    NSRect b = self.bounds;
    CGFloat r = MIN(self.corner, NSHeight(b) / 2);
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(NSMinX(b), NSMinY(b))];
    [path lineToPoint:NSMakePoint(NSMaxX(b), NSMinY(b))];
    [path lineToPoint:NSMakePoint(NSMaxX(b), NSMaxY(b) - r)];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(b) - r, NSMaxY(b) - r) radius:r startAngle:0 endAngle:90];
    [path lineToPoint:NSMakePoint(NSMinX(b) + r, NSMaxY(b))];
    [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(b) + r, NSMaxY(b) - r) radius:r startAngle:90 endAngle:180];
    [path closePath];
    return path;
}

- (void)drawRect:(NSRect)dirty {
    [(self.fill ?: NSColor.windowBackgroundColor) setFill];
    [[self outline] fill];
}

- (void)setSelected:(NSInteger)selected {
    _selected = selected;
    [self.subviews enumerateObjectsUsingBlock:^(DPSiteRow *row, NSUInteger i, BOOL *stop) { row.selected = (NSInteger)i == selected; }];
}

@end

// The bar's colour, from a spot in the middle of its button row, where nothing's drawn on it.
static NSColor *DPPanelFill(NSView *panel, NSView *toolbar) {
    if (!toolbar) return nil;
    NSRect spot = [panel convertRect:NSMakeRect(round(NSMidX(toolbar.bounds)), round(NSMidY(toolbar.bounds)), 1, 1) fromView:toolbar];
    NSBitmapImageRep *rep = [panel bitmapImageRepForCachingDisplayInRect:spot];
    if (!rep) return nil;
    [panel cacheDisplayInRect:spot toBitmapImageRep:rep];
    return [[rep colorAtX:0 y:0] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
}

static CGFloat DPPanelCorner(NSView *panel) {
    __block CGFloat corner = 0;
    NSSize size = panel.bounds.size;
    DPFindView(panel, ^BOOL(NSView *view) {
        if (NSEqualSizes(view.frame.size, size)) corner = MAX(corner, view.layer.cornerRadius);
        return NO;
    });
    return corner ?: 16;
}

static NSView *DPToolbarOf(NSView *panel) {
    return DPFindView(panel, ^BOOL(NSView *view) { return [NSStringFromClass(view.class) hasSuffix:@".ToolbarView"]; });
}

static void DPPlaceList(DPSiteMode *mode) {
    DPSiteList *list = (DPSiteList *)mode.list;
    NSView *panel = list.panel, *host = panel.superview, *toolbar = DPToolbarOf(panel);
    if (!host || !toolbar) return;
    if (list.superview != host) [host addSubview:list positioned:NSWindowAbove relativeTo:panel];
    NSRect bar = [host convertRect:toolbar.bounds fromView:toolbar], frame = panel.frame;
    CGFloat top = host.isFlipped ? NSMinY(bar) : NSMaxY(bar), height = MAX(list.height, NSHeight(bar));
    frame = NSMakeRect(NSMinX(frame), host.isFlipped ? top : top - height, NSWidth(frame), height);
    list.hidden = !list.subviews.count;
    if (!NSEqualRects(list.frame, frame)) list.frame = frame;
}

// The rows: what's typed first, then the site's suggestions.
static void DPShowRows(DPSiteMode *mode, NSArray<NSString *> *suggestions, void (^search)(NSString *query)) {
    DPSiteList *list = (DPSiteList *)mode.list;
    if (!list) return;
    NSString *typed = [mode.field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<NSString *> *queries = [NSMutableArray array];
    if (typed.length) [queries addObject:typed];
    for (NSString *suggestion in suggestions) {
        BOOL seen = NO;
        for (NSString *query in queries) seen = seen || [query caseInsensitiveCompare:suggestion] == NSOrderedSame;
        if (!seen && queries.count < 8) [queries addObject:suggestion];
    }
    NSString *current = list.selected >= 0 && list.selected < (NSInteger)list.subviews.count ? ((DPSiteRow *)list.subviews[list.selected]).query : nil;
    [list.subviews.copy makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSImage *icon = [NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil];
    __weak DPSiteList *weakList = list;
    [queries enumerateObjectsUsingBlock:^(NSString *query, NSUInteger i, BOOL *stop) {
        DPSiteRow *row = [[DPSiteRow alloc] initWithQuery:query icon:icon];
        row.pick = ^{ search(query); };
        row.hover = ^{ weakList.selected = (NSInteger)i; };
        [list addSubview:row];
    }];
    NSUInteger keep = current ? [queries indexOfObject:current] : NSNotFound;
    // For a site where what's typed is rarely what's wanted as it is, like a company's name for a symbol, its first
    // suggestion is picked to begin with.
    NSInteger first = [mode.site[@"pickFirst"] boolValue] && queries.count > 1 ? 1 : 0;
    list.selected = keep == NSNotFound || !suggestions.count ? first : (NSInteger)keep;
    DPPlaceList(mode);
    list.needsLayout = YES;
    list.needsDisplay = YES;
}

BOOL DPSiteSearchOwns(NSView *view) {
    for (NSView *up = view; up; up = up.superview) if ([up isKindOfClass:DPSiteList.class]) return YES;
    return NO;
}


static NSMutableDictionary<NSString *, NSImage *> *DPIcons;

// The site's icon, as a suggestion for it showed it.
static NSImage *DPIconFor(NSView *panel, NSDictionary *site) {
    if (!DPIcons) DPIcons = [NSMutableDictionary dictionary];
    NSView *hint = DPGet(panel, &DPHintKey);
    NSString *row = hint.superview ? DPRowText(hint.superview) : @"";
    if ([row containsString:site[@"domain"]] || [row containsString:[site[@"name"] lowercaseString]]) {
        NSImageView *icon = (NSImageView *)DPFindView(hint.superview, ^BOOL(NSView *view) {
            return [view isKindOfClass:NSImageView.class] && [NSStringFromClass(view.superview.class) containsString:@"IconContainerView"];
        });
        if (icon.image) DPIcons[site[@"domain"]] = icon.image;
    }
    return DPIcons[site[@"domain"]] ?: [NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];
}

static NSView *DPPill(NSDictionary *site, NSImage *icon, CGFloat height) {
    NSView *pill = [[NSView alloc] initWithFrame:NSZeroRect];
    pill.wantsLayer = YES;
    pill.layer.cornerRadius = 6;
    pill.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.12].CGColor;
    NSTextField *label = [NSTextField labelWithString:site[@"name"]];
    label.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    label.textColor = NSColor.labelColor;
    [label sizeToFit];
    CGFloat x = 6;
    if (icon) {
        NSImageView *image = [NSImageView imageViewWithImage:icon];
        image.frame = NSMakeRect(x, round((height - 16) / 2), 16, 16);
        image.imageScaling = NSImageScaleProportionallyUpOrDown;
        [pill addSubview:image];
        x += 16 + 5;
    }
    label.frame = NSMakeRect(x, round((height - NSHeight(label.frame)) / 2), ceil(NSWidth(label.frame)), NSHeight(label.frame));
    [pill addSubview:label];
    pill.frame = NSMakeRect(0, 0, NSMaxX(label.frame) + 8, height);
    return pill;
}

@interface DPSiteInput : NSView
@property(strong) NSView *pill;
@property(strong) NSTextField *field;
@end

@implementation DPSiteInput
- (void)layout {
    [super layout];
    NSRect bounds = self.bounds;
    CGFloat height = NSHeight(self.pill.frame);
    self.pill.frame = NSMakeRect(0, round(NSMidY(bounds) - height / 2), NSWidth(self.pill.frame), height);
    CGFloat x = NSMaxX(self.pill.frame) + 6, fieldHeight = ceil(self.field.intrinsicContentSize.height);
    self.field.frame = NSMakeRect(x, round(NSMidY(bounds) - fieldHeight / 2), MAX(0, NSWidth(bounds) - x), fieldHeight);
}
@end

static void DPReplaceText(NSTextView *text, NSString *string) {
    [text insertText:string replacementRange:NSMakeRange(0, text.string.length)];
    text.selectedRange = NSMakeRange(string.length, 0);
}

static void DPPlaceInput(DPSiteMode *mode) {
    NSView *dias = mode.dias, *input = mode.input;
    if (!dias.superview || !input) return;
    if (input.superview != dias.superview) [dias.superview addSubview:input positioned:NSWindowAbove relativeTo:dias];
    // Taller than Dia's box, so the pill has room; centred on it.
    NSRect frame = NSInsetRect(dias.frame, 0, -3);
    if (!NSEqualRects(input.frame, frame)) input.frame = frame;
    if (!dias.hidden) dias.hidden = YES;
}

static void DPLeaveSite(NSView *panel, NSTextView *text, BOOL restoreText) {
    DPSiteMode *mode = DPGet(panel, &DPModeKey);
    if (!mode) return;
    DPSet(panel, &DPModeKey, nil);
    NSWindow *window = mode.field.window;
    BOOL focused = window && (window.firstResponder == mode.field || window.firstResponder == mode.field.currentEditor);
    [mode.input removeFromSuperview];
    mode.dias.hidden = NO;
    if (mode.changes) [NSNotificationCenter.defaultCenter removeObserver:mode.changes];
    mode.asked++;
    [mode.list removeFromSuperview];
    if (restoreText) DPReplaceText(text, mode.typed ?: @"");
    if (focused) [window makeFirstResponder:text];
}

static void DPEnterSite(NSView *panel, NSTextView *text, NSDictionary *site) {
    NSView *dias = text.enclosingScrollView.superview;
    if (!dias.superview) return;
    DPSiteMode *mode = [DPSiteMode new];
    mode.site = site;
    mode.typed = DPTyped(text);
    mode.dias = dias;
    DPSiteInput *input = [[DPSiteInput alloc] initWithFrame:dias.frame];
    input.pill = DPPill(site, DPIconFor(panel, site), 24);
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.bezeled = NO;
    field.bordered = NO;
    field.drawsBackground = NO;
    field.focusRingType = NSFocusRingTypeNone;
    field.usesSingleLineMode = YES;
    field.cell.scrollable = YES;
    field.cell.wraps = NO;
    field.font = text.font ?: [NSFont systemFontOfSize:16];
    field.textColor = text.textColor ?: NSColor.labelColor;
    NSAttributedString *placeholder = [text respondsToSelector:@selector(placeholderAttributedString)] ? [(id)text placeholderAttributedString] : nil;
    NSDictionary *look = placeholder.length ? [placeholder attributesAtIndex:0 effectiveRange:NULL] : @{NSFontAttributeName : field.font, NSForegroundColorAttributeName : NSColor.placeholderTextColor};
    field.placeholderAttributedString = [[NSAttributedString alloc] initWithString:[@"Search " stringByAppendingString:site[@"name"]] attributes:look];
    input.field = field;
    [input addSubview:input.pill];
    [input addSubview:field];
    mode.input = input;
    mode.field = field;
    DPSet(panel, &DPModeKey, mode);
    DPRemoveSiteHint(panel);
    DPReplaceText(text, @"");  // Nothing for Dia to suggest from.
    DPPlaceInput(mode);
    [input layoutSubtreeIfNeeded];
    [text.window makeFirstResponder:field];
    DPSiteList *list = [[DPSiteList alloc] initWithFrame:NSZeroRect];
    list.panel = panel;
    list.fill = DPPanelFill(panel, DPToolbarOf(panel));
    list.corner = DPPanelCorner(panel);
    list.hidden = YES;
    NSShadow *shadow = [NSShadow new];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.3];
    shadow.shadowBlurRadius = 24;
    list.shadow = shadow;
    mode.list = list;
    __weak DPSiteMode *weak = mode;
    void (^search)(NSString *) = ^(NSString *query) {
        DPSiteMode *mode = weak;
        if (mode.open) mode.open(DPSearchURL(mode.site, query));
    };
    mode.changes = [NSNotificationCenter.defaultCenter addObserverForName:NSControlTextDidChangeNotification object:field queue:nil usingBlock:^(NSNotification *note) {
        DPSiteMode *mode = weak;
        NSString *query = [mode.field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSInteger asked = ++mode.asked;
        DPShowRows(mode, @[], search);
        if (!query.length) return;
        // A moment's pause in typing before asking, and only the latest answer counts.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weak.asked != asked) return;
            DPAskSite(weak.site, query, NO, ^(NSArray<NSString *> *found) {
                if (weak.asked == asked) DPShowRows(weak, found, search);
            });
        });
    }];
}

void DPSiteSearchRefresh(NSView *panel, NSTextView *text) {
    if (!panel || !text) return;
    DPSiteMode *mode = DPGet(panel, &DPModeKey);
    if (!DPSiteSearch.on) {
        DPRemoveSiteHint(panel);
        return DPLeaveSite(panel, text, NO);
    }
    if (mode) {
        DPRemoveSiteHint(panel);
        if (text.string.length) DPReplaceText(text, @"");
        DPPlaceInput(mode);  // Dia may have laid the bar out again.
        return DPPlaceList(mode);
    }
    NSDictionary *site = DPSiteFor(text);
    if (site) DPShowSiteHint(panel, site);
    else DPRemoveSiteHint(panel);
}

BOOL DPSiteSearchKey(NSEvent *event, NSView *panel, NSTextView *text, void (^open)(NSString *url)) {
    if (!DPSiteSearch.on || event.type != NSEventTypeKeyDown || !panel || !text) return NO;
    NSEventModifierFlags mods = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl | NSEventModifierFlagShift);
    DPSiteMode *mode = DPGet(panel, &DPModeKey);
    NSTextView *editor = (NSTextView *)mode.field.currentEditor;
    if (mode ? editor.hasMarkedText : text.hasMarkedText) return NO;
    NSString *query = [mode.field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    DPSiteList *list = (DPSiteList *)mode.list;
    if (mode) mode.open = open;
    if (list.selected > 0 && list.selected < (NSInteger)list.subviews.count) query = ((DPSiteRow *)list.subviews[list.selected]).query;
    switch (event.keyCode) {
        case 125:  // Down
        case 126:  // Up
            if (!mode) return NO;
            if (list.subviews.count) list.selected = (list.selected + (event.keyCode == 125 ? 1 : -1) + (NSInteger)list.subviews.count) % (NSInteger)list.subviews.count;
            return YES;
        case 48: {  // Tab
            if (mode) {
                if (mods == NSEventModifierFlagShift) DPLeaveSite(panel, text, YES);
                return YES;
            }
            NSDictionary *site = mods ? nil : DPSiteFor(text);
            if (!site) return NO;
            DPEnterSite(panel, text, site);
            DPSiteMode *entered = DPGet(panel, &DPModeKey);
            entered.open = open;
            return YES;
        }
        case 36:
        case 76:  // Return
            if (!mode || mods) return NO;
            open(DPSearchURL(mode.site, query));
            return YES;
        case 51:  // Delete, with nothing left to delete
            if (!mode || mode.field.stringValue.length) return NO;
            DPLeaveSite(panel, text, YES);
            return YES;
        case 53:  // Escape leaves the site first, then closes the bar
            if (!mode) return NO;
            DPLeaveSite(panel, text, YES);
            return YES;
    }
    return NO;
}

NSView *DPSiteSearchField(NSView *panel) {
    DPSiteMode *mode = panel ? DPGet(panel, &DPModeKey) : nil;
    return mode.field;
}

void DPSiteSearchEnd(NSView *panel, NSTextView *text) {
    DPRemoveSiteHint(panel);
    DPLeaveSite(panel, text, NO);
}

DP_PATCH(DPSiteSearch) {
    .key = @"siteSearch",
    .order = 93,
    .title = @"Search Sites from the Bar",
    .detail = @"Type a site's name or address, like YouTube, Amazon, Reddit or Google Scholar, and its suggestion offers Tab to search it. Press Tab and the site shows in the bar, with its own suggestions as you type. Delete or Escape goes back.",
    .symbol = @"magnifyingglass.circle.fill",
    .tint = @"systemOrangeColor",
    .requires = @"commandBar",
    .section = @"Site Search",
};
