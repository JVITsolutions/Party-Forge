class_name LivingForgeStateBoard
extends Control

const CLASS_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_class_card.tscn")
const SEAT_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_seat_card.tscn")
const STATUS_BADGE_SCENE := preload("res://scenes/ui/living_forge/components/forge_status_badge.tscn")
const ACTION_BAR_SCENE := preload("res://scenes/ui/living_forge/components/forge_action_bar.tscn")
const INPUT_PROMPT_SCENE := preload("res://scenes/ui/living_forge/components/forge_input_prompt.tscn")
const REQUIRED_STATES: Array[StringName] = [
	&"focused", &"previewed", &"selected", &"locked", &"compatible",
	&"needs_attention", &"pending", &"disabled", &"success", &"warning", &"error",
]

var _state_controls: Dictionary = {}
var _compound_controls: Dictionary = {}
var _action_counts: Dictionary = {}
var _preview_counts: Dictionary = {}
var _selection_counts: Dictionary = {}
var _input_tracker := ActiveInputDevice.new()
var _action_bar: Control
var _prompts: Array[Control] = []
var _built := false


func _ready() -> void:
	_ensure_built()
	set_process_input(true)


func semantic_state_ids() -> Array[StringName]:
	_ensure_built()
	return REQUIRED_STATES.duplicate()


func state_control(state: StringName) -> Control:
	_ensure_built()
	return _state_controls.get(state) as Control


func compound_control(compound_id: StringName) -> Control:
	_ensure_built()
	return _compound_controls.get(compound_id) as Control


func interaction_action_button(example_id: StringName) -> Button:
	_ensure_built()
	match example_id:
		&"primary": return _action_bar.call(&"button_for", &"confirm") as Button
		&"secondary_pressed": return _action_bar.call(&"button_for", &"inspect") as Button
		&"unavailable": return _action_bar.call(&"button_for", &"unavailable") as Button
	return null


func set_action_evidence_mode(enabled: bool) -> void:
	_ensure_built()
	var primary := _action_bar.call(&"button_for", &"confirm") as Button
	var secondary := _action_bar.call(&"button_for", &"inspect") as Button
	var unavailable := _action_bar.call(&"button_for", &"unavailable") as Button
	primary.toggle_mode = enabled
	primary.button_pressed = enabled
	secondary.toggle_mode = enabled
	secondary.button_pressed = enabled
	if enabled:
		primary.text = "PRIMARY — PRESSED"
		primary.accessibility_description = "Primary action pressed-state proof using the authoritative pressed style."
		secondary.text = "SECONDARY — PRESSED / INSET"
		secondary.accessibility_description = "Secondary action pressed-state proof using the authoritative inset pressed style."
		unavailable.text = "UNAVAILABLE — INERT"
		unavailable.accessibility_description = "Unavailable action disabled and inert proof."
		return
	primary.text = "Confirm Proof"
	primary.accessibility_description = "Confirm the component proof."
	secondary.text = "Inspect State"
	secondary.accessibility_description = "Inspect the focused component state."
	unavailable.text = "Future Action"
	unavailable.accessibility_description = "Future action unavailable. Not part of this slice."


func apply_theme_variant(high_contrast: bool) -> void:
	theme = LivingForgeThemeCatalog.resolve(high_contrast, 100, 100)
	(get_node("Background") as ColorRect).color = LivingForgeTokens.color(&"surface_inset", high_contrast)
	(get_node("Margin/Layout/Header/Variant") as Label).text = "HIGH CONTRAST" if high_contrast else "NORMAL CONTRAST"
	_apply_component_variant(high_contrast)


func component_tree_signature() -> Array[String]:
	_ensure_built()
	var signature: Array[String] = []
	_append_signature(self, signature)
	signature.sort()
	return signature


func visible_enabled_controls_without_consumers() -> Array[String]:
	_ensure_built()
	var missing: Array[String] = []
	for node: Node in find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or not button.is_visible_in_tree() or button.disabled:
			continue
		if button.pressed.get_connections().is_empty():
			missing.append(String(button.get_path()))
			continue
		if button.has_signal(&"selection_requested") and button.get_signal_connection_list(&"selection_requested").is_empty():
			missing.append("%s:selection_requested" % button.get_path())
		if button.has_signal(&"preview_requested") and button.get_signal_connection_list(&"preview_requested").is_empty():
			missing.append("%s:preview_requested" % button.get_path())
	return missing


