class_name CharacterPresentation
extends Node3D

signal attack_event(token: int, action_id: StringName, event_name: StringName)
signal attack_finished(token: int, action_id: StringName)

const HIT_DURATION := 0.1
const MOVEMENT_EPSILON_SQUARED := 0.0001
const LOCOMOTION_TURN_RATE := 10.0
const COMBAT_TURN_RATE := 16.0
const CONTACT_SHADOW_HEIGHT := 0.006
const REQUIRED_MODEL_METHODS: Array[StringName] = [
	&"set_body_preset",
	&"set_palette",
	&"apply_equipment_visual",
	&"clear_equipment_visual",
	&"play_action",
	&"play_feedback",
	&"set_hit_weight",
	&"set_downed",
]

@export var fallback_mesh_path: NodePath
var active_profile: CharacterVisualProfile
var active_model: Node3D
var active_palette_id: StringName
var hit_remaining := 0.0
var logged_errors: Dictionary = {}
var latest_planar_velocity := Vector3.ZERO
var last_movement_direction := Vector3.FORWARD
var target_yaw := 0.0
var locomotion_action_id: StringName = &""
var transient_action_id: StringName = &""
var transient_locked := false
var downed_locked := false
var active_sequence_token := 0
var _action_event_callable := Callable()
var _action_finished_callable := Callable()

func apply_profile(profile: CharacterVisualProfile, primary_color: Color) -> bool:
	_clear_model()
	_ensure_contact_shadow()
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
	if not _validate_active_model_api():
		return _fail_active(&"model_api", "required model API is incomplete")
	if not active_model.has_signal(&"action_finished"):
		return _fail_active(&"missing_action_finished", "required model signal action_finished is missing")
	if not active_model.has_signal(&"action_event"):
		return _fail_active(&"missing_action_event", "required model signal action_event is missing")
	if not _has_valid_model_signal(&"action_finished", [TYPE_STRING_NAME]):
		return _fail_active(&"invalid_action_finished", "required model signal action_finished must declare exactly one StringName argument")
	if not _has_valid_model_signal(&"action_event", [TYPE_STRING_NAME, TYPE_STRING_NAME]):
		return _fail_active(&"invalid_action_event", "required model signal action_event must declare exactly two StringName arguments")
	_action_event_callable = Callable(self, &"_on_model_action_event").bind(active_model)
	_action_finished_callable = Callable(self, &"_on_model_action_finished").bind(active_model)
	if active_model.connect(&"action_event", _action_event_callable) != OK:
		return _fail_active(&"connect_action_event", "required model signal action_event could not be connected")
	if active_model.connect(&"action_finished", _action_finished_callable) != OK:
		return _fail_active(&"connect_action_finished", "required model signal action_finished could not be connected")
	if not _call_bool(&"set_body_preset", [profile.default_body_preset]):
		return _fail_active(&"body", "body preset rejected")
	active_palette_id = profile.default_palette_id
	if not _call_bool(&"set_palette", [active_palette_id, primary_color]):
		return _fail_active(&"palette", "palette rejected")
	if profile.default_equipment.is_empty():
		for definition: EquipmentVisualDefinition in profile.default_equipment_visuals:
			if definition == null or not _call_bool(&"apply_equipment_visual", [definition.slot_id, definition]):
				return _fail_active(StringName("slot_%s" % (definition.slot_id if definition != null else &"<null>")), "equipment visual rejected")
	else:
		for entry: EquipmentLoadoutEntry in profile.default_equipment:
			if entry == null or entry.item == null or entry.item.presentation == null or not _call_bool(&"apply_equipment_visual", [entry.slot_id, entry.item.presentation]):
				return _fail_active(StringName("slot_%s" % (entry.slot_id if entry != null else &"<null>")), "equipment item rejected")
	if not play_idle():
		return _fail_active(&"idle", "idle action rejected")
	if active_model.has_method(&"refresh_grounding") and not refresh_grounding():
		return _fail_active(&"grounding", "visible model bounds could not be grounded")
	locomotion_action_id = profile.idle_action_id
	_set_fallback_visible(false)
	return true

