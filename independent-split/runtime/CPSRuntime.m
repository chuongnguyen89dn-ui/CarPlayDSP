#import "CPSRuntime.h"
#import "../CPSLayouts.h"
#import "../shared/CPSSettings.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <unistd.h>

// Private entry points are checked before use. The evidence for each group is
// recorded in IMPLEMENTATION_EVIDENCE.md. No reference dylib is loaded here.
static id CPSGet(id object, NSString *name) {
    SEL selector=NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? ((id(*)(id,SEL))objc_msgSend)(object,selector) : nil;
}
static id CPSObject(id object, NSString *name, id argument) {
    SEL selector=NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? ((id(*)(id,SEL,id))objc_msgSend)(object,selector,argument) : nil;
}
static void CPSSetObject(id object, NSString *name, id argument) {
    SEL selector=NSSelectorFromString(name);
    if([object respondsToSelector:selector]) ((void(*)(id,SEL,id))objc_msgSend)(object,selector,argument);
}
static void CPSBool(id object, NSString *name, BOOL argument) {
    SEL selector=NSSelectorFromString(name);
    if([object respondsToSelector:selector]) ((void(*)(id,SEL,BOOL))objc_msgSend)(object,selector,argument);
}
static void CPSInteger(id object, NSString *name, NSInteger argument) {
    SEL selector=NSSelectorFromString(name);
    if([object respondsToSelector:selector]) ((void(*)(id,SEL,NSInteger))objc_msgSend)(object,selector,argument);
}
static void CPSRect(id object, NSString *name, CGRect argument) {
    SEL selector=NSSelectorFromString(name);
    if([object respondsToSelector:selector]) ((void(*)(id,SEL,CGRect))objc_msgSend)(object,selector,argument);
}
static NSError *CPSError(NSString *message) {
    return [NSError errorWithDomain:CPSPreferences code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}
static void CPSLog(NSString *message) {
    NSLog(@"CarPlaySplit %@",message);
    if(![NSProcessInfo.processInfo.processName isEqual:@"SpringBoard"])return;
    static dispatch_queue_t queue;static dispatch_once_t once;
    dispatch_once(&once,^{queue=dispatch_queue_create("com.chuong.carplaysplit.log",DISPATCH_QUEUE_SERIAL);});
    NSString *line=[NSString stringWithFormat:@"%@ %@\n",[NSDate date],message];
    dispatch_async(queue,^{@autoreleasepool{@try{
        NSString *dir=@"/var/mobile/Library/Logs",*path=[dir stringByAppendingPathComponent:@"CarPlaySplit-runtime.log"];
        NSFileManager *fm=NSFileManager.defaultManager;[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        if([[fm attributesOfItemAtPath:path error:nil] fileSize]>2*1024*1024)[fm removeItemAtPath:path error:nil];
        if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:@{NSFilePosixPermissions:@0644}];
        NSFileHandle *file=[NSFileHandle fileHandleForWritingAtPath:path];[file seekToEndOfFile];[file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];[file closeFile];
    }@catch(NSException *e){NSLog(@"CarPlaySplit log write: %@",e.reason);}}});
}
static id CPSPreference(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)CPSPreferences));
}
static void CPSWritePreference(NSString *key,id value) {
    CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)CPSPreferences);
    CFPreferencesAppSynchronize((__bridge CFStringRef)CPSPreferences);
}
static NSMutableSet<NSString *> *CPSHostedBundles;
static NSMutableSet *CPSHostedScenes;
static NSMapTable *CPSSceneGeometry;
static NSMapTable *CPSControllerGeometry;
static NSMapTable *CPSHandleOwners;
static UIWindow *CPSWindow;
static CPSSplitController *CPSRoot;

