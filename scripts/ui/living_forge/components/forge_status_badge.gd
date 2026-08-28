class_name ForgeStatusBadge
extends PanelContainer

const ICON_ROOT := "res://assets/ui/living_forge/icons/tabler-3.46.0/"
const ICON_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 icon_color : source_color = vec4(1.0);
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	COLOR = vec4(icon_color.rgb, sampled.a * icon_color.a);
}
"""
const STATE_CUES := {
	&"success": {"text": "SUCCESS", "icon": "check.svg", "shape": "CHECKED HEX", "accessibility_description": "Operation succeeded."},
	&"warning": {"text": "WARNING", "icon": "alert-triangle.svg", "shape": "WARNING TRIANGLE", "accessibility_description": "Attention is required."},
	&"error": {"text": "ERROR", "icon": "alert-triangle.svg", "shape": "BROKEN HEX", "accessibility_description": "An error occurred."},
}

var _state: StringName = &"success"
var _high_contrast := false


func present(data: Dictionary) -> void:
	var state := StringName(data.get("state", &"success"))
	_state = state
	var cue: Dictionary = STATE_CUES.get(state, STATE_CUES[&"error"])
	var label := String(data.get("label", cue["text"]))
	var icon := get_node("Content/Icon") as TextureRect
	icon.texture = load(ICON_ROOT + String(cue["icon"])) as Texture2D
	var semantic_color := LivingForgeTokens.color(_color_role(), _high_contrast)
	_tint_texture(icon, semantic_color)
	var text := get_node("Content/Text") as Label
	text.text = label
	text.add_theme_color_override(&"font_color", semantic_color)
	_apply_shape_geometry(state, semantic_color)
	accessibility_description = String(data.get("accessibility_description", cue["accessibility_description"]))
	set_meta(&"semantic_state", state)


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	var semantic_color := LivingForgeTokens.color(_color_role(), high_contrast)
	_tint_texture(get_node("Content/Icon") as TextureRect, semantic_color)
	_apply_shape_geometry(_state, semantic_color)
	(get_node("Content/Text") as Label).add_theme_color_override(&"font_color", semantic_color)


func _color_role() -> StringName:
	if _state == &"success":
		return &"valid"
	if _state == &"warning":
		return &"warning"
	return &"error"


func _apply_shape_geometry(state: StringName, color: Color) -> void:
	var geometry := get_node("Content/ShapeLayer/Geometry") as Polygon2D
	geometry.color = color
	if state == &"warning":
		geometry.polygon = PackedVector2Array([Vector2(8, 0), Vector2(16, 16), Vector2(0, 16)])
	elif state == &"error":
		geometry.polygon = PackedVector2Array([Vector2(4, 0), Vector2(12, 0), Vector2(16, 6), Vector2(12, 8), Vector2(16, 12), Vector2(12, 16), Vector2(4, 16), Vector2(0, 8)])
	else:
		geometry.polygon = PackedVector2Array([Vector2(4, 0), Vector2(12, 0), Vector2(16, 8), Vector2(12, 16), Vector2(4, 16), Vector2(0, 8)])


func _tint_texture(texture_rect: TextureRect, color: Color) -> void:
	var icon_material := texture_rect.material as ShaderMaterial
	if icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		icon_material = ShaderMaterial.new()
		icon_material.shader = shader
		texture_rect.material = icon_material
	icon_material.set_shader_parameter(&"icon_color", color)
