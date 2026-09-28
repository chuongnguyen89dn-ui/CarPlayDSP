#pragma once
#import <CoreGraphics/CoreGraphics.h>
#import <stdbool.h>
#import <math.h>

// Pure transition logic: UI adapter performs changes only after a validated transition.
typedef enum {
    CPSModeNormal=0,
    CPSModeEntering=1,
    CPSModeExpanded=2,
    CPSModeExiting=3
} CPSMode;

typedef enum {
    CPSEventExpand=0,
    CPSEventRestore=1,
    CPSEventAnimationFinished=2,
    CPSEventDisconnect=3
} CPSEvent;

typedef struct {
    CPSMode mode;
    CGFloat dividerFraction;
} CPSState;

static inline bool CPSValidFraction(CGFloat fraction) {
    return isfinite(fraction) && fraction > 0 && fraction < 1;
}

static inline bool CPSSetDividerFraction(CPSState *state, CGFloat fraction) {
    if (!state || !CPSValidFraction(fraction)) return false;
    state->dividerFraction=fraction;
    return true;
}

// Idempotent requests; disconnect always returns to normal.
// Returns false when a transition is not valid; caller must not mutate host UI.
static inline bool CPSAdvance(CPSState *state, CPSEvent event) {
    if (!state || !CPSValidFraction(state->dividerFraction)) return false;
    if (event==CPSEventDisconnect) { state->mode=CPSModeNormal; return true; }
    switch(state->mode) {
        case CPSModeNormal:
            if(event==CPSEventExpand) { state->mode=CPSModeEntering; return true; }
            if(event==CPSEventRestore) return true;
            break;
        case CPSModeEntering:
            if(event==CPSEventAnimationFinished) { state->mode=CPSModeExpanded; return true; }
            if(event==CPSEventRestore) { state->mode=CPSModeExiting; return true; }
            if(event==CPSEventExpand) return true;
            break;
        case CPSModeExpanded:
            if(event==CPSEventRestore) { state->mode=CPSModeExiting; return true; }
            if(event==CPSEventExpand) return true;
            break;
        case CPSModeExiting:
            if(event==CPSEventAnimationFinished) { state->mode=CPSModeNormal; return true; }
            if(event==CPSEventExpand) { state->mode=CPSModeEntering; return true; }
            if(event==CPSEventRestore) return true;
            break;
    }
    return false;
}
