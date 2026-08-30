class_name MainMenuScreen
extends CanvasLayer

signal route_requested(route_id: StringName)
signal cancel_requested

var _projection := MainMenuProjection.new()
var _pending_preferred_focus: Control
var _last_route_origin: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_actions()
	_apply_projection()
	if visible:
		_focus_available_action(_pending_preferred_focus)
	_pending_preferred_focus = null


func present(next_projection: MainMenuProjection) -> void:
	_projection = next_projection.copy() if next_projection != null else MainMenuProjection.new()
	_apply_projection()
	if is_open() and is_inside_tree():
		var focus_owner := get_viewport().gui_get_focus_owner()
		if (focus_owner == null or is_ancestor_of(focus_owner)) and not _is_available_action(focus_owner):
			_focus_available_action()


func open(preferred_focus: Control = null) -> void:
	visible = true
	if not is_inside_tree():
		_pending_preferred_focus = preferred_focus
		return
	_pending_preferred_focus = null
	_focus_available_action(preferred_focus)


func close() -> void:
	visible = false
	_pending_preferred_focus = null
	if not is_inside_tree():
		return
	var focus_owner := get_tree().root.gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()


func is_open() -> bool:
	return visible


func projection() -> MainMenuProjection:
	return _projection.copy()

func route_origin() -> Control:
	return _last_route_origin if _last_route_origin != null and is_instance_valid(_last_route_origin) else null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"ui_cancel"):
		return
	cancel_requested.emit()
	if is_inside_tree():
		if _should_repair_menu_focus_after_cancel(get_tree().root.gui_get_focus_owner()):
			_focus_available_action()
		get_tree().root.set_input_as_handled()


func _should_repair_menu_focus_after_cancel(focus_owner: Control) -> bool:
	if not is_open():
		return false
	if focus_owner == null:
		return true
	if not is_ancestor_of(focus_owner):
		return false
	return not _is_available_action(focus_owner)


func _apply_projection() -> void:
	_configure_action(_primary_action(), _projection.primary_label, _projection.primary_visible, _projection.primary_enabled)
	_configure_action(_city_tree(), _projection.city_tree_label, _projection.city_tree_visible, _projection.city_tree_enabled)
	_configure_action(_armoury(), _projection.armoury_label, _projection.armoury_visible, _projection.armoury_enabled)
	_configure_warehouse_action(_warehouse(), _projection.warehouse_label, _warehouse_lock_badge())
	_configure_action(_city_armoury_hotspot(), "City Armoury", _projection.armoury_visible, _projection.armoury_enabled)
	_configure_warehouse_action(_city_warehouse_hotspot(), "City Warehouse", _city_warehouse_lock_badge())
	_configure_action(
		_developer_quick_start(),
		_projection.developer_quick_start_label,
		_projection.developer_quick_start_visible,
		_projection.developer_quick_start_enabled
	)
	_configure_action(_settings(), _projection.settings_label, _projection.settings_visible, _projection.settings_enabled)
	_configure_action(_quit(), _projection.quit_label, _projection.quit_visible, _projection.quit_enabled)
	_active_profile().text = _projection.active_profile_text
	_status().text = _projection.status_text
	_active_profile().accessibility_name = "Active profile"
	_active_profile().accessibility_description = "Current player profile. %s" % _projection.active_profile_text
	_city_tree().accessibility_name = _projection.city_tree_label
	_city_tree().accessibility_description = "Open the City passive tree for the active profile."
	_developer_quick_start().accessibility_name = _projection.developer_quick_start_label
	_developer_quick_start().accessibility_description = "Developer-only control. Start a test run without changing profile progress."
	# The blockout intentionally has no mandatory entrance animation. Both motion
	# preferences therefore reach a fully interactive state in the same frame.
	_backdrop().modulate = Color.WHITE
	_rebuild_focus_loop()


func _configure_action(button: Button, label: String, should_show: bool, should_enable: bool) -> void:
	button.text = label
	button.visible = should_show
	button.disabled = not should_enable
	button.focus_mode = Control.FOCUS_ALL if should_show and should_enable else Control.FOCUS_NONE


func _configure_warehouse_action(button: Button, label: String, badge: Label) -> void:
	var state := _projection.warehouse_presentation_state
	var visible_state := state != WarehousePresentationResult.State.HIDDEN
	_configure_action(button, label, visible_state, visible_state)
	var locked := state == WarehousePresentationResult.State.LOCKED
	badge.visible = visible_state and locked
	button.accessibility_name = label
	button.accessibility_description = (
		"Warehouse locked. Requires Stash Access. Select for unlock guidance."
		if locked
		else "Open permanent Warehouse storage."
	)