func exercise_enabled_actions() -> Dictionary:
	_ensure_built()
	_action_counts.clear()
	for action_id: StringName in [&"inspect", &"confirm"]:
		var button := _action_bar.call(&"button_for", action_id) as Button
		if button != null:
			button.pressed.emit()
	var unavailable := _action_bar.call(&"button_for", &"unavailable") as Button
	if unavailable != null:
		unavailable.pressed.emit()
	return _action_counts.duplicate(true)


func action_button(action_id: StringName) -> Button:
	_ensure_built()
	return _action_bar.call(&"button_for", action_id) as Button


func action_count(action_id: StringName) -> int:
	return int(_action_counts.get(action_id, 0))


func preview_count(class_id: StringName) -> int:
	return int(_preview_counts.get(class_id, 0))


func selection_count(class_id: StringName) -> int:
	return int(_selection_counts.get(class_id, 0))


func active_prompt_mode() -> StringName:
	return _input_tracker.device_kind


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	apply_theme_variant(false)
	_build_seats()
	_build_state_inventory()
	_build_action_bar()
	_build_prompts()
	_apply_component_variant(false)


func _build_seats() -> void:
	var row := get_node("Margin/Layout/SeatRow") as HBoxContainer
	for seat_number: int in range(1, 5):
		var seat := SEAT_CARD_SCENE.instantiate() as Control
		seat.name = "Seat_%d" % seat_number
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat.call(&"present", {
			"seat_number": seat_number,
			"available": seat_number == 1,
			"profile_name": "ACTIVE PROFILE - PLAYER 1" if seat_number == 1 else "Future local player",
			"status": "READY - KEYBOARD / CONTROLLER",
			"accessibility_description": "Player 1 active seat." if seat_number == 1 else "Player %d. Local co-op coming soon. Unavailable." % seat_number,
		})
		row.add_child(seat)


func _apply_component_variant(high_contrast: bool) -> void:
	for node: Node in find_children("*", "Control", true, false):
		if node.has_method(&"apply_accessibility_variant"):
			node.call(&"apply_accessibility_variant", high_contrast)


func _build_state_inventory() -> void:
	var grid := get_node("Margin/Layout/Scroll/States") as GridContainer
	_add_class_state(grid, &"focused", {"name": "FOCUSED", "role": "Keyboard / Controller", "playstyle": "Navigation focus"})
	_add_class_state(grid, &"previewed", {"name": "PREVIEWED", "role": "Presentation only", "playstyle": "Hover never commits"})
	_add_class_state(grid, &"selected", {"name": "SELECTED", "role": "Confirmed identity", "playstyle": "Choice retained", "selected": true})
	_add_class_state(grid, &"locked", {"name": "LOCKED", "role": "Requirement unmet", "playstyle": "Explicit reason", "locked": true})
	_add_class_state(grid, &"compatible", {"name": "COMPATIBLE", "role": "Loadout ready", "playstyle": "Valid pairing", "compatible": true})
	_add_class_state(grid, &"needs_attention", {"name": "NEEDS ATTENTION", "role": "Review required", "playstyle": "Action needed", "needs_attention": true})
	_add_class_state(grid, &"pending", {"name": "PENDING", "role": "Checking request", "playstyle": "Stable geometry", "pending": true})
	_add_class_state(grid, &"disabled", {"name": "DISABLED", "role": "Unavailable", "playstyle": "Readable reason", "disabled": true})
	_add_badge_state(grid, &"success", "SUCCESS - REQUEST ACCEPTED")
	_add_badge_state(grid, &"warning", "WARNING - REVIEW LOADOUT")
	_add_badge_state(grid, &"error", "ERROR - TRY AGAIN")
	_add_compound_state(grid, &"selected_compatible", {"name": "SELECTED + READY", "role": "Compound state", "playstyle": "Both cues persist", "selected": true, "compatible": true})
	_add_compound_state(grid, &"selected_attention", {"name": "SELECTED + REVIEW", "role": "Compound state", "playstyle": "Choice needs attention", "selected": true, "needs_attention": true})
	_add_compound_state(grid, &"focused_selected", {"name": "FOCUSED + SELECTED", "role": "Compound state", "playstyle": "Navigation preserves choice", "selected": true, "compatible": true}, true)
	_add_compound_state(grid, &"select_a", {"name": "A - SELECTED", "role": "Committed choice", "playstyle": "Selection stays on A", "selected": true})
	_add_compound_state(grid, &"preview_b", {"name": "B - PREVIEW", "role": "Non-committing look", "playstyle": "Selection remains on A"}, false, true)


