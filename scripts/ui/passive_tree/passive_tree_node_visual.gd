class_name PassiveTreeNodeVisual
extends Control

const CIRCLE_RADIUS_RATIO := 0.48

var _view: PassiveTreeNodeViewData


func bind_view(view: PassiveTreeNodeViewData) -> void:
	_view = view.copy() if view != null else null
	queue_redraw()


func _draw() -> void:
	if _view == null:
		return
	var center := size * 0.5
	var radius := circle_radius_for_size(size)
	var fill := state_color(_view.state)
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


func circle_radius_for_size(node_size: Vector2) -> float:
	return maxf(10.0, minf(node_size.x, node_size.y) * CIRCLE_RADIUS_RATIO)


func _outline_color() -> Color:
	return Color(0.98, 0.72, 0.22, 1.0) if _view != null and _view.permanent else Color(0.88, 0.9, 1.0)


static func state_color(state: StringName) -> Color:
	match state:
		&"allocated":
			return Color(0.18, 0.72, 0.48, 0.95)
		&"allocatable":
			return Color(0.2, 0.48, 0.88, 0.95)
		&"obscured":
			return Color(0.12, 0.14, 0.2, 0.98)
		_:
			return Color(0.32, 0.34, 0.42, 0.95)
