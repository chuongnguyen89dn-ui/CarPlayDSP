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
static inline id CPSMsg(id obj,NSString *sel) {SEL s=NSSelectorFromString(sel);return [obj respondsToSelector:s]?((id(*)(id,SEL))objc_msgSend)(obj,s):nil;}
static inline NSArray *CPSAppCatalog(void) {
    id workspace=CPSMsg(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace");NSMutableArray *out=[NSMutableArray array];
    for(id app in CPSMsg(workspace,@"allApplications")){
        NSString *bid=CPSMsg(app,@"applicationIdentifier"),*name=CPSMsg(app,@"localizedName"),*type=CPSMsg(app,@"applicationType");
        if(!bid.length||!name.length||[bid isEqual:CPSDomain])continue;
        if(![type isEqual:@"User"]&&![@[@"com.apple.Maps",@"com.apple.mobilemusic",@"com.apple.mobilesafari",@"com.apple.podcasts",@"com.apple.MobileSMS"] containsObject:bid])continue;
        [out addObject:@{@"id":bid,@"title":name}];
    }
    return [out sortedArrayUsingComparator:^NSComparisonResult(id a,id b){return [a[@"title"] localizedCaseInsensitiveCompare:b[@"title"]];}];
}
@interface CPSSettingsController : UITableViewController
@end
