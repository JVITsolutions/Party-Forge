class_name UpgradesLedgerPage
extends CharacterLedgerPage

var selected_upgrade_id: StringName
var _rows_by_id: Dictionary = {}
var _first_button: Button


func refresh() -> void:
	if provider == null or context == null:
		return
	_clear_rows()
	var rows := provider.upgrade_rows(context.selected_member_id)
	_empty_state().visible = rows.is_empty()
	if rows.is_empty():
		selected_upgrade_id = &""
		_clear_detail()
		return
	for row: Dictionary in rows:
		var upgrade_id := StringName(row.get("id", &""))
		if upgrade_id.is_empty() or _rows_by_id.has(upgrade_id):
			continue
		var detail := provider.upgrade_detail(row)
		var button := _create_row_button(upgrade_id, row, detail)
		_rows().add_child(button)
		_rows_by_id[upgrade_id] = row
		if _first_button == null:
			_first_button = button
	if _rows_by_id.is_empty():
		_empty_state().visible = true
		selected_upgrade_id = &""
		_clear_detail()
		return
	if not select_upgrade(selected_upgrade_id):
		select_upgrade(StringName(_first_button.get_meta("upgrade_id", &"")))


func select_upgrade(upgrade_id: StringName) -> bool:
	var row_value: Variant = _rows_by_id.get(upgrade_id)
	if row_value == null:
		return false
	var row := row_value as Dictionary
	var detail := provider.upgrade_detail(row)
	selected_upgrade_id = upgrade_id
	_set_detail_text("Title", detail.get("title", row.get("display_name", "")))
	_set_detail_text("Rank", detail.get("rank_text", row.get("rank_text", "")))
	_set_detail_text("Ownership", detail.get("ownership", row.get("ownership", "")))
	_set_detail_text("Description", detail.get("description", row.get("description", "")))
	_set_detail_text("Effects", _joined_lines(detail.get("effect_lines", [])))
	_set_detail_text("Applicability", _applicability_text(detail, row))
	_set_detail_text("Keywords", _joined_lines(detail.get("keyword_lines", [])))
	return true


func initial_focus() -> Control:
	return _first_button


func _create_row_button(
	upgrade_id: StringName,
	row: Dictionary,
	detail: Dictionary
) -> Button:
	var button := Button.new()
	button.name = "Upgrade_%s" % upgrade_id
	button.custom_minimum_size = Vector2(0.0, 76.0)
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fields := PackedStringArray([
		String(row.get("display_name", upgrade_id)),
		"%s | %s" % [row.get("rank_text", ""), row.get("ownership", "")],
	])
	var effect_lines := _string_lines(detail.get("effect_lines", []))
	if not effect_lines.is_empty():
		fields.append(effect_lines[0])
	button.text = "\n".join(fields)
	button.tooltip_text = _tooltip_text(detail, row)
	button.set_meta("upgrade_id", upgrade_id)
	button.pressed.connect(select_upgrade.bind(upgrade_id))
	button.focus_entered.connect(select_upgrade.bind(upgrade_id))
	return button


func _tooltip_text(detail: Dictionary, row: Dictionary) -> String:
	var sections := PackedStringArray()
	var description := String(detail.get("description", row.get("description", ""))).strip_edges()
	if not description.is_empty():
		sections.append(description)
	var effects := _string_lines(detail.get("effect_lines", []))
	if not effects.is_empty():
		sections.append("Effects\n%s" % "\n".join(effects))
	var applicability := _applicability_text(detail, row)
	if not applicability.is_empty():
		sections.append("Applicability\n%s" % applicability)
	var keywords := _string_lines(detail.get("keyword_lines", []))
	if not keywords.is_empty():
		sections.append("Keywords\n%s" % "\n".join(keywords))
	return "\n\n".join(sections)


func _applicability_text(detail: Dictionary, row: Dictionary) -> String:
	var lines := PackedStringArray()
	for value: Variant in [
		detail.get("applicability", row.get("applicability", "")),
		detail.get("eligibility_text", ""),
		detail.get("inheritance_text", ""),
	]:
		var line := String(value).strip_edges()
		if not line.is_empty() and line not in lines:
			lines.append(line)
	return "\n".join(lines)


func _joined_lines(values: Variant) -> String:
	return "\n".join(_string_lines(values))


func _string_lines(values: Variant) -> PackedStringArray:
	var lines := PackedStringArray()
	if values is Array or values is PackedStringArray:
		for value: Variant in values:
			lines.append(String(value))
	return lines


func _clear_rows() -> void:
	for child: Node in _rows().get_children():
		child.free()
	_rows_by_id.clear()
	_first_button = null


func _clear_detail() -> void:
	for label_name: String in [
		"Title",
		"Rank",
		"Ownership",
		"Description",
		"Effects",
		"Applicability",
		"Keywords",
	]:
		_set_detail_text(label_name, "")


func _set_detail_text(label_name: String, value: Variant) -> void:
	(_detail().get_node(label_name) as Label).text = String(value)


func _empty_state() -> Label:
	return get_node("Layout/Content/UpgradeSide/EmptyState") as Label


func _rows() -> VBoxContainer:
	return get_node("Layout/Content/UpgradeSide/UpgradeScroll/UpgradeRows") as VBoxContainer


func _detail() -> VBoxContainer:
	return get_node("Layout/Content/DetailPanel/Detail") as VBoxContainer
