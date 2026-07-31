class_name StatsLedgerPage
extends CharacterLedgerPage

var selected_stat_id: StringName

var _show_all := false
var _stat_buttons: Dictionary = {}
var _first_stat_button: Button

func _ready() -> void:
	_connect_show_all()

func refresh() -> void:
	_connect_show_all()
	_clear_generated_groups()
	_stat_buttons.clear()
	_first_stat_button = null
	var member := _selected_member_row()
	if member.is_empty():
		_identity().text = "No party member selected."
		_traits_and_capabilities().text = ""
		_clear_detail()
		return
	_render_header(member)
	var rows := provider.stat_rows(context.selected_member_id, _show_all)
	var current_group_id: StringName
	var current_group: VBoxContainer
	for row: Dictionary in rows:
		var group_id := row.group_id as StringName
		if current_group == null or group_id != current_group_id:
			current_group_id = group_id
			current_group = _create_group(group_id)
		var button := _create_stat_button(row)
		current_group.add_child(button)
		_stat_buttons[row.stat_id] = button
		if _first_stat_button == null:
			_first_stat_button = button
	if _stat_buttons.has(selected_stat_id):
		select_stat(selected_stat_id)
	elif _first_stat_button != null:
		select_stat(_first_stat_button.get_meta("stat_id") as StringName)
	else:
		selected_stat_id = &""
		_clear_detail()

func set_show_all(enabled: bool) -> void:
	_show_all = enabled
	var toggle := _show_all_toggle()
	if toggle.button_pressed != enabled:
		toggle.set_pressed_no_signal(enabled)
	refresh()

func select_stat(stat_id: StringName) -> bool:
	if provider == null or context == null or not _stat_buttons.has(stat_id):
		return false
	var detail := provider.stat_detail(context.selected_member_id, stat_id)
	if detail.is_empty():
		return false
	selected_stat_id = stat_id
	for button_id: Variant in _stat_buttons:
		(_stat_buttons[button_id] as Button).button_pressed = button_id == stat_id
	_detail_title().text = String(detail.get("title", "Missing definition: %s" % stat_id))
	_detail_value().text = String(detail.get("value_text", ""))
	_detail_description().text = String(detail.get("description", ""))
	_detail_cap().text = String(detail.get("cap_text", ""))
	var source_lines := PackedStringArray()
	for source: Dictionary in detail.get("sources", []):
		source_lines.append(_source_line(source))
	_detail_sources().text = "\n".join(source_lines)
	return true

func has_stat(stat_id: StringName) -> bool:
	return _stat_buttons.has(stat_id)

func initial_focus() -> Control:
	return _first_stat_button

func _connect_show_all() -> void:
	var toggle := _show_all_toggle()
	if not toggle.toggled.is_connected(set_show_all):
		toggle.toggled.connect(set_show_all)
	toggle.set_pressed_no_signal(_show_all)

func _selected_member_row() -> Dictionary:
	if provider == null or context == null:
		return {}
	for row: Dictionary in provider.member_rows():
		if int(row.member_id) == context.selected_member_id:
			return row
	return {}

func _render_header(member: Dictionary) -> void:
	var character_name := String(member.get("character_name", "")).strip_edges()
	if character_name.is_empty():
		character_name = "Member %d" % int(member.member_id)
	var health_state := ""
	if bool(member.get("is_dead", false)):
		health_state = " | Dead"
	elif bool(member.get("is_downed", false)):
		health_state = " | Downed"
	_identity().text = "%s | %s Rank %d | %s | Health %s / %s%s" % [
		character_name,
		String(member.class_name),
		int(member.class_rank),
		String(member.role_name),
		_number(float(member.health_current)),
		_number(float(member.health_maximum)),
		health_state,
	]
	_traits_and_capabilities().text = "Traits: %s | Capabilities: %s" % [
		_join_ids(member.get("traits", [])),
		_join_ids(member.get("capabilities", [])),
	]

func _create_group(group_id: StringName) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = "Group_%s" % group_id
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = String(group_id).replace("_", " ").capitalize()
	group.add_child(heading)
	_groups().add_child(group)
	return group

func _create_stat_button(row: Dictionary) -> Button:
	var stat_id := row.stat_id as StringName
	var button := Button.new()
	button.name = "Stat_%s" % stat_id
	button.text = "%s    %s" % [String(row.display_name), String(row.formatted_value)]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("stat_id", stat_id)
	var detail := provider.stat_detail(context.selected_member_id, stat_id)
	button.tooltip_text = String(detail.get("description", ""))
	button.pressed.connect(select_stat.bind(stat_id))
	button.focus_entered.connect(select_stat.bind(stat_id))
	return button

func _clear_generated_groups() -> void:
	for child: Node in _groups().get_children():
		child.free()

func _clear_detail() -> void:
	_detail_title().text = "Select a stat"
	_detail_value().text = ""
	_detail_description().text = ""
	_detail_cap().text = ""
	_detail_sources().text = ""

func _source_line(row: Dictionary) -> String:
	var operation := int(row.get("operation", -1))
	var label := str(row.get("source_label", row.get("source_id", "Unknown")))
	var value := float(row.get("value", 0.0))
	match operation:
		-1:
			return "%s: %s" % [label, _number(value)]
		StatModifier.Operation.FLAT:
			return "%s: %s flat" % [label, _signed_number(value)]
		StatModifier.Operation.INCREASED:
			return "%s: %s%% increased" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.REDUCED:
			return "%s: %s%% reduced" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.MORE:
			return "%s: %s%% more" % [label, _signed_number(value * 100.0)]
		StatModifier.Operation.LESS:
			return "%s: %s%% less" % [label, _signed_number(value * 100.0)]
		_:
			return "%s: %s" % [label, _number(value)]

func _number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.4f" % value).rstrip("0").rstrip(".")

func _signed_number(value: float) -> String:
	var prefix := "+" if value >= 0.0 else "-"
	return prefix + _number(absf(value))

func _join_ids(values: Array) -> String:
	var labels := PackedStringArray()
	for value: Variant in values:
		labels.append(String(value).replace("_", " ").capitalize())
	return ", ".join(labels) if not labels.is_empty() else "None"

func _identity() -> Label:
	return get_node("Layout/Header/Identity") as Label

func _traits_and_capabilities() -> Label:
	return get_node("Layout/Header/TraitsAndCapabilities") as Label

func _show_all_toggle() -> CheckButton:
	return get_node("Layout/Content/StatSide/ShowAll") as CheckButton

func _groups() -> VBoxContainer:
	return get_node("Layout/Content/StatSide/StatScroll/Groups") as VBoxContainer

func _detail_title() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Title") as Label

func _detail_value() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Value") as Label

func _detail_description() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Description") as Label

func _detail_cap() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Cap") as Label

func _detail_sources() -> Label:
	return get_node("Layout/Content/DetailPanel/Detail/Sources") as Label
