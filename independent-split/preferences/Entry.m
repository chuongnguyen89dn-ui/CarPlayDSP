#import "../shared/CPSSettings.h"
@interface PSListController : UIViewController
@end
@interface CPSPreferencesController : PSListController
@property(nonatomic,strong) CPSSettingsController *settings;
@end
@implementation CPSPreferencesController
- (void)viewDidLoad{[super viewDidLoad];self.title=@"CarPlay Split";self.settings=[CPSSettingsController new];[self addChildViewController:self.settings];self.settings.view.frame=self.view.bounds;self.settings.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[self.view addSubview:self.settings.view];[self.settings didMoveToParentViewController:self];}
@end
