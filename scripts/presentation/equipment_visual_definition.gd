class_name EquipmentVisualDefinition
extends Resource

@export var id: StringName
@export var slot_id: StringName
@export var geometry_key: StringName
@export var visual_channels: Array[StringName] = []
@export var supported_slot_ids: Array[StringName] = []
@export var presentation_scene: PackedScene
@export var fit_policy: StringName = &"shared"
@export var attachment_mode: StringName = &"rigid_socket"
@export var body_fits: Array[EquipmentBodyFitDescriptor] = []
@export var rig_id: StringName
@export var skeleton_topology_signature: String
@export var canonical_rest_signature: String
@export var skin_bind_signature: String
@export var icon_master: Texture2D
@export var icon_runtime: Texture2D
@export var socket_id: StringName
@export var body_preset_ids: Array[StringName] = [&"masculine", &"feminine"]
@export var combat_visible := true
@export var item_colors: Dictionary = {}
@export var wearer_accent_channel: StringName
@export var weapon_animation_family_id: StringName
@export var launch_socket_id: StringName
@export var readability_channels: Array[StringName] = []
@export var readability_anchor_name: StringName
@export var action_origin_socket_name: StringName
@export var projectile_launch_socket_name: StringName
@export var attachment_role_id: StringName = &"wearable"

func is_held_item() -> bool:
	return combat_visible and attachment_role_id == &"held"

func body_fit_for(body_preset_id: StringName) -> EquipmentBodyFitDescriptor:
	if body_preset_id not in [&"masculine", &"feminine"]:
		return null
	if body_fits.is_empty():
		return EquipmentBodyFitDescriptor.legacy(body_preset_id, presentation_scene)
	for descriptor: EquipmentBodyFitDescriptor in body_fits:
		if descriptor != null and descriptor.validates_for_body(body_preset_id, fit_policy == &"shared"):
			return descriptor
	return null

func presentation_scene_for(body_preset_id: StringName) -> PackedScene:
	var descriptor := body_fit_for(body_preset_id)
	return descriptor.presentation_scene if descriptor != null else null

func mesh_root_paths_for(body_preset_id: StringName) -> Array[NodePath]:
	var descriptor := body_fit_for(body_preset_id)
	return descriptor.mesh_root_paths if descriptor != null else []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment visual id is empty")
	var legacy_embedded := supported_slot_ids.is_empty() and presentation_scene == null and icon_master == null and icon_runtime == null
	if legacy_embedded:
		if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment visual %s slot %s is invalid" % [id, slot_id])
		if geometry_key.is_empty(): errors.append("equipment visual %s geometry key is empty" % id)
		if visual_channels.is_empty(): errors.append("equipment visual %s has no visual channels" % id)
		return errors
	if supported_slot_ids.is_empty(): errors.append("equipment visual %s has no supported slots" % id)
	for supported_slot: StringName in supported_slot_ids:
		if not EquipmentSlotCatalog.is_valid(supported_slot): errors.append("equipment visual %s slot %s is invalid" % [id, supported_slot])
	if slot_id.is_empty(): errors.append("equipment visual %s primary slot is empty" % id)
	elif slot_id not in supported_slot_ids: errors.append("equipment visual %s primary slot is unsupported" % id)
	if body_preset_ids != [&"masculine", &"feminine"]: errors.append("equipment visual %s body presets are incomplete" % id)
	if icon_master == null or icon_runtime == null: errors.append("equipment visual %s icon pair is incomplete" % id)
	if fit_policy not in [&"shared", &"variant"]: errors.append("equipment visual %s fit policy %s is invalid" % [id, fit_policy])
	if attachment_mode not in [&"rigid_socket", &"shared_skin"]: errors.append("equipment visual %s attachment mode %s is invalid" % [id, attachment_mode])
	_validate_body_fits(errors)
	var has_presentation := combat_visible or presentation_scene != null or not body_fits.is_empty()
	if combat_visible and presentation_scene == null and body_fits.is_empty(): errors.append("equipment visual %s visible scene is missing" % id)
	if has_presentation and attachment_mode == &"rigid_socket" and socket_id.is_empty(): errors.append("equipment visual %s rigid socket is missing" % id)
	if has_presentation and attachment_mode == &"shared_skin":
		if rig_id.is_empty(): errors.append("equipment visual %s shared skin rig ID is missing" % id)
		if skeleton_topology_signature.is_empty(): errors.append("equipment visual %s shared skin topology signature is missing" % id)
		if canonical_rest_signature.is_empty(): errors.append("equipment visual %s shared skin canonical rest signature is missing" % id)
		if skin_bind_signature.is_empty(): errors.append("equipment visual %s shared skin bind signature is missing" % id)
	if readability_channels.is_empty(): errors.append("equipment visual %s readability channels are empty" % id)
	if attachment_role_id not in [&"wearable", &"held", &"back"]: errors.append("equipment visual %s attachment role %s is invalid" % [id, attachment_role_id])
	if is_held_item() and (readability_anchor_name.is_empty() or action_origin_socket_name.is_empty()): errors.append("equipment visual %s held-item anchors are incomplete" % id)
	if attachment_role_id == &"back" and readability_anchor_name.is_empty(): errors.append("equipment visual %s back readability anchor is missing" % id)
	if is_held_item() and weapon_animation_family_id in [&"light_bow", &"greatbow"] and projectile_launch_socket_name.is_empty(): errors.append("equipment visual %s projectile launch socket is missing" % id)
	return errors

func _validate_body_fits(errors: PackedStringArray) -> void:
	if body_fits.is_empty():
		return
	var seen_body_ids: Dictionary = {}
	for descriptor: EquipmentBodyFitDescriptor in body_fits:
		if descriptor == null:
			errors.append("equipment visual %s body fit descriptor is missing" % id)
			continue
		if seen_body_ids.has(descriptor.body_preset_id):
			errors.append("equipment visual %s duplicates body fit %s" % [id, descriptor.body_preset_id])
		seen_body_ids[descriptor.body_preset_id] = true
		for error: String in descriptor.validate():
			errors.append("equipment visual %s %s" % [id, error])
	if fit_policy == &"shared" and not seen_body_ids.has(&"shared"):
		errors.append("equipment visual %s shared fit requires a shared descriptor" % id)
	if fit_policy == &"variant":
		for body_preset: StringName in [&"masculine", &"feminine"]:
			if not seen_body_ids.has(body_preset):
				errors.append("equipment visual %s variant fit is missing %s descriptor" % [id, body_preset])
		_validate_shared_scene_root_separation(errors)

func _validate_shared_scene_root_separation(errors: PackedStringArray) -> void:
	for left_index: int in range(body_fits.size()):
		var left := body_fits[left_index]
		if left == null or left.presentation_scene == null:
			continue
		for right_index: int in range(left_index + 1, body_fits.size()):
			var right := body_fits[right_index]
			if right == null or right.presentation_scene != left.presentation_scene:
				continue
			for left_path: NodePath in left.mesh_root_paths:
				for right_path: NodePath in right.mesh_root_paths:
					if _root_paths_overlap(left_path, right_path):
						errors.append("equipment visual %s shared-scene body fit roots overlap" % id)
						return

func _root_paths_overlap(left_path: NodePath, right_path: NodePath) -> bool:
	var left_text := String(left_path)
	var right_text := String(right_path)
	return left_text == right_text or left_text == "." or right_text == "." or left_text.begins_with(right_text + "/") or right_text.begins_with(left_text + "/")
