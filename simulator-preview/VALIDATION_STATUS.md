# DuoDash UI Fix — verified continuation, 2026-10-02

Branch: `duodash-fullscreen-adapter`. Inspected baseline: `f3cc22b`.

## User acceptance criteria

Preserve DuoDash 1.1.3 UI, app picker, two panes, divider, swap and behavior.
Only add fullscreen and reversible bar/Dock hiding. Horizontal divider drag
must still work; fullscreen must fill the released space without a black band.
Do not recreate the original UI. A Simulator screenshot of the original UI
must be reviewed before treating this as ready for DEB/device testing.
The user clarified that the reported red pane/app crash occurred in the earlier
independently implemented Split app. It has not been reproduced in original
DuoDash. Returning to the original engine may avoid that bug, but this is not
yet a verified runtime result. Do not block adapter work on diagnosing the
retired independent implementation or attribute its crash to DuoDash.

## Verified findings

- Actions run `36998044885` succeeded and produced inspection and screenshot
  artifacts. Success proves execution of the old workflow, not UI acceptance.
- `main.m` draws Maps/Music cards and text symbols. It has no original DuoDash
  app picker or split implementation. `build-and-capture.sh` compiles only
  `main.m`, not the adapter, then takes screenshots of an ordinary iPhone app.
  The 427x240 value is an internal canvas, not the screenshot dimensions.
- The workflow downloads `DuoDash_1.1.3_Fullscreen427_iphoneos-arm64.deb` from
  `chuongnguyen89dn-ui/DauDat-CarPlay/main`.
- Its actual Debian package version is **1.1.3+fullscreen1**, not pristine
  1.1.3. It already includes `DuoDashUnifiedFullscreen.dylib` alongside
  `DuoDash.dylib`. This must be accounted for before testing another adapter.
- DEB SHA256: `ea0d3bb8c8b9da2b45c3f158f390a7966419e84899f820d06f45cd51401fa465`.
- DuoDash.dylib SHA256:
  `b41dd7f892bfd3722e95a40f764a989886078b4a30943c1f0b50d47b6e248a47`.
- Both Mach-O slices (arm64 and arm64e) declare LC_BUILD_VERSION platform 2
  (iOS device), not platform 7 (iOS Simulator). Dependencies include
  CydiaSubstrate and the package injects into system processes. Extracting the
  DEB does not create a Simulator-compatible app or host for its original UI.
- `DauDat-CarPlay/main` contains the DuoDash DEB, Airaw DEB and a handoff file,
  with no DuoDash source project. The inspected adapter/research branches also
  do not contain original DuoDash UI source.
- The adapter's dependency `com.sensetechlab.duodash (= 1.1.3)` does not match
  the inspected `1.1.3+fullscreen1` package. Do not broaden this dependency
  blindly and thereby enable two unverified fullscreen tweaks together.

## Gate correction

`build-and-capture.sh` now fails before compiling or launching the placeholder
UI. The workflow retains package inspection artifacts but cannot mark mock
screenshots as a passed DuoDash gate. Original UI and runtime code are unchanged.

## Actual blockers / next work

For the requested original-UI Simulator gate, obtain the original DuoDash UI
source buildable for Simulator, or a compatible Simulator build with its host
and dependencies. A device-only DEB and screenshots of a replica do not satisfy
this prerequisite. Do not remove the guard merely to make CI green.

Use original DuoDash for the baseline, with Airaw and other fullscreen adapters
absent. Collect a crash/system log if the problem reproduces there. Existing
evidence of co-injected Airaw is in the root handoff document; it does not
establish the cause of the earlier independent app's red pane error.

## Adapter lifetime correction

Commit `ccadfe2` replaces nonretained app pointers with zeroing weak,
identity-based collections. It prevents later restore/relayout from messaging
an app object that has already been deallocated. The Foundation regression
test passed on macOS. This is a code-level adapter fix, not proof that the
previous independent app's red pane issue is fixed. No original DuoDash UI,
app picker or split engine was replaced.

Once an original-UI Simulator target is available, exercise the actual adapter
and capture baseline, app picker, fullscreen, divider resize/swap, and restore
at the requested viewport. Record the exact commit and package hashes and
review the images. Until then **no accepted Simulator screenshot exists**.

References:
- https://github.com/chuongnguyen89dn-ui/carplaydsp/actions/runs/36998044885
- https://github.com/chuongnguyen89dn-ui/DauDat-CarPlay/tree/main