func _rebuild_focus_loop() -> void:
	var available: Array[Button] = []
	for button: Button in _action_buttons():
		button.focus_next = NodePath()
		button.focus_previous = NodePath()
		button.focus_neighbor_top = NodePath()
		button.focus_neighbor_bottom = NodePath()
		if button.visible and not button.disabled:
			available.append(button)
	if available.is_empty():
		return
	for index: int in range(available.size()):
		var current := available[index]
		var next := available[(index + 1) % available.size()]
		var previous := available[posmod(index - 1, available.size())]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_top = current.get_path_to(previous)


func _focus_available_action(preferred_focus: Control = null) -> void:
	var target := preferred_focus if _is_available_action(preferred_focus) else _first_available_action()
	if target != null:
		target.grab_focus()


func _first_available_action() -> Button:
	for button: Button in _action_buttons():
		if button.visible and not button.disabled:
			return button
	return null


func _is_available_action(control: Control) -> bool:
	return (
		control is Button
		and control in _action_buttons()
		and control.visible
		and not (control as Button).disabled
		and control.focus_mode != Control.FOCUS_NONE
	)


func _connect_actions() -> void:
	if not _primary_action().pressed.is_connected(_on_primary_action_pressed):
		_primary_action().pressed.connect(_on_primary_action_pressed)
	if not _city_tree().pressed.is_connected(_on_city_tree_pressed):
		_city_tree().pressed.connect(_on_city_tree_pressed)
	if not _developer_quick_start().pressed.is_connected(_on_developer_quick_start_pressed):
		_developer_quick_start().pressed.connect(_on_developer_quick_start_pressed)
	if not _armoury().pressed.is_connected(_on_armoury_pressed): _armoury().pressed.connect(_on_armoury_pressed)
	if not _warehouse().pressed.is_connected(_on_warehouse_pressed): _warehouse().pressed.connect(_on_warehouse_pressed)
	if not _city_armoury_hotspot().pressed.is_connected(_on_city_armoury_hotspot_pressed): _city_armoury_hotspot().pressed.connect(_on_city_armoury_hotspot_pressed)
	if not _city_warehouse_hotspot().pressed.is_connected(_on_city_warehouse_hotspot_pressed): _city_warehouse_hotspot().pressed.connect(_on_city_warehouse_hotspot_pressed)
	if not _settings().pressed.is_connected(_on_settings_pressed):
		_settings().pressed.connect(_on_settings_pressed)
	if not _quit().pressed.is_connected(_on_quit_pressed):
		_quit().pressed.connect(_on_quit_pressed)


func _on_primary_action_pressed() -> void:
	_emit_route(_projection.primary_route_id, _primary_action())


func _on_city_tree_pressed() -> void:
	_emit_route(_projection.city_tree_route_id, _city_tree())


func _on_developer_quick_start_pressed() -> void:
	_emit_route(_projection.developer_quick_start_route_id, _developer_quick_start())

func _on_armoury_pressed() -> void: _emit_route(_projection.armoury_route_id, _armoury())
func _on_warehouse_pressed() -> void: _emit_route(_projection.warehouse_route_id, _warehouse())
func _on_city_armoury_hotspot_pressed() -> void: _emit_route(_projection.armoury_route_id, _city_armoury_hotspot())
func _on_city_warehouse_hotspot_pressed() -> void: _emit_route(_projection.warehouse_route_id, _city_warehouse_hotspot())


func _on_settings_pressed() -> void:
	_emit_route(_projection.settings_route_id, _settings())


func _on_quit_pressed() -> void:
	_emit_route(_projection.quit_route_id, _quit())


func _emit_route(route_id: StringName, origin: Control = null) -> void:
	if route_id != &"":
		_last_route_origin = origin
		route_requested.emit(route_id)


func _action_buttons() -> Array[Button]:
	return [_primary_action(), _city_tree(), _armoury(), _warehouse(), _developer_quick_start(), _settings(), _quit(), _city_armoury_hotspot(), _city_warehouse_hotspot()]


func _backdrop() -> Control:
	return get_node("Backdrop") as Control


func _active_profile() -> Label:
	return get_node("ActiveProfile") as Label


func _primary_action() -> Button:
	return get_node("PrimaryAction") as Button


func _city_tree() -> Button:
	return get_node("CityTree") as Button

func _armoury() -> Button: return get_node("Armoury") as Button
func _warehouse() -> Button: return get_node("Warehouse") as Button
func _warehouse_lock_badge() -> Label: return get_node("Warehouse/LockBadge") as Label
func _city_armoury_hotspot() -> Button: return get_node("CityArmouryHotspot") as Button
func _city_warehouse_hotspot() -> Button: return get_node("CityWarehouseHotspot") as Button
func _city_warehouse_lock_badge() -> Label: return get_node("CityWarehouseHotspot/LockBadge") as Label


func _developer_quick_start() -> Button:
	return get_node("DeveloperQuickStart") as Button


func _settings() -> Button:
	return get_node("Settings") as Button


func _quit() -> Button:
	return get_node("Quit") as Button


func _status() -> Label:
	return get_node("Status") as Label