@interface CPSSceneHost ()
@property(nonatomic,copy,readwrite) NSString *bundleID;
@property(nonatomic,strong,readwrite) UIViewController *controller;
@property(nonatomic,strong,readwrite) id scene;
@property(nonatomic,strong) id entity;
@property(nonatomic,strong) id savedSettings;
@property(nonatomic,strong) id deviceController;
@property(nonatomic,strong) id handle;
@property(nonatomic,strong) NSHashTable *phoneViews;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,copy) void (^ready)(void);
@property(nonatomic,weak) UIView *container;
@property(nonatomic) CGSize requestedSize;
@property(nonatomic) CGSize appliedSize;
@property(nonatomic) NSUInteger attempts;
@property(nonatomic) BOOL closed;
@end

@implementation CPSSceneHost
- (instancetype)initWithBundleID:(NSString *)bundleID error:(NSError **)error {
    if(!(self=[super init])) return nil;
    _bundleID=[bundleID copy];
    @try {
        id applications=CPSGet(NSClassFromString(@"SBApplicationController"),@"sharedInstance");
        id application=CPSObject(applications,@"applicationWithBundleIdentifier:",bundleID);
        Class entityClass=NSClassFromString(@"SBDeviceApplicationSceneEntity");
        Class controllerClass=NSClassFromString(@"SBAppViewController");
        SEL entityInit=NSSelectorFromString(@"initWithApplicationForMainDisplay:");
        SEL controllerInit=NSSelectorFromString(@"initWithIdentifier:andApplicationSceneEntity:");
        if(!application || ![entityClass instancesRespondToSelector:entityInit] ||
           ![controllerClass instancesRespondToSelector:controllerInit] ||
           ![controllerClass instancesRespondToSelector:NSSelectorFromString(@"setRequestedMode:")] ||
           ![controllerClass instancesRespondToSelector:NSSelectorFromString(@"_setCurrentMode:")]) {
            if(error) *error=CPSError(@"Phiên bản iOS này thiếu API mở vùng ứng dụng.");
            return nil;
        }
        _entity=((id(*)(id,SEL,id))objc_msgSend)([entityClass alloc],entityInit,application);
        // SpringBoard uses this identifier to bind the controller to its app scene.
        _controller=((id(*)(id,SEL,id,id))objc_msgSend)([controllerClass alloc],controllerInit,
                       bundleID,_entity);
        if(!_entity || !_controller) {
            if(error) *error=CPSError(@"Không tạo được vùng ứng dụng.");
            return nil;
        }
        CPSBool(_controller,@"setIgnoresOcclusions:",NO);
        CPSBool(_controller,@"setAutomatesLifecycle:",NO);
        [_controller loadViewIfNeeded];
        _controller.view.backgroundColor=UIColor.blackColor;
        _controller.view.clipsToBounds=YES;
        _handle=CPSGet(_controller,@"sceneHandle");
        _savedSettings=[CPSGet(CPSGet(_handle,@"sceneIfExists"),@"settings") copy];
        _phoneViews=[NSHashTable weakObjectsHashTable];
    } @catch(NSException *exception) {
        if(error) *error=CPSError([NSString stringWithFormat:@"Không mở được ứng dụng: %@",exception.reason]);
        return nil;
    }
    return self;
}
- (void)attachTo:(UIViewController *)parent container:(UIView *)container {
    if(self.closed) return;
    self.container=container;
    [CPSHostedBundles addObject:self.bundleID];
    [parent addChildViewController:self.controller];
    [container addSubview:self.controller.view];
    [self.controller didMoveToParentViewController:parent];
    if(self.handle) @synchronized(CPSHostedScenes) { [CPSHandleOwners setObject:self forKey:self.handle]; }
    [self.controller beginAppearanceTransition:YES animated:NO];
    CPSInteger(self.controller,@"setRequestedMode:",2);
    [self.controller endAppearanceTransition];
    __weak typeof(self) weakSelf=self;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
        [weakSelf pollScene];
    }];
    [self pollScene];
}
- (void)pollScene {
    if(self.closed) return;
    @try {
        id handle=CPSGet(self.controller,@"sceneHandle");
        id scene=CPSGet(handle,@"sceneIfExists");
        if(scene) {
            if(!self.scene) {
                self.scene=scene;
                self.handle=handle;
                @synchronized(CPSHostedScenes) {
                    [CPSHostedScenes addObject:scene];
                    if(handle) [CPSHandleOwners setObject:self forKey:handle];
                }
                id layout=CPSGet(NSClassFromString(@"SBMainDisplaySceneLayoutViewController"),@"mainDisplaySceneLayoutViewController");
                for(id appController in CPSGet(layout,@"appViewControllers")) {
                    id sceneController=CPSGet(appController,@"_applicationSceneViewController");
                    id sceneView=CPSGet(sceneController,@"_sceneView");
                    if([CPSGet(sceneView,@"sceneHandle") isEqual:handle] && [sceneView window]!=CPSWindow) {
                        SEL mode=NSSelectorFromString(@"setDisplayMode:animationFactory:completion:");
                        if([sceneView respondsToSelector:mode]) {
                            [self.phoneViews addObject:sceneView];
                            ((void(*)(id,SEL,NSInteger,id,id))objc_msgSend)(sceneView,mode,1,nil,nil);
                        }
                    }
                }
                CPSLog([NSString stringWithFormat:@"scene attached bundle=%@ class=%@",self.bundleID,NSStringFromClass([scene class])]);
                if(self.ready) self.ready();
            }
            if(!CGSizeEqualToSize(self.appliedSize,self.requestedSize)) [self applySize];
            return;
        }
        if(self.scene || ++self.attempts>48) {
            NSString *reason=self.scene ? @"Ứng dụng đã đóng. Chọn lại để mở." : @"Ứng dụng không tạo được màn hình. Chọn lại hoặc chọn ứng dụng khác.";
            void (^failure)(NSString *)=self.failure;
            [self close];
            if(failure) failure(reason);
        }
    } @catch(NSException *exception) {
        void (^failure)(NSString *)=self.failure;
        NSString *reason=[NSString stringWithFormat:@"Lỗi vùng ứng dụng: %@",exception.reason];
        [self close];
        if(failure) failure(reason);
    }
}
- (void)resizeTo:(CGSize)size {
    if(self.closed || size.width<=0 || size.height<=0 || !isfinite(size.width) || !isfinite(size.height)) return;
    self.requestedSize=size;
    // Render at twice the pane's logical size, then scale uniformly. This keeps
    // text usable without stretching either axis and preserves UIKit hit testing.
    CGSize logical=CGSizeMake(round(size.width*2),round(size.height*2));
    NSInteger orientation=logical.width>=logical.height ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait;
    @try {
        self.deviceController=[self.controller valueForKey:@"_deviceAppViewController"];
        if(self.deviceController) {
            @synchronized(CPSHostedScenes) {
                [CPSControllerGeometry setObject:@{@"size":[NSValue valueWithCGSize:logical],@"orientation":@(orientation)} forKey:self.deviceController];
            }
            SEL reference=NSSelectorFromString(@"setContentReferenceSize:withInterfaceOrientation:");
            SEL reference3=NSSelectorFromString(@"setContentReferenceSize:withContentOrientation:andContainerOrientation:");
            if([self.deviceController respondsToSelector:reference])
                ((void(*)(id,SEL,CGSize,NSInteger))objc_msgSend)(self.deviceController,reference,logical,orientation);
            else if([self.deviceController respondsToSelector:reference3])
                ((void(*)(id,SEL,CGSize,NSInteger,NSInteger))objc_msgSend)(self.deviceController,reference3,logical,orientation,orientation);
            CPSInteger(self.deviceController,@"setHomeGrabberDisplayMode:",1);
        }
    } @catch(NSException *exception) { CPSLog(exception.reason); }
    UIView *view=self.controller.view;
    view.transform=CGAffineTransformIdentity;
    view.bounds=(CGRect){CGPointZero,logical};
    view.center=CGPointMake(size.width/2,size.height/2);
    view.transform=CGAffineTransformMakeScale(size.width/logical.width,size.height/logical.height);
    if(self.scene && !CGSizeEqualToSize(self.appliedSize,size)) [self applySize];
}
- (void)applySize {
    if(self.closed || !self.scene || self.requestedSize.width<=0) return;
    id settings=CPSGet(self.scene,@"mutableSettings");
    SEL update=NSSelectorFromString(@"updateSettings:withTransitionContext:completion:");
    if(!settings || ![settings respondsToSelector:NSSelectorFromString(@"setFrame:")] || ![self.scene respondsToSelector:update]) return;
    CGSize logical=CGSizeMake(round(self.requestedSize.width*2),round(self.requestedSize.height*2));
    CPSRect(settings,@"setFrame:",(CGRect){CGPointZero,logical});
    CPSInteger(settings,@"setInterfaceOrientation:",logical.width>=logical.height ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait);
    CPSBool(settings,@"setForeground:",YES);
    CPSBool(settings,@"setBackgrounded:",NO);
    @synchronized(CPSHostedScenes) {
        [CPSSceneGeometry setObject:@{@"frame":[NSValue valueWithCGRect:(CGRect){CGPointZero,logical}],
            @"orientation":@(logical.width>=logical.height ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait)} forKey:self.scene];
    }
    ((void(*)(id,SEL,id,id,id))objc_msgSend)(self.scene,update,settings,nil,nil);
    self.appliedSize=self.requestedSize;
    CPSLog([NSString stringWithFormat:@"pane resized bundle=%@ display=%@ render=%@",self.bundleID,NSStringFromCGSize(self.requestedSize),NSStringFromCGSize(logical)]);
}
- (void)close {
    if(self.closed) return;
    self.closed=YES;
    [self.timer invalidate]; self.timer=nil;
    [CPSHostedBundles removeObject:self.bundleID];
    if(self.scene) @synchronized(CPSHostedScenes) {
        [CPSHostedScenes removeObject:self.scene]; [CPSSceneGeometry removeObjectForKey:self.scene];
    }
    if(self.deviceController) @synchronized(CPSHostedScenes) { [CPSControllerGeometry removeObjectForKey:self.deviceController]; }
    if(self.handle) @synchronized(CPSHostedScenes) { [CPSHandleOwners removeObjectForKey:self.handle]; }
    @try {
        [self.controller willMoveToParentViewController:nil];
        [self.controller beginAppearanceTransition:NO animated:NO];
        // setRequestedMode: queues an asynchronous transition. Releasing the
        // controller during that transition triggers SBAppViewController's
        // dealloc assertion on iOS 16.7.16. Reset the actual mode first.
        CPSInteger(self.controller,@"_setCurrentMode:",0);
        [self.controller endAppearanceTransition];
        [self.controller.view removeFromSuperview];
        [self.controller removeFromParentViewController];
        SEL update=NSSelectorFromString(@"updateSettings:withTransitionContext:completion:");
        id restore=self.savedSettings ? [self.savedSettings mutableCopy] : CPSGet(self.scene,@"mutableSettings");
        if(restore && [self.scene respondsToSelector:update]) {
            id frontmost=CPSGet(UIApplication.sharedApplication,@"_accessibilityFrontMostApplication");
            BOOL active=[CPSGet(frontmost,@"bundleIdentifier") isEqualToString:self.bundleID];
            CPSBool(restore,@"setForeground:",active); CPSBool(restore,@"setBackgrounded:",!active);
            if(!self.savedSettings) {
                CGRect bounds=UIScreen.mainScreen.bounds;
                CPSRect(restore,@"setFrame:",bounds);
                CPSInteger(restore,@"setInterfaceOrientation:",bounds.size.width>bounds.size.height ? UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationPortrait);
            }
            ((void(*)(id,SEL,id,id,id))objc_msgSend)(self.scene,update,restore,nil,nil);
        }
        SEL mode=NSSelectorFromString(@"setDisplayMode:animationFactory:completion:");
        for(id view in self.phoneViews) if([view respondsToSelector:mode])
            ((void(*)(id,SEL,NSInteger,id,id))objc_msgSend)(view,mode,4,nil,nil);
    } @catch(NSException *exception) { CPSLog(exception.reason); }
    self.controller=nil; self.entity=nil; self.scene=nil; self.savedSettings=nil; self.deviceController=nil; self.handle=nil;
    [self.phoneViews removeAllObjects];
}
- (void)dealloc { [self.timer invalidate]; }
@end

