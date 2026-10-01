# DuoDash UI baseline reset

Implementation direction after real-device test:
- Keep the original DuoDash 1.1.3 split UI and interaction model as the UI baseline.
- Do not render replacement black pane containers, duplicate ellipsis controls, or a custom app picker.
- Do not bundle AIRA W.
- Remove the independent compositor prototype from the installable target; its geometry/state files remain research-only.
- Fullscreen work must be an additive adapter around a verified live DuoDash split session: hide/reveal the CarPlay dock and update the existing split host's usable bounds without replacing DuoDash panes.
- Never globally hook UIView/setFrame/setHidden.
- Runtime acceptance: original DuoDash panes must render first. Any fullscreen adapter must fail open (DuoDash remains usable) if the target host cannot be identified.

Known baseline:
- Original DuoDash 1.1.3 was the working split baseline.
- DauDat-CarPlay currently contains Fullscreen427 and AIRA W packages; Fullscreen427 is not treated as the clean original baseline.
