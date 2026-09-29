#import "CPSSettings.h"
@interface CPSAppSettings : UITableViewController
@property(nonatomic,strong) NSArray *apps;
@property(nonatomic,strong) NSMutableSet *selected;
@end
@implementation CPSAppSettings
- (void)viewDidLoad{[super viewDidLoad];self.title=CPST(@"Chọn ứng dụng",@"Choose apps");self.apps=CPSAppCatalog();NSArray *saved=CPSPref(@"allowedApps");self.selected=[NSMutableSet setWithArray:saved?:[self.apps valueForKey:@"id"]];}
- (NSInteger)tableView:(UITableView *)v numberOfRowsInSection:(NSInteger)s{return self.apps.count;}
- (UITableViewCell *)tableView:(UITableView *)v cellForRowAtIndexPath:(NSIndexPath *)p{UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];NSDictionary *a=self.apps[p.row];c.textLabel.text=a[@"title"];c.accessoryType=[self.selected containsObject:a[@"id"]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return c;}
- (void)tableView:(UITableView *)v didSelectRowAtIndexPath:(NSIndexPath *)p{NSString *bid=self.apps[p.row][@"id"];if([self.selected containsObject:bid])[self.selected removeObject:bid];else [self.selected addObject:bid];CPSSetPref(@"allowedApps",self.selected.allObjects);[v reloadRowsAtIndexPaths:@[p] withRowAnimation:UITableViewRowAnimationNone];}
@end
@implementation CPSSettingsController
- (instancetype)init{return [super initWithStyle:UITableViewStyleInsetGrouped];}
- (void)viewDidLoad{[super viewDidLoad];self.title=@"CarPlay Split";}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self.tableView reloadData];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)v{return 4;}
- (NSInteger)tableView:(UITableView *)v numberOfRowsInSection:(NSInteger)s{return s==0?2:s==1?3:s==2?2:3;}
- (NSString *)tableView:(UITableView *)v titleForHeaderInSection:(NSInteger)s{return @[ @"App Bridge",CPST(@"Tự động",@"Automatic"),CPST(@"Giao diện",@"Appearance"),CPST(@"Thông tin & chẩn đoán",@"Information & diagnostics") ][s];}
- (NSString *)tableView:(UITableView *)v titleForFooterInSection:(NSInteger)s{
 if(s==0)return CPST(@"Chọn ứng dụng được dùng trong Split. Mở Split từ màn hình CarPlay; không cần mở trên iPhone.",@"Choose apps available in Split. Launch Split from CarPlay; opening the iPhone app is optional.");
 if(s==1)return CPST(@"Ngắt kết nối: chờ 12 giây; kết nối lại sẽ hủy đóng. Chỉ đóng app Split quản lý, bỏ qua app đang dùng trên iPhone. Đóng hẳn app sẽ dừng nhạc và có thể mất dữ liệu chưa lưu.",@"Disconnect: wait 12 seconds; reconnecting cancels closing. Only Split-managed apps are closed; the foreground phone app is protected. Closing stops audio and may lose unsaved work.");return nil;
}
- (UITableViewCell *)tableView:(UITableView *)v cellForRowAtIndexPath:(NSIndexPath *)p{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];NSString *key=nil;
 if(p.section==0){c.textLabel.text=p.row==0?CPST(@"Bật App Bridge",@"Enable App Bridge"):CPST(@"Chọn ứng dụng",@"Choose apps");if(p.row==0)key=@"enabled";}
 if(p.section==1){c.textLabel.text=@[CPST(@"Tự mở khi kết nối",@"Auto start"),CPST(@"Đóng app cũ khi đổi khung",@"Close replaced apps"),CPST(@"Đóng app khi ngắt CarPlay",@"Close on disconnect")][p.row];key=@[@"autoStart",@"closeReplaced",@"closeDisconnect"][p.row];}
 if(p.section==2){c.textLabel.text=p.row==0?CPST(@"Ngôn ngữ",@"Language"):CPST(@"Cỡ chữ của Split",@"Split text size");c.detailTextLabel.text=p.row==0?CPST(@"Tiếng Việt",@"English"):@[CPST(@"Nhỏ",@"Small"),CPST(@"Vừa",@"Medium"),CPST(@"Lớn",@"Large")][MIN(2,MAX(0,[CPSPref(@"textSize") integerValue]))];}
 if(p.section==3){c.textLabel.text=@[CPST(@"Thông tin màn hình xe",@"Car display information"),CPST(@"Xuất log",@"Export logs"),CPST(@"Phiên bản",@"Version")][p.row];if(p.row==2)c.detailTextLabel.text=@"0.3.0~alpha2";}
 if(key){UISwitch *s=[UISwitch new];s.accessibilityIdentifier=key;s.on=[key isEqual:@"enabled"]?CPSEnabled():[CPSPref(key) boolValue];[s addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;c.selectionStyle=UITableViewCellSelectionStyleNone;}
 else if(!(p.section==3&&p.row==2))c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return c;
}
- (void)toggle:(UISwitch *)s{CPSSetPref(s.accessibilityIdentifier,@(s.on));}
- (void)tableView:(UITableView *)v didSelectRowAtIndexPath:(NSIndexPath *)p{
 [v deselectRowAtIndexPath:p animated:YES];
 if(p.section==0&&p.row==1){[self.navigationController pushViewController:[CPSAppSettings new] animated:YES];return;}
 if(p.section==2){NSArray *labels=p.row==0?@[@"Tiếng Việt",@"English"]:@[CPST(@"Nhỏ",@"Small"),CPST(@"Vừa",@"Medium"),CPST(@"Lớn",@"Large")];UIAlertController *a=[UIAlertController alertControllerWithTitle:[v cellForRowAtIndexPath:p].textLabel.text message:nil preferredStyle:UIAlertControllerStyleActionSheet];for(NSUInteger i=0;i<labels.count;i++){[a addAction:[UIAlertAction actionWithTitle:labels[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){CPSSetPref(p.row==0?@"language":@"textSize",p.row==0?(id)@[@"vi",@"en"][i]:@(i));[v reloadData];}]];}[a addAction:[UIAlertAction actionWithTitle:CPST(@"Hủy",@"Cancel") style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=[v cellForRowAtIndexPath:p];[self presentViewController:a animated:YES completion:nil];return;}
 if(p.section==3&&p.row==0){NSString *info=CPSPref(@"displayInfo")?:CPST(@"Chưa ghi nhận kết nối CarPlay.",@"No CarPlay display recorded yet.");UIAlertController *a=[UIAlertController alertControllerWithTitle:CPST(@"Màn hình xe",@"Car display") message:info preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];[self presentViewController:a animated:YES completion:nil];}
 if(p.section==3&&p.row==1){NSString *path=@"/var/mobile/Library/Logs/CarPlaySplit-runtime.log";if(![[NSFileManager defaultManager]fileExistsAtPath:path]){UIAlertController *a=[UIAlertController alertControllerWithTitle:CPST(@"Chưa có log",@"No log yet") message:CPST(@"Kết nối CarPlay và mở Split để ghi log.",@"Connect CarPlay and open Split to record logs.") preferredStyle:1];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];[self presentViewController:a animated:YES completion:nil];return;}UIActivityViewController *a=[[UIActivityViewController alloc]initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];a.popoverPresentationController.sourceView=[v cellForRowAtIndexPath:p];[self presentViewController:a animated:YES completion:nil];}
}
@end
