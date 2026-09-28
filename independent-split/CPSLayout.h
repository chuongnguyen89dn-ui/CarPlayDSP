#import <CoreGraphics/CoreGraphics.h>
#import <math.h>

// Pure layout model. This code never manipulates a system view or assumes private selectors.
// Host adapter must supply the measured dock reservation and actual scene bounds.
typedef struct {
    CGRect scene;
    CGFloat dockReservedWidth;
    CGFloat dividerWidth;
    CGFloat leadingFraction;
    BOOL dockOnLeadingEdge;
} CPSLayoutInput;

typedef struct {
    CGRect dock;
    CGRect firstPane;
    CGRect divider;
    CGRect secondPane;
    BOOL valid;
} CPSLayout;

static inline CPSLayout CPSComputeLayout(CPSLayoutInput input, BOOL expanded) {
    CPSLayout out = {0};
    if (!isfinite(input.scene.origin.x) || !isfinite(input.scene.origin.y) ||
        !isfinite(input.scene.size.width) || !isfinite(input.scene.size.height) ||
        input.scene.size.width <= 0 || input.scene.size.height <= 0 ||
        !isfinite(input.dockReservedWidth) || !isfinite(input.dividerWidth) ||
        !isfinite(input.leadingFraction) || input.dockReservedWidth < 0 ||
        input.dividerWidth < 0 || input.leadingFraction <= 0 || input.leadingFraction >= 1)
        return out;

    CGFloat dockWidth = expanded ? 0 : input.dockReservedWidth;
    CGFloat available = input.scene.size.width - dockWidth - input.dividerWidth;
    if (available <= 0) return out;
    CGFloat left = available * input.leadingFraction;
    CGFloat right = available - left;
    if (left <= 0 || right <= 0) return out;

    CGFloat x = input.scene.origin.x + ((!expanded && input.dockOnLeadingEdge) ? dockWidth : 0);
    if (!expanded) {
        CGFloat dockX = input.dockOnLeadingEdge ? input.scene.origin.x : CGRectGetMaxX(input.scene)-dockWidth;
        out.dock = CGRectMake(dockX, input.scene.origin.y, dockWidth, input.scene.size.height);
    }
    out.firstPane = CGRectMake(x, input.scene.origin.y, left, input.scene.size.height);
    out.divider = CGRectMake(x+left, input.scene.origin.y, input.dividerWidth, input.scene.size.height);
    out.secondPane = CGRectMake(x+left+input.dividerWidth, input.scene.origin.y, right, input.scene.size.height);
    out.valid = YES;
    return out;
}
