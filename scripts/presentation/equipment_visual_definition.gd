class_name EquipmentVisualDefinition
extends Resource

@export var id: StringName
@export var slot_id: StringName
@export var geometry_key: StringName
@export var visual_channels: Array[StringName] = []
@export var supported_slot_ids: Array[StringName] = []
@export var presentation_scene: PackedScene
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
	if combat_visible and (presentation_scene == null or socket_id.is_empty()): errors.append("equipment visual %s visible scene or socket is missing" % id)
	if readability_channels.is_empty(): errors.append("equipment visual %s readability channels are empty" % id)
	if attachment_role_id not in [&"wearable", &"held", &"back"]: errors.append("equipment visual %s attachment role %s is invalid" % [id, attachment_role_id])
	if is_held_item() and (readability_anchor_name.is_empty() or action_origin_socket_name.is_empty()): errors.append("equipment visual %s held-item anchors are incomplete" % id)
	if attachment_role_id == &"back" and readability_anchor_name.is_empty(): errors.append("equipment visual %s back readability anchor is missing" % id)
	if is_held_item() and weapon_animation_family_id in [&"light_bow", &"greatbow"] and projectile_launch_socket_name.is_empty(): errors.append("equipment visual %s projectile launch socket is missing" % id)
	return errors