func set_body_preset(preset_id: StringName) -> bool:
	var applied := active_model != null and _call_bool(&"set_body_preset", [preset_id])
	return applied and (not active_model.has_method(&"refresh_grounding") or refresh_grounding())

func set_palette(palette_id: StringName, primary_color: Color) -> bool:
	if active_model == null or not _call_bool(&"set_palette", [palette_id, primary_color]):
		return false
	active_palette_id = palette_id
	return true

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	if active_model == null or definition == null or not EquipmentSlotCatalog.is_valid(slot_id):
		return false
	if definition.supported_slot_ids.is_empty() and definition.slot_id != slot_id:
		return false
	if not definition.supported_slot_ids.is_empty() and slot_id not in definition.supported_slot_ids:
		return false
	var applied := _call_bool(&"apply_equipment_visual", [slot_id, definition])
	return applied and (not active_model.has_method(&"refresh_grounding") or refresh_grounding())

func clear_equipment_visual(slot_id: StringName) -> bool:
	if active_model == null or not EquipmentSlotCatalog.is_valid(slot_id):
		return false
	var cleared := _call_bool(&"clear_equipment_visual", [slot_id])
	return cleared and (not active_model.has_method(&"refresh_grounding") or refresh_grounding())

func refresh_grounding() -> bool:
	var grounded := active_model != null and active_model.has_method(&"refresh_grounding") and bool(active_model.call(&"refresh_grounding"))
	if grounded:
		var actor := get_parent()
		var health_bar := actor.get_node_or_null("HealthBar3D") if actor != null else null
		if health_bar != null and health_bar.has_method(&"refresh_presentation_anchor"):
			health_bar.call(&"refresh_presentation_anchor")
	return grounded

func visual_bounds() -> AABB:
	if active_model == null or not active_model.has_method(&"visual_bounds"):
		return AABB()
	var bounds: AABB = active_model.call(&"visual_bounds")
	return active_model.transform * bounds

func equipped_weapon_family() -> StringName:
	return StringName(active_model.call(&"equipped_weapon_family")) if active_model != null and active_model.has_method(&"equipped_weapon_family") else &"unarmed"

func socket_global_transform(socket_id: StringName) -> Transform3D:
	if active_model == null or not active_model.has_method(&"socket_global_transform"):
		return global_transform
	var value: Transform3D = active_model.call(&"socket_global_transform", socket_id)
	return value

func resolve_attack_presentation(definition: AttackDefinition) -> AttackPresentationDefinition:
	if active_profile == null or definition == null:
		return null
	return active_profile.resolve_attack_presentation(definition.id, equipped_weapon_family())

func start_attack(definition: AttackDefinition, target: CombatTarget, presentation: AttackPresentationDefinition, token: int, playback_rate: float) -> bool:
	if downed_locked or active_model == null or definition == null or target == null or presentation == null or token <= 0 or not is_finite(playback_rate) or playback_rate <= 0.0:
		return false
	var previous_yaw := rotation.y
	var previous_target_yaw := target_yaw
	if target.is_available and target.actor != null and is_instance_valid(target.actor):
		var presentation_position := global_position if is_inside_tree() else position
		_face_direction(target.position - presentation_position)
	active_sequence_token = token
	if _begin_transient(presentation.action_id, playback_rate):
		return true
	active_sequence_token = 0
	rotation.y = previous_yaw
	target_yaw = previous_target_yaw
	return false

func action_playback_rate() -> float:
	if active_model == null:
		return 1.0
	var player := active_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	return maxf(player.speed_scale, 0.001) if player != null else 1.0

func finish_attack_sequence() -> void:
	active_sequence_token = 0
	if not transient_locked:
		return
	transient_locked = false
	transient_action_id = &""
	locomotion_action_id = &""
	if not downed_locked:
		_apply_latest_locomotion()

