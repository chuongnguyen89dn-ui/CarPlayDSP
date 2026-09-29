#import "CPSRuntime.h"
#import "../CPSLayout.h"
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

static void CPSStop(void);

@interface CPSPicker : UITableViewController
@property(nonatomic,copy) void (^selection)(NSString *bundleID);
@property(nonatomic,strong) NSArray<NSDictionary *> *apps;
@property(nonatomic,copy) NSString *excludedBundle;
@end
@implementation CPSPicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"Chọn ứng dụng";
    self.tableView.rowHeight=48;
    self.tableView.backgroundColor=UIColor.systemBackgroundColor;
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Đóng" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    NSMutableArray *apps=[NSMutableArray array];
    id controller=CPSGet(NSClassFromString(@"SBApplicationController"),@"sharedInstance");
    for(id app in CPSGet(controller,@"allInstalledApplications")) {
        NSString *bid=CPSGet(app,@"bundleIdentifier"), *title=CPSGet(app,@"displayName");
        NSString *type=CPSGet(app,@"bundleType");
        if(!bid.length || !title.length || [bid isEqualToString:self.excludedBundle] || [bid isEqualToString:CPSPreferences]) continue;
        if(![type isEqualToString:@"User"] && ![@[@"com.apple.Maps",@"com.apple.mobilemusic",@"com.apple.mobilesafari",@"com.apple.podcasts"] containsObject:bid]) continue;
        [apps addObject:@{@"id":bid,@"title":title}];
    }
    self.apps=[apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
        return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]];
    }];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.apps.count; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"app"];
    if(!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"app"];
    NSDictionary *app=self.apps[path.row];
    cell.textLabel.text=app[@"title"]; cell.detailTextLabel.text=app[@"id"];
    SEL icon=NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if([UIImage respondsToSelector:icon]) cell.imageView.image=((id(*)(id,SEL,id,int,CGFloat))objc_msgSend)(UIImage.class,icon,app[@"id"],0,UIScreen.mainScreen.scale);
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    NSString *bid=self.apps[path.row][@"id"];
    void (^selection)(NSString *)=self.selection;
    [self dismissViewControllerAnimated:YES completion:^{ if(selection) selection(bid); }];
}
@end

