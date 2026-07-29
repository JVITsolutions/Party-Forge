# Party Forge Responsive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Party Forge's status HUD, modal panels, and boss banner in their intended positions at 1280×720, 1920×1080, and 3840×2160.

**Architecture:** Scene-authored Godot `Control` anchors define each UI element's attachment to the viewport, while symmetric logical offsets retain the current control sizes. A headless layout-contract test calculates each control rectangle at several viewport sizes so responsive behavior is verified without runtime positioning code.

**Tech Stack:** Godot 4.7.1 stable Mono editor, typed GDScript, Godot `.tscn` resources, PowerShell verification commands, custom headless GDScript test runner.

## Global Constraints

- Logical design resolution remains exactly 1920×1080.
- Stretch mode remains exactly `canvas_items` and the game preserves its 16:9 aspect ratio.
- Status HUD remains at the upper-left with a 16-pixel logical margin.
- Class selection, level-up, and result panels remain fixed-size and centered on both axes.
- Boss banner remains fixed-size, horizontally centered, and 80 logical pixels from the top.
- Existing fonts, control sizes, visibility behavior, signals, and gameplay logic remain unchanged.
- Preserve all current user-authored and Godot-serialized changes.
- Do not alter projectile behavior, redesign the HUD, add art, or introduce runtime layout scripts.
- Stage only the files explicitly listed by each task; leave unrelated modified scripts unstaged.

## File Structure

- Create `tests/unit/test_responsive_ui.gd`: resolution-independent layout-contract assertions.
- Modify `project.godot`: retain the user's 1920×1080 fullscreen settings and explicitly preserve the 16:9 aspect ratio.
- Modify `scenes/ui/hud.tscn`: center class selection and the boss banner while retaining the top-left status HUD.
- Modify `scenes/ui/level_up_panel.tscn`: center the level-up panel while preserving current Godot UID serialization.
- Modify `scenes/ui/run_result_panel.tscn`: center the inner result panel inside its existing full-screen root.
- Create `docs/development/RESPONSIVE_UI_TUTORIAL.md`: explain how the layout works and how the user can safely modify and test it in Godot.

---

### Task 1: Responsive Layout Contract and Scene Anchors

**Files:**

- Create: `tests/unit/test_responsive_ui.gd`
- Modify: `project.godot`
- Modify: `scenes/ui/hud.tscn`
- Modify: `scenes/ui/level_up_panel.tscn`
- Modify: `scenes/ui/run_result_panel.tscn`

**Interfaces:**

- Consumes: `res://scenes/ui/hud.tscn` and the custom `TestAssertions` helpers automatically available to unit suites.
- Produces: a scene-only layout contract in which modal controls use center anchors, the boss banner uses a center-top anchor, and the status HUD remains top-left.

- [ ] **Step 1: Record the dirty-worktree boundary before editing**

Run:

```powershell
git status --short
git diff -- project.godot scenes/ui/hud.tscn scenes/ui/level_up_panel.tscn scenes/ui/run_result_panel.tscn
```

Expected: the user's existing changes are visible in `project.godot` and `scenes/ui/level_up_panel.tscn`; unrelated script changes remain present but outside this task's staging scope.

- [ ] **Step 2: Write the failing multi-resolution layout test**

Create `tests/unit/test_responsive_ui.gd`:

