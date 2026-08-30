class_name UpgradeRecipientPicker
extends Control

signal recipient_selected(choice_key: StringName, member_id: int)
signal cancelled

var _choice_key: StringName
var _recipient_buttons: Dictionary = {}
var _recipient_visibility_request_revision := 0
var _recipient_visibility_request_target_id := 0
var _interaction_enabled := false


func _ready() -> void:
	var cancel := get_node("Content/Cancel") as Button
	if not cancel.pressed.is_connected(_on_cancelled):
		cancel.pressed.connect(_on_cancelled)
	set_interaction_enabled(visible)


func show_for(choice_key: StringName, recipient_rows: Array[Dictionary]) -> void:
	_invalidate_recipient_visibility_requests()
	_choice_key = choice_key
	visible = true
	var scroll := get_node("Content/RecipientsScroll") as ScrollContainer
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().min_value)
	var rows := get_node("Content/RecipientsScroll/Rows") as VBoxContainer
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.free()
	_recipient_buttons.clear()
	var enabled_count := 0
	for row: Dictionary in recipient_rows:
		var member_id := int(row.get("member_id", 0))
		var button := Button.new()
		button.name = "Member_%d" % member_id
		button.custom_minimum_size = Vector2(0.0, 112.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.set_meta("member_id", member_id)
		button.set_meta("recipient_row", row)
		button.text = _row_text(row)
		button.accessibility_name = button.text.replace("\n", ", ")
		button.disabled = not bool(row.get("eligible", false))
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.tooltip_text = String(row.get("disabled_reason", ""))
		if not button.disabled:
			enabled_count += 1
			button.pressed.connect(_on_recipient_pressed.bind(choice_key, member_id))
			button.focus_entered.connect(_on_recipient_focused.bind(member_id))
		rows.add_child(button)
		_recipient_buttons[member_id] = button
	set_interaction_enabled(true)
	var empty_reason := get_node("Content/EmptyReason") as Label
	empty_reason.visible = enabled_count == 0
	empty_reason.text = "No eligible party member remains. Return to the offer and choose another upgrade." if enabled_count == 0 else ""
	_configure_recipient_focus_neighbors()
	var initial_focus := _first_enabled_button()
	if initial_focus == null:
		initial_focus = get_node("Content/Cancel") as Button
	if initial_focus.is_inside_tree():
		initial_focus.grab_focus()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	for button: Button in _recipient_buttons.values():
		_set_button_focus_enabled(button, enabled)
	_set_button_focus_enabled(get_node("Content/Cancel") as Button, enabled)


func _set_button_focus_enabled(button: Button, enabled: bool) -> void:
	var focusable := enabled and button.visible and not button.disabled
	if not focusable and button.has_focus():
		button.release_focus()
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE


func _configure_recipient_focus_neighbors() -> void:
	var enabled_buttons: Array[Button] = []
	for child: Node in (get_node("Content/RecipientsScroll/Rows") as VBoxContainer).get_children():
		var button := child as Button
		if button != null and button.visible and not button.disabled:
			enabled_buttons.append(button)
	var cancel := get_node("Content/Cancel") as Button
	for index: int in enabled_buttons.size():
		var button := enabled_buttons[index]
		_set_focus_neighbor(button, &"focus_neighbor_top", enabled_buttons[index - 1] if index > 0 else cancel)
		_set_focus_neighbor(button, &"focus_neighbor_bottom", enabled_buttons[index + 1] if index + 1 < enabled_buttons.size() else cancel)
	_set_focus_neighbor(cancel, &"focus_neighbor_top", enabled_buttons[-1] if not enabled_buttons.is_empty() else null)
	_set_focus_neighbor(cancel, &"focus_neighbor_bottom", enabled_buttons[0] if not enabled_buttons.is_empty() else cancel)


func _set_focus_neighbor(control: Control, property_name: StringName, target: Control) -> void:
	control.set(property_name, control.get_path_to(target) if target != null else NodePath())


func recipient_row(member_id: int) -> Dictionary:
	var button := _recipient_buttons.get(member_id) as Button
	return (button.get_meta("recipient_row", {}) as Dictionary).duplicate(true) if button != null else {}


func _first_enabled_button() -> Button:
	for child: Node in (get_node("Content/RecipientsScroll/Rows") as VBoxContainer).get_children():
		var button := child as Button
		if button != null and not button.disabled:
			return button
	return null


func _on_recipient_focused(member_id: int) -> void:
	_request_recipient_visibility(member_id)
	_ensure_recipient_visible(member_id)


func _ensure_recipient_visible(member_id: int) -> bool:
	var button := _recipient_buttons.get(member_id) as Button
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree():
		return false
	(get_node("Content/RecipientsScroll") as ScrollContainer).ensure_control_visible(button)
	return true


func _request_recipient_visibility(member_id: int) -> int:
	_recipient_visibility_request_revision += 1
	_recipient_visibility_request_target_id = member_id
	var request_revision := _recipient_visibility_request_revision
	call_deferred(&"_apply_recipient_visibility_request", member_id, request_revision)
	return request_revision


func _apply_recipient_visibility_request(member_id: int, request_revision: int) -> bool:
	if request_revision != _recipient_visibility_request_revision:
		return false
	return _ensure_recipient_visible(member_id)


func _invalidate_recipient_visibility_requests() -> void:
	_recipient_visibility_request_revision += 1
	_recipient_visibility_request_target_id = 0


func _row_text(row: Dictionary) -> String:
	var lines := PackedStringArray([
		"%s  [#%d]" % [row.get("character_name", "Unknown"), int(row.get("member_id", 0))],
		"%s · %s · Class Rank %d" % [
			row.get("class_name", "Unknown"),
			row.get("role_name", "Unknown"),
			int(row.get("class_rank", 0)),
		],
		"Health %s / %s · Upgrade Rank %d -> %d" % [
			_value_text(float(row.get("health_current", 0.0))),
			_value_text(float(row.get("health_maximum", 0.0))),
			int(row.get("current_rank", 0)),
			int(row.get("next_rank", 0)),
		],
	])
	for preview: String in row.get("preview_lines", []):
		lines.append(preview)
	var disabled_reason := String(row.get("disabled_reason", ""))
	if not disabled_reason.is_empty():
		lines.append(disabled_reason)
	return "\n".join(lines)


func _value_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.1f" % value).rstrip("0").rstrip(".")


func _on_recipient_pressed(choice_key: StringName, member_id: int) -> void:
	if choice_key == _choice_key:
		recipient_selected.emit(choice_key, member_id)


func _on_cancelled() -> void:
	cancelled.emit()
