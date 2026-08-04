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
		_node_visual().call(&"bind_view", null)
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
	var font_color := _font_color_for_state(_view.state)
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]:
		add_theme_color_override(color_name, font_color)
	add_theme_color_override("font_outline_color", _font_outline_color(font_color, _view.permanent))
	add_theme_constant_override("outline_size", 4 if _view.permanent else 3)
	disabled = false
	_node_visual().call(&"bind_view", _view)


func view_data() -> PassiveTreeNodeViewData:
	return _view.copy() if _view != null else null


func _on_pressed() -> void:
	if _view != null:
		node_selected.emit(_view.id)


func _node_visual() -> Control:
	return get_node("NodeVisual") as Control


func _font_color_for_state(state: StringName) -> Color:
	return Color(0.025, 0.035, 0.055, 1.0) if state in [&"allocated", &"allocatable"] else Color(0.97, 0.98, 1.0, 1.0)


func _font_outline_color(font_color: Color, permanent: bool) -> Color:
	if permanent:
		return Color(0.98, 0.72, 0.22, 1.0)
	return Color(0.92, 0.95, 1.0, 1.0) if font_color.get_luminance() < 0.5 else Color(0.025, 0.035, 0.055, 1.0)
