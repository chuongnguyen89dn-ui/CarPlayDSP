# DuoDash gesture fullscreen — investigation (2026-09-28)

## User-visible acceptance criteria
- Home: native CarPlay dock visible.
- Enter split view: both panes expand edge-to-edge without selecting a pane or tapping a fullscreen icon.
- Swipe gesture drives transition; preserve native app gestures and divider drag.
- Exit split: restore dock and original layout.
- No black screen, no blank 45pt dock reservation, no lost hit-testing; test on actual device.
- AIRA W is not part of the requested mechanism.

## Verified repository state
- Main workflow packages DuoDash_1.1.3_Fullscreen427 and Airaw 1.6.7 together, adds ConflictProbe.
- Main repository has ConflictProbe.xm and audio DSP Tweak.xm, but no source for DuoDashUnifiedFullscreen.dylib or DuoDash.dylib.
- The package name is com.chuong.duodash-airaw 1.0.3. Do not confuse a successful build with device runtime success.
- Uploaded Conflict.log confirms DuoDash and Airaw loaded into CarPlayTemplateUIHost, CarPlay and SpringBoard; DuoDashUnifiedFullscreen appears as a loaded image and as caller of UI_MOVE_WINDOW events. This alone does not establish the root cause.

## Research / implementation gates
1. Preserve known-working original DEB and original package metadata. Do not change main branch or publish a user-facing package during investigation.
2. Inspect package contents and existing fullscreen binary/strings, filters and loaded classes; determine which module actually owns split root, dock and gesture.
3. Instrument transitions narrowly: split enter/exit, pane root frame, dock frame/hidden, scene bounds, hit test, divider gestures. Avoid blanket UIView geometry mutations.
4. Implement a reversible state machine: NORMAL -> ENTERING -> FULLSCREEN -> EXITING -> NORMAL. Cache original constraints/frames and restore on exit/disconnect.
5. Scope gesture to verified container/edge; establish direction and threshold from actual video/gesture trace. Do not invent direction or intercept divider/app gestures.
6. Validate two screen geometries (including 427x240) and safe-area/scene propagation; avoid zero-size or black layer.
7. Build isolated test package on branch, inspect contents and CI logs, then deploy only after explicit packaging review. Runtime success requires device logs and visual test.

## External documentation
- https://sensetechlab.com/duodash/features/ — DualApps, resize, layout and app picker.
- https://developer.apple.com/documentation/carplay/displaying-content-in-carplay — CarPlay scene/window lifecycle.
- https://developer.apple.com/documentation/carplay/using-the-carplay-simulator — simulator alone is not sufficient.

## Open blockers
- Original DuoDash and modified Fullscreen427 binaries are third-party binaries, no corresponding source present in carplaydsp.
- Need concrete comparison of their binary hooks/filters and exact swipe direction from the reference video before writing geometry hooks.
