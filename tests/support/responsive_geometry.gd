extends RefCounted

const EPSILON := 0.01


static func control_rect(control: Control, parent_rect: Rect2) -> Rect2:
	var top_left := parent_rect.position + Vector2(
		parent_rect.size.x * control.anchor_left + control.offset_left,
		parent_rect.size.y * control.anchor_top + control.offset_top,
	)
	var bottom_right := parent_rect.position + Vector2(
		parent_rect.size.x * control.anchor_right + control.offset_right,
		parent_rect.size.y * control.anchor_bottom + control.offset_bottom,
	)
	return Rect2(top_left, bottom_right - top_left)


static func contains(outer: Rect2, inner: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x - EPSILON
		and inner.position.y >= outer.position.y - EPSILON
		and inner.end.x <= outer.end.x + EPSILON
		and inner.end.y <= outer.end.y + EPSILON
	)