#include "CPSInterface.inc"

static id CPSCarDisplay(void) {
    id external=CPSGet(NSClassFromString(@"AVExternalDevice"),@"currentCarPlayExternalDevice");
    NSArray *screenIDs=CPSGet(external,@"screenIDs");
    if(!screenIDs.count) return nil;
    for(id display in CPSGet(NSClassFromString(@"CADisplay"),@"displays")) {
        if([screenIDs containsObject:CPSGet(display,@"uniqueId")]) return display;
    }
    return nil;
}
static void CPSStop(void) {
    [CPSRoot shutdown];
    CPSWindow.hidden=YES; CPSWindow.rootViewController=nil;
    CPSRoot=nil; CPSWindow=nil;
    notify_post("com.chuong.carplaysplit.stopped");
    CPSLog(@"split dismissed; original Dashboard exposed");
}
static void CPSStart(void) {
    if(!CPSEnabled())return;
    if(CPSWindow) { notify_post("com.chuong.carplaysplit.started"); return; }
    @try {
        id display=CPSCarDisplay();
        Class configClass=NSClassFromString(@"FBSDisplayConfiguration"), windowClass=NSClassFromString(@"UIRootSceneWindow");
        SEL configInit=NSSelectorFromString(@"initWithCADisplay:isMainDisplay:"),windowInit=NSSelectorFromString(@"initWithDisplayConfiguration:");
        if(!display || ![configClass instancesRespondToSelector:configInit] || ![windowClass instancesRespondToSelector:windowInit]) {
            CPSLog(@"cannot start: CarPlay display or window API unavailable");
            notify_post("com.chuong.carplaysplit.unavailable"); return;
        }
        id config=((id(*)(id,SEL,id,BOOL))objc_msgSend)([configClass alloc],configInit,display,NO);
        UIWindow *window=((id(*)(id,SEL,id))objc_msgSend)([windowClass alloc],windowInit,config);
        if(!window || CGRectIsEmpty(window.bounds)) { CPSLog(@"empty external window"); return; }
        CPSRoot=[CPSSplitController new]; CPSWindow=window;
        window.windowLevel=UIWindowLevelAlert+100;
        window.backgroundColor=UIColor.blackColor;
        window.rootViewController=CPSRoot;
        window.hidden=NO;
        CPSWritePreference(@"displayInfo",[NSString stringWithFormat:@"%@ pt\nscale %.2f\n%@",NSStringFromCGRect(window.bounds),window.screen.scale,UIDevice.currentDevice.systemVersion]);
        notify_post("com.chuong.carplaysplit.started");
        CPSLog([NSString stringWithFormat:@"split window visible bounds=%@",NSStringFromCGRect(window.bounds)]);
    } @catch(NSException *exception) { CPSLog(exception.reason); CPSStop(); }
}

