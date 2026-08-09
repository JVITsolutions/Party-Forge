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
	var result: Array[Dictionary] = []
	for key: String in keys:
		var parts := key.split("|", false)
		if parts.size() != 2 or not String(parts[1]).is_valid_int():
			continue
		var stat_id := String(parts[0])
		var operation := int(parts[1])
		var delta := float(inspected_totals.get(key, 0.0)) - float(equipped_totals.get(key, 0.0))
		if is_zero_approx(delta):
			delta = 0.0
		result.append({
			"stat_id": stat_id,
			"operation": operation,
			"delta": delta,
			"direction": 1 if delta > 0.0 else -1 if delta < 0.0 else 0,
			"text": _delta_text(stat_id, operation, delta),
		})
	return result


static func _delta_text(stat_id: String, operation: int, delta: float) -> String:
	var stat_name := stat_id.replace("_", " ").capitalize()
	var display_value := delta if operation == StatModifier.Operation.FLAT else delta * 100.0
	var suffix := "" if operation == StatModifier.Operation.FLAT else "%"
	return "%s%s%s %s" % ["+" if display_value > 0.0 else "", _number(display_value), suffix, stat_name]


static func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")
