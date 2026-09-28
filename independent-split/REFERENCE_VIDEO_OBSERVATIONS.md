# Reference video observations (2026-09-28)

Source: user-provided 60.3667-second, 710x512, 30fps MP4. This is a visual behavior reference, not evidence of the installed tweak's identity.

Observed frames:
- Opening: navigation/map area and video are displayed side by side.
- A compact vertical three-dot handle appears at the boundary between left and right surfaces; a two-arrow circular control appears above it in some states.
- The left surface changes between launcher, video playlist, map/search, and navigation while right video remains visible.
- In later frames the map is on the right and video on the left; a vertical app dock is visible along the far left of the map-only view.
- A touch near the boundary is visible. Exact gesture direction and touch target cannot be inferred reliably from sampled frames.
- The video does not establish whether both surfaces are native CarPlay app scenes, a mirrored phone app, a webview, or another compositor.

Engineering implications:
- Do not implement by simply hiding the dock or changing arbitrary UIView frames.
- Establish live surface ownership and touch routing first.
- Need actual target-device process/scene inventory before selecting injection point or private selectors.
- Preserve left/right swapping independently from dock expansion and divider ratio.

No device-success claim or final package claim follows from this observation.
