# Passive Tree Circle Label Containment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Increase the visible passive-node circles to approximately 116 pixels and constrain every full node name to the circle interior without changing City data, topology, coordinates, or gameplay.

**Architecture:** Keep the existing `168 x 120` button as the interaction and layout footprint. Make `PassiveTreeNodeVisual` the single authority for visible radius, and apply one transparent `StyleBoxEmpty` content inset to every Button interaction state so native word-smart wrapping uses the circle-safe interior. Extend the production visual runner to measure every circular node's word regions against the same radius API.

**Tech Stack:** Godot 4.7.1 Mono, GDScript, `.tscn` scene resources, Party Forge focused/unit/integration runners, Git worktrees.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment` until conflict-safe integration.
- Use only `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` for shell verification.
- Preserve the `168 x 120` interaction rectangle, all 37 LatticeWright coordinates, 37 connections, six portal charters, City Heart diamond, gameplay semantics, font size, complete names, word-smart wrapping, and no-ellipsis behavior.
- Set the circular radius ratio to exactly `0.48`, yielding `57.6` pixels of radius and `115.2` pixels of diameter at production size.
- Constrain text with exactly 32-pixel left/right and 24-pixel top/bottom transparent content margins in every Button interaction state.
- Do not change either format-3/runtime-v3 City artifact or any active art, body-model, HUD, attack-windup, Review Batch 1, Frost, or run-seed path.
- Preserve authoritative main's exact 68 untracked `.gd.uid` files and all registered worktrees. Never reset, clean, delete, rewrite history, or force-push.

---

### Task 1: Make the current escaped-label defect fail under automation

**Files:**
- Modify: `tests/unit/test_passive_tree_readability.gd`
- Modify: `tests/integration/city_tree_v3_visual_runner.gd`

**Interfaces:**
- Consumes: the production `PassiveTreeNodeControl`, its `NodeVisual`, and the visual runner's existing wrapped-text measurements.
- Produces: a failing contract for `NodeVisual.circle_radius_for_size(node_size: Vector2) -> float`, stable content margins, and word-region containment inside every non-keystone circle.

- [ ] **Step 1: Extend the unit contract before production changes**

After locating `NodeVisual` in `_test_node_control_readability_contract`, add guarded radius and style assertions:

```gdscript
TestAssertions.truthy(visual.has_method(&"circle_radius_for_size"), "node visual exposes its production circle-radius contract", failures)
if visual.has_method(&"circle_radius_for_size"):
	TestAssertions.near(float(visual.call(&"circle_radius_for_size", Vector2(168.0, 120.0))), 57.6, 0.001, "passive-node circles use the approved 115.2-pixel diameter", failures)
for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
	var style := node_control.get_theme_stylebox(style_name)
	TestAssertions.truthy(style != null, "%s state owns a label-inset style" % style_name, failures)
	if style != null:
		TestAssertions.near(style.get_content_margin(SIDE_LEFT), 32.0, 0.001, "%s left label inset" % style_name, failures)
		TestAssertions.near(style.get_content_margin(SIDE_RIGHT), 32.0, 0.001, "%s right label inset" % style_name, failures)
		TestAssertions.near(style.get_content_margin(SIDE_TOP), 24.0, 0.001, "%s top label inset" % style_name, failures)
		TestAssertions.near(style.get_content_margin(SIDE_BOTTOM), 24.0, 0.001, "%s bottom label inset" % style_name, failures)
```

- [ ] **Step 2: Extend the visual runner to check all circular labels**

Rename `_full_label_renderability(canvas, charter_id)` to `_full_label_renderability(canvas, node_id)` and keep its existing return contract. After image capture, iterate every non-keystone/start node and require each measured word rectangle to sit inside the actual production circle:

```gdscript
for node_id: StringName in canvas.node_ids():
	var control := canvas.node_control(node_id)
	var view := canvas.node_view(node_id)
	if control == null or view == null or view.type in [&"keystone", &"start"]:
		continue
	var renderability := _full_label_renderability(canvas, node_id)
	var visual := control.find_child("NodeVisual", false, false) as Control
	_assert(visual != null and visual.has_method(&"circle_radius_for_size"), "%s resolves its production circle geometry" % node_id)
	if visual == null or not visual.has_method(&"circle_radius_for_size"):
		continue
	var scale := control.get_global_transform().get_scale().abs()
	var radius := float(visual.call(&"circle_radius_for_size", control.size)) * minf(scale.x, scale.y)
	for region_value: Variant in renderability.get("word_regions", []) as Array:
		var region := region_value as Dictionary
		_assert(_rect_inside_circle(region.get("rect", Rect2()) as Rect2, control.get_global_rect().get_center(), radius), "%s word '%s' escapes its visible circle" % [node_id, String(region.get("word", ""))])
```

Add the pure helper:

```gdscript
func _rect_inside_circle(rect: Rect2, center: Vector2, radius: float) -> bool:
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for corner: Vector2 in corners:
		if corner.distance_to(center) > radius + 0.5:
			return false
	return true
```

- [ ] **Step 3: Run RED and record the intended failures**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --editor --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' --import --quit-after 600
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_passive_tree_readability.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
```

Expected: import exits 0; focused and visual gates exit nonzero because the current visual has no radius-contract method, has no 32/24 content margins, and permits words outside the 100.8-pixel circle. No production file changes before this RED evidence.

---

### Task 2: Enlarge the circle and constrain native text layout

**Files:**
- Modify: `scripts/ui/passive_tree/passive_tree_node_visual.gd`
- Modify: `scenes/ui/passive_tree/passive_tree_node_control.tscn`
- Test: `tests/unit/test_passive_tree_readability.gd`
- Test: `tests/integration/city_tree_v3_visual_runner.gd`

