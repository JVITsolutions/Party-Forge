class_name ForgePartyMemberCard
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
	&"normal": {"text": "READY", "icon": "shield.svg", "owned": false, "color_role": &"valid", "shape": &"hex"},
	&"critical": {"text": "CRITICAL", "icon": "alert-triangle.svg", "owned": false, "color_role": &"error", "shape": &"triangle"},
	&"downed": {"text": "DOWNED", "icon": "downed.svg", "owned": true, "color_role": &"error", "shape": &"diamond"},
	&"dead": {"text": "DEAD", "icon": "dead.svg", "owned": true, "color_role": &"error", "shape": &"broken"},
}
const LEADER_TEXT_PATHS: Array[NodePath] = [
	NodePath("Surface/Content/Identity/Name"),
	NodePath("Surface/Content/Identity/Class"),
	NodePath("Surface/Content/Meta"),
	NodePath("Surface/Content/Health/Value"),
	NodePath("Surface/Content/StateCue/StateText"),
	NodePath("Surface/LeaderCue/Text"),
]
const BASELINE_CARD_HEIGHT := 184.0

var _bound_member_id := 0
var _semantic_state: StringName = &"normal"
var _high_contrast := false
var _background_opacity_percent := PartyForgeSettings.DEFAULT_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT
var _has_valid_binding := false
var _interaction_disabled := false
var _mouse_hovered := false
var _focused := false


func present(member: PartyMemberHudProjection) -> void:
	if member == null:
		_clear_binding()
		return
	_has_valid_binding = true
	_bound_member_id = member.member_id
	_focused = _focused or has_focus()
	(get_node("Surface/Content/Identity/Name") as Label).text = _format_name(member)
	(get_node("Surface/Content/Identity/Class") as Label).text = _format_class(member)
	(get_node("Surface/Content/Meta") as Label).text = "LEVEL %d  ·  RANK %d" % [member.level, member.rank]
	var health := get_node("Surface/Content/Health/Bar") as ProgressBar
	health.max_value = member.max_health
	health.value = member.health
	(get_node("Surface/Content/Health/Value") as Label).text = "%s / %s" % [_number(member.health), _number(member.max_health)]
	var leader := get_node("Surface/LeaderCue") as Control
	leader.visible = member.is_leader
	_semantic_state = _resolve_state(member)
	_apply_semantic_state()
	accessibility_name = "Inspect %s, %s, Level %d, %s of %s health" % [
		member.display_name,
		member.class_label,
		member.level,
		_number(member.health),
		_number(member.max_health),
	]
	accessibility_description = "%s Rank %d. State: %s.%s" % [accessibility_name, member.rank, String(_semantic_state).capitalize(), " Leader." if member.is_leader else ""]
	_render_interaction()


func semantic_state_id() -> StringName:
	return _semantic_state


func semantic_state_inventory() -> Dictionary:
	return STATE_CUES.duplicate(true)


func set_interaction_disabled(value: bool) -> void:
	_interaction_disabled = value
	_render_interaction()


func apply_leader_density(compact: bool) -> float:
	var content := get_node("Surface/Content") as VBoxContainer
	content.add_theme_constant_override(&"separation", 0)
	var inset := 8.0 if compact else 16.0
	content.offset_left = inset
	content.offset_top = inset
	content.offset_right = -inset
	content.offset_bottom = -inset
	for path: NodePath in LEADER_TEXT_PATHS:
		(get_node(path) as Label).remove_theme_font_size_override(&"font_size")
	(get_node("Surface/Content/Health/Bar") as ProgressBar).custom_minimum_size.y = 14.0 if compact else 16.0
	(get_node("Surface/Content/Health/Value") as Label).custom_minimum_size.x = 96.0
	(get_node("Surface/Content/StateCue") as Control).custom_minimum_size.y = 24.0 if compact else 26.0
	(get_node("Surface/Content/StateCue/StateIcon") as TextureRect).custom_minimum_size = Vector2.ONE * 24.0
	(get_node("Surface/LeaderCue/Icon") as TextureRect).custom_minimum_size = Vector2.ONE * 24.0
	custom_minimum_size.y = maxf(BASELINE_CARD_HEIGHT, content.get_combined_minimum_size().y + inset * 2.0)
	return custom_minimum_size.y


