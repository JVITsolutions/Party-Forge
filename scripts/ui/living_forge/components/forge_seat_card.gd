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


func present(data: Dictionary) -> void:
	var seat_number := int(data.get("seat_number", 1))
	var available := bool(data.get("available", seat_number == 1))
	(get_node("Content/Seat") as Label).text = "PLAYER %d" % seat_number
	var identity := get_node("Content/Identity") as Label
	identity.text = String(data.get("profile_name", "Awaiting profile" if available else "Future local player"))
	var ready := get_node("Content/Ready") as Label
	ready.text = String(data.get("status", "READY"))
	ready.visible = available
	var future_plate := get_node("Content/FuturePlate") as Control
	var availability := get_node("Content/FuturePlate/Row/Availability") as Label
	availability.text = COMING_SOON_COPY
	future_plate.visible = not available
	_apply_lock_icon_tint()
	var default_description := "Player %d seat." % seat_number if available else "Player %d. Local co-op Coming Soon. Unavailable." % seat_number
	accessibility_description = String(data.get("accessibility_description", default_description))
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_apply_lock_icon_tint()


func _apply_lock_icon_tint() -> void:
	var lock_icon := get_node("Content/FuturePlate/Row/LockShape") as TextureRect
	var icon_material := lock_icon.material as ShaderMaterial
	if icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		icon_material = ShaderMaterial.new()
		icon_material.shader = shader
		lock_icon.material = icon_material
	icon_material.set_shader_parameter(&"icon_color", LivingForgeTokens.color(LOCK_ICON_COLOR_ROLE, _high_contrast))
