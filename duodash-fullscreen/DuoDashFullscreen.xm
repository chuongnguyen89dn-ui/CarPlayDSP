// ARC bridge fix verified in source; rebuild trigger.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// Weak, identity-based ownership: closing an app must not leave a dangling
// pointer for the next relayout/restore. Snapshot arrays retain live objects
// only for the duration of an operation.
#import "DDFAppState.h"

static DDFAppState *gState;
static __weak UIView *gDockView;
static BOOL gHidden;
static CGFloat gDockWidth;

static void ensureState(void) {
    if (!gState) gState = [DDFAppState new];
}
static void trackApp(id app) {
    ensureState();
    if (app) [gState.apps addObject:app];
}
static void relayoutApps(void) {
    for (id app in gState.apps.allObjects) {
        if ([app respondsToSelector:@selector(relayoutAllWindows)])
            ((void(*)(id,SEL))objc_msgSend)(app,@selector(relayoutAllWindows));
    }
}
static void applyFrames(void) {
    ensureState();
    if (!gHidden) {
        for (id app in gState.frames.keyEnumerator.allObjects) {
            NSValue *value = [gState.frames objectForKey:app];
            if (value && [app respondsToSelector:@selector(setBridgeFrame:)])
                ((void(*)(id,SEL,CGRect))objc_msgSend)(app,@selector(setBridgeFrame:),value.CGRectValue);
        }
        [gState.frames removeAllObjects];
        return;
    }
    id leftApp = nil;
    CGFloat leftX = CGFLOAT_MAX;
    for (id app in gState.apps.allObjects) {
        if (![app respondsToSelector:@selector(bridgeFrame)] ||
            ![app respondsToSelector:@selector(setBridgeFrame:)]) continue;
        CGRect r = ((CGRect(*)(id,SEL))objc_msgSend)(app,@selector(bridgeFrame));
        if (r.size.width < 2 || r.size.height < 2) continue;
        if (![gState.frames objectForKey:app])
            [gState.frames setObject:[NSValue valueWithCGRect:r] forKey:app];
        if (CGRectGetMinX(r) < leftX) { leftX = CGRectGetMinX(r); leftApp = app; }
    }
    if (leftApp) {
        CGRect r = [[gState.frames objectForKey:leftApp] CGRectValue];
        CGFloat dw = gDockWidth > 1 ? gDockWidth : 45.0;
        r.origin.x -= dw;
        r.size.width += dw;
        ((void(*)(id,SEL,CGRect))objc_msgSend)(leftApp,@selector(setBridgeFrame:),r);
    }
}
static void setFullscreen(BOOL hidden) { if (!gDockView) return; if (hidden) { CGRect r=[gDockView convertRect:gDockView.bounds toView:gDockView.window]; gDockWidth=MAX(1.0,r.size.width); gHidden=YES; gDockView.hidden=YES; gDockView.alpha=0.0; } else { gHidden=NO; gDockView.hidden=NO; gDockView.alpha=1.0; } applyFrames(); relayoutApps(); }
static void (*origAppSetBridgeFrame)(id,SEL,CGRect); static void appSetBridgeFrame(id self,SEL _cmd,CGRect frame) { trackApp(self); if (origAppSetBridgeFrame) origAppSetBridgeFrame(self,_cmd,frame); }
static void (*origAppSetIsSplit)(id,SEL,BOOL); static void appSetIsSplit(id self,SEL _cmd,BOOL split) { trackApp(self); if (origAppSetIsSplit) origAppSetIsSplit(self,_cmd,split); }
static void (*origDockViewDidAppear)(id,SEL,BOOL); static void dockViewDidAppear(id self,SEL _cmd,BOOL animated) { if (origDockViewDidAppear) origDockViewDidAppear(self,_cmd,animated); if ([self respondsToSelector:@selector(view)]) gDockView=[self view]; }
static CGPoint gStart; static BOOL gTracking; static void (*origDivBegan)(id,SEL,NSSet *,UIEvent *); static void (*origDivEnded)(id,SEL,NSSet *,UIEvent *); static void (*origDivCancelled)(id,SEL,NSSet *,UIEvent *);
static void divBegan(id self,SEL _cmd,NSSet *touches,UIEvent *event) { if (origDivBegan) origDivBegan(self,_cmd,touches,event); UITouch *t=[touches anyObject]; if(t){gStart=[t locationInView:self];gTracking=YES;} }
static void divEnded(id self,SEL _cmd,NSSet *touches,UIEvent *event) { if(origDivEnded) origDivEnded(self,_cmd,touches,event); if(!gTracking)return; gTracking=NO; UITouch *t=[touches anyObject]; if(!t)return; CGPoint end=[t locationInView:self]; CGFloat dx=end.x-gStart.x,dy=end.y-gStart.y; if(fabs(dy)>=28.0 && fabs(dy)>fabs(dx)*1.35) setFullscreen(!gHidden); }
static void divCancelled(id self,SEL _cmd,NSSet *touches,UIEvent *event) { if(origDivCancelled) origDivCancelled(self,_cmd,touches,event); gTracking=NO; }
__attribute__((constructor)) static void initDuoDashFullscreen(void) { @autoreleasepool { Class app=objc_getClass("CNABUIApp"); if(app){MSHookMessageEx(app,@selector(setBridgeFrame:),(IMP)appSetBridgeFrame,(IMP *)&origAppSetBridgeFrame);MSHookMessageEx(app,@selector(setIsSplit:),(IMP)appSetIsSplit,(IMP *)&origAppSetIsSplit);} Class dock=objc_getClass("DBAppDockViewController");if(!dock)dock=objc_getClass("CARAppDockViewController");if(dock)MSHookMessageEx(dock,@selector(viewDidAppear:),(IMP)dockViewDidAppear,(IMP *)&origDockViewDidAppear); Class divider=objc_getClass("CNABDividerView");if(divider){MSHookMessageEx(divider,@selector(touchesBegan:withEvent:),(IMP)divBegan,(IMP *)&origDivBegan);MSHookMessageEx(divider,@selector(touchesEnded:withEvent:),(IMP)divEnded,(IMP *)&origDivEnded);MSHookMessageEx(divider,@selector(touchesCancelled:withEvent:),(IMP)divCancelled,(IMP *)&origDivCancelled);}}}
