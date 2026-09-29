# CarPlay Split 0.3.0 alpha2

Independent implementation; no DuoDash, Airaw or Cauxo binary/source payload is included.
The bottom-gap investigation for the reference DuoDash installation is deferred.

## Implemented

- Eight layouts: single, left/right, top/bottom, three columns, one left/two right,
  two left/one right, one top/two bottom, two top/one bottom.
- Thin 3-point divider grip with larger touch target. Live scene resizing.
  Drag to an outer edge maximizes a remaining pane; the bottom edge grip restores
  the split. This action never terminates an app.
- Translucent bottom toolbar: Layout, Swap, Tasks, Exit; hides after 3 seconds.
  No central dimming layer, app-list toolbar item, or CarPlay Settings item.
- Top-corner pane activators show a compact app picker in that pane. App content
  taps retain their original meaning. Layout selection shows eight miniature shapes.
- iPhone Settings preference bundle and optional phone settings app: App Bridge
  toggle/allowlist, auto-start, close replaced apps, close on disconnect, language,
  Split text size, last display info and log export. Layout and hide-delay knobs
  are deliberately absent from phone settings.
- CarPlay launcher icon remains the entry point. No phone launch is required.
  Ordinary apps can be selected inside Split through its own scene-hosting bridge;
  this is not the proprietary CarBridge tweak and does not add every app to the
  stock CarPlay launcher.
- Optional process termination applies only to apps opened by Split in this
  SpringBoard session. It skips the foreground phone app and fails closed if the
  foreground API cannot be checked. Closing uses a checked RBS termination request
  off the main thread, then observes BKS application state for exit/restart.
- Disconnection cleanup waits 12 seconds and is cancelled on reconnection.
  All destructive automatic options default off. Manual exit only detaches scenes.
- Bounded runtime log at /var/mobile/Library/Logs/CarPlaySplit-runtime.log.

## Evidence and validation limits

The supplied DuoDash dylib SHA256 is
16ffab22b4246dea9978cae92df7ec635d833ec067b4d9f425a231b26edec601.
In its arm64 slice, CNABLayoutIconView drawRect: at 0x26bc0 uses the pane-count
array at 0x761b8: 1,2,2,3,3,3,3,3. Rectangle helper 0x16da4 branches on layout IDs
1–8 and provides the shapes above. Only the shape vocabulary was used; the new
CPSLayouts.h partitions the actual supplied bounds independently without copied
reference padding or fixed head-unit dimensions.

Process API behavior was reviewed in pookjw/Cauxo's
CCPAppSwitcherViewModel.mm. This implementation uses independent code, checks
selector availability, and reports API failure or observed restart. It makes no
claim that map/navigation processes will always remain stopped.

The host geometry test covers 2,592 combinations over four screen rectangles,
all eight layouts, extreme/invalid ratios, coverage, overlap and maximized panes.
The DEB verifier checks signed Mach-O app, tweak and preference bundle, iOS target,
load-command/section overlap, preference loader metadata and dependencies.
Passing these checks is not physical-device runtime validation. CarPlay gestures,
scene lifetime, preference loading and app termination still require vehicle/device
observations before this can be called stable.
