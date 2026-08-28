class_name ForgeInputPrompt
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
	&"focused": {"text": "ACTIVE PROMPT", "icon": "keyboard.svg", "shape": "PROMPT BRACKET", "accessibility_description": "Active input prompt."},
}

var action_id: StringName = &""
var device_kind: StringName = &"keyboard_mouse"
var raw_binding_label := ""
var _high_contrast := false


func present(next_action_id: StringName, next_device_kind: StringName, label: String) -> void:
	action_id = next_action_id
	device_kind = next_device_kind
	raw_binding_label = label
	var icon := get_node("Content/Icon") as TextureRect
	icon.texture = load(ICON_ROOT + ("device-gamepad.svg" if device_kind == &"controller" else "keyboard.svg")) as Texture2D
	_tint_texture(icon, LivingForgeTokens.color(&"focus_outline", _high_contrast))
	var action_copy := _compact_action_copy(action_id)
	(get_node("Content/Label") as Label).text = "%s — %s" % [_compact_binding_copy(action_id, device_kind, label), action_copy]
	(get_node("Content/Action") as Label).text = action_copy
	tooltip_text = "Full binding: %s" % label
	accessibility_description = "%s. %s binding: %s." % [action_copy, "Controller" if device_kind == &"controller" else "Keyboard and mouse", label]


func label_for_action(next_action_id: StringName, next_device_kind: StringName) -> String:
	return InputBindingFormatter.events_for_device(InputMap.action_get_events(next_action_id), next_device_kind == &"controller")


func _compact_binding_copy(next_action_id: StringName, next_device_kind: StringName, raw_label: String) -> String:
	if next_device_kind == &"controller":
		for event: InputEvent in InputMap.action_get_events(next_action_id):
			if event is InputEventJoypadButton:
				match (event as InputEventJoypadButton).button_index:
					JOY_BUTTON_A: return "A"
					JOY_BUTTON_B: return "B"
					JOY_BUTTON_X: return "X"
					JOY_BUTTON_Y: return "Y"
					_: return "Button %d" % (event as InputEventJoypadButton).button_index
	var first_binding := raw_label.split(" / ", false, 1)[0].strip_edges()
	return "Unbound" if first_binding == InputBindingFormatter.MISSING_BINDING else first_binding


func _compact_action_copy(next_action_id: StringName) -> String:
	var normalized := String(next_action_id).to_lower()
	if normalized == "ui_accept" or normalized.ends_with("select") or normalized.ends_with("accept"):
		return "Select"
	if normalized == "ui_cancel" or normalized.ends_with("back") or normalized.ends_with("cancel"):
		return "Back"
	for prefix: String in ["living_forge_", "ui_"]:
		if normalized.begins_with(prefix):
			normalized = normalized.trim_prefix(prefix)
	return normalized.replace("_", " ").capitalize()


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_tint_texture(get_node("Content/Icon") as TextureRect, LivingForgeTokens.color(&"focus_outline", high_contrast))


func _tint_texture(texture_rect: TextureRect, color: Color) -> void:
	var icon_material := texture_rect.material as ShaderMaterial
	if icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		icon_material = ShaderMaterial.new()
		icon_material.shader = shader
		texture_rect.material = icon_material
	icon_material.set_shader_parameter(&"icon_color", color)