**Interfaces:**
- Consumes: `PassiveTreeNodeVisual._draw()` and Godot Button theme style states.
- Produces: `circle_radius_for_size(node_size: Vector2) -> float` as the production geometry authority and stable 104-by-72 label-layout space.

- [ ] **Step 1: Add the single production radius authority**

In `PassiveTreeNodeVisual`, add the constant and method, then make `_draw()` consume it:

```gdscript
const CIRCLE_RADIUS_RATIO := 0.48

func circle_radius_for_size(node_size: Vector2) -> float:
	return maxf(10.0, minf(node_size.x, node_size.y) * CIRCLE_RADIUS_RATIO)
```

Replace:

```gdscript
var radius := maxf(10.0, minf(size.x, size.y) * 0.42)
```

with:

```gdscript
var radius := circle_radius_for_size(size)
```

- [ ] **Step 2: Apply one transparent content inset to all Button states**

Increase the scene `load_steps` to 4, add this subresource, and reference it from every interaction style:

```ini
[sub_resource type="StyleBoxEmpty" id="StyleBoxEmpty_label_safe"]
content_margin_left = 32.0
content_margin_top = 24.0
content_margin_right = 32.0
content_margin_bottom = 24.0
```

```ini
theme_override_styles/normal = SubResource("StyleBoxEmpty_label_safe")
theme_override_styles/hover = SubResource("StyleBoxEmpty_label_safe")
theme_override_styles/pressed = SubResource("StyleBoxEmpty_label_safe")
theme_override_styles/hover_pressed = SubResource("StyleBoxEmpty_label_safe")
theme_override_styles/focus = SubResource("StyleBoxEmpty_label_safe")
theme_override_styles/disabled = SubResource("StyleBoxEmpty_label_safe")
```

- [ ] **Step 3: Run GREEN for the focused and visual contracts**

Run the same focused and visual commands from Task 1.

Expected: focused runner exits 0 with exactly one `TEST_SUMMARY: PASS (0 failures)`; visual runner exits 0 with exactly one `CITY_TREE_V3_VISUAL_SUMMARY: PASS`; every circle-label assertion passes; forbidden diagnostic count is zero.

- [ ] **Step 4: Inspect the fresh screenshot**

Open the exact path printed by `CITY_TREE_V3_VISUAL_PATH`. Confirm all 37 nodes remain visible, all circular labels are contained, the City Heart diamond is unchanged, connections remain unobstructed, and the complete tree remains fitted at 1920 x 1080.

- [ ] **Step 5: Commit the tested correction**

```powershell
git -c safe.directory='*' -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' diff --check
git -c safe.directory='*' -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' add -- scripts/ui/passive_tree/passive_tree_node_visual.gd scenes/ui/passive_tree/passive_tree_node_control.tscn tests/unit/test_passive_tree_readability.gd tests/integration/city_tree_v3_visual_runner.gd
git -c safe.directory='*' -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\passive-tree-circle-label-containment' commit -m 'fix: contain passive labels inside circles'
```

---

### Task 3: Qualify, review, integrate, and publish the exact correction

**Files:**
- Verify all Task 1-2 diffs; no new production files are expected.
- Write runtime logs and screenshots only below a fresh isolated temporary evidence root.

**Interfaces:**
- Consumes: the exact committed feature candidate and authoritative `main`/`origin/main` state.
- Produces: exact-commit test evidence, an inline 1920 x 1080 capture, and a conflict-free normal publication if all containment gates pass.

- [ ] **Step 1: Run focused and owning integration gates**

From a cold exact-commit archive with isolated `APPDATA` and `LOCALAPPDATA`, run:

```text
tests/unit/test_passive_tree_readability.gd
tests/unit/test_passive_tree_screen.gd
tests/unit/test_latticewright_runtime_v3_city_adapter.gd
tests/integration/city_tree_v3_visual_runner.gd
tests/integration/passive_tree_responsive_runner.gd
tests/integration/passive_tree_input_runner.gd
tests/integration/passive_tree_profile_runner.gd
```

Require native exit 0, each exact PASS marker once, and zero test failure, failing summary, script/parse/load error, segmentation, ObjectDB leak, RID leak, or certificate-load diagnostics.

- [ ] **Step 2: Run the complete regression suite**

```powershell
$archiveSource = Join-Path $evidenceRoot 'source'
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path $archiveSource --quit-after 7200 --script res://tests/test_runner.gd
```

Expected: native exit 0 and exactly one current `TEST_SUMMARY: PASS (267 suites)` with zero forbidden diagnostics.

- [ ] **Step 3: Review the exact diff**

Verify the committed diff changes only the two production UI files, the two owning tests, this plan, and the approved spec. Confirm no City artifact, coordinate, gameplay, or excluded lane changed.

- [ ] **Step 4: Recheck containment and remote drift**

Require authoritative `main` to have zero tracked/staged changes and exactly the original 68 untracked `.gd.uid` records with the same paths, bytes, and hashes. Fetch normally and require local `main`, `origin/main`, and live `refs/heads/main` to match the reviewed base before merging.

- [ ] **Step 5: Integrate and publish normally**

Merge the exact candidate into `main` with a normal non-force merge. Stop on conflict or unexpected scope. Re-run the focused, visual, responsive, and full-suite gates on the exact merge commit, then push `refs/heads/main:refs/heads/main` normally.

- [ ] **Step 6: Verify and show the result**

Require local `main`, `origin/main`, and live GitHub `refs/heads/main` to match the merge commit, the feature candidate to be an ancestor, `git diff --check` to pass, and the original UID manifest to remain byte-identical. Show the exact passing screenshot inline for remote viewing and preserve every registered worktree.
