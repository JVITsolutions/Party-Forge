# Passive Tree Enlarged Node Fit Design

**Status:** Approved by Jacob on 2026-09-02. The original enlarged-node direction was amended after geometry proof: re-author the 37 LatticeWright placement coordinates so the enlarged tree can actually fit, while preserving every semantic contract.

## Problem

The City v3 graph and all 37 connection paths are valid for LatticeWright's historical 92-by-34 geometry profile, but production passive-tree controls expose only 96 px of usable text width. The six district-charter labels require 162-206 px on one line, so the current no-wrap 104-by-104 controls ellipsize the labels and three charter regions collide with neighboring controls.

The first enlarged-node implementation proved that uniform scale alone cannot preserve the current coordinates. With 168-by-120 controls, the 1472-by-863 production canvas fits the authored graph at zoom 0.450, while the closest authored node pair needs zoom 2.182 to avoid overlap. The coordinate layout must therefore change; weakening label or overlap checks is not an acceptable remedy.

## Approved behavior

- Re-author only the 37 placement coordinates in LatticeWright format-3. Preserve all 37 placement/content IDs, names, point costs, descriptions, activation states, effects, requirements, 37 stable connection IDs and endpoint pairs, six portal identities and targets, graph topology, allocation behavior, and gameplay semantics.
- Use one widescreen, topology-preserving City layout whose six district paths remain visually distinct and whose charter node is the terminal node for each district.
- Enlarge every passive-tree node uniformly to exactly 168 by 120 px. Node names wrap at word boundaries and never use ellipsis. Do not special-case charter nodes.
- Scale and center the entire graph through the production canvas so every enlarged control fits inside the supported desktop viewport with a fixed safe margin.
- Apply the same fit after rebuild, open, and viewport resize. Player pan and zoom remain available after the initial fit.
- Draw connections between the final projected node centers. The final format-3 coordinates must contain no enlarged-node overlap, no proper edge crossing, no edge corridor through a non-endpoint enlarged node, and no shared-node junction within four degrees of perpendicular.
- The full node names, including all six `District Charter` names, must be visibly rendered, unellipsized, inside the viewport, and free of label/control overlap in the accepted 1920-by-1080 capture.

## Production boundaries

- `PassiveTreeNodeControl` owns uniform wrapped-name sizing and text presentation.
- `PassiveTreeCanvas` owns content bounds, uniform fit zoom, centering pan, and resize refitting.
- `PassiveTreeScreen` requests the production fit after rebuild/open/viewport changes; tests do not reach through a test-only production API.
- LatticeWright's Party Forge City contract owns the exact replacement coordinates and validates them using the production 168-by-120 node footprint, 12-unit node clearance, 8-unit edge corridor, and four-degree perpendicular exclusion.
- LatticeWright regenerates both canonical City sample files from that one contract. Party Forge consumes the exact regenerated runtime-v3 sample; it does not maintain a hand-edited coordinate fork.

## Failure behavior

- Missing views or a zero-sized canvas leave the existing zoom and pan unchanged rather than producing invalid values.
- Fit calculations clamp to the existing production zoom range.
- A label that cannot fit at the supported viewport fails the visual acceptance runner; the test must not lower font size, abbreviate text, or substitute tooltip-only content.

## Verification

- RED: the strict Task 8 visual runner fails on all six full-label width checks and reports the three observed collisions while all 37 strict connection-path checks pass.
- GREEN: production font metrics prove every wrapped label fits its control; all 37 controls fit the canvas; no control text region overlaps another control; all 37 connection paths retain at least 95 percent pixel coverage with a maximum two-sample internal gap.
- Compare semantic projections before and after re-layout. The projection must be byte-identical after removing only each placement's `position`; exactly 37 positions must change in both source and runtime exports.
- Run the LatticeWright City contract tests, deterministic sample regeneration, format-3 open/save/reopen/export acceptance, typecheck, lint, and the owning suite.
- Re-run the existing passive-tree input, profile, and responsive integrations to prove allocation, navigation, and supported viewports remain unchanged.
- Capture and render the final 1920-by-1080 Party Forge City screen for remote approval.

## Exclusions

No data-format migration, ID/topology/effect/activation change, new node, district-tree activation, tooltip-only workaround, label-layer workaround, art asset, HUD change, or unrelated passive-tree redesign is included.
