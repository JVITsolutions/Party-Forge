# Party Forge Responsive UI Tutorial

## The Two Coordinate Systems

Party Forge draws its interface on a 1920×1080 logical canvas. Godot then scales that canvas to the physical game window or monitor. On a 3840×2160 display, each logical UI pixel becomes two physical pixels in each direction.

Changing the logical resolution does not automatically reposition controls that use fixed coordinates. That is why the earlier level-up panel moved toward the upper-left: its offsets still described a position on the old canvas.

## Anchors and Offsets

An anchor says which part of the parent a control follows. An offset says how far the control sits from that anchor in logical pixels.

- Top-left HUD: anchors at top-left, positive offsets create the margin.
- Centered modal: all four anchors at the center, symmetric negative and positive offsets define its size.
- Top-center banner: horizontal anchors at the center, vertical anchors at the top.
- Full-screen overlay: anchors span all four edges.

For a 700×190 centered panel, the offsets are half its size around the center:

- left `-350`
- top `-95`
- right `350`
- bottom `95`

## Reposition a Control in the Godot Editor

1. Open the scene containing the control.
2. Select the `Control`, `PanelContainer`, or `Label` in the Scene tree.
3. In the toolbar's Layout menu, choose the intended anchor preset.
4. Use the Inspector's Layout section to adjust offsets.
5. Keep opposite offsets symmetric for a fixed-size centered control.
6. Save the scene with `Ctrl+S` and run the project with `F6` for the current scene or `F5` for the full game.

Do not drag a centered panel until its anchors are set. Dragging first records coordinates relative to the old anchors and can recreate the upper-left shift.

## Where Party Forge UI Lives

- `scenes/ui/hud.tscn`: status HUD, class selection, boss banner, and instances of the other overlays.
- `scenes/ui/level_up_panel.tscn`: three level-up choices.
- `scenes/ui/run_result_panel.tscn`: victory and defeat dialog.
- `scripts/ui/*.gd`: behavior and signals, not static positioning.
- `project.godot`: logical viewport, fullscreen mode, and stretch behavior.

For layout-only changes, edit the `.tscn` scene in Godot. Change a `.gd` script only when the control's behavior or data needs to change.

## Safely Resize a Centered Panel

1. Decide the new logical width and height.
2. Divide both values by two.
3. Set left and top to the negative halves.
4. Set right and bottom to the positive halves.
5. Run at 1280×720, 1920×1080, and fullscreen 4K.

Example: an 800×240 centered panel uses `-400`, `-120`, `400`, `120`.

## Saving and Testing

Godot saves each edited scene or script as its own file; the project is the folder containing all of those files. Use `Ctrl+S` for the current scene or script, and use the editor's save-all command when several resources are open. Git then records the project as a whole by tracking the individual changed files.

Before committing, review what changed:

```powershell
git status --short
git diff --check
```

Run Party Forge's automated checks with:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

A healthy run ends with `TEST_SUMMARY: PASS`.