func request_inspect() -> void:
	if _is_actionable():
		inspect_requested.emit(_bound_member_id)


func request_ledger() -> void:
	if _is_actionable():
		ledger_requested.emit(_bound_member_id)


func apply_accessibility_variant(high_contrast: bool) -> void:
	_high_contrast = high_contrast
	_apply_semantic_state()
	_render_interaction()


func apply_background_opacity(opacity_percent: int) -> void:
	_background_opacity_percent = clampi(
		opacity_percent,
		PartyForgeSettings.MIN_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT,
		PartyForgeSettings.MAX_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT,
	)
	_apply_semantic_state()


func _format_name(member: PartyMemberHudProjection) -> String:
	return member.display_name


func _format_class(member: PartyMemberHudProjection) -> String:
	return member.class_label.to_upper()


func _resolve_state(member: PartyMemberHudProjection) -> StringName:
	if member.is_dead:
		return &"dead"
	if member.is_downed:
		return &"downed"
	if member.health / maxf(member.max_health, 1.0) <= CombatHudViewModel.CRITICAL_HEALTH_RATIO:
		return &"critical"
	return &"normal"


func _apply_semantic_state() -> void:
	if not _has_valid_binding:
		return
	if not is_inside_tree() and get_node_or_null("Surface/Content/StateCue") == null:
		return
	var cue := STATE_CUES[_semantic_state] as Dictionary
	var role := StringName(cue["color_role"])
	var color := LivingForgeTokens.color(role, _high_contrast)
	var icon := get_node("Surface/Content/StateCue/StateIcon") as TextureRect
	var icon_root := OWNED_ICON_ROOT if bool(cue["owned"]) else TABLER_ICON_ROOT
	icon.texture = load(icon_root + String(cue["icon"])) as Texture2D
	_tint_texture(icon, color)
	var state_text := get_node("Surface/Content/StateCue/StateText") as Label
	state_text.text = String(cue["text"])
	state_text.add_theme_color_override(&"font_color", color)
	var geometry := get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	geometry.color = color
	geometry.polygon = _shape_points(StringName(cue["shape"]))
	var bar := get_node("Surface/Content/Health/Bar") as ProgressBar
	var track := StyleBoxFlat.new()
	track.bg_color = LivingForgeTokens.color(&"surface_inset", _high_contrast)
	track.corner_radius_top_left = 3
	track.corner_radius_top_right = 3
	track.corner_radius_bottom_left = 3
	track.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override(&"background", track)
	bar.add_theme_stylebox_override(&"fill", fill)
	var surface := get_node("Surface") as Panel
	var surface_style := StyleBoxFlat.new()
	var surface_color := LivingForgeTokens.color(&"surface_forged", _high_contrast)
	surface_color.a = 1.0 if _high_contrast else float(_background_opacity_percent) / 100.0
	surface_style.bg_color = surface_color
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
	var leader_color := LivingForgeTokens.color(&"ember_primary", _high_contrast)
	_tint_texture(get_node("Surface/LeaderCue/Icon") as TextureRect, leader_color)
	(get_node("Surface/LeaderCue/Text") as Label).add_theme_color_override(&"font_color", leader_color)
	(get_node("Surface/Content/Identity/Name") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_primary", _high_contrast))
	(get_node("Surface/Content/Identity/Class") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_muted", _high_contrast))
	(get_node("Surface/Content/Meta") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_muted", _high_contrast))
	(get_node("Surface/Content/Health/Value") as Label).add_theme_color_override(&"font_color", LivingForgeTokens.color(&"text_primary", _high_contrast))


func _render_interaction() -> void:
	disabled = _interaction_disabled or not _has_valid_binding or _bound_member_id <= 0
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	if disabled and has_focus():
		release_focus()
	if disabled:
		_focused = false
	(get_node("FocusFrame") as Control).visible = _focused and not disabled
	(get_node("HoverPlate") as Control).visible = _mouse_hovered and not disabled
	var focus_style := StyleBoxFlat.new()
	focus_style.draw_center = false
	focus_style.border_width_left = 4
	focus_style.border_width_top = 4
	focus_style.border_width_right = 4
	focus_style.border_width_bottom = 4
	focus_style.border_color = LivingForgeTokens.color(&"focus_outline", _high_contrast)
	focus_style.corner_radius_top_left = 7
	focus_style.corner_radius_top_right = 7
	focus_style.corner_radius_bottom_left = 7
	focus_style.corner_radius_bottom_right = 7
	(get_node("FocusFrame") as Panel).add_theme_stylebox_override(&"panel", focus_style)
	var hover_style := StyleBoxFlat.new()
	hover_style.draw_center = false
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = LivingForgeTokens.color(&"text_muted", _high_contrast)
	hover_style.corner_radius_top_left = 7
	hover_style.corner_radius_top_right = 7
	hover_style.corner_radius_bottom_left = 7
	hover_style.corner_radius_bottom_right = 7
	(get_node("HoverPlate") as Panel).add_theme_stylebox_override(&"panel", hover_style)
	if _has_valid_binding and disabled and not accessibility_name.ends_with("Unavailable"):
		accessibility_name += ", Unavailable"
	elif _has_valid_binding and not disabled and accessibility_name.ends_with(", Unavailable"):
		accessibility_name = accessibility_name.trim_suffix(", Unavailable")


func _clear_binding() -> void:
	_has_valid_binding = false
	_bound_member_id = 0
	_semantic_state = &""
	if has_focus():
		release_focus()
	_focused = false
	_mouse_hovered = false
	(get_node("Surface/Content/Identity/Name") as Label).text = ""
	(get_node("Surface/Content/Identity/Class") as Label).text = ""
	(get_node("Surface/Content/Meta") as Label).text = ""
	var health := get_node("Surface/Content/Health/Bar") as ProgressBar
	health.max_value = 1.0
	health.value = 0.0
	(get_node("Surface/Content/Health/Value") as Label).text = ""
	(get_node("Surface/LeaderCue") as Control).visible = false
	(get_node("Surface/Content/StateCue/StateText") as Label).text = ""
	(get_node("Surface/Content/StateCue/StateIcon") as TextureRect).texture = null
	var geometry := get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
	geometry.polygon = PackedVector2Array()
	geometry.color = Color.TRANSPARENT
	accessibility_name = "Party member unavailable"
	accessibility_description = "No party member is bound."
	_render_interaction()


func _shape_points(shape: StringName) -> PackedVector2Array:
	match shape:
		&"triangle": return PackedVector2Array([Vector2(8, 0), Vector2(16, 16), Vector2(0, 16)])
		&"diamond": return PackedVector2Array([Vector2(8, 0), Vector2(16, 8), Vector2(8, 16), Vector2(0, 8)])
		&"broken": return PackedVector2Array([Vector2(3, 0), Vector2(13, 0), Vector2(16, 5), Vector2(10, 8), Vector2(16, 11), Vector2(13, 16), Vector2(3, 16), Vector2(0, 11), Vector2(6, 8), Vector2(0, 5)])
	return PackedVector2Array([Vector2(4, 0), Vector2(12, 0), Vector2(16, 8), Vector2(12, 16), Vector2(4, 16), Vector2(0, 8)])


func _tint_texture(texture_rect: TextureRect, color: Color) -> void:
	var material := texture_rect.material as ShaderMaterial
	if material == null:
		var shader := Shader.new()
		shader.code = ICON_SHADER_CODE
		material = ShaderMaterial.new()
		material.shader = shader
		texture_rect.material = material
	material.set_shader_parameter(&"icon_color", color)


func _number(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "%.1f" % value


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
