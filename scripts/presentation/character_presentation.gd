class_name CharacterPresentation
extends Node3D

const HIT_DURATION := 0.1

@export var fallback_mesh_path: NodePath
var active_profile: CharacterVisualProfile
var active_model: Node3D
var active_palette_id: StringName
var hit_remaining := 0.0
var logged_errors: Dictionary = {}

func apply_profile(profile: CharacterVisualProfile, primary_color: Color) -> bool:
	_clear_model()
	active_profile = null
	_set_fallback_visible(true)
	if profile == null:
		return false
	var errors := profile.validate()
	if not errors.is_empty():
		_log_once(&"invalid_profile", "profile=%s operation=apply reason=%s" % [profile.id, errors[0]])
		return false
	active_model = profile.presentation_scene.instantiate() as Node3D
	if active_model == null:
		_log_once(&"invalid_scene", "profile=%s operation=instantiate reason=root is not Node3D" % profile.id)
		return false
	add_child(active_model)
	active_profile = profile
	if not _call_bool(&"set_body_preset", [profile.default_body_preset]):
		return _fail_active(&"body", "body preset rejected")
	active_palette_id = profile.default_palette_id
	if not _call_bool(&"set_palette", [active_palette_id, primary_color]):
		return _fail_active(&"palette", "palette rejected")
	for definition: EquipmentVisualDefinition in profile.default_equipment_visuals:
		if not _call_bool(&"apply_equipment_visual", [definition.slot_id, definition]):
			_log_once(StringName("slot_%s" % definition.slot_id), "profile=%s operation=equipment slot=%s reason=visual rejected" % [profile.id, definition.slot_id])
	_set_fallback_visible(false)
	play_action(&"idle")
	return true

func set_body_preset(preset_id: StringName) -> bool:
	return active_model != null and _call_bool(&"set_body_preset", [preset_id])

func set_palette(palette_id: StringName, primary_color: Color) -> bool:
	if active_model == null or not _call_bool(&"set_palette", [palette_id, primary_color]):
		return false
	active_palette_id = palette_id
	return true

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	if active_model == null or definition == null or not EquipmentSlotCatalog.is_valid(slot_id) or definition.slot_id != slot_id:
		return false
	return _call_bool(&"apply_equipment_visual", [slot_id, definition])

func play_attack(definition: AttackDefinition, target: CombatTarget = null) -> void:
	if active_profile == null or definition == null:
		play_action(&"idle")
		return
	var animation_id := StringName(active_profile.attack_animation_by_id.get(definition.id, &"idle"))
	play_action(animation_id)

func play_action(animation_id: StringName) -> bool:
	return active_model != null and _call_bool(&"play_action", [animation_id])

func flash_hit() -> void:
	if active_model == null:
		return
	hit_remaining = HIT_DURATION
	active_model.call(&"set_hit_weight", 1.0)
	play_action(&"hit_flinch")

func advance_feedback(delta: float) -> void:
	if hit_remaining <= 0.0:
		return
	hit_remaining = maxf(0.0, hit_remaining - maxf(0.0, delta))
	if is_zero_approx(hit_remaining) and active_model != null:
		active_model.call(&"set_hit_weight", 0.0)

func set_downed(is_downed: bool) -> void:
	if active_model != null:
		active_model.call(&"set_downed", is_downed)

func _call_bool(method: StringName, arguments: Array) -> bool:
	if active_model == null or not active_model.has_method(method):
		_log_once(StringName("missing_%s" % method), "profile=%s operation=%s reason=model method is missing" % [_profile_id(), method])
		return false
	return bool(active_model.callv(method, arguments))

func _clear_model() -> void:
	if active_model != null:
		active_model.queue_free()
	active_model = null
	active_palette_id = &""
	hit_remaining = 0.0

func _fail_active(key: StringName, reason: String) -> bool:
	_log_once(key, "profile=%s operation=apply reason=%s" % [_profile_id(), reason])
	_clear_model()
	active_profile = null
	_set_fallback_visible(true)
	return false

func _set_fallback_visible(is_visible: bool) -> void:
	var fallback := get_node_or_null(fallback_mesh_path) as VisualInstance3D
	if fallback != null:
		fallback.visible = is_visible

func _log_once(key: StringName, detail: String) -> void:
	if logged_errors.has(key):
		return
	logged_errors[key] = true
	push_error("PARTY_FORGE_PRESENTATION_ERROR %s" % detail)

func _profile_id() -> StringName:
	return active_profile.id if active_profile != null else &"<none>"
