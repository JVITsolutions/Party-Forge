# Interactive Temporary Popups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make long temporary hover/focus popups inspectable by supporting Alt-held mouse transfer, explicit pinning, mouse scrolling, Y/Triangle pinning, and right-stick scrolling without allowing stale popup content.

**Architecture:** A reusable `TemporaryHoverPopup` base owns source, hold, pin, dismissal, and controller-scroll state. `UpgradeTooltipPanel` supplies upgrade rendering and its scroll target, while `LevelUpPanel` supplies canonical content and treats card exit as a source-release request instead of an unconditional hide.

**Tech Stack:** Godot 4.7.1, typed GDScript, TSCN scenes, SVG UI assets, Godot InputMap, the existing synchronous unit-test harness, a dedicated asynchronous `SceneTree` input/geometry runner, and the connected Godot editor.

## Global Constraints

- Begin execution in an isolated worktree created from `main` with `superpowers:using-git-worktrees`; do not implement directly in the dirty main checkout.
- Before creating the isolated worktree, record `git status --porcelain=v1` from the dirty main checkout in a timestamped file outside the repository. Treat every path in that baseline—not a hard-coded subset—as protected user work. Do not stage, restore, overwrite, or clean any of those main-checkout paths while implementing this feature.
- Apply pinning only to temporary hover/focus popups. Fixed Character Ledger and Settings detail panels remain unchanged.
- Only one temporary popup may be pinned at a time. Pinned content remains locked until explicitly unpinned or forcibly cleared by its surrounding workflow.
- Either Alt key holds an already-visible popup; Alt alone does not create or pin one.
- Mouse wheel and scrollbar dragging remain the keyboard/mouse scrolling mechanisms.
- Controller Y/Triangle toggles pinning, and right-stick vertical input scrolls the visible popup.
- Lifecycle transitions always clear source, hold, pin, scroll-input, and visibility state.
- Input configuration must be idempotent and must not replace unrelated existing action events.
- Preserve the current upgrade card, canonical presentation, recipient selection, confirmation, run pause, and developer-mode behavior.
- Every task follows RED, GREEN, full-suite verification, `git diff --check`, focused commit, and review before the next task.
- Intentional negative-test `push_error` output is acceptable only when the runner exits zero and prints its required PASS summary.

Before creating the worktree, establish safety evidence from the main checkout:

```powershell
$mainCheckout = 'F:\Projects(root)\Game dev\Projects\party-forge'
$dirtyBaseline = Join-Path $env:TEMP ("party-forge-dirty-baseline-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$dirtyHashes = [System.IO.Path]::ChangeExtension($dirtyBaseline, '.sha256')
git -C $mainCheckout status --porcelain=v1 | Set-Content -LiteralPath $dirtyBaseline
Get-Content -LiteralPath $dirtyBaseline | ForEach-Object {
	$relativePath = $_.Substring(3).Trim('"')
	$absolutePath = Join-Path $mainCheckout $relativePath
	if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
		Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256 | Select-Object Hash, Path
	}
} | ConvertTo-Json | Set-Content -LiteralPath $dirtyHashes
Get-Content -LiteralPath $dirtyBaseline
Get-Content -LiteralPath $dirtyHashes
```

Expected: the two external evidence files capture every dirty path and the exact SHA-256 content hash of every dirty file. Keep `$mainCheckout`, `$dirtyBaseline`, and `$dirtyHashes` available for the final audit. If the main checkout changes unexpectedly during execution, stop and report it instead of restoring or cleaning it.

---

## File and Responsibility Map

### Reusable interaction

- Create `scripts/ui/temporary_hover_popup.gd`: source/hold/pin state, dismissal contract, input dispatch, scroll-axis processing, and pin-button synchronization.
- Create `tests/unit/test_temporary_hover_popup.gd`: state-transition and fail-safe unit coverage.

### Upgrade popup presentation

- Modify `scripts/ui/upgrade_tooltip_panel.gd`: extend the reusable base, render only accepted content, preserve scroll position for the pinned source, and retain responsive placement.
- Modify `scenes/ui/upgrade_tooltip_panel.tscn`: interactive mouse filtering, header layout, top-right pin button, and exported base paths/assets.
- Create `assets/ui/pin_outline.svg`: unpinned vector icon.
- Create `assets/ui/pin_filled.svg`: pinned vector icon.
- Create `tools/configure_tooltip_inputs.gd`: idempotent Alt, Y/Triangle, and right-stick InputMap persistence.
- Modify `project.godot`: generated tooltip input actions.
- Modify `tests/unit/test_upgrade_tooltip_ui.gd`: scene, icon, input-map, rendering, and responsive contracts.

### Level-up ownership

