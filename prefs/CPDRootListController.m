#import "CPDRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

@implementation CPDRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *s=[NSMutableArray array];

        PSSpecifier *group=[PSSpecifier preferenceSpecifierNamed:@"CarPlayDSP" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
        [group setProperty:@"Rootless iOS 16 CarPlay DSP proof of concept." forKey:@"footerText"];
        [s addObject:group];

        PSSpecifier *enable=[PSSpecifier preferenceSpecifierNamed:@"Enable DSP" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [enable setProperty:@"com.anhchuong.carplaydsp" forKey:@"defaults"];
        [enable setProperty:@"enabled" forKey:@"key"];
        [enable setProperty:@YES forKey:@"default"];
        [s addObject:enable];

        [s addObject:[PSSpecifier preferenceSpecifierNamed:@"POC Test Filter" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil]];

        PSSpecifier *freq=[PSSpecifier preferenceSpecifierNamed:@"Frequency" target:self set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
        [freq setProperty:@"1000 Hz" forKey:@"default"];
        [s addObject:freq];

        PSSpecifier *gain=[PSSpecifier preferenceSpecifierNamed:@"Gain" target:self set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
        [gain setProperty:@"-15 dB" forKey:@"default"];
        [s addObject:gain];

        PSSpecifier *q=[PSSpecifier preferenceSpecifierNamed:@"Q" target:self set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
        [q setProperty:@"1.0" forKey:@"default"];
        [s addObject:q];

        [s addObject:[PSSpecifier preferenceSpecifierNamed:@"DSP Status / Apply" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil]];
        _specifiers=[s copy];
    }
    return _specifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *p=[[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.anhchuong.carplaydsp"];
    id v=p[[specifier propertyForKey:@"key"]];
    return v ?: [specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *domain=[specifier propertyForKey:@"defaults"];
    NSString *key=[specifier propertyForKey:@"key"];
    NSMutableDictionary *p=[[[NSUserDefaults standardUserDefaults] persistentDomainForName:domain] mutableCopy] ?: [NSMutableDictionary dictionary];
    if(value) p[key]=value; else [p removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:p forName:domain];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.anhchuong.carplaydsp/preferences.changed"), NULL, NULL, true);
}
@end
