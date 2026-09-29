#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <notify.h>

#define CPSStartNotification "com.chuong.carplaysplit.start"
#define CPSStopNotification "com.chuong.carplaysplit.stop"
#define CPSPreferences @"com.chuong.carplaysplit"

@interface CPSSceneHost : NSObject
@property(nonatomic,copy,readonly) NSString *bundleID;
@property(nonatomic,strong,readonly) UIViewController *controller;
@property(nonatomic,strong,readonly) id scene;
@property(nonatomic,copy) void (^failure)(NSString *message);
- (instancetype)initWithBundleID:(NSString *)bundleID error:(NSError **)error;
- (void)attachTo:(UIViewController *)parent container:(UIView *)container;
- (void)resizeTo:(CGSize)size;
- (void)close;
@end

@interface CPSSplitController : UIViewController
- (void)shutdown;
@end

void CPSInstallRuntime(void);