static BOOL CPSConnected;
static NSUInteger CPSConnectionGeneration;
static void CPSConnectionChanged(void) {
    BOOL connected=CPSCarDisplay()!=nil;if(connected==CPSConnected)return;
    CPSConnected=connected;NSUInteger generation=++CPSConnectionGeneration;
    CPSLog(connected?@"CarPlay connected":@"CarPlay disconnected");
    if(connected){if(CPSEnabled()&&[CPSPref(@"autoStart")boolValue])CPSStart();return;}
    NSArray *managed=CPSManaged.allObjects;CPSStop();
    if(![CPSPref(@"closeDisconnect")boolValue])return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(generation!=CPSConnectionGeneration||CPSCarDisplay()||![CPSPref(@"closeDisconnect")boolValue])return;
        for(NSString *bid in managed)CPSTerminate(bid,nil,^(NSString *status){CPSLog([NSString stringWithFormat:@"disconnect cleanup %@: %@",bid,status]);});
    });
}

static void (*CPSOriginalUpdate)(id,SEL,id,id,id);
static void CPSUpdate(id scene,SEL selector,id settings,id context,id completion) {
    BOOL hosted=NO; NSDictionary *geometry=nil;
    @synchronized(CPSHostedScenes) { hosted=[CPSHostedScenes containsObject:scene]; geometry=[CPSSceneGeometry objectForKey:scene]; }
    if(hosted) {
        @try {
            id copy=[settings mutableCopy];
            CPSBool(copy,@"setForeground:",YES); CPSBool(copy,@"setBackgrounded:",NO);
            if(geometry) {
                CPSRect(copy,@"setFrame:",[geometry[@"frame"] CGRectValue]);
                CPSInteger(copy,@"setInterfaceOrientation:",[geometry[@"orientation"] integerValue]);
            }
            settings=copy ?: settings;
        } @catch(NSException *e) { CPSLog(e.reason); }
    }
    CPSOriginalUpdate(scene,selector,settings,context,completion);
}
static int (*CPSOriginalLock)(id,SEL,id,id);
static int CPSLock(id object,SEL selector,id scene,id settings) {
    @synchronized(CPSHostedScenes) { if([CPSHostedScenes containsObject:scene]) return 0; }
    return CPSOriginalLock(object,selector,scene,settings);
}
static void (*CPSOriginalDisplayMode)(id,SEL,NSInteger,id,id);
static void CPSDisplayMode(id view,SEL selector,NSInteger mode,id animation,id completion) {
    id handle=CPSGet(view,@"sceneHandle"); CPSSceneHost *host=nil;
    if(handle) @synchronized(CPSHostedScenes) { host=[CPSHandleOwners objectForKey:handle]; }
    if(host && mode==4 && [view window]!=CPSWindow) {
        [host.phoneViews addObject:view]; mode=1;
    }
    CPSOriginalDisplayMode(view,selector,mode,animation,completion);
}
static void (*CPSOriginalReference)(id,SEL,CGSize,NSInteger);
static void CPSReference(id object,SEL selector,CGSize size,NSInteger orientation) {
    NSDictionary *geometry;
    @synchronized(CPSHostedScenes) { geometry=[CPSControllerGeometry objectForKey:object]; }
    if(geometry) { size=[geometry[@"size"] CGSizeValue]; orientation=[geometry[@"orientation"] integerValue]; }
    CPSOriginalReference(object,selector,size,orientation);
}
static void (*CPSOriginalReference3)(id,SEL,CGSize,NSInteger,NSInteger);
static void CPSReference3(id object,SEL selector,CGSize size,NSInteger content,NSInteger container) {
    NSDictionary *geometry;
    @synchronized(CPSHostedScenes) { geometry=[CPSControllerGeometry objectForKey:object]; }
    if(geometry) { size=[geometry[@"size"] CGSizeValue]; content=[geometry[@"orientation"] integerValue]; container=content; }
    CPSOriginalReference3(object,selector,size,content,container);
}
static BOOL CPSHook(Class cls,SEL selector,IMP replacement,IMP *original) {
    Method method=class_getInstanceMethod(cls,selector);
    if(!method) return NO;
    *original=method_getImplementation(method);
    if(!class_addMethod(cls,selector,replacement,method_getTypeEncoding(method))) method_setImplementation(method,replacement);
    return YES;
}
// CarPlay owns its own launcher process on iOS 16. Add only our app to its
// library. Selecting that icon signals SpringBoard to open the external UI;
// the iPhone application never needs to be launched.
static id (*CPSOriginalNewCarLibrary)(id,SEL);
static id CPSNewCarLibrary(id cls,SEL selector) {
    id library=CPSOriginalNewCarLibrary(cls,selector);
    @try {
        NSString *bundle=CPSPreferences;
        id app=CPSObject(library,@"applicationInfoForBundleIdentifier:",bundle);
        if(!app) {
            id proxy=CPSObject(NSClassFromString(@"LSApplicationProxy"),@"applicationProxyForIdentifier:",bundle);
            SEL add=NSSelectorFromString(@"addApplicationProxy:withOverrideURL:");
            if(proxy && [library respondsToSelector:add]) {
                ((void(*)(id,SEL,id,id))objc_msgSend)(library,add,proxy,nil);
                app=CPSObject(library,@"applicationInfoForBundleIdentifier:",bundle);
            }
        }
        Ivar declarationIvar=class_getInstanceVariable([app class],"_carPlayDeclaration");
        Class declarationClass=NSClassFromString(@"CRCarPlayAppDeclaration");
        if(app && declarationIvar && declarationClass && !object_getIvar(app,declarationIvar)) {
            id declaration=[declarationClass new];
            CPSBool(declaration,@"setSupportsTemplates:",NO);
            CPSBool(declaration,@"setSupportsMaps:",YES);
            CPSSetObject(declaration,@"setBundleIdentifier:",bundle);
            CPSSetObject(declaration,@"setBundlePath:",CPSGet(app,@"bundleURL"));
            object_setIvar(app,declarationIvar,declaration);
            CPSLog(@"registered launcher icon in CarPlay");
        } else if(!app || !declarationIvar || !declarationClass) {
            CPSLog(@"CarPlay launcher registration API unavailable");
        }
    } @catch(NSException *exception) { CPSLog([NSString stringWithFormat:@"launcher registration: %@",exception.reason]); }
    return library;
}
static id (*CPSOriginalCarLaunch)(id,SEL,id,id);
static id CPSCarLaunch(id cls,SEL selector,id application,id settings) {
    NSString *bundle=CPSGet(application,@"bundleIdentifier");
    if([bundle isEqualToString:CPSPreferences]) {
        CPSLog(@"launcher icon tapped; requesting external split");
        notify_post(CPSStartNotification);
        return nil;
    }
    return CPSOriginalCarLaunch(cls,selector,application,settings);
}
static void CPSInstallCarLauncher(void) {
    Class libraryClass=NSClassFromString(@"CARApplication");
    Class launchClass=NSClassFromString(@"CARApplicationLaunchInfo");
    if(!CPSOriginalNewCarLibrary)
        CPSHook(object_getClass(libraryClass),NSSelectorFromString(@"_newApplicationLibrary"),(IMP)CPSNewCarLibrary,(IMP *)&CPSOriginalNewCarLibrary);
    if(!CPSOriginalCarLaunch)
        CPSHook(object_getClass(launchClass),NSSelectorFromString(@"launchInfoForApplication:withActivationSettings:"),(IMP)CPSCarLaunch,(IMP *)&CPSOriginalCarLaunch);
}
@interface CPSHomeGestureTarget : NSObject
- (void)hold:(UILongPressGestureRecognizer *)gesture;
@end
@implementation CPSHomeGestureTarget
- (void)hold:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan) notify_post(CPSStartNotification);
}
@end
static CPSHomeGestureTarget *CPSGestureTarget;
static char CPSGestureKey;
static void CPSAttachGesture(UIView *view) {
    if(!view.window || objc_getAssociatedObject(view,&CPSGestureKey)) return;
    UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:CPSGestureTarget action:@selector(hold:)];
    hold.minimumPressDuration=0.75;
    [view addGestureRecognizer:hold];
    objc_setAssociatedObject(view,&CPSGestureKey,hold,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void (*CPSOriginalDBMove)(id,SEL);
static void CPSDBMove(id view,SEL selector) { CPSOriginalDBMove(view,selector); CPSAttachGesture(view); }
static void (*CPSOriginalCARMove)(id,SEL);
static void CPSCARMove(id view,SEL selector) { CPSOriginalCARMove(view,selector); CPSAttachGesture(view); }
static void CPSInstallHomeGesture(void) {
    if(!CPSOriginalDBMove) CPSHook(NSClassFromString(@"DBStatusBarHomeButton"),@selector(didMoveToWindow),(IMP)CPSDBMove,(IMP *)&CPSOriginalDBMove);
    if(!CPSOriginalCARMove) CPSHook(NSClassFromString(@"CARStatusBarHomeButton"),@selector(didMoveToWindow),(IMP)CPSCARMove,(IMP *)&CPSOriginalCARMove);
}
void CPSInstallRuntime(void) {
    NSString *process=NSProcessInfo.processInfo.processName;
    if([process isEqualToString:@"SpringBoard"]) {
        CPSHostedBundles=[NSMutableSet set]; CPSHostedScenes=[NSMutableSet set];
        CPSManaged=[NSMutableSet set];CPSTerminating=[NSMutableSet set];
        dlopen("/System/Library/PrivateFrameworks/RunningBoardServices.framework/RunningBoardServices",RTLD_LAZY);
        dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",RTLD_LAZY);
        CPSStateMonitor=[NSClassFromString(@"BKSApplicationStateMonitor") new];
        CPSSceneGeometry=[NSMapTable strongToStrongObjectsMapTable];
        CPSControllerGeometry=[NSMapTable weakToStrongObjectsMapTable];
        CPSHandleOwners=[NSMapTable strongToWeakObjectsMapTable];
        CPSHook(NSClassFromString(@"SBDeviceApplicationSceneView"),NSSelectorFromString(@"setDisplayMode:animationFactory:completion:"),(IMP)CPSDisplayMode,(IMP *)&CPSOriginalDisplayMode);
        Class sceneController=NSClassFromString(@"SBDeviceApplicationSceneViewController");
        CPSHook(sceneController,NSSelectorFromString(@"setContentReferenceSize:withInterfaceOrientation:"),(IMP)CPSReference,(IMP *)&CPSOriginalReference);
        CPSHook(sceneController,NSSelectorFromString(@"setContentReferenceSize:withContentOrientation:andContainerOrientation:"),(IMP)CPSReference3,(IMP *)&CPSOriginalReference3);
        CPSHook(NSClassFromString(@"FBScene"),NSSelectorFromString(@"updateSettings:withTransitionContext:completion:"),(IMP)CPSUpdate,(IMP *)&CPSOriginalUpdate);
        CPSHook(NSClassFromString(@"SBSuspendedUnderLockManager"),NSSelectorFromString(@"_shouldBeBackgroundUnderLockForScene:withSettings:"),(IMP)CPSLock,(IMP *)&CPSOriginalLock);
        static int startToken,stopToken;
        notify_register_dispatch(CPSStartNotification,&startToken,dispatch_get_main_queue(),^(int token) { CPSStart(); });
        notify_register_dispatch(CPSStopNotification,&stopToken,dispatch_get_main_queue(),^(int token) { CPSStop(); });
        static int preferenceToken;
        notify_register_dispatch(CPSChanged,&preferenceToken,dispatch_get_main_queue(),^(int token){
            CFPreferencesAppSynchronize((__bridge CFStringRef)CPSPreferences);
            if(!CPSEnabled()){CPSStop();return;}
            NSArray *allowed=CPSPref(@"allowedApps");
            if(allowed)for(NSString *bid in [CPSHostedBundles copy])if(![allowed containsObject:bid])[CPSRoot detachBundle:bid];
        });
        for(NSString *name in @[@"CarPlayIsConnectedDidChange",UIScreenDidConnectNotification,UIScreenDidDisconnectNotification])
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){CPSConnectionChanged();}];
        // Some heads advertise their display after UIScreen notification. Poll only connection identity.
        [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *t){CPSConnectionChanged();}];
        CPSConnectionChanged();
    } else if([process isEqualToString:@"CarPlay"]) {
        CPSInstallCarLauncher();
        CPSGestureTarget=[CPSHomeGestureTarget new];
        CPSInstallHomeGesture();
        __block NSUInteger attempts=0;
        [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
            CPSInstallHomeGesture(); if(++attempts>=15) [timer invalidate];
        }];
    }
}
__attribute__((constructor)) static void CPSInitialize(void) {
    @autoreleasepool {
        if([NSProcessInfo.processInfo.processName isEqualToString:@"CarPlay"])
            CPSInstallRuntime();
        else dispatch_async(dispatch_get_main_queue(), ^{ CPSInstallRuntime(); });
    }
}
