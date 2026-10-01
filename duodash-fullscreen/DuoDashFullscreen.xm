#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

static NSMutableArray *gApps;
static __weak UIView *gDockView;
static NSMutableDictionary *gOriginalFrames;
static BOOL gHidden;
static CGFloat gDockWidth;

static void ensureState(void) {
    if (!gApps) gApps = [NSMutableArray array];
    if (!gOriginalFrames) gOriginalFrames = [NSMutableDictionary dictionary];
}

static void trackApp(id app) {
    ensureState();
    for (NSValue *v in gApps)
        if ([v pointerValue] == (__bridge void *)app) return;
    [gApps addObject:[NSValue valueWithNonretainedObject:app]];
}

static void relayoutApps(void) {
    for (NSValue *v in [gApps copy]) {
        id app = [v nonretainedObjectValue];
        if (app && [app respondsToSelector:@selector(relayoutAllWindows)])
            ((void(*)(id,SEL))objc_msgSend)(app, @selector(relayoutAllWindows));
    }
}

static void applyFrames(void) {
    ensureState();
    NSArray *apps = [gApps copy];

    if (!gHidden) {
        for (NSValue *key in [gOriginalFrames allKeys]) {
            id app = [key nonretainedObjectValue];
            NSValue *value = gOriginalFrames[key];
            if (app && value && [app respondsToSelector:@selector(setBridgeFrame:)])
                ((void(*)(id,SEL,CGRect))objc_msgSend)(app, @selector(setBridgeFrame:), value.CGRectValue);
        }
        [gOriginalFrames removeAllObjects];
        return;
    }

    NSValue *leftKey = nil;
    CGFloat leftX = CGFLOAT_MAX;
    for (NSValue *v in apps) {
        id app = [v nonretainedObjectValue];
        if (!app || ![app respondsToSelector:@selector(bridgeFrame)] || ![app respondsToSelector:@selector(setBridgeFrame:)])
            continue;
        CGRect r = ((CGRect(*)(id,SEL))objc_msgSend)(app, @selector(bridgeFrame));
        if (r.size.width < 2 || r.size.height < 2) continue;

        NSValue *key = [NSValue valueWithNonretainedObject:app];
        if (!gOriginalFrames[key]) gOriginalFrames[key] = [NSValue valueWithCGRect:r];

        if (CGRectGetMinX(r) < leftX) {
            leftX = CGRectGetMinX(r);
            leftKey = key;
        }
    }

    if (leftKey) {
        id app = [leftKey nonretainedObjectValue];
        CGRect r = [gOriginalFrames[leftKey] CGRectValue];
        CGFloat dw = gDockWidth > 1 ? gDockWidth : 45.0;
        r.origin.x -= dw;
        r.size.width += dw;
        ((void(*)(id,SEL,CGRect))objc_msgSend)(app, @selector(setBridgeFrame:), r);
    }
}

static void setFullscreen(BOOL hidden) {
    if (!gDockView) return;

    if (hidden) {
        CGRect r = [gDockView convertRect:gDockView.bounds toView:gDockView.window];
        gDockWidth = MAX(1.0, r.size.width);
        gHidden = YES;
        gDockView.hidden = YES;
        gDockView.alpha = 0.0;
    } else {
        gHidden = NO;
        gDockView.hidden = NO;
        gDockView.alpha = 1.0;
    }

    applyFrames();
    relayoutApps();
}

static void (*origAppSetBridgeFrame)(id,SEL,CGRect);
static void appSetBridgeFrame(id self, SEL _cmd, CGRect frame) {
    trackApp(self);
    if (origAppSetBridgeFrame) origAppSetBridgeFrame(self,_cmd,frame);
}

static void (*origAppSetIsSplit)(id,SEL,BOOL);
static void appSetIsSplit(id self, SEL _cmd, BOOL split) {
    trackApp(self);
    if (origAppSetIsSplit) origAppSetIsSplit(self,_cmd,split);
}

static void (*origDockViewDidAppear)(id,SEL,BOOL);
static void dockViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (origDockViewDidAppear) origDockViewDidAppear(self,_cmd,animated);
    if ([self respondsToSelector:@selector(view)]) gDockView = [self view];
}

static CGPoint gStart;
static BOOL gTracking;
static void (*origDivBegan)(id,SEL,NSSet *,UIEvent *);
static void (*origDivEnded)(id,SEL,NSSet *,UIEvent *);
static void (*origDivCancelled)(id,SEL,NSSet *,UIEvent *);

static void divBegan(id self, SEL _cmd, NSSet *touches, UIEvent *event) {
    if (origDivBegan) origDivBegan(self,_cmd,touches,event);
    UITouch *t = [touches anyObject];
    if (t) { gStart = [t locationInView:self]; gTracking = YES; }
}

static void divEnded(id self, SEL _cmd, NSSet *touches, UIEvent *event) {
    if (origDivEnded) origDivEnded(self,_cmd,touches,event);
    if (!gTracking) return;
    gTracking = NO;
    UITouch *t = [touches anyObject];
    if (!t) return;
    CGPoint end = [t locationInView:self];
    CGFloat dx = end.x - gStart.x, dy = end.y - gStart.y;

    if (fabs(dy) >= 28.0 && fabs(dy) > fabs(dx) * 1.35)
        setFullscreen(!gHidden);
}

static void divCancelled(id self, SEL _cmd, NSSet *touches, UIEvent *event) {
    if (origDivCancelled) origDivCancelled(self,_cmd,touches,event);
    gTracking = NO;
}

__attribute__((constructor))
static void initDuoDashFullscreen(void) {
    @autoreleasepool {
        Class app = objc_getClass("CNABUIApp");
        if (app) {
            MSHookMessageEx(app,@selector(setBridgeFrame:),(IMP)appSetBridgeFrame,(IMP *)&origAppSetBridgeFrame);
            MSHookMessageEx(app,@selector(setIsSplit:),(IMP)appSetIsSplit,(IMP *)&origAppSetIsSplit);
        }

        Class dock = objc_getClass("DBAppDockViewController");
        if (!dock) dock = objc_getClass("CARAppDockViewController");
        if (dock)
            MSHookMessageEx(dock,@selector(viewDidAppear:),(IMP)dockViewDidAppear,(IMP *)&origDockViewDidAppear);

        Class divider = objc_getClass("CNABDividerView");
        if (divider) {
            MSHookMessageEx(divider,@selector(touchesBegan:withEvent:),(IMP)divBegan,(IMP *)&origDivBegan);
            MSHookMessageEx(divider,@selector(touchesEnded:withEvent:),(IMP)divEnded,(IMP *)&origDivEnded);
            MSHookMessageEx(divider,@selector(touchesCancelled:withEvent:),(IMP)divCancelled,(IMP *)&origDivCancelled);
        }
    }
}
