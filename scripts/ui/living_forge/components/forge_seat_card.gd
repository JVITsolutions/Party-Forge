class_name ForgeSeatCard
extends PanelContainer

const COMING_SOON_COPY := "LOCAL CO-OP - COMING SOON"
const LOCK_ICON_COLOR_ROLE := &"disabled"
const ICON_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 icon_color : source_color = vec4(1.0);
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	COLOR = vec4(icon_color.rgb, sampled.a * icon_color.a);
}
"""
const STATE_CUES := {
	&"locked": {"text": "COMING SOON", "icon": "lock.svg", "shape": "future plate", "accessibility_description": "Seat locked for a future feature."},
	&"disabled": {"text": "UNAVAILABLE", "icon": "lock.svg", "shape": "future plate", "accessibility_description": "Seat unavailable."},
}

var _high_contrast := false
var _available := false
var _seat_number := 1
var _base_status := "READY"
var _base_accessibility_description := "Player seat."
var _compact_presentation := false
var _future_row: HBoxContainer
var _lock_shape: TextureRect
var _availability: Label
var _compact_future_stack: VBoxContainer


func present(data: Dictionary) -> void:
	_ensure_future_nodes()
	var seat_number := int(data.get("seat_number", 1))
	_seat_number = seat_number
	var available := bool(data.get("available", seat_number == 1))
	_available = available
	(get_node("Content/Seat") as Label).text = "PLAYER %d" % seat_number
	var identity := get_node("Content/Identity") as Label
	identity.text = String(data.get("profile_name", "Awaiting profile" if available else "Future local player"))
	var ready := get_node("Content/Ready") as Label
	_base_status = String(data.get("status", "READY"))
	ready.text = _base_status
	ready.visible = available
	var future_plate := get_node("Content/FuturePlate") as Control
	_availability.text = COMING_SOON_COPY
	future_plate.visible = not available
	_apply_lock_icon_tint()
	var default_description := "Player %d seat." % seat_number if available else "Player %d. Local co-op Coming Soon. Unavailable." % seat_number
	_base_accessibility_description = String(data.get("accessibility_description", default_description))
	accessibility_description = _base_accessibility_description
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_compact_presentation()


func present_prompt_device(device_kind: StringName, compact: bool) -> void:
	if not _available:
		return
	var controller := device_kind == ActiveInputDevice.CONTROLLER
	var prompt_copy := "GAMEPAD" if controller else ("K+M" if compact else "KEYBOARD + MOUSE")
	(get_node("Content/Ready") as Label).text = "%s · %s%s" % [_base_status, "" if compact else "PROMPTS: ", prompt_copy]
	var style_copy := "gamepad" if controller else "keyboard and mouse"
	accessibility_description = "%s Current prompt style is %s. No controller is assigned." % [_base_accessibility_description, style_copy]


func set_compact_presentation(enabled: bool) -> void:
	_compact_presentation = enabled
	_apply_compact_presentation()


func _apply_compact_presentation() -> void:
	_ensure_future_nodes()
	var seat := get_node("Content/Seat") as Label
	var identity := get_node("Content/Identity") as Label
	var future_plate := get_node("Content/FuturePlate") as PanelContainer
	seat.text = "P%d" % _seat_number if _compact_presentation else "PLAYER %d" % _seat_number
	identity.visible = _available or not _compact_presentation
	_lock_shape.visible = true
	_availability.visible = true
	_availability.text = COMING_SOON_COPY
	remove_theme_stylebox_override(&"panel")
	future_plate.remove_theme_stylebox_override(&"panel")
	if not _compact_presentation:
		_restore_desktop_future_row()
		return
	if not _available:
		_use_compact_future_stack(future_plate)
	var card_style := get_theme_stylebox(&"panel").duplicate() as StyleBox
	card_style.content_margin_left = 12.0
	card_style.content_margin_top = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_bottom = 12.0
	add_theme_stylebox_override(&"panel", card_style)
	var future_style := future_plate.get_theme_stylebox(&"panel").duplicate() as StyleBox
	future_style.content_margin_left = 8.0
	future_style.content_margin_top = 8.0
	future_style.content_margin_right = 8.0
	future_style.content_margin_bottom = 8.0
	future_plate.add_theme_stylebox_override(&"panel", future_style)


func _ensure_future_nodes() -> void:
	if _future_row != null:
		return
	_future_row = get_node("Content/FuturePlate/Row") as HBoxContainer
	_lock_shape = _future_row.get_node("LockShape") as TextureRect
	_availability = _future_row.get_node("Availability") as Label


func _use_compact_future_stack(future_plate: PanelContainer) -> void:
	if _compact_future_stack == null:
		_compact_future_stack = VBoxContainer.new()
		_compact_future_stack.name = "CompactFutureStack"
		_compact_future_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_compact_future_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_compact_future_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_compact_future_stack.add_theme_constant_override(&"separation", 4)
		future_plate.add_child(_compact_future_stack)
		_compact_future_stack.owner = self
		_lock_shape.owner = null
		_availability.owner = null
		_lock_shape.reparent(_compact_future_stack)
		_availability.reparent(_compact_future_stack)
		_lock_shape.owner = self
		_availability.owner = self
	_future_row.visible = false
	_compact_future_stack.visible = true
	_lock_shape.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_availability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_availability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_availability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _restore_desktop_future_row() -> void:
	if _compact_future_stack == null:
		_future_row.visible = true
		return
	_lock_shape.owner = null
	_availability.owner = null
	_lock_shape.reparent(_future_row)
	_availability.reparent(_future_row)
	_lock_shape.owner = self
	_availability.owner = self
	_compact_future_stack.get_parent().remove_child(_compact_future_stack)
	_compact_future_stack.free()
	_compact_future_stack = null
	_future_row.move_child(_lock_shape, 0)
	_future_row.move_child(_availability, 1)
	_future_row.visible = true
	_lock_shape.size_flags_horizontal = Control.SIZE_FILL
	_availability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_availability.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_availability.autowrap_mode = TextServer.AUTOWRAP_OFF


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_apply_lock_icon_tint()


func _apply_lock_icon_tint() -> void:
	_ensure_future_nodes()
	var icon_material := _lock_shape.material as ShaderMaterial
	if icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		icon_material = ShaderMaterial.new()
		icon_material.shader = shader
		_lock_shape.material = icon_material
	icon_material.set_shader_parameter(&"icon_color", LivingForgeTokens.color(LOCK_ICON_COLOR_ROLE, _high_contrast))
