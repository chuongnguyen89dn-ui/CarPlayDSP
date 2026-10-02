#import "../DDFAppState.h"
#include <assert.h>
#include <stdio.h>

// Equal objects must still represent separate app instances.
@interface EqualApp : NSObject @end
@implementation EqualApp
- (BOOL)isEqual:(id)other { return [other isKindOfClass:EqualApp.class]; }
- (NSUInteger)hash { return 1; }
@end

int main(void) {
    @autoreleasepool {
        DDFAppState *state = [DDFAppState new];
        __weak id closedApp;
        @autoreleasepool {
            id app = [EqualApp new];
            closedApp = app;
            [state.apps addObject:app];
            [state.apps addObject:app];
            [state.frames setObject:@"saved frame" forKey:app];
            assert(state.apps.count == 1);
        }
        assert(closedApp == nil);
        assert(state.apps.allObjects.count == 0);
        assert(state.frames.keyEnumerator.allObjects.count == 0);

        @autoreleasepool {
            id first = [EqualApp new], second = [EqualApp new];
            [state.apps addObject:first];
            [state.apps addObject:second];
            [state.frames setObject:@"first" forKey:first];
            [state.frames setObject:@"second" forKey:second];
            assert(state.apps.count == 2);
            assert([[state.frames objectForKey:first] isEqual:@"first"]);
            assert([[state.frames objectForKey:second] isEqual:@"second"]);

            // A restore/relayout snapshot keeps its objects alive while used.
            NSArray *snapshot = state.apps.allObjects;
            closedApp = first;
            first = nil;
            assert(closedApp != nil);
            assert(snapshot.count == 2);
            [state.frames removeAllObjects];
            assert(state.frames.count == 0);
        }
        assert(closedApp == nil);
        assert(state.apps.allObjects.count == 0);
        puts("PASS: closed apps disappear; identity and operation lifetimes preserved");
    }
    return 0;
}
