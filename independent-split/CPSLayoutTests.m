#import <Foundation/Foundation.h>
#import "CPSLayout.h"
#import <assert.h>
#import <math.h>

static void near(CGFloat actual, CGFloat expected) { assert(fabs(actual-expected) < 0.001); }
static void check(CPSLayoutInput input, BOOL expanded) {
    CPSLayout r=CPSComputeLayout(input,expanded);
    assert(r.valid);
    near(CGRectGetMinX(r.divider),CGRectGetMaxX(r.firstPane));
    near(CGRectGetMinX(r.secondPane),CGRectGetMaxX(r.divider));
    near(CGRectGetMaxX(r.secondPane),CGRectGetMaxX(input.scene)-(expanded || input.dockOnLeadingEdge ? 0 : input.dockReservedWidth));
    near(CGRectGetHeight(r.firstPane),CGRectGetHeight(input.scene));
    near(CGRectGetHeight(r.secondPane),CGRectGetHeight(input.scene));
    near(CGRectGetWidth(r.firstPane)+CGRectGetWidth(r.divider)+CGRectGetWidth(r.secondPane),
         CGRectGetWidth(input.scene)-(expanded ? 0 : input.dockReservedWidth));
}
int main(void) {
    @autoreleasepool {
        for (int leading=0;leading<2;leading++) {
            for (int expanded=0;expanded<2;expanded++) {
                for (int i=1;i<10;i++) {
                    CPSLayoutInput in={CGRectMake(0,0,427,240),45,5,i/10.0,leading};
                    check(in,expanded);
                    CPSLayout r=CPSComputeLayout(in,expanded);
                    near(CGRectGetWidth(r.dock),expanded?0:45);
                    if(expanded) near(CGRectGetMinX(r.firstPane),0);
                    else near(CGRectGetMinX(r.firstPane),leading?45:0);
                }
            }
        }
        CPSLayoutInput offset={CGRectMake(20,30,800,480),60,8,0.4,YES};
        check(offset,NO); check(offset,YES);
        CPSLayoutInput bad=offset; bad.dockReservedWidth=900;
        assert(!CPSComputeLayout(bad,NO).valid);
        bad=offset; bad.leadingFraction=NAN;
        assert(!CPSComputeLayout(bad,YES).valid);
        bad=offset; bad.scene.size.width=0;
        assert(!CPSComputeLayout(bad,YES).valid);
        puts("CPSLayout geometry tests passed");
    }
    return 0;
}