func play_attack(definition: AttackDefinition, target: CombatTarget = null) -> void:
	if downed_locked or active_profile == null or definition == null:
		return
	var animation_id := StringName(active_profile.attack_animation_by_id.get(definition.id, &"idle"))
	if animation_id == active_profile.idle_action_id:
		if play_idle():
			locomotion_action_id = active_profile.idle_action_id
		return
	var previous_yaw := rotation.y
	var previous_target_yaw := target_yaw
	if target != null and target.is_available and is_instance_valid(target.actor):
		var presentation_position := global_position if is_inside_tree() else position
		_face_direction(target.position - presentation_position)
	if not _begin_transient(animation_id):
		rotation.y = previous_yaw
		target_yaw = previous_target_yaw

func play_action(animation_id: StringName, playback_rate: float = 1.0) -> bool:
	return not downed_locked and active_model != null and _call_bool(&"play_action", [animation_id, playback_rate])

func play_idle() -> bool:
	return active_profile != null and play_action(active_profile.idle_action_id)

func update_locomotion(world_velocity: Vector3) -> bool:
	if not world_velocity.is_finite():
		_log_once(&"invalid_locomotion_velocity", "profile=%s operation=locomotion reason=velocity is not finite" % _profile_id())
		return false
	if active_profile == null or active_model == null:
		return false
	latest_planar_velocity = Vector3(world_velocity.x, 0.0, world_velocity.z)
	if transient_locked or downed_locked:
		return true
	return _apply_latest_locomotion()

func flash_hit() -> void:
	if downed_locked or active_model == null:
		return
	hit_remaining = HIT_DURATION
	active_model.call(&"set_hit_weight", 1.0)
	active_model.call(&"play_feedback", &"hit_flinch")

func advance_feedback(delta: float) -> void:
	if hit_remaining <= 0.0:
		return
	hit_remaining = maxf(0.0, hit_remaining - maxf(0.0, delta))
	if is_zero_approx(hit_remaining) and active_model != null:
		active_model.call(&"set_hit_weight", 0.0)

