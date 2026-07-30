class_name UpgradeRecipientPicker
extends Control

signal recipient_selected(choice: UpgradeChoice, member_id: int)
signal cancelled

var _choice: UpgradeChoice


func _ready() -> void:
	var cancel := get_node("Content/Cancel") as Button
	if not cancel.pressed.is_connected(_on_cancelled):
		cancel.pressed.connect(_on_cancelled)


func show_for(choice: UpgradeChoice, recipient_rows: Array[Dictionary]) -> void:
	_choice = choice
	visible = true
	var rows := get_node("Content/RecipientsScroll/Rows") as VBoxContainer
	for child: Node in rows.get_children():
		rows.remove_child(child)
		child.free()
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
		button.disabled = not bool(row.get("eligible", false))
		button.tooltip_text = String(row.get("disabled_reason", ""))
		if not button.disabled:
			button.pressed.connect(_on_recipient_pressed.bind(choice, member_id))
		rows.add_child(button)


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


func _on_recipient_pressed(choice: UpgradeChoice, member_id: int) -> void:
	if choice == _choice:
		recipient_selected.emit(choice, member_id)


func _on_cancelled() -> void:
	cancelled.emit()
