class_name StorageSlotButton
extends Button

signal item_dropped(source_container_id: StringName, source_slot: int, item_id: String, destination_container_id: StringName, destination_slot: int)
signal inspection_started(source: StorageSlotButton)
signal inspection_ended(source: StorageSlotButton)

const METRICS := preload("res://scripts/ui/storage/equipment_ui_metrics.gd")
const RARITY_PALETTE := preload("res://scripts/ui/storage/item_rarity_palette.gd")

var container_id: StringName
var slot := -1
var item_id := ""
var _detail: Dictionary = {}
var _selected := false
var _held := false
var _drop_target_active := false
var _drop_target_valid := false
var _mouse_inside := false
var _focus_inside := false
var _inspection_active := false
var _wired := false
var _disabled_overlay: Label


func _ready() -> void:
	_wire_inspection()
	_ensure_disabled_overlay()


func bind_item(
	container_id_value: StringName,
	slot_value: int,
	item_id_value: String,
	detail_value: Dictionary,
	empty_label: String = "",
) -> void:
	_wire_inspection()
	_ensure_disabled_overlay()
	container_id = container_id_value
	slot = slot_value
	item_id = item_id_value
	_detail = detail_value.duplicate(true)
	_selected = false
	_held = false
	_drop_target_active = false
	_drop_target_valid = false
	icon = null
	text = ""
	tooltip_text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	expand_icon = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if item_id.is_empty():
		text = empty_label
		accessibility_name = "%s empty" % empty_label if not empty_label.is_empty() else "Empty storage slot %d" % slot
	else:
		var path := String(_detail.get("icon_path", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			icon = load(path) as Texture2D
		else:
			text = "?"
		var name := String(_detail.get("name", "Unknown Item"))
		var rarity := String(_detail.get("rarity_name", "Unknown Rarity"))
		accessibility_name = "%s, %s" % [name, rarity]
		if icon == null:
			accessibility_name += ", icon unavailable"
	var is_disabled := not item_id.is_empty() and bool(_detail.get("is_disabled", false))
	_disabled_overlay.visible = is_disabled
	if is_disabled:
		var reasons := PackedStringArray()
		var value: Variant = _detail.get("disabled_requirement_lines", [])
		if value is PackedStringArray:
			reasons = (value as PackedStringArray).duplicate()
		elif value is Array:
			for reason: Variant in value as Array:
				reasons.append(String(reason))
		accessibility_name += ", Disabled"
		if not reasons.is_empty():
			accessibility_name += ", %s" % "; ".join(reasons)
	_apply_disabled_content_style(is_disabled)
	apply_viewport_size(get_viewport_rect().size if is_inside_tree() else Vector2(1920.0, 1080.0))
	_apply_style()


func detail() -> Dictionary:
	return _detail.duplicate(true)


func source_id() -> StringName:
	return StringName("%s:%d:%s" % [String(container_id), slot, item_id])


func set_selected(active: bool) -> void:
	_selected = active
	_apply_style()


func set_held(active: bool) -> void:
	_held = active
	_apply_style()


func set_drop_target(active: bool, valid: bool) -> void:
	_drop_target_active = active
	_drop_target_valid = valid
	_apply_style()


func apply_viewport_size(viewport_size: Vector2) -> void:
	var metrics: Dictionary = METRICS.for_viewport(viewport_size)
	custom_minimum_size = metrics["slot_size"] as Vector2


func _get_drag_data(_position: Vector2) -> Variant:
	if item_id.is_empty():
		return null
	var preview: Control
	if icon != null:
		var texture := TextureRect.new()
		texture.texture = icon
		texture.custom_minimum_size = Vector2(64.0, 64.0)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview = texture
	else:
		var fallback := Label.new()
		fallback.text = "?"
		fallback.custom_minimum_size = Vector2(64.0, 64.0)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview = fallback
	set_drag_preview(preview)
	return {"container_id": String(container_id), "slot": slot, "item_id": item_id}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not String((data as Dictionary).get("item_id", "")).is_empty()

func _drop_data(_position: Vector2, data: Variant) -> void:
	var source := data as Dictionary
	item_dropped.emit(StringName(String(source["container_id"])), int(source["slot"]), String(source["item_id"]), container_id, slot)


func _wire_inspection() -> void:
	if _wired:
		return
	_wired = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _ensure_disabled_overlay() -> void:
	if _disabled_overlay != null and is_instance_valid(_disabled_overlay):
		return
	_disabled_overlay = Label.new()
	_disabled_overlay.name = "DisabledOverlay"
	_disabled_overlay.text = "DISABLED"
	_disabled_overlay.visible = false
	_disabled_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disabled_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	_disabled_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disabled_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_disabled_overlay.add_theme_font_size_override("font_size", 13)
	_disabled_overlay.add_theme_color_override("font_color", Color(1.0, 0.94, 0.88))
	var warning_style := StyleBoxFlat.new()
	warning_style.bg_color = Color(0.42, 0.055, 0.025, 0.96)
	warning_style.border_color = Color(1.0, 0.48, 0.22)
	warning_style.set_border_width_all(2)
	warning_style.set_corner_radius_all(4)
	_disabled_overlay.add_theme_stylebox_override("normal", warning_style)
	_disabled_overlay.z_index = 10
	add_child(_disabled_overlay)


func _apply_disabled_content_style(disabled: bool) -> void:
	var icon_color := Color(0.62, 0.62, 0.62, 0.50) if disabled else Color.WHITE
	for theme_name: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(theme_name, icon_color)
	var text_color := Color(0.68, 0.68, 0.68) if disabled else Color(0.88, 0.90, 0.94)
	for theme_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(theme_name, text_color)


func _on_mouse_entered() -> void:
	_mouse_inside = true
	_begin_inspection()


func _on_mouse_exited() -> void:
	_mouse_inside = false
	_end_inspection_if_inactive()


func _on_focus_entered() -> void:
	_focus_inside = true
	_begin_inspection()


func _on_focus_exited() -> void:
	_focus_inside = false
	_end_inspection_if_inactive()


func _begin_inspection() -> void:
	if _inspection_active or item_id.is_empty():
		return
	_inspection_active = true
	inspection_started.emit(self)


func _end_inspection_if_inactive() -> void:
	if not _inspection_active or _mouse_inside or _focus_inside:
		return
	_inspection_active = false
	inspection_ended.emit(self)


func _apply_style() -> void:
	var border := RARITY_PALETTE.color_for(StringName(String(_detail.get("rarity_id", ""))))
	var border_width := 2
	if _selected:
		border = Color(0.40, 0.95, 0.55)
		border_width = 3
	if _held:
		border = Color(1.00, 0.72, 0.22)
		border_width = 4
	if _drop_target_active:
		border = Color(0.34, 0.70, 1.00) if _drop_target_valid else Color(1.00, 0.28, 0.28)
		border_width = 4
	add_theme_stylebox_override("normal", _style(border, border_width, Color(0.035, 0.045, 0.065, 0.96)))
	add_theme_stylebox_override("hover", _style(border.lightened(0.22), border_width + 1, Color(0.055, 0.070, 0.100, 0.98)))
	add_theme_stylebox_override("pressed", _style(border, border_width + 1, Color(0.025, 0.032, 0.050, 1.0)))
	add_theme_stylebox_override("focus", _style(Color(0.88, 0.94, 1.0), 3, Color(0.045, 0.060, 0.090, 1.0)))


func _style(border: Color, border_width: int, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style
