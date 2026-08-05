class_name ClassSelectionPanel
extends PanelContainer

signal class_selected(class_id: StringName)
signal settings_requested
signal back_requested

var grid: GridContainer
var _pending_initial_focus: Control
var _compatibility_gate_active := false
var _compatibility_class_id: StringName

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grid()
	_ensure_actions_wired()
	_rebuild_focus_graph()
	if is_open():
		_run_status_block().visible = false
		if _should_claim_implicit_focus():
			_focus_initial()

func configure(definitions: Array[ClassDefinition]) -> void:
	var should_claim_focus := is_open() and _should_claim_implicit_focus()
	var target_grid := _grid()
	for child: Node in target_grid.get_children():
		target_grid.remove_child(child)
		child.free()
	for definition: ClassDefinition in definitions:
		if definition == null:
			continue
		var button := Button.new()
		button.name = "Class_%s" % definition.id
		button.text = "%s\n%s" % [definition.display_name, _role_label(definition.role)]
		button.custom_minimum_size = Vector2(220.0, 72.0)
		button.add_theme_color_override("font_color", definition.color)
		button.add_theme_color_override("font_hover_color", definition.color.lightened(0.2))
		button.pressed.connect(_emit_selection.bind(definition.id))
		target_grid.add_child(button)
	_rebuild_focus_graph()
	if should_claim_focus:
		_focus_initial()

func open() -> void:
	_run_status_block().visible = false
	visible = true
	_rebuild_focus_graph()
	_focus_initial()

func close() -> void:
	visible = false
	_pending_initial_focus = null
	_compatibility_gate_active = false
	_compatibility_class_id = &""
	if not is_inside_tree():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()

func is_open() -> bool:
	return visible

func confirm_run_started() -> void:
	close()
	_run_status_block().visible = true

func begin_compatibility_gate(class_id: StringName) -> Control:
	_compatibility_gate_active = true
	_compatibility_class_id = class_id
	return selection_focus(class_id)

func end_compatibility_gate(restore_focus := true) -> void:
	var target := selection_focus(_compatibility_class_id)
	_compatibility_gate_active = false
	_compatibility_class_id = &""
	if restore_focus and target != null:
		_pending_initial_focus = target
		if target.is_inside_tree() and target.is_visible_in_tree():
			target.grab_focus()
			_pending_initial_focus = null

func compatibility_gate_active() -> bool:
	return _compatibility_gate_active

func selection_focus(class_id: StringName) -> Control:
	return _grid().get_node_or_null("Class_%s" % class_id) as Control

func show_status(message: String) -> void:
	var status := _status_label()
	status.text = message
	status.visible = not message.strip_edges().is_empty()

func clear_status() -> void:
	show_status("")

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"ui_cancel"):
		return
	back_requested.emit()
	if is_inside_tree():
		get_viewport().set_input_as_handled()

func _grid() -> GridContainer:
	if grid == null:
		grid = get_node("Content/Scroll/Grid") as GridContainer
	return grid

func _emit_selection(class_id: StringName) -> void:
	if _compatibility_gate_active:
		return
	class_selected.emit(class_id)

func _emit_settings_requested() -> void:
	settings_requested.emit()

func _emit_back_requested() -> void:
	back_requested.emit()

func _ensure_actions_wired() -> void:
	var settings := get_node_or_null("Content/Actions/Settings") as Button
	if settings != null and not settings.pressed.is_connected(_emit_settings_requested):
		settings.pressed.connect(_emit_settings_requested)
	var back := get_node_or_null("Content/Actions/Back") as Button
	if back != null and not back.pressed.is_connected(_emit_back_requested):
		back.pressed.connect(_emit_back_requested)

func _rebuild_focus_graph() -> void:
	var controls := _focus_controls()
	var available: Array[Button] = []
	for control: Button in controls:
		control.focus_next = NodePath()
		control.focus_previous = NodePath()
		control.focus_neighbor_left = NodePath()
		control.focus_neighbor_right = NodePath()
		control.focus_neighbor_top = NodePath()
		control.focus_neighbor_bottom = NodePath()
		control.focus_mode = Control.FOCUS_ALL if control.visible and not control.disabled else Control.FOCUS_NONE
		if control.focus_mode == Control.FOCUS_ALL:
			available.append(control)
	if available.is_empty():
		return
	for index: int in range(available.size()):
		var current := available[index]
		current.focus_next = current.get_path_to(available[(index + 1) % available.size()])
		current.focus_previous = current.get_path_to(available[posmod(index - 1, available.size())])
	_rebuild_directional_focus()