@interface CPSSplitController ()
@property(nonatomic,strong) NSArray<UIView *> *panes;
@property(nonatomic,strong) NSMutableArray *hosts;
@property(nonatomic,strong) NSArray<UIButton *> *emptyButtons;
@property(nonatomic,strong) UIView *divider;
@property(nonatomic,strong) UIButton *handle;
@property(nonatomic,strong) UIButton *swap;
@property(nonatomic) CGFloat fraction;
@property(nonatomic) BOOL shuttingDown;
@end
@implementation CPSSplitController
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.blackColor;
    self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    NSNumber *saved=CPSPreference(@"fraction");
    self.fraction=saved ? fmin(0.8,fmax(0.2,saved.doubleValue)) : 0.5;
    self.hosts=[NSMutableArray arrayWithObjects:NSNull.null,NSNull.null,nil];
    NSMutableArray *panes=[NSMutableArray array], *empty=[NSMutableArray array];
    for(NSInteger i=0;i<2;i++) {
        UIView *pane=[UIView new]; pane.clipsToBounds=YES; pane.backgroundColor=UIColor.blackColor;
        [self.view addSubview:pane]; [panes addObject:pane];
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        [button setTitle:@"＋ Chọn ứng dụng" forState:UIControlStateNormal];
        button.titleLabel.numberOfLines=0; button.titleLabel.textAlignment=NSTextAlignmentCenter;
        button.titleLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]; button.tag=i;
        [button addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];
        [pane addSubview:button]; [empty addObject:button];
    }
    self.panes=panes; self.emptyButtons=empty;
    self.divider=[UIView new]; self.divider.backgroundColor=[UIColor colorWithWhite:0.12 alpha:1];
    [self.view addSubview:self.divider];
    self.handle=[UIButton buttonWithType:UIButtonTypeSystem];
    [self.handle setTitle:@"⋮" forState:UIControlStateNormal];
    self.handle.titleLabel.font=[UIFont boldSystemFontOfSize:30]; self.handle.tintColor=UIColor.whiteColor;
    self.handle.backgroundColor=[UIColor colorWithWhite:0.16 alpha:0.95]; self.handle.layer.cornerRadius=12;
    self.handle.accessibilityLabel=@"Tỷ lệ và chọn ứng dụng";
    [self.handle addTarget:self action:@selector(menu) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *drag=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.handle addGestureRecognizer:drag]; [self.view addSubview:self.handle];
    self.swap=[UIButton buttonWithType:UIButtonTypeSystem];
    [self.swap setImage:[UIImage systemImageNamed:@"arrow.left.arrow.right"] forState:UIControlStateNormal];
    self.swap.tintColor=UIColor.whiteColor; self.swap.backgroundColor=self.handle.backgroundColor;
    self.swap.layer.cornerRadius=14; self.swap.accessibilityLabel=@"Đổi bên";
    [self.swap addTarget:self action:@selector(swapPanes) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.swap];
    for(NSInteger i=0;i<2;i++) {
        NSString *bid=CPSPreference(i==0?@"left":@"right");
        if([bid isKindOfClass:NSString.class] && bid.length) [self openBundle:bid pane:i];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if(self.shuttingDown) return;
    CPSLayoutInput input={self.view.bounds,0,4,self.fraction,YES};
    CPSLayout layout=CPSComputeLayout(input,YES);
    if(!layout.valid) return;
    self.panes[0].frame=layout.firstPane; self.panes[1].frame=layout.secondPane; self.divider.frame=layout.divider;
    CGFloat x=CGRectGetMidX(layout.divider),y=CGRectGetMidY(self.view.bounds);
    self.handle.frame=CGRectMake(x-16,y-24,32,48);
    self.swap.frame=CGRectMake(x-16,y-63,32,32);
    for(NSInteger i=0;i<2;i++) {
        self.emptyButtons[i].frame=CGRectInset(self.panes[i].bounds,20,20);
        if(self.hosts[i]!=NSNull.null) [(CPSSceneHost *)self.hosts[i] resizeTo:self.panes[i].bounds.size];
    }
}
- (void)choose:(UIButton *)button { [self pickerForPane:button.tag]; }
- (void)pickerForPane:(NSInteger)pane {
    if(self.presentedViewController) return;
    CPSPicker *picker=[CPSPicker new];
    id other=self.hosts[1-pane];
    if(other!=NSNull.null) picker.excludedBundle=[other bundleID];
    __weak typeof(self) weakSelf=self;
    picker.selection=^(NSString *bid) { [weakSelf openBundle:bid pane:pane]; };
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:picker];
    nav.modalPresentationStyle=UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)openBundle:(NSString *)bid pane:(NSInteger)pane {
    if(self.shuttingDown) return;
    id current=self.hosts[pane];
    if(current!=NSNull.null && [[current bundleID] isEqualToString:bid]) return;
    id other=self.hosts[1-pane];
    if(other!=NSNull.null && [[other bundleID] isEqualToString:bid]) return;
    NSError *error=nil;
    CPSSceneHost *host=[[CPSSceneHost alloc] initWithBundleID:bid error:&error];
    if(!host) { [self.emptyButtons[pane] setTitle:error.localizedDescription forState:UIControlStateNormal]; return; }
    id previous=self.hosts[pane];
    if(previous!=NSNull.null) [previous close];
    self.hosts[pane]=host;
    __weak typeof(self) weakSelf=self;
    __weak CPSSceneHost *weakHost=host;
    host.failure=^(NSString *reason) {
        CPSSplitController *strongSelf=weakSelf; CPSSceneHost *failed=weakHost;
        if(!strongSelf || !failed) return;
        NSUInteger current=[strongSelf.hosts indexOfObjectIdenticalTo:failed];
        if(current==NSNotFound) return;
        strongSelf.hosts[current]=NSNull.null;
        [strongSelf.emptyButtons[current] setTitle:reason forState:UIControlStateNormal];
        strongSelf.emptyButtons[current].enabled=YES;
        strongSelf.emptyButtons[current].hidden=NO;
    };
    host.ready=^{
        CPSSplitController *strongSelf=weakSelf; CPSSceneHost *opened=weakHost;
        if(!strongSelf || !opened) return;
        NSUInteger current=[strongSelf.hosts indexOfObjectIdenticalTo:opened];
        if(current!=NSNotFound) {
            strongSelf.emptyButtons[current].enabled=YES;
            strongSelf.emptyButtons[current].hidden=YES;
        }
    };
    [self.emptyButtons[pane] setTitle:@"Đang mở ứng dụng…" forState:UIControlStateNormal];
    self.emptyButtons[pane].enabled=NO;
    self.emptyButtons[pane].hidden=NO;
    @try {
        [host attachTo:self container:self.panes[pane]];
        [self.panes[pane] bringSubviewToFront:self.emptyButtons[pane]];
        [host resizeTo:self.panes[pane].bounds.size];
        CPSWritePreference(pane==0?@"left":@"right",bid);
    } @catch(NSException *exception) {
        [host close]; self.hosts[pane]=NSNull.null;
        self.emptyButtons[pane].enabled=YES;
        self.emptyButtons[pane].hidden=NO;
        [self.emptyButtons[pane] setTitle:exception.reason forState:UIControlStateNormal];
    }
}
- (void)menu {
    if(self.presentedViewController) return;
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"CarPlay Split" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Ứng dụng bên trái" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self dismissViewControllerAnimated:YES completion:^{ [self pickerForPane:0]; }];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Ứng dụng bên phải" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self dismissViewControllerAnimated:YES completion:^{ [self pickerForPane:1]; }];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Tỷ lệ 50/50" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { self.fraction=0.5; [self.view setNeedsLayout]; CPSWritePreference(@"fraction",@(self.fraction)); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Thoát chia đôi" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { CPSStop(); }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.sourceView=self.handle;
    menu.popoverPresentationController.sourceRect=self.handle.bounds;
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)drag:(UIPanGestureRecognizer *)gesture {
    CGFloat width=self.view.bounds.size.width;
    if(width<=4) return;
    CGFloat raw=[gesture locationInView:self.view].x/width;
    self.fraction=fmax(0.2,fmin(0.8,raw));
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
    if(gesture.state==UIGestureRecognizerStateEnded) {
        CPSWritePreference(@"fraction",@(self.fraction));
        if(raw<0.04 || raw>0.96) CPSStop();
    }
}
- (void)swapPanes {
    if(self.shuttingDown) return;
    [self.hosts exchangeObjectAtIndex:0 withObjectAtIndex:1];
    for(NSInteger i=0;i<2;i++) {
        id host=self.hosts[i];
        self.emptyButtons[i].hidden=host!=NSNull.null;
        if(host!=NSNull.null) {
            CPSSceneHost *sceneHost=host;
            [self.panes[i] addSubview:sceneHost.controller.view];
            sceneHost.container=self.panes[i];
            CPSWritePreference(i==0?@"left":@"right",sceneHost.bundleID);
        } else CPSWritePreference(i==0?@"left":@"right",nil);
    }
    [self.view setNeedsLayout]; [self.view layoutIfNeeded];
}
- (void)shutdown {
    if(self.shuttingDown) return;
    self.shuttingDown=YES;
    for(id host in self.hosts) if(host!=NSNull.null) [host close];
    [self.hosts removeAllObjects];
}
@end

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
        notify_post("com.chuong.carplaysplit.started");
        CPSLog([NSString stringWithFormat:@"split window visible bounds=%@",NSStringFromCGRect(window.bounds)]);
    } @catch(NSException *exception) { CPSLog(exception.reason); CPSStop(); }
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
        [[NSNotificationCenter defaultCenter] addObserverForName:@"CarPlayIsConnectedDidChange" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { if(!CPSCarDisplay()) CPSStop(); }];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenDidDisconnectNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { if(!CPSCarDisplay()) CPSStop(); }];
    } else if([process isEqualToString:@"CarPlay"]) {
        CPSGestureTarget=[CPSHomeGestureTarget new];
        CPSInstallHomeGesture();
        __block NSUInteger attempts=0;
        [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer) {
            CPSInstallHomeGesture(); if(++attempts>=15) [timer invalidate];
        }];
    }
}
__attribute__((constructor)) static void CPSInitialize(void) {
    @autoreleasepool { dispatch_async(dispatch_get_main_queue(), ^{ CPSInstallRuntime(); }); }
}
