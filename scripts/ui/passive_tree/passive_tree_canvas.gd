class_name PassiveTreeCanvas
extends Control

signal selection_changed(node_id: StringName)

const NODE_SCENE: PackedScene = preload("res://scenes/ui/passive_tree/passive_tree_node_control.tscn")
const MIN_ZOOM := 0.45
const MAX_ZOOM := 2.25

var _views: Dictionary = {}
var _connections: Array[Dictionary] = []
var _controls: Dictionary = {}
var _selected_id: StringName
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if not resized.is_connected(_layout_nodes):
		resized.connect(_layout_nodes)


func rebuild(node_views: Array, connections: Array) -> void:
	for child: Node in get_children():
		child.free()
	_views.clear()
	_controls.clear()
	_connections.clear()
	_selected_id = &""
	var copies: Array[PassiveTreeNodeViewData] = []
	for value: Variant in node_views:
		var view := value as PassiveTreeNodeViewData
		if view != null and not _views.has(view.id):
			copies.append(view.copy())
	copies.sort_custom(func(left: PassiveTreeNodeViewData, right: PassiveTreeNodeViewData) -> bool: return String(left.id) < String(right.id))
	for view: PassiveTreeNodeViewData in copies:
		_views[view.id] = view
		var node_control := NODE_SCENE.instantiate() as PassiveTreeNodeControl
		node_control.name = "Node_%s" % String(view.id).validate_node_name()
		node_control.bind_view(view)
		node_control.node_selected.connect(select_node)
		add_child(node_control)
		_controls[view.id] = node_control
	for value: Variant in connections:
		if value is Dictionary:
			_connections.append(PassiveTreeNodeViewData.value_only_copy(value) as Dictionary)
	_connections.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	_layout_nodes()
	queue_redraw()


func node_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for value: Variant in _views.keys():
		ids.append(value as StringName)
	ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return ids


func node_view(node_id: StringName) -> PassiveTreeNodeViewData:
	var view := _views.get(node_id) as PassiveTreeNodeViewData
	return view.copy() if view != null else null


func node_control(node_id: StringName) -> PassiveTreeNodeControl:
	return _controls.get(node_id) as PassiveTreeNodeControl


func connection_views() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection: Dictionary in _connections:
		result.append(PassiveTreeNodeViewData.value_only_copy(connection) as Dictionary)
	return result


func selected_node_id() -> StringName:
	return _selected_id


func select_node(node_id: StringName) -> bool:
	var control := _controls.get(node_id) as PassiveTreeNodeControl
	if control == null:
		return false
	for value: Variant in _controls.values():
		(value as BaseButton).button_pressed = value == control
	_selected_id = node_id
	if control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
	selection_changed.emit(node_id)
	return true


func select_connected(direction: Vector2) -> bool:
	if direction.is_zero_approx() or _selected_id.is_empty() or not _views.has(_selected_id):
		return false
	var origin := (_views[_selected_id] as PassiveTreeNodeViewData).position
	var requested := direction.normalized()
	var best_id: StringName
	var best_dot := -INF
	var best_distance := INF
	for candidate_id: StringName in _connected_ids(_selected_id):
		var offset := (_views[candidate_id] as PassiveTreeNodeViewData).position - origin
		if offset.is_zero_approx():
			continue
		var alignment := offset.normalized().dot(requested)
		if alignment <= 0.0:
			continue
		var distance := offset.length_squared()
		if alignment > best_dot + 0.000001 or (is_equal_approx(alignment, best_dot) and (distance < best_distance - 0.000001 or (is_equal_approx(distance, best_distance) and String(candidate_id) < String(best_id)))):
			best_id = candidate_id
			best_dot = alignment
			best_distance = distance
	return not best_id.is_empty() and select_node(best_id)


func set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_layout_nodes()
	queue_redraw()


func zoom_value() -> float:
	return _zoom


func set_pan(value: Vector2) -> void:
	_pan = value
	_layout_nodes()
	queue_redraw()


func pan_value() -> Vector2:
	return _pan


func _connected_ids(node_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for connection: Dictionary in _connections:
		var from_id := StringName(connection.get("from_id", ""))
		var to_id := StringName(connection.get("to_id", ""))
		var candidate := to_id if from_id == node_id else (from_id if to_id == node_id else &"")
		if not candidate.is_empty() and _views.has(candidate) and candidate not in ids:
			ids.append(candidate)
	return ids


func _layout_nodes() -> void:
	for node_id: StringName in _controls:
		var control := _controls[node_id] as Control
		var view := _views[node_id] as PassiveTreeNodeViewData
		control.size = control.custom_minimum_size
		control.position = _project(view.position) - control.size * 0.5


func _project(position: Vector2) -> Vector2:
	return size * 0.5 + _pan + position * _zoom


func _draw() -> void:
	for connection: Dictionary in _connections:
		var from_view := _views.get(StringName(connection.get("from_id", ""))) as PassiveTreeNodeViewData
		var to_view := _views.get(StringName(connection.get("to_id", ""))) as PassiveTreeNodeViewData
		if from_view != null and to_view != null:
			draw_line(_project(from_view.position), _project(to_view.position), Color(0.38, 0.48, 0.68, 0.9), 4.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_MIDDLE or button_event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button_event.pressed
			accept_event()
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(_zoom * 1.1)
			accept_event()
		elif button_event.pressed and button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(_zoom / 1.1)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		set_pan(_pan + (event as InputEventMouseMotion).relative)
		accept_event()