```gdscript
extends RefCounted

const VIEWPORT_SIZES := [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(3840.0, 2160.0),
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_project_display_contract(failures)
	_test_responsive_hud_layout(failures)
	return failures

func _test_project_display_contract(failures: Array[String]) -> void:
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		1920,
		"logical viewport width is 1920",
		failures,
	)
	TestAssertions.equal(
		int(ProjectSettings.get_setting("display/window/size/viewport_height")),
		1080,
		"logical viewport height is 1080",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/mode")),
		"canvas_items",
		"UI uses canvas_items stretch mode",
		failures,
	)
	TestAssertions.equal(
		str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")),
		"keep",
		"UI preserves the 16:9 aspect ratio",
		failures,
	)

func _test_responsive_hud_layout(failures: Array[String]) -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var status_margin := hud.get_node("Margin") as Control
	var boss_banner := hud.get_node("BossBanner") as Control
	var class_selection := hud.get_node("ClassSelection") as Control
	var level_up := hud.get_node("LevelUpPanel") as Control
	var result_root := hud.get_node("RunResultPanel") as Control
	var result_panel := hud.get_node("RunResultPanel/Panel") as Control
	_assert_full_rect(result_root, "run result overlay", failures)

	for viewport_size: Vector2 in VIEWPORT_SIZES:
		_assert_centered(class_selection, viewport_size, "class selection", failures)
		_assert_centered(level_up, viewport_size, "level-up panel", failures)
		_assert_centered(result_panel, viewport_size, "run result panel", failures)
		_assert_size(class_selection, Vector2(540.0, 320.0), "class selection", failures)
		_assert_size(level_up, Vector2(700.0, 190.0), "level-up panel", failures)
		_assert_size(result_panel, Vector2(400.0, 260.0), "run result panel", failures)
		TestAssertions.near(
			_rect_center(boss_banner, viewport_size).x,
			viewport_size.x * 0.5,
			0.01,
			"boss banner is horizontally centered at %s" % viewport_size,
			failures,
		)
		TestAssertions.near(
			_rect_top_left(boss_banner, viewport_size).y,
			80.0,
			0.01,
			"boss banner retains top margin at %s" % viewport_size,
			failures,
		)
		var status_position := _rect_top_left(status_margin, viewport_size)
		TestAssertions.near(status_position.x, 16.0, 0.01, "status HUD retains left margin at %s" % viewport_size, failures)
		TestAssertions.near(status_position.y, 16.0, 0.01, "status HUD retains top margin at %s" % viewport_size, failures)

	hud.free()

func _assert_centered(control: Control, viewport_size: Vector2, label: String, failures: Array[String]) -> void:
	var center := _rect_center(control, viewport_size)
	TestAssertions.near(center.x, viewport_size.x * 0.5, 0.01, "%s center x at %s" % [label, viewport_size], failures)
	TestAssertions.near(center.y, viewport_size.y * 0.5, 0.01, "%s center y at %s" % [label, viewport_size], failures)

func _assert_size(control: Control, expected: Vector2, label: String, failures: Array[String]) -> void:
	var logical_size := Vector2(control.offset_right - control.offset_left, control.offset_bottom - control.offset_top)
	TestAssertions.equal(logical_size, expected, "%s retains logical size" % label, failures)

func _assert_full_rect(control: Control, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(
		Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom),
		Vector4(0.0, 0.0, 1.0, 1.0),
		"%s anchors cover its parent" % label,
		failures,
	)
	TestAssertions.equal(
		Vector4(control.offset_left, control.offset_top, control.offset_right, control.offset_bottom),
		Vector4.ZERO,
		"%s has no edge offsets" % label,
		failures,
	)

func _rect_center(control: Control, viewport_size: Vector2) -> Vector2:
	var top_left := _rect_top_left(control, viewport_size)
	var bottom_right := Vector2(
		viewport_size.x * control.anchor_right + control.offset_right,
		viewport_size.y * control.anchor_bottom + control.offset_bottom,
	)
	return (top_left + bottom_right) * 0.5

func _rect_top_left(control: Control, viewport_size: Vector2) -> Vector2:
	return Vector2(
		viewport_size.x * control.anchor_left + control.offset_left,
		viewport_size.y * control.anchor_top + control.offset_top,
	)
```

- [ ] **Step 3: Run the suite and verify the new test fails for the old absolute offsets**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: exit code `1`, `TEST_SUMMARY: FAIL`, and failures from `res://tests/unit/test_responsive_ui.gd` showing that the old absolute positions are not centered at one or more tested resolutions.

- [ ] **Step 4: Make the minimal project and scene changes**

In `project.godot`, retain the user's display values and make aspect preservation explicit:

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=3
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

In `scenes/ui/hud.tscn`, replace the layout properties for `BossBanner` and `ClassSelection` with:

