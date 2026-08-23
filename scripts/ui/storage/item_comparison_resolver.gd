class_name ItemComparisonResolver
extends RefCounted


static func resolve(
	inspected: Dictionary,
	leader_slots: Array[Dictionary],
	item_records: Dictionary,
	projected_lines_by_slot: Dictionary = {},
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var compatible: Array = inspected.get("compatible_slot_ids", [])
	var inspected_id := String(inspected.get("instance_id", ""))
	for slot_entry: Dictionary in leader_slots:
		var slot_id := String(slot_entry.get("slot_id", ""))
		if slot_id not in compatible:
			continue
		var instance_id := String(slot_entry.get("instance_id", ""))
		if instance_id.is_empty() or instance_id == inspected_id:
			continue
		var stored: Variant = item_records.get(instance_id, {})
		if not stored is Dictionary:
			continue
		var equipped := (stored as Dictionary).duplicate(true)
		if equipped.is_empty():
			continue
		result.append({
			"slot_id": slot_id,
			"item": equipped,
			"delta_lines": (projected_lines_by_slot[slot_id] as Array).duplicate(true) if projected_lines_by_slot.has(slot_id) else _delta_lines(inspected, equipped),
		})
	return result


static func _delta_lines(inspected: Dictionary, equipped: Dictionary) -> Array[Dictionary]:
	var result := base_damage_delta_rows(
		inspected.get("base_damage_components", []) as Array,
		equipped.get("base_damage_components", []) as Array,
	)
	var inspected_totals: Dictionary = (inspected.get("modifier_totals", {}) as Dictionary).duplicate(true)
	var equipped_totals: Dictionary = (equipped.get("modifier_totals", {}) as Dictionary).duplicate(true)
	var keys: Array[String] = []
	for key: Variant in inspected_totals:
		var normalized := String(key)
		if normalized not in keys:
			keys.append(normalized)
	for key: Variant in equipped_totals:
		var normalized := String(key)
		if normalized not in keys:
			keys.append(normalized)
	keys.sort()
	for key: String in keys:
		var parts := key.split("|", false)
		if parts.size() != 2 or not String(parts[1]).is_valid_int():
			continue
		var stat_id := String(parts[0])
		var operation := int(parts[1])
		var delta := float(inspected_totals.get(key, 0.0)) - float(equipped_totals.get(key, 0.0))
		if is_zero_approx(delta):
			delta = 0.0
		var raw_direction := 1 if delta > 0.0 else -1 if delta < 0.0 else 0
		result.append({
			"stat_id": stat_id,
			"operation": operation,
			"delta": delta,
			"direction": 0,
			"raw_direction": raw_direction,
			"text": _raw_delta_text(stat_id, operation, delta, raw_direction),
			"accessible_text": _raw_delta_accessible_text(stat_id, operation, delta, raw_direction),
		})
	return result


static func base_damage_delta_rows(candidate_components: Array, current_components: Array) -> Array[Dictionary]:
	var candidate_by_type := _base_damage_by_type(candidate_components)
	var current_by_type := _base_damage_by_type(current_components)
	var type_ids: Array[String] = []
	for key: Variant in candidate_by_type:
		type_ids.append(String(key))
	for key: Variant in current_by_type:
		var type_id := String(key)
		if type_id not in type_ids:
			type_ids.append(type_id)
	type_ids.sort()
	var result: Array[Dictionary] = []
	for type_id: String in type_ids:
		var candidate := candidate_by_type.get(type_id, {}) as Dictionary
		var current := current_by_type.get(type_id, {}) as Dictionary
		var before_minimum := float(current.get("minimum_damage", 0.0))
		var before_maximum := float(current.get("maximum_damage", 0.0))
		var after_minimum := float(candidate.get("minimum_damage", 0.0))
		var after_maximum := float(candidate.get("maximum_damage", 0.0))
		if is_equal_approx(before_minimum, after_minimum) and is_equal_approx(before_maximum, after_maximum):
			continue
		var before_midpoint := before_minimum + (before_maximum - before_minimum) * 0.5
		var after_midpoint := after_minimum + (after_maximum - after_minimum) * 0.5
		var delta := after_midpoint - before_midpoint
		var minimum_equal := is_equal_approx(before_minimum, after_minimum)
		var maximum_equal := is_equal_approx(before_maximum, after_maximum)
		var minimum_improved := after_minimum > before_minimum and not minimum_equal
		var maximum_improved := after_maximum > before_maximum and not maximum_equal
		var minimum_reduced := after_minimum < before_minimum and not minimum_equal
		var maximum_reduced := after_maximum < before_maximum and not maximum_equal
		var direction := 0
		if (minimum_equal or minimum_improved) and (maximum_equal or maximum_improved):
			direction = 1
		elif (minimum_equal or minimum_reduced) and (maximum_equal or maximum_reduced):
			direction = -1
		var symbol := "▲" if direction > 0 else "▼" if direction < 0 else "•"
		var meaning := "improved" if direction > 0 else "reduced" if direction < 0 else "changed"
		var source := candidate if not candidate.is_empty() else current
		var label := String(source.get("display_name", type_id.replace("_", " ").capitalize()))
		var text := "%s %s Base Damage %s-%s -> %s-%s — %s" % [
			symbol, label,
			_number(before_minimum), _number(before_maximum),
			_number(after_minimum), _number(after_maximum), meaning,
		]
		result.append({
			"row_type": "base_damage",
			"stat_id": StringName("base_damage:%s" % type_id),
			"damage_type_id": StringName(type_id),
			"presentation_color": source.get("presentation_color", Color.WHITE),
			"before_minimum": before_minimum,
			"before_maximum": before_maximum,
			"after_minimum": after_minimum,
			"after_maximum": after_maximum,
			"delta": delta,
			"direction": direction,
			"text": text,
			"accessible_text": "%s; %s" % [text, meaning],
		})
	return result


static func _base_damage_by_type(components: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in components:
		if not value is Dictionary:
			continue
		var component := value as Dictionary
		var type_id := String(component.get("damage_type_id", ""))
		if not type_id.is_empty():
			result[type_id] = component.duplicate(true)
	return result


static func _raw_delta_text(stat_id: String, operation: int, delta: float, raw_direction: int) -> String:
	return "- %s %s: %s %s -- benefit unknown" % [
		_raw_stat_name(stat_id),
		_fallback_value_label(stat_id, operation),
		_raw_display_value(stat_id, operation, delta),
		_raw_direction_word(raw_direction),
	]


static func _raw_delta_accessible_text(stat_id: String, operation: int, delta: float, raw_direction: int) -> String:
	return "%s %s is %s %s; benefit unknown; neutral comparison" % [
		_raw_stat_name(stat_id),
		_fallback_value_label(stat_id, operation),
		_raw_display_value(stat_id, operation, delta),
		_raw_direction_word(raw_direction),
	]


static func _raw_stat_name(stat_id: String) -> String:
	var definition := GameCatalog.STAT_CATALOG.definition(StringName(stat_id))
	return definition.display_name if definition != null else stat_id.replace("_", " ").capitalize()


static func _raw_display_value(stat_id: String, operation: int, delta: float) -> String:
	if operation == StatModifier.Operation.FLAT:
		var definition := GameCatalog.STAT_CATALOG.definition(StringName(stat_id))
		if definition != null:
			return definition.format_modifier_value(absf(delta))
	return "%s%s" % [_number(absf(delta if operation == StatModifier.Operation.FLAT else delta * 100.0)), "" if operation == StatModifier.Operation.FLAT else "%"]


static func _fallback_value_label(stat_id: String, operation: int) -> String:
	var definition := GameCatalog.STAT_CATALOG.definition(StringName(stat_id))
	if operation == StatModifier.Operation.FLAT and definition != null and definition.value_format == StatDefinition.ValueFormat.RATIO_PERCENT:
		return "item modifier"
	return "raw %s roll" % _operation_name(operation)


static func _operation_name(operation: int) -> String:
	match operation:
		StatModifier.Operation.FLAT:
			return "flat"
		StatModifier.Operation.INCREASED:
			return "increased"
		StatModifier.Operation.REDUCED:
			return "reduced"
		StatModifier.Operation.MORE:
			return "more"
		StatModifier.Operation.LESS:
			return "less"
		_:
			return "unknown"


static func _raw_direction_word(raw_direction: int) -> String:
	return "higher" if raw_direction > 0 else "lower" if raw_direction < 0 else "unchanged"


static func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")
