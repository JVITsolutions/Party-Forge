class_name EquipmentEligibility
extends RefCounted

static func validate_structure(item: EquipmentBaseDefinition, class_definition: ClassDefinition, requested_slot_id: StringName, loadout: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	if item == null or class_definition == null:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR reason=item or class is missing")
		return errors
	if requested_slot_id not in item.compatible_slot_ids:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s slot=%s reason=incompatible slot" % [item.id, requested_slot_id])
	var tags := class_definition.normalized_eligibility_tags()
	if item.item_type_id in [&"helmet", &"body_armour", &"legs", &"gloves", &"boots"] and item.weight_class_id in [&"light", &"medium", &"heavy"]:
		var weight_tag := StringName("armour_%s" % item.weight_class_id)
		if weight_tag not in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=missing weight capability %s" % [item.id, weight_tag])
	for tag: StringName in item.required_all_tags:
		if tag not in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=missing tag %s" % [item.id, tag])
	if not item.required_any_tags.is_empty() and not item.required_any_tags.any(func(tag: StringName) -> bool: return tag in tags):
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=no compatible archetype tag" % item.id)
	for tag: StringName in item.excluded_tags:
		if tag in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=excluded tag %s" % [item.id, tag])
	var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
	if requested_slot_id == &"off_hand" and main_hand != null and &"off_hand" in main_hand.reserved_slot_ids and not is_compatible_reserved_item(main_hand, item):
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=offhand reserved by %s" % [item.id, main_hand.id])
	if requested_slot_id == &"main_hand" and &"off_hand" in item.reserved_slot_ids:
		var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
		if off_hand != null and not is_compatible_reserved_item(item, off_hand): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=equipped offhand %s is incompatible" % [item.id, off_hand.id])
	return errors

static func unmet_attribute_requirements(item: EquipmentBaseDefinition, attributes: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if item == null:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR reason=item or class is missing")
		return errors
	var attribute_ids: Array[StringName] = []
	for attribute_id: Variant in item.attribute_requirements:
		attribute_ids.append(StringName(attribute_id))
	attribute_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	for attribute_id: StringName in attribute_ids:
		var required := float(item.attribute_requirements.get(attribute_id, item.attribute_requirements.get(String(attribute_id), NAN)))
		var current := float(attributes.get(attribute_id, attributes.get(String(attribute_id), 0.0)))
		if not is_finite(required) or not is_finite(current) or current < required:
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=attribute %s" % [item.id, attribute_id])
	return errors

static func validate_equip(item: EquipmentBaseDefinition, class_definition: ClassDefinition, requested_slot_id: StringName, loadout: Dictionary = {}, attributes: Dictionary = {}) -> PackedStringArray:
	var errors := validate_structure(item, class_definition, requested_slot_id, loadout)
	if item == null or class_definition == null:
		return errors
	errors.append_array(unmet_attribute_requirements(item, attributes))
	return errors

static func is_compatible_reserved_item(reserving_item: EquipmentBaseDefinition, reserved_item: EquipmentBaseDefinition) -> bool:
	if reserving_item == null or reserved_item == null:
		return false
	if reserved_item.item_type_id not in reserving_item.compatible_offhand_item_types:
		return false
	if reserved_item.item_type_id == &"quiver":
		return not reserving_item.weapon_family_id.is_empty() and reserved_item.weapon_family_id == reserving_item.weapon_family_id
	return true
