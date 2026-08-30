class_name ForgeAlertCard
extends Button

signal activated(member_id: int)
signal inspect_requested(member_id: int)
signal ledger_requested(member_id: int)

const TABLER_ICON_ROOT := "res://assets/ui/living_forge/icons/tabler-3.46.0/"
const OWNED_ICON_ROOT := "res://assets/ui/living_forge/icons/party-forge/"
const ICON_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 icon_color : source_color = vec4(1.0);
void fragment() {
	vec4 sampled = texture(TEXTURE, UV);
	COLOR = vec4(icon_color.rgb, sampled.a * icon_color.a);
}
"""
const STATE_CUES := {
	&"critical": {"text": "CRITICAL", "icon": "alert-triangle.svg", "owned": false, "color_role": &"warning", "shape": &"triangle"},
	&"downed": {"text": "DOWNED", "icon": "downed.svg", "owned": true, "color_role": &"error", "shape": &"diamond"},
	&"dead": {"text": "DEAD", "icon": "dead.svg", "owned": true, "color_role": &"error", "shape": &"broken"},
}

var _bound_member_id := 0
var _semantic_state: StringName = &"critical"
var _can_inspect := false
var _can_open_ledger := false
var _high_contrast := false
var _mouse_hovered := false
var _focused := false


func present_alert(alert: CombatAlertProjection) -> void:
	if alert == null:
		_bound_member_id = 0
		_can_inspect = false
		_can_open_ledger = false
		_render_interaction()
		return
	_bound_member_id = alert.member_id
	_can_inspect = alert.can_inspect
	_can_open_ledger = alert.can_open_ledger
	_focused = _focused or has_focus()
	_semantic_state = _state_for_severity(alert.severity)
	(get_node("Surface/Content/Summary") as Label).text = alert.summary
	(get_node("Surface/Content/Detail") as Label).text = alert.detail
	var routes: Array[String] = []
	if _can_inspect:
		routes.append("INSPECT")
	if _can_open_ledger:
		routes.append("LEDGER")
	(get_node("Surface/Content/Routes") as Label).text = "  ·  ".join(routes) if not routes.is_empty() else "NO ROUTE AVAILABLE"
	_apply_semantic_state()
	accessibility_name = "%s. %s. %s" % [String(_semantic_state).capitalize(), alert.summary, alert.detail]
	accessibility_description = "%s Available actions: %s." % [accessibility_name, ", ".join(routes).capitalize() if not routes.is_empty() else "none"]
	_render_interaction()


func semantic_state_id() -> StringName:
	return _semantic_state


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func request_inspect() -> void:
	if _is_actionable() and _can_inspect:
		inspect_requested.emit(_bound_member_id)


func request_ledger() -> void:
	if _is_actionable() and _can_open_ledger:
		ledger_requested.emit(_bound_member_id)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_apply_semantic_state()
	_render_interaction()


func _state_for_severity(severity: CombatAlertProjection.Severity) -> StringName:
	match severity:
		CombatAlertProjection.Severity.DEAD: return &"dead"
		CombatAlertProjection.Severity.DOWNED: return &"downed"
	return &"critical"


func _apply_semantic_state() -> void:
	var cue := STATE_CUES[_semantic_state] as Dictionary
	var color := LivingForgeTokens.color(StringName(cue["color_role"]), _high_contrast)
	var icon := get_node("Surface/StateIcon") as TextureRect
	icon.texture = load((OWNED_ICON_ROOT if bool(cue["owned"]) else TABLER_ICON_ROOT) + String(cue["icon"])) as Texture2D
	_tint_texture(icon, color)
	var state_text := get_node("Surface/StateText") as Label
	state_text.text = String(cue["text"])
	state_text.add_theme_color_override(&"font_color", color)
	var geometry := get_node("Surface/StateShape/Geometry") as Polygon2D
	geometry.color = color
	geometry.polygon = _shape_points(StringName(cue["shape"]))
	var surface := get_node("Surface") as Panel
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = LivingForgeTokens.color(&"surface_forged", _high_contrast)
	surface_style.border_width_left = 4
	surface_style.border_width_top = 1
	surface_style.border_width_right = 1
	surface_style.border_width_bottom = 1
	surface_style.border_color = color
	surface_style.corner_radius_top_left = 6
	surface_style.corner_radius_top_right = 6
	surface_style.corner_radius_bottom_left = 6
	surface_style.corner_radius_bottom_right = 6
	surface.add_theme_stylebox_override(&"panel", surface_style)
	(get_node("Surface/Content/Summary") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_primary", _high_contrast))
	(get_node("Surface/Content/Detail") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_muted", _high_contrast))
	(get_node("Surface/Content/Routes") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"focus_outline", _high_contrast))


func _render_interaction() -> void:
	disabled = _bound_member_id <= 0 or (not _can_inspect and not _can_open_ledger)
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	if disabled and has_focus():
		release_focus()
	if disabled:
		_focused = false
	(get_node("FocusFrame") as Control).visible = _focused and not disabled
	(get_node("HoverPlate") as Control).visible = _mouse_hovered and not disabled
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	for property: StringName in [&"border_width_left", &"border_width_top", &"border_width_right", &"border_width_bottom"]:
		focus_style.set(property, 4)
	focus_style.border_color = LivingForgeTokens.color(&"focus_outline", _high_contrast)
	(get_node("FocusFrame") as Panel).add_theme_stylebox_override(&"panel", focus_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.draw_center = false
	for property: StringName in [&"border_width_left", &"border_width_top", &"border_width_right", &"border_width_bottom"]:
		hover_style.set(property, 2)
	hover_style.border_color = LivingForgeTokens.color(&"text_muted", _high_contrast)
	(get_node("HoverPlate") as Panel).add_theme_stylebox_override(&"panel", hover_style)
	if disabled and not accessibility_name.ends_with("Unavailable"):
		accessibility_name += ". Unavailable"


func _shape_points(shape: StringName) -> PackedVector2Array:
	if shape == &"triangle":
		return PackedVector2Array([Vector2(8, 0), Vector2(16, 16), Vector2(0, 16)])
	if shape == &"diamond":
		return PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)])
	return PackedVector2Array([Vector2(3, 0), Vector2(13, 0), Vector2(16, 5), Vector2(10, 8), Vector2(16, 11), Vector2(13, 16), Vector2(3, 16), Vector2(0, 11), Vector2(6, 8), Vector2(0, 5)])


func _tint_texture(texture_rect: TextureRect, color: Color) -> void:
	var material := texture_rect.material as ShaderMaterial
	if material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		material = ShaderMaterial.new()
		material.shader = shader
		texture_rect.material = material
	material.set_shader_parameter(&"icon_color", color)


func _is_actionable() -> bool:
	return not disabled and _bound_member_id > 0


func _on_pressed() -> void:
	if _is_actionable():
		activated.emit(_bound_member_id)


func _on_focus_entered() -> void:
	if disabled:
		return
	_focused = true
	_render_interaction()


func _on_focus_exited() -> void:
	_focused = false
	_render_interaction()


func _on_mouse_entered() -> void:
	if disabled:
		return
	_mouse_hovered = true
	_render_interaction()


func _on_mouse_exited() -> void:
	_mouse_hovered = false
	_render_interaction()