func _add_class_state(grid: GridContainer, state: StringName, data: Dictionary) -> void:
	var card := CLASS_CARD_SCENE.instantiate() as Control
	card.name = "State_%s" % state
	var presentation := data.duplicate(true)
	presentation["class_id"] = state
	presentation["accessibility_description"] = "%s semantic state. %s." % [String(state).replace("_", " ").capitalize(), String(data.get("playstyle", "State cue"))]
	card.call(&"present", presentation)
	if state == &"focused":
		card.call(&"show_semantic_state", &"focused")
	elif state == &"previewed":
		card.call(&"set_previewed", true)
	card.connect(&"preview_requested", _on_preview_requested)
	card.connect(&"selection_requested", _on_selection_requested)
	grid.add_child(card)
	_state_controls[state] = card


func _add_badge_state(grid: GridContainer, state: StringName, label: String) -> void:
	var badge := STATUS_BADGE_SCENE.instantiate() as Control
	badge.name = "State_%s" % state
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.call(&"present", {
		"state": state,
		"label": label,
		"accessibility_description": "%s status. %s" % [String(state).capitalize(), label],
	})
	grid.add_child(badge)
	_state_controls[state] = badge


func _add_compound_state(grid: GridContainer, compound_id: StringName, data: Dictionary, focused := false, previewed := false) -> void:
	var card := CLASS_CARD_SCENE.instantiate() as Control
	card.name = "Compound_%s" % compound_id
	var presentation := data.duplicate(true)
	presentation["class_id"] = compound_id
	presentation["accessibility_description"] = "%s compound class-card proof." % String(compound_id).replace("_", " ").capitalize()
	card.call(&"present", presentation)
	card.connect(&"preview_requested", _on_preview_requested)
	card.connect(&"selection_requested", _on_selection_requested)
	grid.add_child(card)
	if previewed:
		card.call(&"set_previewed", true)
	if focused:
		card.set_meta(&"evidence_requires_live_focus", true)
	_compound_controls[compound_id] = card


func _build_action_bar() -> void:
	_action_bar = ACTION_BAR_SCENE.instantiate() as Control
	_action_bar.name = "ActionBar"
	_action_bar.call(&"present", [
		{"id": &"inspect", "label": "Inspect State", "enabled": true, "kind": &"secondary", "accessibility_description": "Inspect the focused component state."},
		{"id": &"confirm", "label": "Confirm Proof", "enabled": true, "kind": &"primary", "accessibility_description": "Confirm the component proof."},
		{"id": &"unavailable", "label": "Future Action", "enabled": false, "kind": &"unavailable", "reason": "Not part of this slice.", "accessibility_description": "Future action unavailable. Not part of this slice."},
	])
	_action_bar.connect(&"action_requested", _on_action_requested)
	get_node("Margin/Layout/Footer").add_child(_action_bar)


func _build_prompts() -> void:
	var prompt_row := get_node("Margin/Layout/PromptRow") as HBoxContainer
	for action_id: StringName in [&"ui_accept", &"ui_cancel"]:
		var prompt := INPUT_PROMPT_SCENE.instantiate() as Control
		prompt.name = "Prompt_%s" % action_id
		prompt_row.add_child(prompt)
		_prompts.append(prompt)
	_update_prompts()


func _input(event: InputEvent) -> void:
	if _input_tracker.observe(event):
		_update_prompts()


func _update_prompts() -> void:
	for prompt: Control in _prompts:
		var action_id := StringName(String(prompt.name).trim_prefix("Prompt_"))
		var label := String(prompt.call(&"label_for_action", action_id, _input_tracker.device_kind))
		prompt.call(&"present", action_id, _input_tracker.device_kind, label)
	(get_node("Margin/Layout/Header/Device") as Label).text = "ACTIVE INPUT: %s" % String(_input_tracker.device_kind).replace("_", " ").to_upper()


func _on_action_requested(action_id: StringName) -> void:
	_action_counts[action_id] = int(_action_counts.get(action_id, 0)) + 1
	(get_node("Margin/Layout/Footer/Consumed") as Label).text = "CONSUMED: %s" % String(action_id).to_upper()


func _on_preview_requested(class_id: StringName) -> void:
	_preview_counts[class_id] = int(_preview_counts.get(class_id, 0)) + 1
	(get_node("Margin/Layout/Footer/Consumed") as Label).text = "PREVIEW CONSUMED: %s" % String(class_id).to_upper()


func _on_selection_requested(class_id: StringName) -> void:
	_selection_counts[class_id] = int(_selection_counts.get(class_id, 0)) + 1
	(get_node("Margin/Layout/Footer/Consumed") as Label).text = "SELECTION CONSUMED: %s" % String(class_id).to_upper()


func _append_signature(node: Node, output: Array[String]) -> void:
	output.append("%s|%s" % [get_path_to(node), node.get_class()])
	for child: Node in node.get_children():
		_append_signature(child, output)
