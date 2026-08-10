class_name EquipmentComparisonProjectionService
extends RefCounted

const RESOLVED_COMPARISONS := preload("res://scripts/ui/storage/resolved_stat_comparison_service.gd")
const ITEM_COMPARISONS := preload("res://scripts/ui/storage/item_comparison_resolver.gd")


static func compare(
	current_stats: ResolvedStatSnapshot,
	candidate_stats: ResolvedStatSnapshot,
	catalog: StatCatalog,
	current_action_estimates: Array = [],
	candidate_action_estimates: Array = [],
	current_activation: EquipmentActivationResult = null,
	candidate_activation: EquipmentActivationResult = null,
	candidate_item_id: String = "",
	item_labels: Dictionary = {},
	disabled_requirement_lines_by_item: Dictionary = {},
	damage_types: DamageTypeCatalog = GameCatalog.DAMAGE_TYPES,
) -> Array[Dictionary]:
	var result := RESOLVED_COMPARISONS.compare(current_stats, candidate_stats, catalog)
	_append_base_damage_rows(result, current_activation, candidate_activation, damage_types)
	_append_action_rows(result, current_action_estimates, candidate_action_estimates)
	_append_activation_rows(result, current_activation, candidate_activation, candidate_item_id, item_labels, disabled_requirement_lines_by_item)
	return result


static func _append_base_damage_rows(
	result: Array[Dictionary],
	current_activation: EquipmentActivationResult,
	candidate_activation: EquipmentActivationResult,
	damage_types: DamageTypeCatalog,
) -> void:
	if current_activation == null or candidate_activation == null or damage_types == null:
		return
	var current := _project_weapon_components(current_activation.weapon_snapshot(), damage_types)
	var candidate := _project_weapon_components(candidate_activation.weapon_snapshot(), damage_types)
	result.append_array(ITEM_COMPARISONS.base_damage_delta_rows(candidate, current))


static func _project_weapon_components(snapshot: ActiveWeaponDamageSnapshot, damage_types: DamageTypeCatalog) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if snapshot == null:
		return result
	for component: ItemBaseDamageComponent in snapshot.components:
		if component == null:
			continue
		var definition := damage_types.definition(component.damage_type_id)
		if definition == null:
			continue
		result.append({
			"damage_type_id": String(component.damage_type_id),
			"display_name": definition.display_name,
			"presentation_color": definition.presentation_color,
			"minimum_damage": component.minimum_damage,
			"maximum_damage": component.maximum_damage,
		})
	return result


static func _append_action_rows(result: Array[Dictionary], current_values: Array, candidate_values: Array) -> void:
	var current_by_id := _action_by_id(current_values)
	var candidate_by_id := _action_by_id(candidate_values)
	var action_ids: Array[String] = []
	for key: Variant in current_by_id:
		action_ids.append(String(key))
	for key: Variant in candidate_by_id:
		var id := String(key)
		if id not in action_ids:
			action_ids.append(id)
	action_ids.sort()
	for action_id: String in action_ids:
		var current := current_by_id.get(action_id) as ActionCombatEstimate
		var candidate := candidate_by_id.get(action_id) as ActionCombatEstimate
		if current == null or candidate == null or not current.available or not candidate.available:
			continue
		var label := candidate.display_name if not candidate.display_name.is_empty() else action_id.replace("_", " ").capitalize()
		if current.is_healing and candidate.is_healing:
			_append_action_row(result, action_id, label, "healing_amount", "Healing / Use", current.healing_amount, candidate.healing_amount)
			_append_action_row(result, action_id, label, "uses_per_second", "Uses / Second", current.attacks_per_second, candidate.attacks_per_second)
			_append_action_row(result, action_id, label, "estimated_hps", "Estimated HPS", current.estimated_hps, candidate.estimated_hps)
		elif not current.is_healing and not candidate.is_healing:
			_append_action_row(result, action_id, label, "normal_hit", "Normal Hit", current.normal_hit, candidate.normal_hit)
			_append_action_row(result, action_id, label, "critical_hit", "Critical Hit", current.critical_hit, candidate.critical_hit)
			_append_action_row(result, action_id, label, "average_hit", "Average Hit", current.average_hit, candidate.average_hit)
			_append_action_row(result, action_id, label, "attacks_per_second", "Attacks / Second", current.attacks_per_second, candidate.attacks_per_second)
			_append_action_row(result, action_id, label, "estimated_dps", "DPS", current.estimated_dps, candidate.estimated_dps)
		_append_action_row(result, action_id, label, "range", "Range", current.range, candidate.range)
		if current.area_radius > 0.0 or candidate.area_radius > 0.0:
			_append_action_row(result, action_id, label, "area_radius", "Area Radius", current.area_radius, candidate.area_radius)
		if current.projectile_speed > 0.0 or candidate.projectile_speed > 0.0:
			_append_action_row(result, action_id, label, "projectile_speed", "Projectile Speed", current.projectile_speed, candidate.projectile_speed)