func advance_visual(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var rate := COMBAT_TURN_RATE if transient_locked else LOCOMOTION_TURN_RATE
	var maximum_step := rate * delta
	var difference := angle_difference(rotation.y, target_yaw)
	rotation.y = wrapf(rotation.y + clampf(difference, -maximum_step, maximum_step), -PI, PI)

func set_downed(is_downed: bool) -> void:
	downed_locked = is_downed
	if is_downed:
		active_sequence_token = 0
		transient_locked = false
		transient_action_id = &""
	if active_model == null:
		return
	active_model.call(&"set_downed", is_downed)
	if not is_downed:
		locomotion_action_id = &""
		_apply_latest_locomotion()

func _apply_latest_locomotion() -> bool:
	if active_profile == null or active_model == null:
		return false
	var moving := latest_planar_velocity.length_squared() > MOVEMENT_EPSILON_SQUARED
	var requested := active_profile.walk_action_id if moving else active_profile.idle_action_id
	if requested == locomotion_action_id:
		if moving:
			last_movement_direction = latest_planar_velocity.normalized()
			_face_direction(last_movement_direction)
		return true
	if not play_action(requested):
		_log_once(&"locomotion_action_rejected", "profile=%s operation=locomotion reason=action %s was rejected" % [_profile_id(), requested])
		return false
	if moving:
		last_movement_direction = latest_planar_velocity.normalized()
		_face_direction(last_movement_direction)
	locomotion_action_id = requested
	return true

func _face_direction(direction: Vector3) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= MOVEMENT_EPSILON_SQUARED:
		return
	target_yaw = atan2(-planar.x, -planar.z)

func _begin_transient(animation_id: StringName, playback_rate: float = 1.0) -> bool:
	if downed_locked:
		return false
	if not play_action(animation_id, playback_rate):
		return false
	transient_action_id = animation_id
	transient_locked = true
	return true

func _on_model_action_event(animation_id: StringName, event_name: StringName, source_model: Node3D) -> void:
	if source_model == active_model:
		attack_event.emit(active_sequence_token, animation_id, event_name)

func _on_model_action_finished(animation_id: StringName, source_model: Node3D) -> void:
	if source_model != active_model:
		return
	var finished_token := active_sequence_token
	attack_finished.emit(finished_token, animation_id)
	if active_sequence_token == finished_token:
		active_sequence_token = 0
	if not transient_locked or animation_id != transient_action_id:
		return
	transient_locked = false
	transient_action_id = &""
	locomotion_action_id = &""
	if not downed_locked:
		_apply_latest_locomotion()

func _has_valid_model_signal(signal_name: StringName, expected_types: Array[int]) -> bool:
	if active_model == null:
		return false
	for signal_info: Dictionary in active_model.get_signal_list():
		if StringName(signal_info.get(&"name", &"")) != signal_name:
			continue
		var arguments: Array = signal_info.get(&"args", [])
		if arguments.size() != expected_types.size():
			return false
		for index: int in arguments.size():
			var argument := arguments[index] as Dictionary
			if int(argument.get(&"type", TYPE_NIL)) != expected_types[index]:
				return false
		return true
	return false

func _call_bool(method: StringName, arguments: Array) -> bool:
	if active_model == null or not active_model.has_method(method):
		_log_once(StringName("missing_%s" % method), "profile=%s operation=%s reason=model method is missing" % [_profile_id(), method])
		return false
	return bool(active_model.callv(method, arguments))

func _validate_active_model_api() -> bool:
	var is_complete := true
	for method: StringName in REQUIRED_MODEL_METHODS:
		if not active_model.has_method(method):
			is_complete = false
			_log_once(StringName("missing_%s" % method), "profile=%s operation=%s reason=model method is missing" % [_profile_id(), method])
	return is_complete

func _clear_model() -> void:
	if active_model != null:
		if _action_event_callable.is_valid() and active_model.has_signal(&"action_event") and active_model.is_connected(&"action_event", _action_event_callable):
			active_model.disconnect(&"action_event", _action_event_callable)
		if _action_finished_callable.is_valid() and active_model.has_signal(&"action_finished") and active_model.is_connected(&"action_finished", _action_finished_callable):
			active_model.disconnect(&"action_finished", _action_finished_callable)
		active_model.queue_free()
	_action_event_callable = Callable()
	_action_finished_callable = Callable()
	active_model = null
	active_palette_id = &""
	hit_remaining = 0.0
	latest_planar_velocity = Vector3.ZERO
	last_movement_direction = Vector3.FORWARD
	locomotion_action_id = &""
	transient_action_id = &""
	transient_locked = false
	downed_locked = false
	active_sequence_token = 0
	rotation.y = 0.0
	target_yaw = 0.0

func _ensure_contact_shadow() -> void:
	if get_node_or_null("ContactShadow") != null:
		return
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.34
	mesh.height = 0.008
	mesh.radial_segments = 24
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.02, 0.02, 0.025, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	shadow.mesh = mesh
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = CONTACT_SHADOW_HEIGHT
	add_child(shadow)

func _fail_active(key: StringName, reason: String) -> bool:
	_log_once(key, "profile=%s operation=apply reason=%s" % [_profile_id(), reason])
	_clear_model()
	active_profile = null
	_set_fallback_visible(true)
	return false

func _set_fallback_visible(should_be_visible: bool) -> void:
	var fallback := get_node_or_null(fallback_mesh_path) as VisualInstance3D
	if fallback != null:
		fallback.visible = should_be_visible

func _log_once(key: StringName, detail: String) -> void:
	if logged_errors.has(key):
		return
	logged_errors[key] = true
	push_error("PARTY_FORGE_PRESENTATION_ERROR %s" % detail)

func _profile_id() -> StringName:
	return active_profile.id if active_profile != null else &"<none>"
