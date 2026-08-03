class_name PassiveTreeNodeControl
extends Button

signal node_selected(node_id: StringName)

const OBSCURED_NAME := "???"

var _view: PassiveTreeNodeViewData


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	flat = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func bind_view(view: PassiveTreeNodeViewData) -> void:
	_view = view.copy() if view != null else null
	if _view == null:
		text = ""
		disabled = true
		tooltip_text = ""
		queue_redraw()
		return
	if _view.state == &"obscured":
		_view.display_name = OBSCURED_NAME
		_view.description = OBSCURED_NAME
		_view.cost = -1
		_view.cost_text = "?"
		_view.effect_lines.clear()
		_view.requirement_lines.clear()
		_view.keyword_lines.clear()
		_view.metadata.clear()
		_view.permanent = false
		_view.allocated = false
		_view.allocatable = false
		_view.decision_code = &"node_obscured"
		_view.decision_message = ""
		_view.refund_policy_text = ""
		_view.development_lines.clear()
	text = _view.display_name
	if _view.state == &"obscured":
		tooltip_text = ""
	else:
		var tooltip_lines: Array[String] = [_view.description, "Refund Policy: %s" % _view.refund_policy_text]
		tooltip_lines.append_array(_view.development_lines)
		tooltip_text = "\n".join(tooltip_lines)
	add_theme_color_override("font_outline_color", Color(0.98, 0.72, 0.22, 1.0) if _view.permanent else Color(0.08, 0.1, 0.16, 1.0))
	add_theme_constant_override("outline_size", 4 if _view.permanent else 1)
	disabled = false
	queue_redraw()


func view_data() -> PassiveTreeNodeViewData:
	return _view.copy() if _view != null else null


func _on_pressed() -> void:
	if _view != null:
		node_selected.emit(_view.id)


func _draw() -> void:
	if _view == null:
		return
	var center := size * 0.5
	var radius := maxf(10.0, minf(size.x, size.y) * 0.42)
	var fill := _state_color(_view.state)
	if _view.type in [&"keystone", &"start"]:
		var points := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(points, fill)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), _outline_color(), 4.0 if _view.permanent else 3.0, true)
	else:
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 32, _outline_color(), 4.0 if _view.permanent else 3.0, true)


func _outline_color() -> Color:
	return Color(0.98, 0.72, 0.22, 1.0) if _view != null and _view.permanent else Color(0.88, 0.9, 1.0)


func _state_color(state: StringName) -> Color:
	match state:
		&"allocated":
			return Color(0.18, 0.72, 0.48, 0.95)
		&"allocatable":
			return Color(0.2, 0.48, 0.88, 0.95)
		&"obscured":
			return Color(0.12, 0.14, 0.2, 0.98)
		_:
			return Color(0.32, 0.34, 0.42, 0.95)
