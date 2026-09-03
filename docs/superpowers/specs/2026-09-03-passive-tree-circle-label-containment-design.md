# Passive Tree Circle Label Containment Design

## Goal

Keep every passive-node name visually inside its circular node body while preserving the approved City topology, coordinates, gameplay behavior, and full-tree viewport fit.

## Confirmed Root Cause

The production button owns a `168 x 120` interaction rectangle, but `PassiveTreeNodeVisual` draws non-keystone nodes with a radius of only `42%` of the shorter dimension. The resulting visible diameter is `100.8` pixels. Native button text wraps against nearly the full 168-pixel interaction width, so labels can pass the circle boundary while still remaining inside the button and satisfying the existing tests.

## Approved Correction

- Preserve the existing `168 x 120` interaction rectangle and all 37 LatticeWright coordinates.
- Increase the non-keystone circle radius to `48%` of the 120-pixel short dimension, producing a `115.2`-pixel visible diameter (approximately 116 pixels).
- Constrain native button-label layout to a centered 104-pixel-wide safe interior using transparent style content margins. Preserve word-smart wrapping, centered alignment, current font size, full names, and no ellipsis.
- Apply the same safe label inset to the normal, hover, pressed, hover-pressed, and disabled content states so interaction never changes wrapping. Do not override Godot's separate inherited focus-overlay style.
- Preserve and pixel-verify the visible keyboard/controller focus indicator together with the City Heart diamond, colors, outlines, activation behavior, connections, pan/zoom controls, and detail panel.
- Continue using the existing content-fit path. No format-3 source/runtime artifacts or LatticeWright coordinates change.

## Rejected Alternatives

- A true 168-pixel circle was rejected because it would overlap the current vertical spacing, force another LatticeWright coordinate reflow, and likely reduce the final fitted zoom.
- Reducing the font or abbreviating labels was rejected because it weakens readability and discards the approved full names.
- Drawing an ellipse was rejected because the requested visual is circular.

## Verification

Strict TDD will first extend the readability and visual tests so the current 100.8-pixel circle fails. The tests will require the exact approved radius, stable label margins across content states, an inherited focus overlay with a visible focused-versus-unfocused pixel difference, complete unellipsized text, and every rendered node label's measured bounds to remain inside its visible circle or diamond. The focused unit set, City visual runner, passive-tree responsive/input/profile runners, complete test suite, diff check, and a fresh 1920 x 1080 screenshot must pass before integration.

## Containment and Publication

Work remains isolated on `fix/passive-tree-circle-label-containment`. The authoritative checkout's 68 untracked `.gd.uid` files and every existing worktree remain untouched. At a pristine result, integrate conflict-safely into `main`, push normally, verify local/tracking/live heads, and show the exact passing screenshot inline.
