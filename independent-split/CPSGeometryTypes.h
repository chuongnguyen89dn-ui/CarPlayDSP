#pragma once
#include <stdbool.h>
#ifdef CPS_PORTABLE_GEOMETRY_TEST
// Minimal scalar types for running the layout arithmetic on Linux. Device builds
// always use Apple's CoreGraphics declarations below.
typedef double CGFloat;
typedef struct { CGFloat x,y; } CGPoint;
typedef struct { CGFloat width,height; } CGSize;
typedef struct { CGPoint origin; CGSize size; } CGRect;
static inline CGRect CGRectMake(CGFloat x,CGFloat y,CGFloat width,CGFloat height) { return (CGRect){{x,y},{width,height}}; }
static inline CGFloat CGRectGetMinX(CGRect r) { return r.origin.x; }
static inline CGFloat CGRectGetMaxX(CGRect r) { return r.origin.x+r.size.width; }
static inline CGFloat CGRectGetWidth(CGRect r) { return r.size.width; }
static inline CGFloat CGRectGetHeight(CGRect r) { return r.size.height; }
#else
#include <CoreGraphics/CoreGraphics.h>
#endif
