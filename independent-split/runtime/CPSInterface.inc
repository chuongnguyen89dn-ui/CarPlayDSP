// Independent UI, loaded after CPSSceneHost so all scene lifetime operations stay shared.
static void CPSStop(void);
static NSMutableSet<NSString *> *CPSManaged;
static NSMutableSet<NSString *> *CPSTerminating;
static id CPSStateMonitor;
static NSString *CPSCloseGuard(NSString *bid) {
    if(![CPSManaged containsObject:bid]) return CPST(@"App không do Split quản lý",@"Not managed by Split");
    SEL front=NSSelectorFromString(@"_accessibilityFrontMostApplication");
    if(![UIApplication.sharedApplication respondsToSelector:front]) return CPST(@"Không xác minh được app trên iPhone",@"Cannot verify foreground phone app");
    id app=CPSGet(UIApplication.sharedApplication,@"_accessibilityFrontMostApplication");
    if([CPSGet(app,@"bundleIdentifier") isEqual:bid]) return CPST(@"App đang mở trên iPhone",@"App is in use on iPhone");
    return nil;
}
static NSInteger CPSAppState(NSString *bid) {
    SEL s=NSSelectorFromString(@"applicationStateForApplication:");
    return [CPSStateMonitor respondsToSelector:s]?((NSInteger(*)(id,SEL,id))objc_msgSend)(CPSStateMonitor,s,bid):-1;
}
static void CPSTerminate(NSString *bid,void(^detach)(void),void(^done)(NSString *)) {
    NSString *guard=CPSCloseGuard(bid); if(guard){done(guard);return;}
    if([CPSTerminating containsObject:bid]) {done(CPST(@"Đang đóng…",@"Closing…"));return;}
    @try {
        Class contextClass=NSClassFromString(@"RBSTerminateContext"),requestClass=NSClassFromString(@"RBSTerminateRequest");
        id predicate=CPSObject(NSClassFromString(@"RBSProcessPredicate"),@"predicateMatchingBundleIdentifier:",bid);
        SEL contextInit=NSSelectorFromString(@"initWithExplanation:"),requestInit=NSSelectorFromString(@"initWithPredicate:context:"),execute=NSSelectorFromString(@"execute:error:");
        if(!predicate||![contextClass instancesRespondToSelector:contextInit]||![requestClass instancesRespondToSelector:requestInit]||![requestClass instancesRespondToSelector:execute]||CPSAppState(bid)<0){done(CPST(@"iOS thiếu API đóng/xác minh",@"Close/verification API unavailable"));return;}
        id context=((id(*)(id,SEL,id))objc_msgSend)([contextClass alloc],contextInit,@"User closed app in CarPlay Split");
        id request=((id(*)(id,SEL,id,id))objc_msgSend)([requestClass alloc],requestInit,predicate,context);
        [CPSTerminating addObject:bid];if(detach)detach();
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
            NSError *error=nil;
            @try { ((void(*)(id,SEL,id __autoreleasing *,NSError *__autoreleasing *))objc_msgSend)(request,execute,NULL,&error); }
            @catch(NSException *e){error=CPSError(e.reason?:@"Termination exception");}
            dispatch_async(dispatch_get_main_queue(),^{
                if(error){[CPSTerminating removeObject:bid];CPSLog([NSString stringWithFormat:@"terminate %@ error=%@",bid,error]);done(error.localizedDescription);return;}
                // A successful request is not proof of process exit. Observe, then check for restart.
                __block int attempts=0;
                [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer){
                    NSInteger state=CPSAppState(bid);
                    if(state==0){[timer invalidate];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
                        NSInteger later=CPSAppState(bid);[CPSTerminating removeObject:bid];
                        if(later==0)[CPSManaged removeObject:bid];
                        NSString *status=later==0?CPST(@"Đã đóng",@"Closed"):CPST(@"App đã tự chạy lại",@"App restarted");
                        CPSLog([NSString stringWithFormat:@"terminate %@: %@ state=%ld",bid,status,(long)later]);done(status);
                    });}else if(++attempts>=12){[timer invalidate];[CPSTerminating removeObject:bid];CPSLog([NSString stringWithFormat:@"terminate %@ still running state=%ld",bid,(long)state]);done(CPST(@"App vẫn chạy — chưa đóng được",@"Still running — could not close"));}
                }];
            });
        });
    }@catch(NSException *e){[CPSTerminating removeObject:bid];CPSLog(e.reason);done(CPST(@"Không đóng được app",@"Could not close app"));}
}
static NSArray *CPSAvailableApps(void) {
    NSMutableArray *apps=[NSMutableArray array];
    id controller=CPSGet(NSClassFromString(@"SBApplicationController"),@"sharedInstance");
    for(id app in CPSGet(controller,@"allInstalledApplications")){
        NSString *bid=CPSGet(app,@"bundleIdentifier"),*name=CPSGet(app,@"displayName"),*type=CPSGet(app,@"bundleType");
        if(!bid.length||!name.length||[bid isEqual:CPSPreferences])continue;
        if(![type isEqual:@"User"]&&![@[@"com.apple.Maps",@"com.apple.mobilemusic",@"com.apple.mobilesafari",@"com.apple.podcasts",@"com.apple.MobileSMS"] containsObject:bid])continue;
        [apps addObject:@{@"id":bid,@"title":name}];
    }
    return [apps sortedArrayUsingComparator:^NSComparisonResult(id a,id b){return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]];}];
}
@interface CPSList : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary *> *rows;
@property(nonatomic,copy) void(^pick)(NSDictionary *);
@property(nonatomic,copy) void(^touch)(void);
@end
@implementation CPSList
- (void)viewDidLoad{[super viewDidLoad];self.tableView.backgroundColor=UIColor.clearColor;self.tableView.rowHeight=40;self.tableView.separatorColor=[UIColor.whiteColor colorWithAlphaComponent:.14];}
- (NSInteger)tableView:(UITableView *)v numberOfRowsInSection:(NSInteger)s{return self.rows.count;}
- (UITableViewCell *)tableView:(UITableView *)v cellForRowAtIndexPath:(NSIndexPath *)p{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];c.backgroundColor=UIColor.clearColor;c.textLabel.text=self.rows[p.row][@"title"];c.textLabel.font=[UIFont systemFontOfSize:CPSFontSize()];c.textLabel.textColor=UIColor.whiteColor;c.textLabel.adjustsFontSizeToFitWidth=YES;return c;
}
- (void)tableView:(UITableView *)v didSelectRowAtIndexPath:(NSIndexPath *)p{[v deselectRowAtIndexPath:p animated:YES];if(self.touch)self.touch();if(self.pick)self.pick(self.rows[p.row]);}
- (void)scrollViewWillBeginDragging:(UIScrollView *)v{if(self.touch)self.touch();}
@end
@interface CPSLayoutIcon : UIButton
@property(nonatomic) int kind;
@end
@implementation CPSLayoutIcon
- (void)drawRect:(CGRect)rect{[super drawRect:rect];CPSFrames f=CPSFramesMake(CGRectInset(self.bounds,9,8),self.kind,self.kind==4?1./3:.5,self.kind==4?2./3:.5,-1);[[UIColor.whiteColor colorWithAlphaComponent:.85]setStroke];for(int i=0;i<f.count;i++){UIBezierPath *p=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(f.panes[i],1.5,1.5) cornerRadius:2];p.lineWidth=1.2;[p stroke];}}
@end
@interface CPSSplitController ()
@property(nonatomic,strong) NSArray<UIView *> *panes;
@property(nonatomic,strong) NSMutableArray *hosts;
@property(nonatomic,strong) NSArray<UIButton *> *emptyButtons;
@property(nonatomic,strong) NSArray<UIButton *> *paneButtons;
@property(nonatomic,strong) NSArray<UIButton *> *grips;
@property(nonatomic,strong) NSArray<UIView *> *lines;
@property(nonatomic,strong) UIButton *edge;
@property(nonatomic,strong) UIVisualEffectView *toolbar;
@property(nonatomic,strong) UIStackView *toolbarStack;
@property(nonatomic,strong) UIVisualEffectView *panel;
@property(nonatomic,strong) CPSList *list;
@property(nonatomic,strong) NSTimer *hideTimer;
@property(nonatomic) NSInteger layoutKind,maximized,panelPane;
@property(nonatomic) CGFloat fraction,secondary;
@property(nonatomic) BOOL shuttingDown;
@property(nonatomic,strong) UILabel *statusLabel;
@end
@implementation CPSSplitController
- (UIInterfaceOrientationMask)supportedInterfaceOrientations{return UIInterfaceOrientationMaskAll;}
- (BOOL)prefersStatusBarHidden{return YES;}
- (UIButton *)button:(NSString *)symbol label:(NSString *)label action:(SEL)action {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];b.tintColor=UIColor.whiteColor;b.accessibilityLabel=label;[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (UIVisualEffectView *)glass {
 UIVisualEffectView *v=[[UIVisualEffectView alloc]initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];v.layer.cornerRadius=12;v.clipsToBounds=YES;v.layer.borderWidth=.5;v.layer.borderColor=[UIColor.whiteColor colorWithAlphaComponent:.25].CGColor;[self.view addSubview:v];return v;
}
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.blackColor;self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 self.layoutKind=CPSPref(@"layout")?[CPSPref(@"layout") integerValue]:2;if(self.layoutKind<1||self.layoutKind>8)self.layoutKind=2;
 self.fraction=CPSPref(@"fraction")?CPSClamp([CPSPref(@"fraction") doubleValue],.02,.98):(self.layoutKind==4?1./3:.5);
 self.secondary=CPSPref(@"secondary")?CPSClamp([CPSPref(@"secondary") doubleValue],.02,.98):(self.layoutKind==4?2./3:.5);self.maximized=-1;
 self.hosts=[NSMutableArray arrayWithObjects:NSNull.null,NSNull.null,NSNull.null,nil];NSMutableArray *panes=[NSMutableArray array],*empty=[NSMutableArray array],*buttons=[NSMutableArray array],*grips=[NSMutableArray array],*lines=[NSMutableArray array];
 for(int i=0;i<3;i++){
  UIView *p=[UIView new];p.backgroundColor=UIColor.blackColor;p.clipsToBounds=YES;[self.view addSubview:p];[panes addObject:p];
  UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:CPST(@"＋ Chọn ứng dụng",@"＋ Choose app") forState:0];b.tintColor=UIColor.whiteColor;b.titleLabel.font=[UIFont systemFontOfSize:CPSFontSize()];b.titleLabel.numberOfLines=0;b.titleLabel.textAlignment=NSTextAlignmentCenter;b.tag=i;[b addTarget:self action:@selector(choose:) forControlEvents:UIControlEventTouchUpInside];[p addSubview:b];[empty addObject:b];
  UIButton *corner=[self button:@"ellipsis" label:CPST(@"Chọn app trong khung",@"Choose pane app") action:@selector(choose:)];corner.tag=i;corner.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:.18];corner.layer.cornerRadius=12;[self.view addSubview:corner];[buttons addObject:corner];
 }
 self.panes=panes;self.emptyButtons=empty;self.paneButtons=buttons;
 for(int i=0;i<2;i++){
  UIView *line=[UIView new];line.backgroundColor=[UIColor.whiteColor colorWithAlphaComponent:.18];line.userInteractionEnabled=NO;[self.view addSubview:line];[lines addObject:line];
  UIButton *g=[UIButton buttonWithType:UIButtonTypeCustom];g.tag=i;g.accessibilityLabel=CPST(@"Kéo đổi tỷ lệ; chạm mở thanh công cụ",@"Drag to resize; tap for toolbar");[g addTarget:self action:@selector(menu) forControlEvents:UIControlEventTouchUpInside];[g addGestureRecognizer:[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(drag:)]];UIView *mark=[UIView new];mark.tag=77;mark.userInteractionEnabled=NO;mark.backgroundColor=[UIColor.whiteColor colorWithAlphaComponent:.9];mark.layer.cornerRadius=1.5;[g addSubview:mark];[self.view addSubview:g];[grips addObject:g];
 }
 self.grips=grips;self.lines=lines;
 self.edge=[self button:@"ellipsis" label:CPST(@"Mở thanh công cụ",@"Show toolbar") action:@selector(edgeTap)];self.edge.layer.cornerRadius=12;self.edge.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:.18];[self.view addSubview:self.edge];
 self.toolbar=[self glass];self.toolbar.hidden=YES;self.toolbarStack=[[UIStackView alloc]init];self.toolbarStack.distribution=UIStackViewDistributionFillEqually;[self.toolbar.contentView addSubview:self.toolbarStack];
 NSArray *symbols=@[@"rectangle.split.2x1",@"arrow.left.arrow.right",@"square.stack",@"xmark"],*labels=@[CPST(@"Bố cục",@"Layout"),CPST(@"Đổi chỗ",@"Swap"),CPST(@"Đa nhiệm",@"Tasks"),CPST(@"Thoát",@"Exit")],*actions=@[@"layouts",@"swapPanes",@"tasks",@"exitSplit"];
 for(int i=0;i<4;i++){UIButton *b=[self button:symbols[i] label:labels[i] action:NSSelectorFromString(actions[i])];b.titleLabel.font=[UIFont systemFontOfSize:10];[b setTitle:[@" " stringByAppendingString:labels[i]] forState:0];[self.toolbarStack addArrangedSubview:b];}
 self.statusLabel=[UILabel new];self.statusLabel.textColor=UIColor.whiteColor;self.statusLabel.backgroundColor=[UIColor.blackColor colorWithAlphaComponent:.5];self.statusLabel.font=[UIFont systemFontOfSize:12];self.statusLabel.textAlignment=NSTextAlignmentCenter;self.statusLabel.numberOfLines=2;self.statusLabel.hidden=YES;[self.view addSubview:self.statusLabel];
 NSInteger count=self.layoutKind==1?1:(self.layoutKind<=3?2:3);
 for(NSInteger i=0;i<count;i++){NSString *bid=CPSPref(@[@"left",@"right",@"third"][i]);if([bid isKindOfClass:NSString.class]&&bid.length)[self openBundle:bid pane:i];}
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];if(self.shuttingDown)return;
 CGRect bounds=self.view.bounds;CPSFrames f=CPSFramesMake(bounds,(int)self.layoutKind,self.fraction,self.secondary,(int)self.maximized);
 for(int i=0;i<3;i++){
  CGRect frame=f.panes[i];self.panes[i].frame=frame;self.panes[i].hidden=CGRectIsEmpty(frame);
  self.emptyButtons[i].frame=self.panes[i].bounds;self.paneButtons[i].hidden=CGRectIsEmpty(frame)||frame.size.width<40||frame.size.height<35;
  self.paneButtons[i].frame=CGRectMake(CGRectGetMaxX(frame)-34,CGRectGetMinY(frame)+2,32,26);
  if(!CGRectIsEmpty(frame)&&self.hosts[i]!=NSNull.null)[self.hosts[i] resizeTo:frame.size];
 }
 for(int i=0;i<2;i++){
  BOOL hidden=i>=f.boundaryCount||CGRectIsEmpty(bounds);self.grips[i].hidden=hidden;self.lines[i].hidden=hidden;if(hidden)continue;
  CGRect r=f.boundaries[i];BOOL vertical=f.vertical[i];
  if(vertical){self.lines[i].frame=CGRectMake(r.origin.x-.5,r.origin.y,1,r.size.height);self.grips[i].frame=CGRectMake(r.origin.x-18,CGRectGetMidY(r)-22,36,44);}
  else {self.lines[i].frame=CGRectMake(r.origin.x,r.origin.y-.5,r.size.width,1);self.grips[i].frame=CGRectMake(CGRectGetMidX(r)-22,r.origin.y-18,44,36);}
  [self.grips[i] viewWithTag:77].frame=vertical?CGRectMake(16.5,8,3,28):CGRectMake(8,16.5,28,3);
 }
 CGFloat width=MIN(350,bounds.size.width-16);self.toolbar.frame=CGRectMake((bounds.size.width-width)/2,bounds.size.height-42,width,36);self.toolbarStack.frame=self.toolbar.bounds;
 self.edge.frame=CGRectMake(CGRectGetMidX(bounds)-20,bounds.size.height-26,40,24);self.edge.hidden=!self.toolbar.hidden;
 self.statusLabel.frame=CGRectMake(8,4,bounds.size.width-16,34);
 if(self.panel){CGFloat desired=self.list?MIN(120,MAX(40,self.list.rows.count*40)):88;CGFloat w=MIN(220,bounds.size.width-16),h=MIN(desired,bounds.size.height-54);CGFloat x=(bounds.size.width-w)/2,y=bounds.size.height-h-46;
  if(self.panelPane>=0){CGRect p=self.panes[self.panelPane].frame;w=MIN(w,MAX(40,p.size.width-8));h=MIN(h,MAX(40,p.size.height-34));x=CGRectGetMaxX(p)-w-4;y=p.origin.y+30;}
  self.panel.frame=CGRectMake(x,MAX(0,y),w,h);if(self.list)self.list.view.frame=self.panel.contentView.bounds;
  else {NSArray *buttons=self.panel.contentView.subviews;CGFloat bw=w/4,bh=h/2;for(NSUInteger i=0;i<buttons.count;i++)[buttons[i] setFrame:CGRectMake((i%4)*bw,(i/4)*bh,bw,bh)];}
 }
}
- (void)armHide {
 [self.hideTimer invalidate];__weak typeof(self) weak=self;self.hideTimer=[NSTimer scheduledTimerWithTimeInterval:3 repeats:NO block:^(NSTimer *t){if(weak.list.tableView.dragging||weak.list.tableView.decelerating){[weak armHide];return;}[weak dismissPanel];weak.toolbar.hidden=YES;[weak.view setNeedsLayout];}];
}
- (void)menu{[self dismissPanel];self.toolbar.hidden=!self.toolbar.hidden;[self armHide];[self.view setNeedsLayout];}
- (void)edgeTap{if(self.maximized>=0){self.maximized=-1;self.fraction=self.layoutKind==4?1./3:.5;self.secondary=self.layoutKind==4?2./3:.5;[self saveLayout];[self.view setNeedsLayout];}else [self menu];}
- (void)dismissPanel{[self.list willMoveToParentViewController:nil];[self.list.view removeFromSuperview];[self.list removeFromParentViewController];self.list=nil;[self.panel removeFromSuperview];self.panel=nil;}
- (void)showRows:(NSArray *)rows pane:(NSInteger)pane pick:(void(^)(NSDictionary *))pick {
 [self dismissPanel];self.panelPane=pane;self.panel=[self glass];CPSList *list=[CPSList new];list.rows=rows;list.pick=pick;__weak typeof(self) weak=self;list.touch=^{[weak armHide];};self.list=list;[self addChildViewController:list];[self.panel.contentView addSubview:list.view];[list didMoveToParentViewController:self];[self armHide];[self.view setNeedsLayout];
}
- (void)choose:(UIButton *)button {
 NSInteger index=button.tag;NSMutableArray *rows=[NSMutableArray array];for(NSDictionary *app in CPSAvailableApps()){BOOL duplicate=NO;for(int i=0;i<3;i++)if(i!=index&&self.hosts[i]!=NSNull.null&&[[self.hosts[i] bundleID]isEqual:app[@"id"]])duplicate=YES;if(!duplicate)[rows addObject:app];}
 if(!rows.count){[self message:CPST(@"Chưa tìm thấy ứng dụng phù hợp",@"No eligible apps found")];return;}
 __weak typeof(self) weak=self;[self showRows:rows pane:index pick:^(NSDictionary *a){[weak dismissPanel];[weak openBundle:a[@"id"] pane:index];}];
}
- (void)message:(NSString *)text{self.statusLabel.text=text;self.statusLabel.hidden=NO;__weak typeof(self) weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,4*NSEC_PER_SEC),dispatch_get_main_queue(),^{if([weak.statusLabel.text isEqual:text])weak.statusLabel.hidden=YES;});}
- (void)openBundle:(NSString *)bid pane:(NSInteger)pane {
 if(self.shuttingDown||pane<0||pane>2||!CPSEnabled()||[CPSTerminating containsObject:bid])return;
 for(id h in self.hosts)if(h!=NSNull.null&&[[h bundleID]isEqual:bid])return;
 NSError *error=nil;CPSSceneHost *host=[[CPSSceneHost alloc]initWithBundleID:bid error:&error];if(!host){[self message:error.localizedDescription];return;}
 id previous=self.hosts[pane];NSString *old=previous==NSNull.null?nil:[previous bundleID];if(previous!=NSNull.null)[previous close];self.hosts[pane]=host;
 __weak typeof(self) weak=self;__weak CPSSceneHost *wh=host;
 host.failure=^(NSString *reason){CPSSplitController *s=weak;CPSSceneHost *h=wh;if(!s||!h)return;NSUInteger i=[s.hosts indexOfObjectIdenticalTo:h];if(i==NSNotFound)return;s.hosts[i]=NSNull.null;s.emptyButtons[i].enabled=YES;s.emptyButtons[i].hidden=NO;[s.emptyButtons[i] setTitle:reason forState:0];};
 host.ready=^{CPSSplitController *s=weak;CPSSceneHost *h=wh;if(!s||!h)return;NSUInteger i=[s.hosts indexOfObjectIdenticalTo:h];if(i!=NSNotFound){s.emptyButtons[i].hidden=YES;s.emptyButtons[i].enabled=YES;}};
 [self.emptyButtons[pane]setTitle:CPST(@"Đang mở…",@"Opening…") forState:0];self.emptyButtons[pane].hidden=NO;self.emptyButtons[pane].enabled=NO;
 @try{[host attachTo:self container:self.panes[pane]];[CPSManaged addObject:bid];CPSSetObject(CPSStateMonitor,@"updateInterestedBundleIDs:",CPSManaged.allObjects);[self.panes[pane]bringSubviewToFront:self.emptyButtons[pane]];[host resizeTo:self.panes[pane].bounds.size];CPSWritePreference(@[@"left",@"right",@"third"][pane],bid);}
 @catch(NSException *e){[host close];self.hosts[pane]=NSNull.null;self.emptyButtons[pane].enabled=YES;[self.emptyButtons[pane]setTitle:e.reason forState:0];}
 if(old&&[CPSPref(@"closeReplaced")boolValue])CPSTerminate(old,nil,^(NSString *status){[weak message:status];});
}
- (void)saveLayout{CPSWritePreference(@"layout",@(self.layoutKind));CPSWritePreference(@"fraction",@(self.fraction));CPSWritePreference(@"secondary",@(self.secondary));}
- (void)layouts {
 [self dismissPanel];self.panelPane=-1;self.panel=[self glass];NSArray *names=@[CPST(@"Một khung",@"One pane"),CPST(@"Trái / phải",@"Left / right"),CPST(@"Trên / dưới",@"Top / bottom"),CPST(@"Ba cột",@"Three columns"),CPST(@"Một trái, hai phải",@"One left, two right"),CPST(@"Hai trái, một phải",@"Two left, one right"),CPST(@"Một trên, hai dưới",@"One top, two bottom"),CPST(@"Hai trên, một dưới",@"Two top, one bottom")];
 for(int i=1;i<=8;i++){CPSLayoutIcon *b=[CPSLayoutIcon buttonWithType:UIButtonTypeCustom];b.kind=i;b.tag=i;b.accessibilityLabel=names[i-1];b.backgroundColor=i==self.layoutKind?[UIColor.whiteColor colorWithAlphaComponent:.15]:UIColor.clearColor;[b addTarget:self action:@selector(setLayout:) forControlEvents:UIControlEventTouchUpInside];[self.panel.contentView addSubview:b];}[self armHide];[self.view setNeedsLayout];
}
- (void)setLayout:(UIButton *)b {
 self.layoutKind=b.tag;self.maximized=-1;self.fraction=b.tag==4?1./3:.5;self.secondary=b.tag==4?2./3:.5;NSInteger count=b.tag==1?1:(b.tag<=3?2:3);
 for(NSInteger i=count;i<3;i++)if(self.hosts[i]!=NSNull.null){[self.hosts[i]close];self.hosts[i]=NSNull.null;self.emptyButtons[i].hidden=NO;self.emptyButtons[i].enabled=YES;[self.emptyButtons[i]setTitle:CPST(@"＋ Chọn ứng dụng",@"＋ Choose app") forState:0];}
 [self saveLayout];[self dismissPanel];[self armHide];[self.view setNeedsLayout];
}
- (void)drag:(UIPanGestureRecognizer *)g {
 [self.hideTimer invalidate];if(g.state==UIGestureRecognizerStateBegan){[self dismissPanel];self.toolbar.hidden=YES;}
 CPSFrames f=CPSFramesMake(self.view.bounds,(int)self.layoutKind,self.fraction,self.secondary,-1);int n=(int)g.view.tag;if(n>=f.boundaryCount)return;CGPoint p=[g locationInView:self.view];BOOL vertical=f.vertical[n];CGFloat length=vertical?self.view.bounds.size.width:self.view.bounds.size.height;if(length<=0)return;double raw=CPSClamp((vertical?p.x:p.y)/length,0,1),v=raw;
 if(n==0){if(self.layoutKind==4)v=MIN(v,self.secondary);self.fraction=v;}else {if(self.layoutKind==4)v=MAX(v,self.fraction);self.secondary=v;}
 if(g.state==UIGestureRecognizerStateEnded){
  if(raw<.03||raw>.97){CPSFrames end=CPSFramesMake(self.view.bounds,(int)self.layoutKind,self.fraction,self.secondary,-1);CGRect boundary=f.boundaries[n];CGPoint probe=CGPointMake(CGRectGetMidX(boundary),CGRectGetMidY(boundary));if(vertical)probe.x=raw<.03?self.view.bounds.size.width-.1:.1;else probe.y=raw<.03?self.view.bounds.size.height-.1:.1;double area=-1;NSInteger candidate=-1;for(int i=0;i<end.count;i++){CGRect r=end.panes[i];double a=r.size.width*r.size.height;if(a>area){area=a;self.maximized=i;}if(!CGRectIsEmpty(r)&&CGRectContainsPoint(r,probe))candidate=i;}if(candidate>=0)self.maximized=candidate;}
  [self saveLayout];[self armHide];
 }else if(g.state==UIGestureRecognizerStateCancelled){self.fraction=self.layoutKind==4?1./3:.5;self.secondary=self.layoutKind==4?2./3:.5;[self armHide];}
 [self.view setNeedsLayout];[self.view layoutIfNeeded];
}
- (void)swapPanes {
 NSInteger count=self.layoutKind==1?1:(self.layoutKind<=3?2:3);if(count<2)return;
 id first=self.hosts[0];for(NSInteger i=0;i<count-1;i++)self.hosts[i]=self.hosts[i+1];self.hosts[count-1]=first;
 for(int i=0;i<count;i++){id h=self.hosts[i];self.emptyButtons[i].hidden=h!=NSNull.null;self.emptyButtons[i].enabled=YES;[self.emptyButtons[i]setTitle:CPST(@"＋ Chọn ứng dụng",@"＋ Choose app") forState:0];if(h!=NSNull.null){CPSSceneHost *host=h;[self.panes[i]addSubview:host.controller.view];host.container=self.panes[i];}CPSWritePreference(@[@"left",@"right",@"third"][i],h==NSNull.null?nil:[h bundleID]);}
 [self armHide];[self.view setNeedsLayout];
}
- (void)detachBundle:(NSString *)bid {
 for(int i=0;i<3;i++)if(self.hosts[i]!=NSNull.null&&[[self.hosts[i]bundleID]isEqual:bid]){[self.hosts[i]close];self.hosts[i]=NSNull.null;self.emptyButtons[i].hidden=NO;self.emptyButtons[i].enabled=YES;[self.emptyButtons[i]setTitle:CPST(@"＋ Chọn ứng dụng",@"＋ Choose app") forState:0];CPSWritePreference(@[@"left",@"right",@"third"][i],nil);}
}
- (void)tasks {
 NSMutableArray *rows=[NSMutableArray array];if(CPSManaged.count)[rows addObject:@{@"id":@"*",@"title":CPST(@"Đóng tất cả app của Split",@"Close all Split apps")}];
 for(NSString *bid in [CPSManaged.allObjects sortedArrayUsingSelector:@selector(compare:)]){id app=CPSObject(CPSGet(NSClassFromString(@"SBApplicationController"),@"sharedInstance"),@"applicationWithBundleIdentifier:",bid);NSString *title=CPSGet(app,@"displayName")?:bid;[rows addObject:@{@"id":bid,@"title":[NSString stringWithFormat:@"×  %@",title]}];}
 if(!rows.count){[self message:CPST(@"Không có app do Split quản lý",@"No apps managed by Split")];return;}
 __weak typeof(self) weak=self;[self showRows:rows pane:-1 pick:^(NSDictionary *row){NSArray *ids=[row[@"id"]isEqual:@"*"]?CPSManaged.allObjects:@[row[@"id"]];[weak dismissPanel];for(NSString *bid in ids)CPSTerminate(bid,^{[weak detachBundle:bid];},^(NSString *status){[weak message:[NSString stringWithFormat:@"%@: %@",bid,status]];});}];
}
- (void)exitSplit{CPSStop();}
- (void)shutdown {
 if(self.shuttingDown)return;self.shuttingDown=YES;[self.hideTimer invalidate];[self dismissPanel];for(id host in self.hosts)if(host!=NSNull.null)[host close];[self.hosts removeAllObjects];
}
@end