- Modify `scripts/ui/level_up_panel.gd`: source-key routing, replacement rejection, actual-dismiss synchronization, and lifecycle clearing.
- Modify `tests/unit/test_level_up_targeting_ui.gd`: production composition, hold/pin locking, replacement rejection, controller pinning, and transition cleanup.

### Runtime acceptance

- Create `tests/integration/temporary_popup_input_runner.gd`: real SubViewport keyboard, mouse, controller, scrolling, and target-resolution geometry checks.

---

### Task 1: Reusable temporary-popup state and dismissal contract

**Files:**
- Create: `scripts/ui/temporary_hover_popup.gd`
- Create: `tests/unit/test_temporary_hover_popup.gd`

**Interfaces:**
- Produces: `TemporaryHoverPopup.present_source(source_id: StringName) -> bool`.
- Produces: `TemporaryHoverPopup.release_source(source_id: StringName) -> void`.
- Produces: `TemporaryHoverPopup.set_hold_active(active: bool) -> void`.
- Produces: `TemporaryHoverPopup.toggle_pin() -> void`.
- Produces: `TemporaryHoverPopup.force_dismiss() -> void`.
- Produces: `TemporaryHoverPopup.is_pinned() -> bool` and `is_current_source(source_id: StringName) -> bool`.
- Emits: `dismissed` only when a visible popup actually closes and `pin_changed(pinned: bool)` only when pin state changes.

- [ ] **Step 1: Write the failing state-transition test**

Create `tests/unit/test_temporary_hover_popup.gd`:

```gdscript
extends RefCounted


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_transient_and_hold_lifetime(failures)
	_test_pin_lock_and_replacement(failures)
	_test_forced_reset(failures)
	return failures


func _test_transient_and_hold_lifetime(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	popup.force_dismiss()
	TestAssertions.truthy(popup.present_source(&"first"), "first source is accepted", failures)
	TestAssertions.truthy(popup.visible, "accepted source reveals popup", failures)
	popup.release_source(&"first")
	TestAssertions.truthy(not popup.visible, "transient source exit dismisses", failures)

	popup.present_source(&"first")
	popup.set_hold_active(true)
	popup.release_source(&"first")
	TestAssertions.truthy(popup.visible, "Alt hold retains inactive source", failures)
	popup.set_hold_active(false)
	TestAssertions.truthy(not popup.visible, "Alt release dismisses inactive unpinned source", failures)
	popup.free()


func _test_pin_lock_and_replacement(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	var pin_events: Array[bool] = []
	popup.pin_changed.connect(func(pinned: bool) -> void: pin_events.append(pinned))
	popup.force_dismiss()
	popup.present_source(&"first")
	popup.toggle_pin()
	popup.release_source(&"first")
	TestAssertions.truthy(popup.visible and popup.is_pinned(), "pin survives source exit", failures)
	TestAssertions.truthy(not popup.present_source(&"second"), "pinned content rejects another source", failures)
	TestAssertions.truthy(popup.is_current_source(&"first"), "rejected source cannot replace identity", failures)
	popup.toggle_pin()
	TestAssertions.truthy(not popup.visible, "unpinning inactive source dismisses", failures)
	TestAssertions.equal(pin_events, [true, false], "pin signal reports exact transitions", failures)
	popup.free()


func _test_forced_reset(failures: Array[String]) -> void:
	var popup := TemporaryHoverPopup.new()
	var dismiss_events: Array[bool] = []
	popup.dismissed.connect(func() -> void: dismiss_events.append(true))
	popup.force_dismiss()
	popup.present_source(&"first")
	popup.set_hold_active(true)
	popup.toggle_pin()
	popup.force_dismiss()
	TestAssertions.truthy(not popup.visible, "forced reset hides popup", failures)
	TestAssertions.truthy(not popup.is_pinned(), "forced reset clears pin", failures)
	TestAssertions.truthy(not popup.is_current_source(&"first"), "forced reset clears source", failures)
	TestAssertions.equal(dismiss_events.size(), 1, "forced reset emits one actual dismissal", failures)
	popup.force_dismiss()
	TestAssertions.equal(dismiss_events.size(), 1, "hidden reset does not duplicate dismissal", failures)
	popup.free()
```

- [ ] **Step 2: Run the suite and verify RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
```

Expected: import or suite failure because `TemporaryHoverPopup` does not exist; after import recognizes the test, `TEST_SUMMARY: FAIL` names the missing contract.

- [ ] **Step 3: Implement the reusable base**

Create `scripts/ui/temporary_hover_popup.gd`:

```gdscript
class_name TemporaryHoverPopup
extends PanelContainer

signal dismissed
signal pin_changed(pinned: bool)

const CONTROLLER_SCROLL_SPEED := 560.0
const INPUT_DEADZONE := 0.15

