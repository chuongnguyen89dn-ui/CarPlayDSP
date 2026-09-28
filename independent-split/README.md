# Independent CarPlay split prototype

This branch is isolated from the public Sileo package. It does not import or package DuoDash or AIRA W.

## Scope
Build an independent split compositor only after identifying the actual CarPlay scene/window ownership on the target iOS version. Do not assume a hidden dock automatically releases its reserved layout area.

## Evidence gates
1. Inventory target OS, rootless injection paths, CarPlay process names, scene hierarchy, window owners and existing gesture recognizers. Capture before/after geometry and touch coordinates.
2. Prove two live app surfaces can coexist under the chosen compositor; do not mistake snapshots for live apps.
3. Prove a dock-free layout can reclaim its reserved inset while preserving hit testing.
4. Attach gesture to a verified splitter handle without stealing native app gestures; measure thresholds from the reference video.
5. Implement reversible transitions, preserve divider ratio, restore on disconnect and crash/relaunch.
6. Only then create a separate package and test on both screen sizes.

## Failure policy
No global UIView frame/hidden hooks. No injection into unrelated processes. No guessed private selectors. No public deployment based on a green CI build alone.

## Acceptance
Two live CarPlay applications, draggable divider, swipe-driven dock disappearance and edge-to-edge panes, reverse gesture restores dock, correct hit testing, no black screen.

## Current status
Architecture and test gates only. No working compositor, no device validation, no new DEB.
