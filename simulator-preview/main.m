#import <UIKit/UIKit.h>

static UILabel *Label(NSString *text, CGFloat size, UIColor *color) {
    UILabel *l=[UILabel new]; l.text=text; l.font=[UIFont systemFontOfSize:size weight:UIFontWeightSemibold]; l.textColor=color; l.textAlignment=NSTextAlignmentCenter; return l;
}
static UIView *Card(CGRect f, UIColor *color, NSString *title, NSString *subtitle) {
    UIView *v=[[UIView alloc] initWithFrame:f]; v.backgroundColor=color; v.layer.cornerRadius=12; v.clipsToBounds=YES;
    UILabel *a=Label(title,18,UIColor.whiteColor); a.frame=CGRectMake(8,24,f.size.width-16,24); [v addSubview:a];
    UILabel *b=Label(subtitle,11,[UIColor colorWithWhite:1 alpha:.72]); b.frame=CGRectMake(8,52,f.size.width-16,18); [v addSubview:b];
    UIView *art=[[UIView alloc] initWithFrame:CGRectMake(14,84,f.size.width-28,f.size.height-100)]; art.backgroundColor=[UIColor colorWithWhite:1 alpha:.09]; art.layer.cornerRadius=8; [v addSubview:art];
    return v;
}

@interface PreviewVC : UIViewController @end
@implementation PreviewVC
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=[UIColor colorWithRed:.035 green:.04 blue:.055 alpha:1];
    BOOL full=[NSProcessInfo.processInfo.arguments containsObject:@"--fullscreen"];
    UILabel *head=Label(full?@"DuoDash · FULLSCREEN":@"DuoDash · SPLIT",15,UIColor.whiteColor); head.frame=CGRectMake(0,8,self.view.bounds.size.width,24); head.autoresizingMask=UIViewAutoresizingFlexibleWidth; [self.view addSubview:head];
    UILabel *note=Label(@"Simulator visual gate · CarPlay viewport 427 × 240",10,[UIColor colorWithWhite:1 alpha:.55]); note.frame=CGRectMake(0,31,self.view.bounds.size.width,16); note.autoresizingMask=UIViewAutoresizingFlexibleWidth; [self.view addSubview:note];

    CGFloat scale=MIN((self.view.bounds.size.width-24)/427.0,(self.view.bounds.size.height-64)/240.0);
    UIView *cp=[[UIView alloc] initWithFrame:CGRectMake(0,0,427*scale,240*scale)]; cp.center=CGPointMake(self.view.bounds.size.width/2,58+(self.view.bounds.size.height-58)/2); cp.autoresizingMask=UIViewAutoresizingFlexibleMargins; cp.backgroundColor=UIColor.blackColor; cp.layer.borderWidth=1; cp.layer.borderColor=[UIColor colorWithWhite:1 alpha:.18].CGColor; cp.clipsToBounds=YES; [self.view addSubview:cp];
    UIView *canvas=[[UIView alloc] initWithFrame:CGRectMake(0,0,427,240)]; canvas.transform=CGAffineTransformMakeScale(scale,scale); canvas.layer.anchorPoint=CGPointZero; canvas.layer.position=CGPointZero; [cp addSubview:canvas];

    CGFloat dock=full?0:45, divider=5, available=427-dock-divider, left=round(available*.50), right=available-left;
    if(!full){
        UIView *d=[[UIView alloc] initWithFrame:CGRectMake(0,0,45,240)]; d.backgroundColor=[UIColor colorWithRed:.08 green:.09 blue:.12 alpha:1]; [canvas addSubview:d];
        NSArray *icons=@[@"◉",@"⌖",@"♫",@"▦"]; for(int i=0;i<4;i++){ UILabel *x=Label(icons[i],18,[UIColor colorWithWhite:1 alpha:.85]); x.frame=CGRectMake(0,22+i*49,45,30); [d addSubview:x]; }
    }
    CGFloat x=dock;
    UIView *p1=Card(CGRectMake(x,0,left,240),[UIColor colorWithRed:.08 green:.24 blue:.38 alpha:1],@"Maps",@"DuoDash pane A"); [canvas addSubview:p1];
    UIView *dv=[[UIView alloc] initWithFrame:CGRectMake(x+left,0,divider,240)]; dv.backgroundColor=[UIColor colorWithWhite:.78 alpha:1]; [canvas addSubview:dv];
    UIView *handle=[[UIView alloc] initWithFrame:CGRectMake(1,94,3,52)]; handle.backgroundColor=[UIColor colorWithWhite:.28 alpha:1]; handle.layer.cornerRadius=1.5; [dv addSubview:handle];
    UIView *p2=Card(CGRectMake(x+left+divider,0,right,240),[UIColor colorWithRed:.18 green:.12 blue:.30 alpha:1],@"Music",@"DuoDash pane B"); [canvas addSubview:p2];
    UILabel *swap=Label(@"⇄",18,UIColor.whiteColor); swap.frame=CGRectMake(427-42,8,32,28); swap.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; swap.layer.cornerRadius=14; swap.clipsToBounds=YES; [canvas addSubview:swap];
    UILabel *picker=Label(@"•••",15,UIColor.whiteColor); picker.frame=CGRectMake(427-42,44,32,28); picker.backgroundColor=[UIColor colorWithWhite:0 alpha:.35]; picker.layer.cornerRadius=14; picker.clipsToBounds=YES; [canvas addSubview:picker];
}
- (BOOL)prefersStatusBarHidden { return YES; }
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate> @property(nonatomic,strong) UIWindow *window; @end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts { self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.window.rootViewController=[PreviewVC new]; [self.window makeKeyAndVisible]; return YES; }
@end
int main(int argc,char **argv){ @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class)); } }
