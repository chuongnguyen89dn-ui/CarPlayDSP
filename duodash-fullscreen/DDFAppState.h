#import <Foundation/Foundation.h>

// Included by the adapter and its Foundation-only lifecycle regression test.
@interface DDFAppState : NSObject
@property(nonatomic, strong, readonly) NSHashTable *apps;
@property(nonatomic, strong, readonly) NSMapTable *frames;
@end

@implementation DDFAppState
- (instancetype)init {
    self = [super init];
    if (self) {
        NSPointerFunctionsOptions keys = NSPointerFunctionsWeakMemory |
                                        NSPointerFunctionsObjectPointerPersonality;
        _apps = [[NSHashTable alloc] initWithOptions:keys capacity:0];
        _frames = [[NSMapTable alloc] initWithKeyOptions:keys
                                          valueOptions:NSPointerFunctionsStrongMemory
                                              capacity:0];
    }
    return self;
}
@end
