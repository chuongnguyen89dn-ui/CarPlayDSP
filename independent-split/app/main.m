#import <UIKit/UIKit.h>
#import <notify.h>
#import "../runtime/CPSRuntime.h"

@interface CPSPhoneController : UIViewController
@property(nonatomic,strong) UILabel *status;
@property(nonatomic) NSInteger requestNumber;
@end
@implementation CPSPhoneController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"CarPlay Split";
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIStackView *stack=[[UIStackView alloc] init];
    stack.axis=UILayoutConstraintAxisVertical; stack.spacing=22; stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor]
    ]];
    UILabel *title=[UILabel new]; title.text=@"Hai ứng dụng trên CarPlay";
    title.font=[UIFont preferredFontForTextStyle:UIFontTextStyleTitle1]; title.numberOfLines=0;
    [stack addArrangedSubview:title];
    UILabel *instructions=[UILabel new]; instructions.numberOfLines=0;
    instructions.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    instructions.text=@"Kết nối iPhone với CarPlay rồi mở chia đôi.\n\nTrên màn hình xe: kéo dấu ⋮ để đổi tỷ lệ, chạm dấu ⋮ để chọn ứng dụng hoặc thoát. Nút hai mũi tên đổi vị trí hai ứng dụng.\n\nBạn cũng có thể nhấn giữ nút Home của CarPlay để mở chia đôi.";
    [stack addArrangedSubview:instructions];
    UIButton *start=[UIButton buttonWithType:UIButtonTypeSystem];
    [start setTitle:@"Mở trên CarPlay" forState:UIControlStateNormal];
    start.titleLabel.font=[UIFont boldSystemFontOfSize:20];
    [start addTarget:self action:@selector(start) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:start];
    UIButton *stop=[UIButton buttonWithType:UIButtonTypeSystem];
    [stop setTitle:@"Thoát chia đôi" forState:UIControlStateNormal];
    [stop addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:stop];
    self.status=[UILabel new]; self.status.numberOfLines=0;
    self.status.textColor=UIColor.secondaryLabelColor;
    self.status.text=@"Sẵn sàng. Thao tác khi xe đang đỗ.";
    [stack addArrangedSubview:self.status];
    __weak typeof(self) weakSelf=self;
    static int unavailableToken,startedToken,stoppedToken;
    notify_register_dispatch("com.chuong.carplaysplit.unavailable",&unavailableToken,dispatch_get_main_queue(),^(int token) {
        weakSelf.requestNumber++; weakSelf.status.text=@"Không mở được cửa sổ CarPlay. Kiểm tra kết nối và phiên bản iOS.";
    });
    notify_register_dispatch("com.chuong.carplaysplit.started",&startedToken,dispatch_get_main_queue(),^(int token) {
        weakSelf.requestNumber++; weakSelf.status.text=@"Đã mở cửa sổ chia đôi. Chọn ứng dụng trên màn hình CarPlay.";
    });
    notify_register_dispatch("com.chuong.carplaysplit.stopped",&stoppedToken,dispatch_get_main_queue(),^(int token) {
        weakSelf.requestNumber++; weakSelf.status.text=@"Đã thoát chia đôi.";
    });
}
- (void)start {
    self.status.text=@"Đang mở CarPlay…";
    NSInteger request=++self.requestNumber;
    notify_post(CPSStartNotification);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC),dispatch_get_main_queue(),^{
        if(self.requestNumber==request) self.status.text=@"Không nhận được phản hồi. Hãy respring sau khi cài rồi kết nối lại CarPlay.";
    });
}
- (void)stop { notify_post(CPSStopNotification); }
@end
@interface CPSAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation CPSAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[CPSPhoneController new]];
    [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char **argv) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(CPSAppDelegate.class)); }
}
