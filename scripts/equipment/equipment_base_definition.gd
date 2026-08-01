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
@export var attribute_requirements: Dictionary = {}
@export var handedness_id: StringName = &"none"
@export var reserved_slot_ids: Array[StringName] = []
@export var compatible_offhand_item_types: Array[StringName] = []
@export var weapon_family_id: StringName
@export var implicit_family_id: StringName
@export var presentation: EquipmentVisualDefinition

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
	if implicit_family_id.is_empty(): errors.append("equipment %s implicit family hook is empty" % id)
	if presentation == null or presentation.id != id: errors.append("equipment %s presentation link is invalid" % id)
	return errors