@export var scroll_target_path: NodePath
@export var pin_button_path: NodePath
@export var unpinned_icon: Texture2D
@export var pinned_icon: Texture2D

var _source_id := &""
var _source_active := false
var _hold_active := false
var _pinned := false
var _scroll_axis := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var button := _pin_button()
	if button != null and not button.pressed.is_connected(toggle_pin):
		button.pressed.connect(toggle_pin)
	_sync_pin_button()


func present_source(source_id: StringName) -> bool:
	if source_id.is_empty():
		return false
	if _pinned and not is_current_source(source_id):
		return false
	var changed := not is_current_source(source_id)
	_source_id = source_id
	_source_active = true
	visible = true
	if changed:
		scroll_to_top()
	return true


func release_source(source_id: StringName) -> void:
	if not is_current_source(source_id):
		return
	_source_active = false
	_dismiss_if_unretained()


func set_hold_active(active: bool) -> void:
	_hold_active = active and visible
	if not _hold_active:
		_dismiss_if_unretained()


func toggle_pin() -> void:
	if not visible:
		return
	_pinned = not _pinned
	_sync_pin_button()
	pin_changed.emit(_pinned)
	if not _pinned:
		_dismiss_if_unretained()


func force_dismiss() -> void:
	var was_visible := visible
	_source_id = &""
	_source_active = false
	_hold_active = false
	_pinned = false
	_scroll_axis = 0.0
	visible = false
	scroll_to_top()
	_sync_pin_button()
	if was_visible:
		dismissed.emit()


func is_pinned() -> bool:
	return _pinned


func is_current_source(source_id: StringName) -> bool:
	return not _source_id.is_empty() and _source_id == source_id


func scroll_to_top() -> void:
	var scroll := _scroll_target()
	if scroll != null:
		scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(&"tooltip_hold"):
		if event.is_action_pressed(&"tooltip_hold"):
			set_hold_active(true)
			_mark_input_handled()
			return
		if event.is_action_released(&"tooltip_hold"):
			set_hold_active(false)
			_mark_input_handled()
			return
	if not visible:
		return
	if InputMap.has_action(&"tooltip_pin") and event.is_action_pressed(&"tooltip_pin"):
		toggle_pin()
		_mark_input_handled()
		return
	if InputMap.has_action(&"tooltip_scroll_up") and InputMap.has_action(&"tooltip_scroll_down"):
		_scroll_axis = event.get_action_strength(&"tooltip_scroll_down") - event.get_action_strength(&"tooltip_scroll_up")
		if absf(_scroll_axis) >= INPUT_DEADZONE:
			_mark_input_handled()


func _process(delta: float) -> void:
	if not visible or absf(_scroll_axis) < INPUT_DEADZONE:
		return
	var scroll := _scroll_target()
	if scroll != null:
		scroll.scroll_vertical += int(roundf(_scroll_axis * CONTROLLER_SCROLL_SPEED * delta))


func _dismiss_if_unretained() -> void:
	if visible and not _source_active and not _hold_active and not _pinned:
		force_dismiss()


func _pin_button() -> Button:
	return get_node_or_null(pin_button_path) as Button if not pin_button_path.is_empty() else null


func _scroll_target() -> ScrollContainer:
	return get_node_or_null(scroll_target_path) as ScrollContainer if not scroll_target_path.is_empty() else null


func _sync_pin_button() -> void:
	var button := _pin_button()
	if button == null:
		return
	button.button_pressed = _pinned
	button.icon = pinned_icon if _pinned else unpinned_icon
	var action := "Unpin details" if _pinned else "Pin details"
	button.tooltip_text = action
	button.accessibility_name = action


func _mark_input_handled() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()
```

- [ ] **Step 4: Verify GREEN, full suite, and diff hygiene**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
git diff --check
```

Expected: `TEST_SUMMARY: PASS`; the new suite covers hold, pin lock, replacement denial, and forced reset; diff check exits zero.

- [ ] **Step 5: Commit Task 1**

```powershell
git add scripts/ui/temporary_hover_popup.gd scripts/ui/temporary_hover_popup.gd.uid tests/unit/test_temporary_hover_popup.gd tests/unit/test_temporary_hover_popup.gd.uid
git commit -m "feat: add temporary popup interaction state"
```

---

### Task 2: Upgrade tooltip pin shell and input actions

**Files:**
- Create: `assets/ui/pin_outline.svg`
- Create: `assets/ui/pin_filled.svg`
- Create: `tools/configure_tooltip_inputs.gd`
- Modify: `project.godot`
- Modify: `scripts/ui/upgrade_tooltip_panel.gd`
- Modify: `scenes/ui/upgrade_tooltip_panel.tscn`
- Modify: `tests/unit/test_upgrade_tooltip_ui.gd`

