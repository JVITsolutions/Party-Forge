class_name EquipmentBaseDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var item_type_id: StringName
@export var compatible_slot_ids: Array[StringName] = []
@export var weight_class_id: StringName = &"accessory"
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var generation_weight := 100.0
@export var generation_tags: Array[StringName] = []
@export var implicit_affix_ids: Array[StringName] = []
@export var attribute_requirements: Dictionary = {}
@export var handedness_id: StringName = &"none"
@export var reserved_slot_ids: Array[StringName] = []
@export var compatible_offhand_item_types: Array[StringName] = []
@export var weapon_family_id: StringName
@export var implicit_family_id: StringName
@export var presentation: EquipmentVisualDefinition

func normalized_generation_tags() -> Array[StringName]:
	var tags := generation_tags.duplicate()
	for tag: StringName in required_all_tags + required_any_tags:
		if tag not in tags:
			tags.append(tag)
	for tag: StringName in [item_type_id, weight_class_id, weapon_family_id]:
		if not tag.is_empty() and tag not in tags:
			tags.append(tag)
	if required_all_tags.is_empty() and required_any_tags.is_empty() and &"global" not in tags:
		tags.append(&"global")
	tags.sort()
	return tags

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment base id is empty")
	if display_name.strip_edges().is_empty(): errors.append("equipment %s display name is empty" % id)
	if item_type_id.is_empty(): errors.append("equipment %s item type is empty" % id)
	if weight_class_id not in [&"accessory", &"light", &"medium", &"heavy", &"weapon"]: errors.append("equipment %s weight class %s is invalid" % [id, weight_class_id])
	if compatible_slot_ids.is_empty(): errors.append("equipment %s has no compatible slots" % id)
	for slot_id: StringName in compatible_slot_ids + reserved_slot_ids:
		if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment %s slot %s is invalid" % [id, slot_id])
	if handedness_id not in [&"none", &"one_hand", &"two_hand"]: errors.append("equipment %s handedness %s is invalid" % [id, handedness_id])
	if handedness_id == &"two_hand" and (&"main_hand" not in compatible_slot_ids or &"off_hand" not in reserved_slot_ids): errors.append("equipment %s two-hand reservation is invalid" % id)
	if not is_finite(generation_weight) or generation_weight <= 0.0: errors.append("equipment %s generation weight must be finite and positive" % id)
	var seen_generation_tags: Dictionary = {}
	for tag: StringName in generation_tags:
		if tag.is_empty(): errors.append("equipment %s generation tag is empty" % id)
		elif seen_generation_tags.has(tag): errors.append("equipment %s has duplicate generation tag %s" % [id, tag])
		else: seen_generation_tags[tag] = true
	var seen_implicit_affixes: Dictionary = {}
	for affix_id: StringName in implicit_affix_ids:
		if seen_implicit_affixes.has(affix_id): errors.append("equipment %s has duplicate implicit affix %s" % [id, affix_id])
		else: seen_implicit_affixes[affix_id] = true
	for tag: StringName in normalized_generation_tags():
		if tag in excluded_tags: errors.append("equipment %s generation tag %s is excluded" % [id, tag])
	if implicit_family_id.is_empty(): errors.append("equipment %s implicit family hook is empty" % id)
	if presentation == null or presentation.id != id: errors.append("equipment %s presentation link is invalid" % id)
	return errors
