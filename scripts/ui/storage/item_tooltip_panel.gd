class_name ItemTooltipPanel
extends "res://scripts/ui/temporary_hover_popup.gd"

const CARD_SCRIPT := preload("res://scripts/ui/storage/item_tooltip_card.gd")
const METRICS := preload("res://scripts/ui/storage/equipment_ui_metrics.gd")
const DISMISS_GRACE_SECONDS := 0.12
const HORIZONTAL_CHROME := 44.0
const VERTICAL_CHROME := 140.0

var _detail: Dictionary = {}
var _comparisons: Array[Dictionary] = []
var _anchor: Control
var _developer_mode := false
var _compare_active := false
var _advanced_active := false
var _dismiss_grace_remaining := -1.0
var _pending_release_source := &""


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_hints().text = "Alt / LT Compare   Shift / RT Affixes   Y Pin   Right Stick Scroll"


func show_item(
	detail: Dictionary,
	comparisons: Array[Dictionary],
	anchor: Control,
	source_id: StringName,
	developer_mode: bool = false,
) -> bool:
	var changed := current_source_id() != source_id
	if not present_source(source_id):
		return false
	_dismiss_grace_remaining = -1.0
	_pending_release_source = &""
	_anchor = anchor
	if changed:
		_detail = detail.duplicate(true)
		_comparisons = comparisons.duplicate(true)
		_developer_mode = developer_mode
		_compare_active = false
		_advanced_active = false
	_rebuild_cards()
	_size_and_position()
	call_deferred(&"_deferred_size_and_position", source_id)
	return true


func release_item(source_id: StringName) -> void:
	if not is_current_source(source_id):
		return
	_pending_release_source = source_id
	_dismiss_grace_remaining = DISMISS_GRACE_SECONDS


func set_compare_active(active: bool) -> void:
	if _compare_active == active:
		return
	_compare_active = active
	if visible:
		_rebuild_cards()
		_size_and_position()
		call_deferred(&"_deferred_size_and_position", current_source_id())


func set_advanced_active(active: bool) -> void:
	if _advanced_active == active:
		return
	_advanced_active = active
	if visible:
		_rebuild_cards()
		_size_and_position()
		call_deferred(&"_deferred_size_and_position", current_source_id())


func comparison_active() -> bool:
	return _compare_active


func advanced_active() -> bool:
	return _advanced_active


func card_count() -> int:
	return _cards().get_child_count()


func pin_button_rect() -> Rect2:
	return _pin_control().get_global_rect()


func scrollbar_rect() -> Rect2:
	return _body_scroll().get_v_scroll_bar().get_global_rect()


func force_dismiss() -> void:
	super()
	_detail = {}
	_comparisons.clear()
	_anchor = null
	_developer_mode = false
	_compare_active = false
	_advanced_active = false
	_dismiss_grace_remaining = -1.0
	_pending_release_source = &""
	_clear_cards()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not visible:
		return
	if InputMap.has_action(&"tooltip_compare"):
		if event.is_action_pressed(&"tooltip_compare"):
			set_compare_active(true)
			_mark_input_handled()
			return
		if event.is_action_released(&"tooltip_compare"):
			set_compare_active(false)
			_mark_input_handled()
			return
	if InputMap.has_action(&"tooltip_advanced"):
		if event.is_action_pressed(&"tooltip_advanced"):
			set_advanced_active(true)
			_mark_input_handled()
			return
		if event.is_action_released(&"tooltip_advanced"):
			set_advanced_active(false)
			_mark_input_handled()


func _process(delta: float) -> void:
	super(delta)
	if _dismiss_grace_remaining < 0.0:
		return
	_dismiss_grace_remaining -= delta
	if _dismiss_grace_remaining > 0.0:
		return
	var released_source := _pending_release_source
	_dismiss_grace_remaining = -1.0
	_pending_release_source = &""
	if not released_source.is_empty() and is_current_source(released_source):
		release_source(released_source)


func _rebuild_cards() -> void:
	_clear_cards()
	if _detail.is_empty():
		return
	var inspected := CARD_SCRIPT.new() as Control
	_cards().add_child(inspected)
	var no_deltas: Array[Dictionary] = []
	inspected.call("present", _detail, &"inspected", _advanced_active, no_deltas, _developer_mode)
	if not _compare_active:
		return
	for comparison: Dictionary in _comparisons:
		var item: Variant = comparison.get("item", {})
		if not item is Dictionary or (item as Dictionary).is_empty():
			continue
		var deltas: Array[Dictionary] = []
		var delta_values: Variant = comparison.get("delta_lines", [])
		if delta_values is Array:
			for value: Variant in delta_values as Array:
				if value is Dictionary:
					deltas.append((value as Dictionary).duplicate(true))
		var card := CARD_SCRIPT.new() as Control
		_cards().add_child(card)
		var role := StringName("equipped:%s" % String(comparison.get("slot_id", "")))
		card.call("present", (item as Dictionary).duplicate(true), role, _advanced_active, deltas, _developer_mode)


func _size_and_position() -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	var viewport_size := _viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var metrics: Dictionary = METRICS.for_viewport(viewport_size)
	var count := maxi(1, card_count())
	var card_width := float(metrics["card_width"])
	var gap := float(metrics["card_gap"])
	_cards().add_theme_constant_override("separation", int(roundf(gap)))
	for child: Node in _cards().get_children():
		(child as Control).custom_minimum_size.x = card_width
	var group_width := card_width * count + gap * (count - 1)
	var maximum_height := float(metrics["maximum_card_height"])
	var popup_size := Vector2(group_width + HORIZONTAL_CHROME, maximum_height)
	custom_minimum_size = Vector2(popup_size.x, minf(360.0, maximum_height))
	_body_scroll().custom_minimum_size.y = maxf(220.0, maximum_height - VERTICAL_CHROME)
	size = popup_size
	var margin := float(metrics["edge_margin"])
	var anchor_rect := _anchor.get_global_rect()
	var right_x := anchor_rect.end.x + margin
	var left_x := anchor_rect.position.x - popup_size.x - margin
	var maximum_x := maxf(margin, viewport_size.x - popup_size.x - margin)
	var x := right_x if right_x + popup_size.x <= viewport_size.x - margin else left_x if left_x >= margin else clampf(right_x, margin, maximum_x)
	var maximum_y := maxf(margin, viewport_size.y - popup_size.y - margin)
	global_position = Vector2(clampf(x, margin, maximum_x), clampf(anchor_rect.position.y, margin, maximum_y))


func _deferred_size_and_position(source_id: StringName) -> void:
	if visible and is_current_source(source_id):
		_size_and_position()


func _viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	var parent_control := get_parent() as Control
	return parent_control.size if parent_control != null else Vector2.ZERO


func _clear_cards() -> void:
	if not is_instance_valid(_cards()):
		return
	for child: Node in _cards().get_children():
		child.free()


func _cards() -> HBoxContainer:
	return get_node("Layout/BodyScroll/Cards") as HBoxContainer


func _body_scroll() -> ScrollContainer:
	return get_node("Layout/BodyScroll") as ScrollContainer


func _pin_control() -> Button:
	return get_node("Layout/Header/Pin") as Button


func _input_hints() -> Label:
	return get_node("Layout/InputHints") as Label
