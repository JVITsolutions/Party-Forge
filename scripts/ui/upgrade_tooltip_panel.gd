class_name UpgradeTooltipPanel
extends PanelContainer

const EDGE_MARGIN := 16.0


func _ready() -> void:
	visible = false


func show_content(content: Dictionary, anchor: Control) -> void:
	_set_text("Content/Title", content.get("title", ""))
	_set_text("Content/Rank", content.get("rank_text", ""))
	_set_text("Content/Description", content.get("description", ""))
	_set_lines("Content/Effects", content.get("effect_lines", []))
	_set_text("Content/Eligibility", content.get("eligibility_text", ""))
	_set_text("Content/Inheritance", content.get("inheritance_text", ""))
	_set_lines("Content/Keywords", content.get("keyword_lines", []))
	visible = true
	reset_size()
	if not is_inside_tree() or not anchor.is_inside_tree():
		return
	var popup_size := size
	if popup_size.x <= 0.0 or popup_size.y <= 0.0:
		popup_size = custom_minimum_size
	global_position = clamped_position(
		anchor.get_global_rect(),
		popup_size,
		get_viewport_rect().size
	)


func hide_content() -> void:
	visible = false


static func clamped_position(
	anchor_rect: Rect2,
	popup_size: Vector2,
	viewport_size: Vector2,
	margin: float = EDGE_MARGIN
) -> Vector2:
	var right_x := anchor_rect.end.x + margin
	var left_x := anchor_rect.position.x - popup_size.x - margin
	var maximum_x := maxf(margin, viewport_size.x - popup_size.x - margin)
	var x := right_x
	if right_x + popup_size.x <= viewport_size.x - margin:
		x = right_x
	elif left_x >= margin:
		x = left_x
	else:
		x = clampf(right_x, margin, maximum_x)
	var maximum_y := maxf(margin, viewport_size.y - popup_size.y - margin)
	var y := clampf(anchor_rect.position.y, margin, maximum_y)
	return Vector2(x, y)


func _set_text(path: NodePath, value: Variant) -> void:
	var label := get_node_or_null(path) as Label
	if label != null:
		label.text = str(value)


func _set_lines(path: NodePath, values: Variant) -> void:
	var lines := PackedStringArray()
	for value: Variant in values:
		lines.append(str(value))
	_set_text(path, "\n".join(lines))
