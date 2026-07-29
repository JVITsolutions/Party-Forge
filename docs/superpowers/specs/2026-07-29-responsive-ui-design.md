# Party Forge Responsive UI Design

**Date:** 2026-07-29
**Status:** Approved for planning

## Goal

Make Party Forge's current HUD and overlay panels stay in intentional positions when the game is displayed at 1920×1080 or scaled to a 4K screen. The fix must preserve the user's current project settings and gameplay edits.

## Current Problem

The project uses a 1920×1080 logical viewport with `canvas_items` stretching and fullscreen enabled. Several UI controls still use absolute offsets that were positioned for the earlier, smaller viewport. As a result, level-up and other modal content appears toward the upper-left instead of centered.

Affected controls:

- `HUD/ClassSelection`
- `HUD/BossBanner`
- `LevelUpPanel`
- `RunResultPanel/Panel`

The status HUD under `HUD/Margin` is intentionally placed near the upper-left and is not a centering defect.

## Chosen Approach

Use Godot `Control` anchors and offsets in the scene resources. Anchors define the intended relationship to the viewport, while offsets define each control's fixed logical size and margin.

This approach keeps layout behavior visible and editable in the Godot editor, avoids resolution-specific runtime positioning code, and fits the existing scene structure.

## Layout Rules

- The logical design resolution remains 1920×1080.
- Godot scales the canvas when the physical display is larger, including 3840×2160.
- The combat status HUD remains anchored near the upper-left with a 16-pixel logical margin.
- The class-selection panel remains a fixed logical size and is centered on both axes.
- The level-up panel remains a fixed logical size and is centered on both axes.
- The result panel's full-screen root continues to cover the viewport; its inner panel is centered on both axes.
- The boss banner is horizontally centered near the top with its existing top spacing.
- Existing fonts, control sizes, visibility behavior, signals, and gameplay logic remain unchanged.

## Scene Changes

### HUD

`ClassSelection` will use center anchors with symmetric offsets around the viewport center. `BossBanner` will use a horizontal center anchor with symmetric left and right offsets while retaining a fixed top offset. `Margin` and its status children will remain top-left.

### Level-Up Panel

The root `PanelContainer` will use center anchors and symmetric offsets. Its three choice buttons and their current container-driven sizing remain unchanged.

### Run Result Panel

The full-screen `RunResultPanel` root already follows the viewport. Its child `Panel` will use center anchors and symmetric offsets so the result dialog remains centered.

## Stretch Behavior

The current 1920×1080 logical viewport and `canvas_items` stretch mode are retained. The game will preserve its 16:9 aspect ratio rather than distort the canvas on a differently shaped display; unused physical space may therefore be letterboxed. This change targets proportional scaling between 16:9 resolutions and does not add a resolution selector or settings menu.

## Testing and Acceptance

Add an automated responsive-layout test that instantiates the relevant scenes at multiple viewport sizes. At minimum it will cover 1280×720, 1920×1080, and 3840×2160.

The test will assert that:

- class selection, level-up, and result panels share the viewport center within a small tolerance;
- the boss banner is horizontally centered and remains near the top;
- the status HUD remains near the upper-left;
- the layouts do not depend on a script repositioning them at runtime.

Implementation will follow a red-green cycle: the new test must demonstrate the existing offset-based failure before scene resources are changed. Afterward, the focused UI test, the full automated suite, Godot parser/import validation, and a visual run at the target resolution must pass.

## Preservation and Scope Boundaries

- Preserve all current user-authored and Godot-serialized changes.
- Do not alter projectile behavior in this UI change.
- Do not redesign the HUD, add new art, or change gameplay flow.
- Do not introduce a generalized responsive-layout framework until repeated needs justify one.
- Do not commit unrelated modified files with the documentation or implementation commits.

## User Learning Follow-Up

After the fix is verified, provide a beginner-oriented walkthrough of anchors, offsets, layout presets, logical resolution, and stretch behavior. The walkthrough will explain how to reposition or resize these controls safely in the Godot editor and how to test common resolutions.
