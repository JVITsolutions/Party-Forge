class_name UpgradeTooltipPanel
extends PanelContainer

const EDGE_MARGIN := 16.0
const MAXIMUM_POPUP_HEIGHT := 680.0
const CONTENT_PADDING_ALLOWANCE := 32.0


func _ready() -> void:
	visible = false


func show_content(content: Dictionary, anchor: Control) -> void:
	_set_text("Content/Title", content.get("title", ""))
	_set_text("Content/Rank", content.get("rank_text", ""))
	_set_text("Content/BodyScroll/Body/Description", content.get("description", ""))
	_set_lines("Content/BodyScroll/Body/Effects", content.get("effect_lines", []))
	_set_text("Content/BodyScroll/Body/Eligibility", content.get("eligibility_text", ""))
	_set_text("Content/BodyScroll/Body/Inheritance", content.get("inheritance_text", ""))
	_set_lines("Content/BodyScroll/Body/Keywords", content.get("keyword_lines", []))
	visible = true
	if is_inside_tree():
		reset_size()
	var viewport_size := _viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		size = custom_minimum_size
		return
	var available_height := maxf(0.0, viewport_size.y - EDGE_MARGIN * 2.0)
	var maximum_height := minf(MAXIMUM_POPUP_HEIGHT, available_height)
	var minimum_height := minf(custom_minimum_size.y, maximum_height)
	var body := get_node("Content/BodyScroll/Body") as Control
	var title := get_node("Content/Title") as Control
	var rank := get_node("Content/Rank") as Control
	var preferred_height := (
		body.get_combined_minimum_size().y
		+ title.get_combined_minimum_size().y
		+ rank.get_combined_minimum_size().y
		+ CONTENT_PADDING_ALLOWANCE
	)
	var popup_size := Vector2(
		custom_minimum_size.x,
		clampf(preferred_height, minimum_height, maximum_height)
	)
	size = popup_size
	global_position = clamped_position(
		anchor.get_global_rect(),
		popup_size,
		viewport_size
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
	x = clampf(x, margin, maximum_x)
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


func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	var parent_control := get_parent() as Control
	return parent_control.size if parent_control != null else Vector2.ZERO
