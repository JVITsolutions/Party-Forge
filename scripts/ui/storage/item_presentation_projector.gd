class_name ItemPresentationProjector
extends RefCounted


static func project(
	item: ItemInstance,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	class_definition: ClassDefinition = null,
) -> Dictionary:
	if item == null or equipment == null or foundation == null or stats == null:
		return {}
	var base := equipment.definition(item.base_definition_id)
	var rarity := foundation.rarity(item.rarity_id)
	if base == null or rarity == null:
		return {}
	var requirement_errors := base.validate_attribute_requirements()
	if not requirement_errors.is_empty():
		return {
			"error": "PARTY_FORGE_ITEM_PRESENTATION_ERROR item=%s base=%s %s" % [
				item.instance_id, base.id, requirement_errors[0],
			],
		}
	var affixes: Array[Dictionary] = []
	var totals: Dictionary = {}
	for instance: ItemAffixInstance in item.affixes:
		if instance == null:
			affixes.append({})
			continue
		affixes.append(_project_affix(instance, foundation, stats, totals))
	return {
		"instance_id": item.instance_id,
		"base_definition_id": String(item.base_definition_id),
		"name": base.display_name,
		"item_type_id": String(base.item_type_id),
		"icon_path": _icon_path(base),
		"rarity_id": String(item.rarity_id),
		"rarity_name": rarity.display_name,
		"item_level": item.item_level,
		"compatible_slot_ids": _strings(base.compatible_slot_ids),
		"handedness_id": String(base.handedness_id),
		"attribute_requirements": base.attribute_requirements.duplicate(true),
		"required_all_tags": _strings(base.required_all_tags),
		"required_any_tags": _strings(base.required_any_tags),
		"excluded_tags": _strings(base.excluded_tags),
		"requirement_lines": _requirement_lines(base, stats),
		"equip_warning_lines": _equip_warning_lines(base, class_definition, stats),
		"is_disabled": false,
		"disabled_requirement_lines": PackedStringArray(),
		"core_value_lines": PackedStringArray(),
		"affixes": affixes,
		"modifier_totals": totals,
		"item": item.to_dictionary(),
	}


static func operation_name(operation: int) -> String:
	match operation:
		StatModifier.Operation.FLAT:
			return "Flat"
		StatModifier.Operation.INCREASED:
			return "Increased"
		StatModifier.Operation.REDUCED:
			return "Reduced"
		StatModifier.Operation.MORE:
			return "More"
		StatModifier.Operation.LESS:
			return "Less"
		_:
			return "Unknown (%d)" % operation


static func _project_affix(
	instance: ItemAffixInstance,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	totals: Dictionary,
) -> Dictionary:
	var definition := foundation.affix(instance.definition_id)
	var rolls: Array[Dictionary] = []
	for roll_index: int in instance.rolls.size():
		var roll := instance.rolls[roll_index]
		if roll == null:
			rolls.append({})
			continue
		var stat_definition := stats.definition(roll.stat_id)
		var stat_name := stat_definition.display_name if stat_definition != null else _title(String(roll.stat_id))
		var document := {
			"stat_id": String(roll.stat_id),
			"stat_name": stat_name,
			"operation": roll.operation,
			"operation_name": operation_name(roll.operation),
			"value": roll.value,
			"effect_text": _effect_text(stat_name, roll.operation, roll.value),
		}
		_append_bounds(document, definition, instance.tier, roll_index, roll)
		rolls.append(document)
		var total_key := "%s|%d" % [String(roll.stat_id), roll.operation]
		totals[total_key] = float(totals.get(total_key, 0.0)) + roll.value
	return {
		"definition_id": String(instance.definition_id),
		"display_name": definition.display_name if definition != null else "",
		"affix_kind": instance.affix_kind,
		"tier": instance.tier,
		"rolls": rolls,
	}


static func _append_bounds(
	document: Dictionary,
	definition: ItemAffixDefinition,
	tier: int,
	effect_index: int,
	roll: ItemModifierRoll,
) -> void:
	if definition == null or effect_index < 0 or effect_index >= definition.effects.size():
		return
	var effect := definition.effects[effect_index]
	if effect == null or roll.stat_id != effect.stat_id or roll.operation != effect.operation:
		return
	var tier_definition := definition.tier_definition(tier)
	if tier_definition == null:
		return
	var bounds := tier_definition.roll_bounds(effect_index)
	var minimum := bounds.x
	var maximum := bounds.y
	if not is_finite(minimum) or not is_finite(maximum) or minimum > maximum:
		return
	document["minimum_roll"] = minimum
	document["maximum_roll"] = maximum
	document["roll_fraction"] = 0.0 if is_equal_approx(minimum, maximum) else clampf((roll.value - minimum) / (maximum - minimum), 0.0, 1.0)


