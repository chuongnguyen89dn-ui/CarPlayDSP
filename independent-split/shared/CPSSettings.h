#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <notify.h>
#define CPSDomain @"com.chuong.carplaysplit"
#define CPSChanged "com.chuong.carplaysplit.preferences"
static inline id CPSPref(NSString *key) { CFPreferencesAppSynchronize((__bridge CFStringRef)CPSDomain); return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,(__bridge CFStringRef)CPSDomain)); }
static inline void CPSSetPref(NSString *key,id value) { CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,(__bridge CFStringRef)CPSDomain);CFPreferencesAppSynchronize((__bridge CFStringRef)CPSDomain);notify_post(CPSChanged); }
static inline BOOL CPSEnabled(void) { id v=CPSPref(@"enabled");return !v||[v boolValue]; }
static inline NSString *CPST(NSString *vi,NSString *en) {return [CPSPref(@"language") isEqual:@"en"]?en:vi;}
static inline CGFloat CPSFontSize(void) { NSInteger n=[CPSPref(@"textSize") integerValue];return n==2?17:(n==1?15:13); }
@interface CPSSettingsController : UITableViewController
@end