```ini
[node name="BossBanner" type="Label" parent="."]
visible = false
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -250.0
offset_top = 80.0
offset_right = 250.0
offset_bottom = 150.0
grow_horizontal = 2
theme_override_colors/font_color = Color(1, 0.25, 0.05, 1)
theme_override_font_sizes/font_size = 44
text = "THE FORGE GUARDIAN ARRIVES"
horizontal_alignment = 1

[node name="ClassSelection" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -270.0
offset_top = -160.0
offset_right = 270.0
offset_bottom = 160.0
grow_horizontal = 2
grow_vertical = 2
```

In `scenes/ui/level_up_panel.tscn`, retain the current UID fields and replace only the root layout properties with:

```ini
[node name="LevelUpPanel" type="PanelContainer" unique_id=1370617101]
process_mode = 3
visible = false
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -350.0
offset_top = -95.0
offset_right = 350.0
offset_bottom = 95.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

In `scenes/ui/run_result_panel.tscn`, replace the inner `Panel` layout with:

```ini
[node name="Panel" type="PanelContainer" parent="."]
layout_mode = 0
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -130.0
offset_right = 200.0
offset_bottom = 130.0
grow_horizontal = 2
grow_vertical = 2
```

- [ ] **Step 5: Run the automated suite and verify the layout contract passes**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: exit code `0` and `TEST_SUMMARY: PASS (16 suites)`.

- [ ] **Step 6: Validate imports, parsing, and patch hygiene**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
git diff --check
```

Expected: Godot exits `0` after reaching editor initialization, and `git diff --check` produces no errors.

- [ ] **Step 7: Inspect and commit only the responsive-layout scope**

Run:

```powershell
git diff -- project.godot scenes/ui/hud.tscn scenes/ui/level_up_panel.tscn scenes/ui/run_result_panel.tscn tests/unit/test_responsive_ui.gd
git add -- project.godot scenes/ui/hud.tscn scenes/ui/level_up_panel.tscn scenes/ui/run_result_panel.tscn tests/unit/test_responsive_ui.gd
git diff --cached --check
git diff --cached --name-only
git commit -m "fix: anchor Party Forge UI responsively"
```

Expected: the staged list contains exactly the five files above. The commit preserves the user's previously saved serialization in `project.godot` and `level_up_panel.tscn`; the modified projectile and reformatted scripts remain unstaged.

---

### Task 2: Visual Verification and Beginner Tutorial

**Files:**

- Create: `docs/development/RESPONSIVE_UI_TUTORIAL.md`

**Interfaces:**

- Consumes: the anchored scene contract produced by Task 1 and the open Godot editor.
- Produces: a reusable, editor-oriented guide for modifying and checking Party Forge UI layouts without Codex.

- [ ] **Step 1: Visually verify the responsive layout in Godot**

Use the open Godot editor to run the project and inspect these states:

1. Class selection: panel centered.
2. Active run: health, experience, timer, party list, and traits at upper-left.
3. Level-up: choice panel centered.
4. Boss phase: banner horizontally centered near the top.
5. Victory or defeat: result panel centered.

Test once in a 1920×1080 window and once fullscreen on the 3840×2160 display. Also launch a 1280×720 window from PowerShell:

```powershell
Start-Process -FilePath 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' -ArgumentList @('--path', 'F:\Projects(root)\Game dev\Projects\party-forge', '--windowed', '--resolution', '1280x720')
```

Expected: modal panels remain centered, the banner remains top-center, the status HUD remains upper-left, and none of those controls is clipped at any tested size.

- [ ] **Step 2: Write the reusable Godot UI tutorial**

Create `docs/development/RESPONSIVE_UI_TUTORIAL.md` with this content:

```markdown
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
```

- [ ] **Step 3: Re-run objective checks after visual validation**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
git diff --check
```

Expected: `TEST_SUMMARY: PASS (16 suites)`, both Godot commands exit `0`, and `git diff --check` reports no errors.

- [ ] **Step 4: Commit the tutorial without staging unrelated work**

Run:

```powershell
git add -- docs/development/RESPONSIVE_UI_TUTORIAL.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: explain responsive Godot UI workflow"
```

Expected: the staged list contains only `docs/development/RESPONSIVE_UI_TUTORIAL.md`; the commit succeeds and all unrelated user-authored files remain untouched.