**Interfaces:**
- Consumes: `TemporaryHoverPopup` from Task 1.
- Produces: `UpgradeTooltipPanel.show_content(content: Dictionary, anchor: Control, source_id: StringName) -> bool`.
- Produces InputMap actions: `tooltip_hold`, `tooltip_pin`, `tooltip_scroll_up`, and `tooltip_scroll_down`.

- [ ] **Step 1: Add failing scene, rendering, and InputMap assertions**

Extend `tests/unit/test_upgrade_tooltip_ui.gd` so `run()` calls `_test_interactive_pin_shell_and_inputs(failures)`, then add:

```gdscript
func _test_interactive_pin_shell_and_inputs(failures: Array[String]) -> void:
	var tooltip := (load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene).instantiate() as UpgradeTooltipPanel
	tooltip.call("_ready")
	TestAssertions.truthy(tooltip is TemporaryHoverPopup, "upgrade tooltip uses reusable temporary popup", failures)
	TestAssertions.equal(tooltip.mouse_filter, Control.MOUSE_FILTER_STOP, "tooltip accepts pointer input", failures)
	var pin := tooltip.get_node_or_null("Content/Header/Pin") as Button
	TestAssertions.truthy(pin != null, "tooltip header owns top-right pin button", failures)
	if pin != null:
		TestAssertions.truthy(pin.toggle_mode, "pin exposes pressed and unpressed structure", failures)
		TestAssertions.truthy(pin.icon != null, "pin uses project vector icon", failures)
		TestAssertions.equal(pin.tooltip_text, "Pin details", "unpinned action is explained", failures)
	TestAssertions.equal(tooltip.scroll_target_path, ^"Content/BodyScroll", "tooltip exports controller scroll target", failures)
	TestAssertions.equal(tooltip.pin_button_path, ^"Content/Header/Pin", "tooltip exports pin target", failures)

	for action: StringName in [&"tooltip_hold", &"tooltip_pin", &"tooltip_scroll_up", &"tooltip_scroll_down"]:
		TestAssertions.truthy(InputMap.has_action(action), "InputMap exposes %s" % action, failures)
	var hold_events := InputMap.action_get_events(&"tooltip_hold")
	TestAssertions.truthy(hold_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.keycode == KEY_ALT), "either Alt maps to tooltip hold", failures)
	var pin_events := InputMap.action_get_events(&"tooltip_pin")
	TestAssertions.truthy(pin_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y), "Y/Triangle maps to tooltip pin", failures)
	var up_events := InputMap.action_get_events(&"tooltip_scroll_up")
	var down_events := InputMap.action_get_events(&"tooltip_scroll_down")
	TestAssertions.truthy(up_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and event.axis_value < 0.0), "right stick up maps to popup scroll up", failures)
	TestAssertions.truthy(down_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y and event.axis_value > 0.0), "right stick down maps to popup scroll down", failures)
	tooltip.free()
```

Update existing path assertions from `Content/Title` to `Content/Header/Title`, change the old mouse-filter expectation from `MOUSE_FILTER_IGNORE` to `MOUSE_FILTER_STOP`, and pass a stable source ID to every `show_content` call:

```gdscript
TestAssertions.truthy(tooltip.show_content(content, anchor, &"fixture"), "first tooltip source is accepted", failures)
```

- [ ] **Step 2: Run the suite and verify RED**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
```

Expected: `TEST_SUMMARY: FAIL`; failures name the missing pin header/assets/actions, old mouse filtering, and missing source-aware `show_content` signature.

- [ ] **Step 3: Create the vector pin assets**

Create `assets/ui/pin_outline.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path d="M8 3h8l-1 6 3 3v2h-5v7l-1 1-1-1v-7H6v-2l3-3-1-6Z" fill="none" stroke="#d8e7ff" stroke-width="1.8" stroke-linejoin="round"/>
</svg>
```

Create `assets/ui/pin_filled.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">
  <path d="M8 3h8l-1 6 3 3v2h-5v7l-1 1-1-1v-7H6v-2l3-3-1-6Z" fill="#d8e7ff" stroke="#ffffff" stroke-width="1.2" stroke-linejoin="round"/>
</svg>
```

- [ ] **Step 4: Create and run the idempotent input configurator**

Create `tools/configure_tooltip_inputs.gd`:

```gdscript
extends SceneTree


func _initialize() -> void:
	_set_key_action(&"tooltip_hold", KEY_ALT)
	_set_button_action(&"tooltip_pin", JOY_BUTTON_Y)
	_set_axis_action(&"tooltip_scroll_up", JOY_AXIS_RIGHT_Y, -1.0)
	_set_axis_action(&"tooltip_scroll_down", JOY_AXIS_RIGHT_Y, 1.0)
	ProjectSettings.save()
	print("PARTY_FORGE_TOOLTIP_INPUTS_OK")
	quit(0)


