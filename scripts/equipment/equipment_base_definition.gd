class_name EquipmentBaseDefinition
extends Resource

## The fixed-point activation resolver may only inspect these six requirement
## attributes. Keep requirement authoring and equipment modifier monotonicity on
## this single canonical schema so active items can never invalidate an earlier
## activation pass.
const REQUIREMENT_ATTRIBUTE_IDS: Array[StringName] = ClassGrowthDefinition.CORE_ATTRIBUTE_IDS

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
@export var weapon_damage_profile: WeaponDamageProfile
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

func validate(damage_types: DamageTypeCatalog = null) -> PackedStringArray:
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
	# Cross-catalog profile validation belongs to EquipmentCatalog, which owns the
	# authoritative DamageTypeCatalog. Presentation callers intentionally validate
	# the base-local contract without loading that catalog.
	if weapon_damage_profile != null and damage_types != null:
		errors.append_array(weapon_damage_profile.validate(damage_types))
	errors.append_array(validate_attribute_requirements())
	return errors

func validate_attribute_requirements() -> PackedStringArray:
	var errors := PackedStringArray()
	var keys: Array[Variant] = attribute_requirements.keys()
	keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	for key: Variant in keys:
		var attribute_id := StringName(key) if typeof(key) in [TYPE_STRING, TYPE_STRING_NAME] else &""
		var value: Variant = attribute_requirements[key]
		var value_text := str(value)
		if typeof(key) != TYPE_STRING_NAME:
			errors.append("requirement attribute=%s value=%s reason=attribute id must be StringName" % [String(key), value_text])
			continue
		if attribute_id not in REQUIREMENT_ATTRIBUTE_IDS:
			errors.append("requirement attribute=%s value=%s reason=unknown core attribute" % [attribute_id, value_text])
			continue
		if not value is float and not value is int:
			errors.append("requirement attribute=%s value=%s reason=value must be numeric" % [attribute_id, value_text])
			continue
		var numeric_value := float(value)
		if not is_finite(numeric_value):
			errors.append("requirement attribute=%s value=%s reason=value must be finite" % [attribute_id, value_text])
		elif numeric_value < 0.0:
			errors.append("requirement attribute=%s value=%s reason=value must be nonnegative" % [attribute_id, value_text])
	return errors

static func monotonic_core_modifier_error(stat_id: StringName, operation: int, value: float) -> String:
	if stat_id not in REQUIREMENT_ATTRIBUTE_IDS:
		return ""
	if not is_finite(value):
		return "value must be finite"
	# Every supported operation is exactly neutral at zero, including -0.0.
	if value == 0.0:
		return ""
	if value < 0.0:
		return "value must be nonnegative"
	if operation in [StatModifier.Operation.REDUCED, StatModifier.Operation.LESS]:
		return "operation can reduce a core requirement attribute"
	return ""

static func modifier_operation_name(operation: int) -> String:
	match operation:
		StatModifier.Operation.FLAT: return "flat"
		StatModifier.Operation.INCREASED: return "increased"
		StatModifier.Operation.REDUCED: return "reduced"
		StatModifier.Operation.MORE: return "more"
		StatModifier.Operation.LESS: return "less"
		_: return str(operation)
