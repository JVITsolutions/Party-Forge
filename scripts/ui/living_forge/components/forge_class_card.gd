class_name ForgeClassCard
extends Button

signal preview_requested(class_id: StringName)
signal selection_requested(class_id: StringName)

const STATE_CUES := {
	&"focused": {"text": "FOCUSED", "icon": "arrow-left.svg", "shape": "outline", "accessibility_description": "Focused class card."},
	&"previewed": {"text": "PREVIEW", "icon": "user.svg", "shape": "diamond", "accessibility_description": "Class preview shown."},
	&"selected": {"text": "SELECTED", "icon": "check.svg", "shape": "notch", "accessibility_description": "Class selected."},
	&"locked": {"text": "LOCKED", "icon": "lock.svg", "shape": "plate", "accessibility_description": "Class interaction locked."},
	&"compatible": {"text": "COMPATIBLE", "icon": "check.svg", "shape": "badge", "accessibility_description": "Selected loadout is compatible."},
	&"needs_attention": {"text": "ATTENTION", "icon": "alert-triangle.svg", "shape": "triangle", "accessibility_description": "Class requires attention."},
	&"pending": {"text": "CHECKING", "icon": "hourglass.svg", "shape": "plate", "accessibility_description": "Class request pending."},
	&"disabled": {"text": "UNAVAILABLE", "icon": "lock.svg", "shape": "plate", "accessibility_description": "Class unavailable."},
}
const ICON_ROOT := "res://assets/ui/living_forge/icons/tabler-3.46.0/"
const ICON_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 icon_color : source_color = vec4(1.0);
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	COLOR = vec4(icon_color.rgb, sampled.a * icon_color.a);
}
"""

var class_id: StringName = &""
var _previewed := false
var _focused := false
var _authored_focus_state := false
var _mouse_hovered := false
var _selected := false
var _authored_locked := false
var _interaction_locked := false
var _disabled := false
var _compatible := false
var _needs_attention := false
var _pending := false
var _base_accessibility_description := "Class card."
var _high_contrast := false


func present(data: Dictionary) -> void:
	_authored_focus_state = false
	_focused = has_focus()
	class_id = StringName(data.get("class_id", &""))
	(get_node("Content/Identity/Name") as Label).text = String(data.get("name", "Unknown Class"))
	(get_node("Content/Identity/Role") as Label).text = String(data.get("role", "Role unavailable"))
	var playstyle := get_node("Content/Identity/Playstyle") as Label
	playstyle.text = String(data.get("playstyle", ""))
	playstyle.visible = not playstyle.text.is_empty()
	_selected = bool(data.get("selected", false))
	_compatible = bool(data.get("compatible", false))
	_needs_attention = bool(data.get("needs_attention", false))
	_pending = bool(data.get("pending", false))
	_disabled = bool(data.get("disabled", false))
	_authored_locked = bool(data.get("locked", false))
	_base_accessibility_description = String(data.get("accessibility_description", "%s class card." % (get_node("Content/Identity/Name") as Label).text))
	_render_layers()


func set_previewed(value: bool) -> void:
	_previewed = value
	_render_layers()


func set_interaction_locked(value: bool) -> void:
	_interaction_locked = value
	_render_layers()


func request_preview() -> void:
	if not _is_actionable():
		return
	preview_requested.emit(class_id)


func request_selection() -> void:
	if not _is_actionable():
		return
	selection_requested.emit(class_id)


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func show_semantic_state(state: StringName) -> void:
	_authored_focus_state = state == &"focused"
	_focused = false
	_previewed = state == &"previewed"
	_selected = state == &"selected"
	_authored_locked = state == &"locked"
	_disabled = state == &"disabled"
	_compatible = state == &"compatible"
	_needs_attention = state == &"needs_attention"
	_pending = state == &"pending"
	_render_layers()


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_render_layers()


func _render_layers() -> void:
	disabled = _is_non_actionable()
	(get_node("FocusFrame") as Control).visible = _focused or _authored_focus_state
	(get_node("PreviewIndicator") as Control).visible = _previewed or _focused or _authored_focus_state or _mouse_hovered
	(get_node("SelectionNotch") as Control).visible = _selected
	(get_node("CompatibilityBadge") as Control).visible = _compatible
	(get_node("AttentionBadge") as Control).visible = _needs_attention
	(get_node("LockOverlay") as Control).visible = _is_non_actionable()
	var playstyle := get_node("Content/Identity/Playstyle") as Label
	playstyle.visible = not playstyle.text.is_empty()
	(get_node("LockOverlay/Plate/Content/Text") as Label).text = "CHECKING" if _pending else ("UNAVAILABLE" if _disabled else "LOCKED")
	(get_node("LockOverlay/Plate/Content/Icon") as TextureRect).texture = load(ICON_ROOT + ("hourglass.svg" if _pending else "lock.svg")) as Texture2D
	_apply_layer_colors()
	var descriptions: Array[String] = [_base_accessibility_description]
	for state: StringName in [&"focused", &"previewed", &"selected", &"compatible", &"needs_attention", &"pending", &"locked", &"disabled"]:
		if _state_is_visible(state):
			descriptions.append(String((STATE_CUES[state] as Dictionary)["accessibility_description"]))
	accessibility_description = " ".join(descriptions)


func _state_is_visible(state: StringName) -> bool:
	match state:
		&"focused": return _focused or _authored_focus_state
		&"previewed": return _previewed or _mouse_hovered
		&"selected": return _selected
		&"compatible": return _compatible
		&"needs_attention": return _needs_attention
		&"pending": return _pending
		&"locked": return (_authored_locked or _interaction_locked) and not _disabled and not _pending
		&"disabled": return _disabled
	return false


func _apply_layer_colors() -> void:
	var focus_color := LivingForgeTokens.color(&"focus_outline", _high_contrast)
	var selection_color := LivingForgeTokens.color(&"ember_primary", _high_contrast)
	var compatible_color := LivingForgeTokens.color(&"valid", _high_contrast)
	var warning_color := LivingForgeTokens.color(&"warning", _high_contrast)
	var disabled_color := LivingForgeTokens.color(&"disabled", _high_contrast)
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 4
	focus_style.border_width_top = 4
	focus_style.border_width_right = 4
	focus_style.border_width_bottom = 4
	focus_style.border_color = focus_color
	focus_style.corner_radius_top_left = 6
	focus_style.corner_radius_top_right = 6
	focus_style.corner_radius_bottom_right = 6
	focus_style.corner_radius_bottom_left = 6
	(get_node("FocusFrame") as Panel).add_theme_stylebox_override(&"panel", focus_style)
	(get_node("PreviewIndicator/Shape/Geometry") as Polygon2D).color = focus_color
	(get_node("SelectionNotch/Shape/Geometry") as Polygon2D).color = selection_color
	(get_node("CompatibilityBadge/Shape/Geometry") as Polygon2D).color = compatible_color
	(get_node("AttentionBadge/Shape/Geometry") as Polygon2D).color = warning_color
	_tint_texture(get_node("PreviewIndicator/Icon") as TextureRect, focus_color)
	_tint_texture(get_node("SelectionNotch/Icon") as TextureRect, selection_color)
	_tint_texture(get_node("CompatibilityBadge/Icon") as TextureRect, compatible_color)
	_tint_texture(get_node("AttentionBadge/Icon") as TextureRect, warning_color)
	_tint_texture(get_node("LockOverlay/Plate/Content/Icon") as TextureRect, disabled_color)
	(get_node("PreviewIndicator/Text") as Label).add_theme_color_override(&"font_color", focus_color)
	(get_node("SelectionNotch/Text") as Label).add_theme_color_override(&"font_color", selection_color)
	(get_node("CompatibilityBadge/Text") as Label).add_theme_color_override(&"font_color", compatible_color)
	(get_node("AttentionBadge/Text") as Label).add_theme_color_override(&"font_color", warning_color)
	(get_node("LockOverlay/Plate/Content/Text") as Label).add_theme_color_override(&"font_color", disabled_color)
	var primary := LivingForgeTokens.color(&"text_primary", _high_contrast)
	var muted := LivingForgeTokens.color(&"text_muted", _high_contrast)
	(get_node("Content/Identity/Name") as Label).add_theme_color_override(&"font_color", primary)
	(get_node("Content/Identity/Role") as Label).add_theme_color_override(&"font_color", primary)
	(get_node("Content/Identity/Playstyle") as Label).add_theme_color_override(&"font_color", muted)
	_tint_texture(get_node("Content/Portrait") as TextureRect, muted)


func _tint_texture(texture_rect: TextureRect, color: Color) -> void:
	var icon_material := texture_rect.material as ShaderMaterial
	if icon_material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		icon_material = ShaderMaterial.new()
		icon_material.shader = shader
		texture_rect.material = icon_material
	icon_material.set_shader_parameter(&"icon_color", color)


func _on_focus_entered() -> void:
	if not _is_actionable():
		return
	_focused = true
	_render_layers()
	request_preview()


func _on_focus_exited() -> void:
	_focused = false
	_render_layers()


func _on_mouse_entered() -> void:
	if not _is_actionable():
		return
	_mouse_hovered = true
	_render_layers()
	request_preview()


func _on_mouse_exited() -> void:
	_mouse_hovered = false
	_render_layers()


func _on_pressed() -> void:
	request_selection()


func _is_non_actionable() -> bool:
	return _disabled or _authored_locked or _interaction_locked or _pending or class_id == &""


func _is_actionable() -> bool:
	return not _is_non_actionable()
