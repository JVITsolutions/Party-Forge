class_name ControlsSettingsPage
extends MarginContainer

const ACTION_GROUPS := [
	{
		"name": "Gameplay",
		"actions": [
			{"id": &"move_left", "label": "Move Left"},
			{"id": &"move_right", "label": "Move Right"},
			{"id": &"move_forward", "label": "Move Forward"},
			{"id": &"move_back", "label": "Move Back"},
		],
	},
	{
		"name": "Menus",
		"actions": [
			{"id": &"pause_menu", "label": "Pause Menu"},
			{"id": &"settings_previous_tab", "label": "Previous Settings Tab"},
			{"id": &"settings_next_tab", "label": "Next Settings Tab"},
		],
	},
	{
		"name": "Character Ledger",
		"actions": [
			{"id": &"character_ledger", "label": "Open Character Ledger"},
			{"id": &"ledger_previous_page", "label": "Previous Ledger Page"},
			{"id": &"ledger_next_page", "label": "Next Ledger Page"},
		],
	},
]

var _rows: Dictionary = {}


func _ready() -> void:
	refresh_bindings()


func refresh_bindings() -> void:
	var groups := get_node("Layout/Scroll/Groups") as VBoxContainer
	for child: Node in groups.get_children():
		child.free()
	_rows.clear()
	for group_data: Dictionary in ACTION_GROUPS:
		_build_group(groups, group_data)


func row_for(action_id: StringName) -> Dictionary:
	var row := _rows.get(action_id, {}) as Dictionary
	return row.duplicate(true)


func _build_group(parent: VBoxContainer, group_data: Dictionary) -> void:
	var group := VBoxContainer.new()
	group.name = StringName("Group_%s" % String(group_data.name).to_snake_case())
	group.add_theme_constant_override("separation", 6)
	parent.add_child(group)

	var heading := Label.new()
	heading.name = &"Heading"
	heading.text = String(group_data.name)
	heading.add_theme_font_size_override("font_size", 24)
	group.add_child(heading)

	var header := GridContainer.new()
	header.name = &"Header"
	header.columns = 3
	group.add_child(header)
	_add_cell(header, "Action", &"Action", 260.0)
	_add_cell(header, "Keyboard / Mouse", &"Keyboard", 320.0)
	_add_cell(header, "Controller", &"Controller", 320.0)

	var rows := VBoxContainer.new()
	rows.name = &"Rows"
	rows.add_theme_constant_override("separation", 4)
	group.add_child(rows)
	for action_data: Dictionary in group_data.actions:
		_build_row(rows, action_data)


func _build_row(parent: VBoxContainer, action_data: Dictionary) -> void:
	var action_id := StringName(action_data.id)
	var events := InputMap.action_get_events(action_id)
	var keyboard_text := InputBindingFormatter.events_for_device(events, false)
	var controller_text := InputBindingFormatter.events_for_device(events, true)
	var keyboard_missing := keyboard_text == InputBindingFormatter.MISSING_BINDING
	var controller_missing := controller_text == InputBindingFormatter.MISSING_BINDING

	var row := GridContainer.new()
	row.name = StringName("Row_%s" % action_id)
	row.columns = 3
	parent.add_child(row)
	_add_cell(row, String(action_data.label), &"Action", 260.0)
	var keyboard := _add_cell(row, keyboard_text, &"Keyboard", 320.0)
	var controller := _add_cell(row, controller_text, &"Controller", 320.0)
	if keyboard_missing:
		keyboard.tooltip_text = "Warning: No keyboard or mouse binding exists in InputMap."
	if controller_missing:
		controller.tooltip_text = "Warning: No controller binding exists in InputMap."

	_rows[action_id] = {
		"action_id": action_id,
		"keyboard_text": keyboard_text,
		"controller_text": controller_text,
		"missing_binding": keyboard_missing or controller_missing,
	}


func _add_cell(parent: GridContainer, text: String, node_name: StringName, minimum_width: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.custom_minimum_size.x = minimum_width
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