func _rebuild_directional_focus() -> void:
	var class_buttons := _eligible_class_buttons()
	var settings := get_node_or_null("Content/Actions/Settings") as Button
	var back := get_node_or_null("Content/Actions/Back") as Button
	if class_buttons.is_empty() or settings == null or back == null:
		return
	var columns := maxi(_grid().columns, 1)
	var last_row_start := floori(float(class_buttons.size() - 1) / float(columns)) * columns
	for index: int in range(class_buttons.size()):
		var button := class_buttons[index]
		var column := index % columns
		if column > 0:
			_set_focus_neighbor(button, &"focus_neighbor_left", class_buttons[index - 1])
		if column + 1 < columns and index + 1 < class_buttons.size():
			_set_focus_neighbor(button, &"focus_neighbor_right", class_buttons[index + 1])
		if index >= columns:
			_set_focus_neighbor(button, &"focus_neighbor_top", class_buttons[index - columns])
		else:
			_set_focus_neighbor(button, &"focus_neighbor_top", settings if column + 1 < columns else back)
		if index + columns < class_buttons.size():
			_set_focus_neighbor(button, &"focus_neighbor_bottom", class_buttons[index + columns])
		else:
			_set_focus_neighbor(button, &"focus_neighbor_bottom", settings if column + 1 < columns else back)
	var settings_top_index := mini(last_row_start + 1, class_buttons.size() - 1)
	var settings_bottom_index := mini(1, class_buttons.size() - 1)
	var back_bottom_index := mini(columns - 1, class_buttons.size() - 1)
	_set_focus_neighbor(settings, &"focus_neighbor_left", back)
	_set_focus_neighbor(settings, &"focus_neighbor_right", back)
	_set_focus_neighbor(settings, &"focus_neighbor_top", class_buttons[settings_top_index])
	_set_focus_neighbor(settings, &"focus_neighbor_bottom", class_buttons[settings_bottom_index])
	_set_focus_neighbor(back, &"focus_neighbor_left", settings)
	_set_focus_neighbor(back, &"focus_neighbor_right", settings)
	_set_focus_neighbor(back, &"focus_neighbor_top", class_buttons[-1])
	_set_focus_neighbor(back, &"focus_neighbor_bottom", class_buttons[back_bottom_index])

func _focus_initial() -> void:
	var target := _first_eligible_focus()
	_pending_initial_focus = target
	if target != null and target.is_inside_tree() and target.is_visible_in_tree():
		target.grab_focus()
		_pending_initial_focus = null

func _should_claim_implicit_focus() -> bool:
	if not is_inside_tree():
		return true
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	return focus_owner == null or is_ancestor_of(focus_owner)

func _first_eligible_focus() -> Button:
	for control: Button in _focus_controls():
		if control.visible and not control.disabled and control.focus_mode != Control.FOCUS_NONE:
			return control
	return null

func _focus_controls() -> Array[Button]:
	var controls: Array[Button] = []
	for child: Node in _grid().get_children():
		var button := child as Button
		if button != null:
			controls.append(button)
	var settings := get_node_or_null("Content/Actions/Settings") as Button
	if settings != null:
		controls.append(settings)
	var back := get_node_or_null("Content/Actions/Back") as Button
	if back != null:
		controls.append(back)
	return controls

func _eligible_class_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _grid().get_children():
		var button := child as Button
		if button != null and button.visible and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			buttons.append(button)
	return buttons

func _set_focus_neighbor(control: Control, property_name: StringName, target: Control) -> void:
	control.set(property_name, control.get_path_to(target))

func _run_status_block() -> Control:
	return get_node("../Margin") as Control

func _status_label() -> Label:
	var existing := get_node_or_null("Content/GateStatus") as Label
	if existing != null:
		return existing
	var status := Label.new()
	status.name = "GateStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.visible = false
	(get_node("Content") as VBoxContainer).add_child(status)
	(get_node("Content") as VBoxContainer).move_child(status, 1)
	return status

func _role_label(role: ClassDefinition.Role) -> String:
	match role:
		ClassDefinition.Role.FRONTLINE:
			return "Frontline"
		ClassDefinition.Role.MIDLINE:
			return "Midline"
		ClassDefinition.Role.BACKLINE:
			return "Backline"
		ClassDefinition.Role.SUPPORT:
			return "Support"
		_:
			return "Unknown"
