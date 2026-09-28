#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>
#import <string.h>

static NSString * const CPSLogPath = @"/var/mobile/Documents/CPSSceneProbe.log";
static void CPSLog(NSString *message) {
    @synchronized([UIApplication class]) {
        NSString *line=[NSString stringWithFormat:@"%@ pid=%d process=%@ %@\n",
          [NSDate date],getpid(),[NSProcessInfo processInfo].processName,message];
        int fd=open(CPSLogPath.UTF8String,O_WRONLY|O_CREAT|O_APPEND,0644);
        if(fd>=0) { const char *p=line.UTF8String; write(fd,p,strlen(p)); close(fd); }
    }
}
static void CPSWalk(UIView *view, NSUInteger depth, NSMutableSet *seen) {
    if(!view || depth>5 || [seen containsObject:view]) return;
    [seen addObject:view];
    NSString *name=NSStringFromClass([view class]);
    CPSLog([NSString stringWithFormat:@"depth=%lu class=%@ frame=%@ bounds=%@ hidden=%d alpha=%.3f gestures=%lu children=%lu",
       (unsigned long)depth,name,NSStringFromCGRect(view.frame),NSStringFromCGRect(view.bounds),
       view.hidden,view.alpha,(unsigned long)view.gestureRecognizers.count,(unsigned long)view.subviews.count]);
    for(UIView *child in view.subviews) CPSWalk(child,depth+1,seen);
}
static void CPSSnapshot(void) {
    UIApplication *app=UIApplication.sharedApplication;
    CPSLog(@"SNAPSHOT BEGIN");
    for(UIScene *scene in app.connectedScenes) {
        CPSLog([NSString stringWithFormat:@"scene=%@ state=%ld",NSStringFromClass(scene.class),(long)scene.activationState]);
        if(![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *ws=(UIWindowScene *)scene;
        CPSLog([NSString stringWithFormat:@"scene bounds=%@ orientation=%ld windows=%lu",
          NSStringFromCGRect(ws.coordinateSpace.bounds),(long)ws.interfaceOrientation,(unsigned long)ws.windows.count]);
        for(UIWindow *window in ws.windows) {
            CPSLog([NSString stringWithFormat:@"window=%@ frame=%@ safeArea=%@ root=%@ key=%d",
              NSStringFromClass(window.class),NSStringFromCGRect(window.frame),
              NSStringFromUIEdgeInsets(window.safeAreaInsets),
              NSStringFromClass(window.rootViewController.class),window.isKeyWindow]);
            CPSWalk(window,0,[NSMutableSet set]);
        }
    }
    CPSLog(@"SNAPSHOT END");
}
%ctor {
    @autoreleasepool {
        NSString *name=[NSProcessInfo processInfo].processName;
        if(![name isEqualToString:@"CarPlay"] && ![name isEqualToString:@"CarPlayTemplateUIHost"]) return;
        CPSLog(@"PROBE LOADED; read-only scene inventory");
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
              object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) { CPSSnapshot(); }];
            CPSSnapshot();
        });
    }
}
