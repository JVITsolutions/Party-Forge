# Passive Tree Enlarged Node Fit Design

**Status:** Approved by Jacob on 2026-09-02: enlarge the nodes and scale the tree to fit.

## Problem

The City v3 graph and all 37 connection paths are valid, but production passive-tree controls expose only 96 px of usable text width. The six district-charter labels require 162-206 px on one line, so the current no-wrap 104-by-104 controls ellipsize the labels and three charter regions collide with neighboring controls.

## Approved behavior

- Keep the exact 37 LatticeWright node coordinates, 37 connections, six portal identities, graph topology, allocation behavior, and activation states unchanged.
- Enlarge every passive-tree node uniformly. Node names wrap at word boundaries and never use ellipsis.
- Determine the uniform node size from the production font and the longest wrapped node name, subject to a minimum larger than the current 104-by-104 control. Do not special-case charter nodes.
- Scale and center the entire graph through the production canvas so every enlarged control fits inside the supported desktop viewport with a fixed safe margin.
- Apply the same fit after rebuild, open, and viewport resize. Player pan and zoom remain available after the initial fit.
- Draw connections between the final projected node centers. Uniform projection must preserve edge angles and the validated no-crossing/no-perpendicular topology.
- The full node names, including all six `District Charter` names, must be visibly rendered, unellipsized, inside the viewport, and free of label/control overlap in the accepted 1920-by-1080 capture.

## Production boundaries

- `PassiveTreeNodeControl` owns uniform wrapped-name sizing and text presentation.
- `PassiveTreeCanvas` owns content bounds, uniform fit zoom, centering pan, and resize refitting.
- `PassiveTreeScreen` requests the production fit after rebuild/open/viewport changes; tests do not reach through a test-only production API.
- The LatticeWright source/runtime files and Party Forge domain coordinates remain byte-for-byte unchanged.

## Failure behavior

- Missing views or a zero-sized canvas leave the existing zoom and pan unchanged rather than producing invalid values.
- Fit calculations clamp to the existing production zoom range.
- A label that cannot fit at the supported viewport fails the visual acceptance runner; the test must not lower font size, abbreviate text, or substitute tooltip-only content.

## Verification

- RED: the strict Task 8 visual runner fails on all six full-label width checks and reports the three observed collisions while all 37 strict connection-path checks pass.
- GREEN: production font metrics prove every wrapped label fits its control; all 37 controls fit the canvas; no control text region overlaps another control; all 37 connection paths retain at least 95 percent pixel coverage with a maximum two-sample internal gap.
- Re-run the existing passive-tree input, profile, and responsive integrations to prove allocation, navigation, and supported viewports remain unchanged.
- Capture and render the final 1920-by-1080 Party Forge City screen for remote approval.

## Exclusions

No data-format migration, LatticeWright coordinate change, new node/effect, district-tree activation, tooltip-only workaround, label-layer workaround, art asset, HUD change, or unrelated passive-tree redesign is included.