func _set_key_action(action: StringName, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	_set_action(action, [event])


func _set_button_action(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	_set_action(action, [event])


func _set_axis_action(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	_set_action(action, [event])


func _set_action(action: StringName, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.2, "events": events})
```

Run twice and verify the second run does not change `project.godot`:

```powershell
& $godot --headless --path $project --script res://tools/configure_tooltip_inputs.gd
$firstHash = (Get-FileHash project.godot -Algorithm SHA256).Hash
& $godot --headless --path $project --script res://tools/configure_tooltip_inputs.gd
$secondHash = (Get-FileHash project.godot -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) { throw 'Tooltip input configuration is not idempotent.' }
```

Expected: both runs exit zero and print `PARTY_FORGE_TOOLTIP_INPUTS_OK`; hashes match.

- [ ] **Step 5: Build the interactive tooltip header and source-aware renderer**

Change `UpgradeTooltipPanel` to extend the reusable base and accept the source identity before mutating rendered content:

```gdscript
class_name UpgradeTooltipPanel
extends TemporaryHoverPopup

const EDGE_MARGIN := 16.0
const MAXIMUM_POPUP_HEIGHT := 680.0
const CONTENT_PADDING_ALLOWANCE := 32.0


func show_content(content: Dictionary, anchor: Control, source_id: StringName) -> bool:
	var content_changed := not is_current_source(source_id)
	if not present_source(source_id):
		return false
	if content_changed:
		_set_text("Content/Header/Title", content.get("title", ""))
		_set_text("Content/Rank", content.get("rank_text", ""))
		_set_text("Content/BodyScroll/Body/Description", content.get("description", ""))
		_set_lines("Content/BodyScroll/Body/Effects", content.get("effect_lines", []))
		_set_text("Content/BodyScroll/Body/Eligibility", content.get("eligibility_text", ""))
		_set_text("Content/BodyScroll/Body/Inheritance", content.get("inheritance_text", ""))
		_set_lines("Content/BodyScroll/Body/Keywords", content.get("keyword_lines", []))
		if is_inside_tree():
			reset_size()
	_size_and_position(anchor)
	return true


func hide_content() -> void:
	force_dismiss()
```

Move the existing sizing body into `_size_and_position(anchor: Control) -> void`, updating the title lookup to `Content/Header/Title`. Keep `clamped_position`, `_set_text`, `_set_lines`, and `_viewport_size` otherwise unchanged.

Update `scenes/ui/upgrade_tooltip_panel.tscn` to:

```text
UpgradeTooltipPanel (mouse_filter STOP; scroll_target_path="Content/BodyScroll"; pin_button_path="Content/Header/Pin"; both SVG textures assigned)
└── Content (VBoxContainer)
    ├── Header (HBoxContainer)
    │   ├── Title (Label; horizontal expand/fill)
    │   └── Pin (Button; 44x44; toggle_mode=true; icon-only; tooltip/accessibility supplied by script)
    ├── Rank (Label)
    └── BodyScroll (existing ScrollContainer and Body labels)
```

Set the root and `BodyScroll` to receive mouse input; leave body labels at `MOUSE_FILTER_IGNORE` so the scroll container owns wheel events.

- [ ] **Step 6: Verify GREEN and commit Task 2**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
git diff --check
git add assets/ui/pin_outline.svg assets/ui/pin_filled.svg project.godot tools/configure_tooltip_inputs.gd tools/configure_tooltip_inputs.gd.uid scripts/ui/upgrade_tooltip_panel.gd scenes/ui/upgrade_tooltip_panel.tscn tests/unit/test_upgrade_tooltip_ui.gd
git commit -m "feat: add interactive upgrade tooltip shell"
```

Expected: import and `TEST_SUMMARY: PASS`; InputMap and scene contracts pass; diff check exits zero.

---

### Task 3: Level-up source ownership, locking, and lifecycle cleanup

**Files:**
- Modify: `scripts/ui/level_up_panel.gd`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`

**Interfaces:**
- Consumes: source-aware `UpgradeTooltipPanel.show_content` and `TemporaryHoverPopup.release_source` from Tasks 1-2.
- Preserves: `UpgradeCard.detail_requested(choice, anchor)` and `detail_dismissed(choice)`.

- [ ] **Step 1: Extend the production composition test to reproduce the bug and desired lock**

In `_test_production_card_tooltip_composition`, retain the existing transient-hover assertion, then add this sequence before changing offers:

```gdscript
	personal_card.mouse_entered.emit()
	tooltip.set_hold_active(true)
	personal_card.mouse_exited.emit()
	TestAssertions.truthy(tooltip.visible, "Alt keeps tooltip alive after card exit", failures)
	var pinned_title := (tooltip.get_node("Content/Header/Title") as Label).text
	var pin := tooltip.get_node("Content/Header/Pin") as Button
	pin.pressed.emit()
	tooltip.set_hold_active(false)
	TestAssertions.truthy(tooltip.visible and tooltip.is_pinned(), "mouse pin survives Alt release", failures)

	var second_card := panel.get_node("ContentPanel/OfferView/Content/Cards/Card2") as UpgradeCard
	second_card.mouse_entered.emit()
	TestAssertions.equal((tooltip.get_node("Content/Header/Title") as Label).text, pinned_title, "pinned content rejects another card hover", failures)
	second_card.mouse_exited.emit()
	pin.pressed.emit()
	TestAssertions.truthy(not tooltip.visible, "unpinning inactive source dismisses", failures)
```

Add controller pin coverage using a real action event:

```gdscript
	personal_card.mouse_entered.emit()
	var controller_pin := InputEventJoypadButton.new()
	controller_pin.button_index = JOY_BUTTON_Y
	controller_pin.pressed = true
	tooltip.call("_unhandled_input", controller_pin)
	TestAssertions.truthy(tooltip.is_pinned(), "Y/Triangle pins visible tooltip", failures)
	tooltip.call("_unhandled_input", controller_pin)
	TestAssertions.truthy(not tooltip.is_pinned(), "Y/Triangle unpins visible tooltip", failures)
```

For every existing lifecycle assertion (`show_choices`, `cancel_subflow`, `complete_selection`, and non-offer view), also assert `not tooltip.is_pinned()` and `not tooltip.visible`.

- [ ] **Step 2: Run the suite and verify RED**

```powershell
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
```

Expected: `TEST_SUMMARY: FAIL`; immediate `_on_card_detail_dismissed` still hides during Alt, pinned content may be replaced, and lifecycle ownership is not synchronized.

- [ ] **Step 3: Route source identity through LevelUpPanel**

In `_ready`, connect actual tooltip dismissal once:

```gdscript
	var tooltip := _tooltip()
	if tooltip != null and not tooltip.dismissed.is_connected(_on_tooltip_dismissed):
		tooltip.dismissed.connect(_on_tooltip_dismissed)
```

Replace the end of `_on_card_detail_requested` with:

```gdscript
	var source_id := StringName(choice.key())
	if _tooltip().show_content(content, anchor, source_id):
		_tooltip_choice = choice
```

Replace `_on_card_detail_dismissed` with:

```gdscript
func _on_card_detail_dismissed(choice: UpgradeChoice) -> void:
	if choice == null:
		return
	_tooltip().release_source(StringName(choice.key()))


func _on_tooltip_dismissed() -> void:
	_tooltip_choice = null
```

Replace `_hide_tooltip` and add the typed helper:

```gdscript
func _hide_tooltip() -> void:
	_tooltip_choice = null
	var tooltip := _tooltip()
	if tooltip != null:
		tooltip.force_dismiss()


func _tooltip() -> UpgradeTooltipPanel:
	return get_node_or_null("TooltipPanel") as UpgradeTooltipPanel
```

Keep every existing `_hide_tooltip()` call at new offers, activation, cancellation, confirmation/subflow transitions, and completion. Do not move popup state into `UpgradeCard`.

- [ ] **Step 4: Verify GREEN, full suite, and commit Task 3**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
git diff --check
git add scripts/ui/level_up_panel.gd tests/unit/test_level_up_targeting_ui.gd
git commit -m "feat: pin level-up upgrade details"
```

Expected: `TEST_SUMMARY: PASS`; production composition proves Alt transfer, locked content, both pin inputs, and lifecycle cleanup.

---

### Task 4: Real input, scrolling, target-resolution acceptance, and completion gate

**Files:**
- Create: `tests/integration/temporary_popup_input_runner.gd`
- Modify: `tests/unit/test_upgrade_tooltip_ui.gd` only if a static responsive contract uncovered by the runner needs to be locked.

**Interfaces:**
- Consumes: completed `UpgradeTooltipPanel` and four persisted InputMap actions.
- Produces completion marker: `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)`.

- [ ] **Step 1: Write the asynchronous real-input runner**

Create `tests/integration/temporary_popup_input_runner.gd` with this structure and exact assertions:

```gdscript
extends SceneTree

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var anchor := Button.new()
	anchor.position = Vector2(80.0, 80.0)
	anchor.size = Vector2(320.0, 240.0)
	host.add_child(anchor)
	var tooltip := (load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene).instantiate() as UpgradeTooltipPanel
	host.add_child(tooltip)
	await _wait_for_layout()

	var content := _long_content()
	tooltip.show_content(content, anchor, &"first")
	await _wait_for_layout()
	var scroll := tooltip.get_node("Content/BodyScroll") as ScrollContainer
	var pin := tooltip.get_node("Content/Header/Pin") as Button

	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	viewport.push_input(alt)
	tooltip.release_source(&"first")
	_assert(tooltip.visible, "Alt transfer keeps popup visible")

	var motion := InputEventMouseMotion.new()
	motion.position = scroll.get_global_rect().get_center()
	viewport.push_input(motion)
	var wheel := InputEventMouseButton.new()
	wheel.position = motion.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewport.push_input(wheel)
	await _wait_for_layout()
	_assert(scroll.scroll_vertical > 0, "mouse wheel scrolls Alt-held popup")

	pin.pressed.emit()
	var alt_release := alt.duplicate() as InputEventKey
	alt_release.pressed = false
	viewport.push_input(alt_release)
	await process_frame
	_assert(tooltip.visible and tooltip.is_pinned(), "mouse pin survives Alt release")
	var pinned_title := (tooltip.get_node("Content/Header/Title") as Label).text
	_assert(not tooltip.show_content({"title": "Replacement"}, anchor, &"second"), "pinned popup rejects replacement")
	_assert((tooltip.get_node("Content/Header/Title") as Label).text == pinned_title, "rejected content stays unchanged")

	var controller_pin := InputEventJoypadButton.new()
	controller_pin.button_index = JOY_BUTTON_Y
	controller_pin.pressed = true
	viewport.push_input(controller_pin)
	await process_frame
	_assert(not tooltip.visible, "Y/Triangle unpins and dismisses inactive source")

	tooltip.show_content(content, anchor, &"controller")
	viewport.push_input(controller_pin)
	await process_frame
	_assert(tooltip.is_pinned(), "Y/Triangle pins active controller popup")
	scroll.scroll_vertical = 0
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = 1.0
	viewport.push_input(stick)
	await process_frame
	await process_frame
	_assert(scroll.scroll_vertical > 0, "right stick scrolls visible popup")
	stick.axis_value = 0.0
	viewport.push_input(stick)

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var before := _failures.size()
		viewport.size = viewport_size
		host.size = viewport_size
		anchor.position = Vector2(float(viewport_size.x) * 0.5 - 160.0, 80.0)
		tooltip.force_dismiss()
		tooltip.show_content(content, anchor, &"size_%d" % viewport_size.x)
		await _wait_for_layout()
		var rect := tooltip.get_global_rect()
		var pin_rect := pin.get_global_rect()
		_assert(rect.position.x >= 16.0 and rect.position.y >= 16.0, "popup starts inside %s" % viewport_size)
		_assert(rect.end.x <= viewport_size.x - 16.0 and rect.end.y <= viewport_size.y - 16.0, "popup ends inside %s" % viewport_size)
		_assert(rect.encloses(pin_rect), "pin remains inside popup at %s" % viewport_size)
		_assert(scroll.get_v_scroll_bar().visible, "long content scrolls at %s" % viewport_size)
		if _failures.size() == before:
			print("TEMPORARY_POPUP_INPUT_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	viewport.free()
	if _failures.is_empty():
		print("TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("TEMPORARY_POPUP_INPUT_FAILURE: %s" % failure)
	print("TEMPORARY_POPUP_INPUT_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _long_content() -> Dictionary:
	var effects: Array[String] = []
	var keywords: Array[String] = []
	for index: int in 32:
		effects.append("%d%% increased Area Size from a production-like authored effect." % (index + 1))
	for index: int in 64:
		keywords.append("Keyword %d: A long explanation that requires interactive scrolling." % (index + 1))
	return {
		"title": "Expanding Power",
		"rank_text": "Offered rank 1 / 3",
		"description": "A long authored upgrade used for real popup interaction acceptance.",
		"effect_lines": effects,
		"eligibility_text": "Requires all traits or capabilities: Area",
		"inheritance_text": "",
		"keyword_lines": keywords,
	}
```

- [ ] **Step 2: Run the new runner and correct only demonstrated integration gaps**

```powershell
$popupOutput = & $godot --headless --path $project --script res://tests/integration/temporary_popup_input_runner.gd --quit-after 120 2>&1
$popupExit = $LASTEXITCODE
$popupOutput
if ($popupExit -ne 0 -or $popupOutput -notcontains 'TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)') {
	throw 'Temporary popup real-input acceptance failed.'
}
```

Expected: exit zero, four size markers, and exactly one `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)`. An exit zero without the summary is a failure.

- [ ] **Step 3: Run the automated completion gate**

```powershell
& $godot --headless --path $project --script res://tools/configure_tooltip_inputs.gd
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd --quit-after 60
& $godot --headless --path $project --script res://tests/integration/responsive_ui_geometry_runner.gd --quit-after 30
& $godot --headless --path $project --script res://tests/integration/temporary_popup_input_runner.gd --quit-after 120
git diff --check
rg -n -i 'TO[D]O|TB[D]|PLACEH[O]LDER|FIXME|XXX' scripts/ui/temporary_hover_popup.gd scripts/ui/upgrade_tooltip_panel.gd scripts/ui/level_up_panel.gd tests/unit/test_temporary_hover_popup.gd tests/integration/temporary_popup_input_runner.gd
```

Expected: both configurator and import exit zero; `TEST_SUMMARY: PASS`; existing responsive summary remains `PASS (4 sizes)`; temporary-popup summary is `PASS (4 sizes)`; diff check exits zero; unfinished-marker search has no matches.

Audit the feature branch against its base and confirm its changed-path set contains only files listed in this plan. Separately re-read the saved dirty-main baseline and confirm `git status --porcelain=v1` in the main checkout still contains every protected path with the same tracked/untracked classification:

```powershell
$base = git merge-base main HEAD
git diff --name-only "$base..HEAD"
$baselineStatus = Get-Content -LiteralPath $dirtyBaseline
$currentStatus = @(git -C $mainCheckout status --porcelain=v1)
$statusDelta = Compare-Object $baselineStatus $currentStatus
$baselineHashRows = @(Get-Content -LiteralPath $dirtyHashes -Raw | ConvertFrom-Json)
$currentHashRows = @($baselineHashRows | ForEach-Object {
	Get-FileHash -LiteralPath $_.Path -Algorithm SHA256 | Select-Object Hash, Path
})
$hashDelta = Compare-Object ($baselineHashRows | ForEach-Object { "$($_.Hash) $($_.Path)" }) ($currentHashRows | ForEach-Object { "$($_.Hash) $($_.Path)" })
if ($statusDelta -or $hashDelta) {
	$statusDelta
	$hashDelta
	throw 'Dirty main-checkout protection audit failed.'
}
```

Expected: the feature diff contains only the files declared in Tasks 1-4; status and hash comparisons produce no output. If any protected path disappeared, changed classification, or changed bytes, stop rather than trying to repair it automatically.

- [ ] **Step 4: Run connected-Godot acceptance**

Use the isolated worktree editor session, not the dirty main editor:

1. Start a run and trigger the long `Expanding Power` level-up tooltip.
2. Verify leaving the upgrade without Alt closes the transient tooltip.
3. Hold Alt, move into the tooltip, and verify mouse-wheel scrolling and scrollbar dragging both work.
4. While still holding Alt, click the top-right pin; release Alt and verify the tooltip stays visible.
5. Hover the other two cards and verify title, rank, content, and scroll position remain locked.
6. Click the pin again and verify the inactive tooltip closes.
7. Focus a card with controller, press Y/Triangle, and verify pin state changes visually.
8. Move the right stick vertically and verify the pinned tooltip scrolls; center the stick and verify scrolling stops.
9. Begin recipient selection, return to offers, confirm an upgrade, and trigger a new level-up; verify no pinned content survives any transition.
10. Repeat containment checks at 1920x1080, 2560x1440, and 3840x2160.
11. Read both game and editor logs with details; do not report acceptance if new errors occurred.

- [ ] **Step 5: Commit Task 4**

```powershell
git add tests/integration/temporary_popup_input_runner.gd tests/integration/temporary_popup_input_runner.gd.uid tests/unit/test_upgrade_tooltip_ui.gd
git commit -m "test: verify interactive popup input and layout"
```

Expected: focused final commit, clean feature worktree, and all automated/live evidence recorded for review.

---

## Final Acceptance Gate

Before claiming the feature complete, verify every item:

- Transient card exit still dismisses normally.
- Either Alt key retains only an already-visible popup.
- Mouse wheel and scrollbar dragging work while Alt-held or pinned.
- The top-right pin has distinct pinned/unpinned visuals and accessible action text.
- Pinned content rejects other source hovers and preserves its scroll position.
- Y/Triangle toggles pinning and right-stick vertical input scrolls then stops at center.
- New offers, activation, recipient selection, confirmation, cancellation, completion, and level-up exit forcibly clear popup state.
- Fixed Character Ledger and Settings detail panels remain unchanged.
- 720p regression plus 1080p, 1440p, and 4K popup geometry pass.
- Input configuration is idempotent and preserves unrelated actions.
- Full suite, both integration runners, import, diff check, protected-path audit, and connected-editor logs pass.
- Every path captured in the pre-execution dirty-main baseline retains its original tracked/untracked classification, and no protected file is intentionally rewritten by this feature.