static func _append_action_row(
	result: Array[Dictionary],
	action_id: String,
	action_label: String,
	field: String,
	field_label: String,
	before: float,
	after: float,
) -> void:
	if not is_finite(before) or not is_finite(after):
		return
	var delta := after - before
	if is_zero_approx(delta):
		return
	var direction := 1 if delta > 0.0 else -1
	var symbol := "▲" if direction > 0 else "▼"
	var meaning := "improved" if direction > 0 else "reduced"
	var text := "%s %s %s %s%s — %s" % [symbol, action_label, field_label, "+" if delta > 0.0 else "", _number(delta), meaning]
	result.append({
		"row_type": "action",
		"stat_id": StringName("action:%s:%s" % [action_id, field]),
		"action_id": StringName(action_id),
		"delta": delta,
		"direction": direction,
		"text": text,
		"accessible_text": "%s; %s" % [text, meaning],
	})


static func _append_activation_rows(
	result: Array[Dictionary],
	current: EquipmentActivationResult,
	candidate: EquipmentActivationResult,
	candidate_item_id: String,
	item_labels: Dictionary,
	disabled_requirement_lines_by_item: Dictionary,
) -> void:
	if current == null or candidate == null or not current.ok() or not candidate.ok():
		return
	for item_id: String in current.active_item_ids:
		if item_id == candidate_item_id or candidate.is_active(item_id):
			continue
		var reasons := PackedStringArray(disabled_requirement_lines_by_item.get(item_id, candidate.disabled_reasons(item_id)))
		if reasons.is_empty():
			continue
		var label := String(item_labels.get(item_id, item_id))
		var text := "▼ Warning: %s becomes disabled — %s" % [label, "; ".join(reasons)]
		result.append({
			"row_type": "warning",
			"stat_id": StringName("equipment_disabled:%s" % item_id),
			"item_id": item_id,
			"delta": -1.0,
			"direction": -1,
			"text": text,
			"accessible_text": "%s; reduced equipment effectiveness" % text,
		})
	for item_id: String in candidate.active_item_ids:
		if item_id == candidate_item_id or current.is_active(item_id) or current.disabled_reasons(item_id).is_empty():
			continue
		var label := String(item_labels.get(item_id, item_id))
		var text := "▲ %s becomes active — improved" % label
		result.append({
			"row_type": "status",
			"stat_id": StringName("equipment_active:%s" % item_id),
			"item_id": item_id,
			"delta": 1.0,
			"direction": 1,
			"text": text,
			"accessible_text": "%s; improved equipment effectiveness" % text,
		})


static func _action_by_id(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in values:
		var estimate := value as ActionCombatEstimate
		if estimate != null and not estimate.action_id.is_empty():
			result[String(estimate.action_id)] = estimate
	return result


static func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")