static func _requirement_lines(base: EquipmentBaseDefinition, stats: StatCatalog) -> PackedStringArray:
	var lines := PackedStringArray()
	var attribute_ids: Array[String] = []
	for attribute_id: Variant in base.attribute_requirements:
		attribute_ids.append(String(attribute_id))
	attribute_ids.sort()
	for attribute_id: String in attribute_ids:
		var definition := stats.definition(StringName(attribute_id))
		var label := definition.display_name if definition != null else _title(attribute_id)
		lines.append("Requires %s %s" % [label, _number(float(base.attribute_requirements.get(attribute_id, base.attribute_requirements.get(StringName(attribute_id), 0.0))))])
	if not base.required_all_tags.is_empty():
		lines.append("Requires all: %s" % ", ".join(_tag_labels(base.required_all_tags)))
	if not base.required_any_tags.is_empty():
		lines.append("Requires one: %s" % ", ".join(_tag_labels(base.required_any_tags)))
	if not base.excluded_tags.is_empty():
		lines.append("Cannot be used by: %s" % ", ".join(_tag_labels(base.excluded_tags)))
	return lines


static func _equip_warning_lines(
	base: EquipmentBaseDefinition,
	class_definition: ClassDefinition,
	stats: StatCatalog,
) -> PackedStringArray:
	var lines := PackedStringArray()
	if class_definition == null:
		return lines
	var class_tags := class_definition.normalized_eligibility_tags()
	for tag: StringName in base.required_all_tags:
		if tag not in class_tags:
			lines.append("%s lacks required tag: %s" % [class_definition.display_name, _title(String(tag))])
	if not base.required_any_tags.is_empty() and not base.required_any_tags.any(func(tag: StringName) -> bool: return tag in class_tags):
		lines.append("%s requires one of: %s" % [class_definition.display_name, ", ".join(_tag_labels(base.required_any_tags))])
	for tag: StringName in base.excluded_tags:
		if tag in class_tags:
			lines.append("%s has excluded tag: %s" % [class_definition.display_name, _title(String(tag))])
	var values := class_definition.stat_base_values()
	var attribute_ids: Array[String] = []
	for attribute_id: Variant in base.attribute_requirements:
		attribute_ids.append(String(attribute_id))
	attribute_ids.sort()
	for attribute_id: String in attribute_ids:
		var required := float(base.attribute_requirements.get(attribute_id, base.attribute_requirements.get(StringName(attribute_id), 0.0)))
		var available := float(values.get(attribute_id, values.get(StringName(attribute_id), 0.0)))
		if available >= required:
			continue
		var definition := stats.definition(StringName(attribute_id))
		var label := definition.display_name if definition != null else _title(attribute_id)
		lines.append("%s requires %s %s (has %s)" % [class_definition.display_name, label, _number(required), _number(available)])
	return lines


static func _effect_text(stat_name: String, operation: int, value: float) -> String:
	match operation:
		StatModifier.Operation.FLAT:
			return "%s%s %s" % ["+" if value >= 0.0 else "", _number(value), stat_name]
		StatModifier.Operation.INCREASED:
			return "%s%% increased %s" % [_number(value * 100.0), stat_name]
		StatModifier.Operation.REDUCED:
			return "%s%% reduced %s" % [_number(value * 100.0), stat_name]
		StatModifier.Operation.MORE:
			return "%s%% more %s" % [_number(value * 100.0), stat_name]
		StatModifier.Operation.LESS:
			return "%s%% less %s" % [_number(value * 100.0), stat_name]
		_:
			return "%s %s" % [_number(value), stat_name]


static func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")


static func _tag_labels(tags: Array[StringName]) -> PackedStringArray:
	var labels := PackedStringArray()
	for tag: StringName in tags:
		labels.append(_title(String(tag)))
	return labels


static func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _title(value: String) -> String:
	return value.replace("_", " ").capitalize()


static func _icon_path(base: EquipmentBaseDefinition) -> String:
	var path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [String(base.implicit_family_id), String(base.id)]
	return path if ResourceLoader.exists(path) else ""
