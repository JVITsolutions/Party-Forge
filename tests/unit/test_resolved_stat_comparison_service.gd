extends RefCounted

const RESOLVED_SERVICE_PATH := "res://scripts/ui/storage/resolved_stat_comparison_service.gd"
const EQUIPMENT_SERVICE_PATH := "res://scripts/ui/storage/equipment_comparison_projection_service.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(RESOLVED_SERVICE_PATH), "resolved comparison service exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(EQUIPMENT_SERVICE_PATH), "equipment comparison projection service exists", failures)
	if not ResourceLoader.exists(RESOLVED_SERVICE_PATH) or not ResourceLoader.exists(EQUIPMENT_SERVICE_PATH):
		return failures
	var resolved_service: Script = load(RESOLVED_SERVICE_PATH)
	var equipment_service: Script = load(EQUIPMENT_SERVICE_PATH)
	_test_benefit_direction_and_accessible_text(resolved_service, failures)
	_test_delta_formatting_ignores_absolute_stat_bounds(resolved_service, failures)
	_test_attribute_derived_final_stats(resolved_service, failures)
	_test_action_and_disabled_warning_rows(equipment_service, failures)
	_test_healing_action_rows(equipment_service, failures)
	return failures


func _test_benefit_direction_and_accessible_text(service: Script, failures: Array[String]) -> void:
	var higher := _definition(&"power", "Power", StatDefinition.ComparisonDirection.HIGHER_IS_BETTER)
	var lower := _definition(&"delay", "Delay", StatDefinition.ComparisonDirection.LOWER_IS_BETTER)
	var neutral := _definition(&"reach", "Reach", StatDefinition.ComparisonDirection.NEUTRAL)
	var catalog := StatCatalog.new()
	catalog.definitions = [higher, lower, neutral]
	var current := _snapshot({&"power": 10.0, &"delay": 5.0, &"reach": 2.0})
	var candidate := _snapshot({&"power": 12.0, &"delay": 7.0, &"reach": 3.0})
	var rows: Array = service.call("compare", current, candidate, catalog)
	var power := _row(rows, &"power")
	var delay := _row(rows, &"delay")
	var reach := _row(rows, &"reach")
	TestAssertions.equal(power.get("direction"), 1, "higher-is-better gain is beneficial", failures)
	TestAssertions.truthy(String(power.get("text", "")).begins_with("▲"), "benefit has an upward symbol", failures)
	TestAssertions.truthy("improved" in String(power.get("accessible_text", "")).to_lower(), "benefit accessibility says improved", failures)
	TestAssertions.equal(delay.get("direction"), -1, "lower-is-better increase is harmful", failures)
	TestAssertions.truthy(String(delay.get("text", "")).begins_with("▼"), "loss has a downward symbol", failures)
	TestAssertions.truthy("reduced" in String(delay.get("accessible_text", "")).to_lower(), "loss accessibility says reduced", failures)
	TestAssertions.equal(reach.get("direction"), 0, "neutral metadata keeps a neutral direction", failures)
	TestAssertions.truthy(String(reach.get("text", "")).begins_with("•"), "neutral change has a non-color symbol", failures)


func _test_delta_formatting_ignores_absolute_stat_bounds(service: Script, failures: Array[String]) -> void:
	var current := _snapshot({&"attack_speed": 1.0, &"crit_multiplier": 1.5})
	var candidate := _snapshot({&"attack_speed": 1.02, &"crit_multiplier": 1.6})
	var rows: Array = service.call("compare", current, candidate, GameCatalog.STAT_CATALOG)
	TestAssertions.truthy(String(_row(rows, &"attack_speed").get("text", "")).contains("+0.02x Attack Speed"), "attack-speed delta is formatted without the absolute minimum clamp", failures)
	TestAssertions.truthy(String(_row(rows, &"crit_multiplier").get("text", "")).contains("+10% Critical Strike Multiplier"), "ratio delta is formatted as a percent without the absolute minimum clamp", failures)


func _test_attribute_derived_final_stats(service: Script, failures: Array[String]) -> void:
	var current := _snapshot({
		&"melee_damage": 1.0,
		&"ranged_damage": 1.0,
		&"caster_damage": 1.0,
		&"armor": 4.0,
		&"max_health": 100.0,
	})
	var candidate := _snapshot({
		&"melee_damage": 1.10,
		&"ranged_damage": 1.08,
		&"caster_damage": 1.06,
		&"armor": 5.25,
		&"max_health": 109.0,
	})
	var rows: Array = service.call("compare", current, candidate, GameCatalog.STAT_CATALOG)
	for stat_id: StringName in [&"melee_damage", &"ranged_damage", &"caster_damage", &"armor", &"max_health"]:
		var row := _row(rows, stat_id)
		TestAssertions.truthy(not row.is_empty(), "final comparison includes %s" % stat_id, failures)
		TestAssertions.equal(row.get("direction"), 1, "%s final change is beneficial" % stat_id, failures)


func _test_action_and_disabled_warning_rows(service: Script, failures: Array[String]) -> void:
	var current_stats := _snapshot({&"armor": 4.0})
	var candidate_stats := _snapshot({&"armor": 5.0})
	var current_estimate := ActionCombatEstimate.new()
	current_estimate.action_id = &"fighter_slash"
	current_estimate.display_name = "Fighter Slash"
	current_estimate.available = true
	current_estimate.average_hit = 10.0
	current_estimate.estimated_dps = 20.0
	var supports_geometry := _has_property(current_estimate, &"range") and _has_property(current_estimate, &"area_radius") and _has_property(current_estimate, &"projectile_speed")
	TestAssertions.truthy(supports_geometry, "comparison estimates expose effective geometry fields", failures)
	if supports_geometry:
		current_estimate.set("range", 8.0)
		current_estimate.set("area_radius", 1.5)
		current_estimate.set("projectile_speed", 10.0)
	var candidate_estimate := ActionCombatEstimate.new()
	candidate_estimate.action_id = &"fighter_slash"
	candidate_estimate.display_name = "Fighter Slash"
	candidate_estimate.available = true
	candidate_estimate.average_hit = 12.0
	candidate_estimate.estimated_dps = 24.0
	if supports_geometry:
		candidate_estimate.set("range", 12.0)
		candidate_estimate.set("area_radius", 2.25)
		candidate_estimate.set("projectile_speed", 15.0)
	var current_activation := _activation(["support", "dependent"], {})
	var candidate_activation := _activation(["candidate"], {"dependent": PackedStringArray(["Requires Strength 15 (has 10)"])})
	var rows: Array = service.call(
		"compare",
		current_stats,
		candidate_stats,
		GameCatalog.STAT_CATALOG,
		[current_estimate],
		[candidate_estimate],
		current_activation,
		candidate_activation,
		"candidate",
		{"dependent": "Dependent Plate"},
	)
	TestAssertions.truthy(rows.any(func(row: Dictionary) -> bool:
		return String(row.get("row_type", "")) == "action" and String(row.get("text", "")).contains("Average Hit") and int(row.get("direction", 0)) == 1
	), "action average-hit improvement is projected", failures)
	TestAssertions.truthy(rows.any(func(row: Dictionary) -> bool:
		return String(row.get("row_type", "")) == "action" and String(row.get("text", "")).contains("DPS") and int(row.get("direction", 0)) == 1
	), "action DPS improvement is projected", failures)
	if supports_geometry:
		for geometry_label: String in ["Range", "Area", "Projectile Speed"]:
			TestAssertions.truthy(rows.any(func(row: Dictionary) -> bool:
				return String(row.get("row_type", "")) == "action" and String(row.get("text", "")).contains(geometry_label) and "improved" in String(row.get("accessible_text", "")).to_lower()
			), "action %s improvement is projected accessibly" % geometry_label, failures)
	var warning := rows.filter(func(row: Dictionary) -> bool: return String(row.get("row_type", "")) == "warning")
	TestAssertions.equal(warning.size(), 1, "newly disabled equipment adds one prominent warning", failures)
	if not warning.is_empty():
		TestAssertions.equal(warning[0].get("direction"), -1, "disabled warning is harmful", failures)
		TestAssertions.truthy(String(warning[0].get("text", "")).begins_with("▼ Warning:"), "disabled warning has symbol and prominence", failures)
		TestAssertions.truthy(String(warning[0].get("accessible_text", "")).contains("Dependent Plate") and String(warning[0].get("accessible_text", "")).contains("Requires Strength 15 (has 10)"), "disabled warning names item and exact requirement", failures)


func _test_healing_action_rows(service: Script, failures: Array[String]) -> void:
	var current := _healing_estimate(50.0, 1.0, 50.0, 10.0)
	var improved := _healing_estimate(60.0, 1.25, 75.0, 10.0)
	var improved_rows: Array = service.call(
		"compare", ResolvedStatSnapshot.new(), ResolvedStatSnapshot.new(), GameCatalog.STAT_CATALOG,
		[current], [improved],
	)
	for expected: Dictionary in [
		{"stat_id": &"action:cleric_heal:healing_amount", "label": "Healing / Use", "delta": 10.0},
		{"stat_id": &"action:cleric_heal:uses_per_second", "label": "Uses / Second", "delta": 0.25},
		{"stat_id": &"action:cleric_heal:estimated_hps", "label": "Estimated HPS", "delta": 25.0},
	]:
		var row := _row(improved_rows, expected["stat_id"])
		TestAssertions.near(float(row.get("delta", 0.0)), float(expected["delta"]), 0.0001, "%s increase uses the shared estimate delta" % expected["label"], failures)
		TestAssertions.equal(row.get("direction"), 1, "%s increase is beneficial" % expected["label"], failures)
		TestAssertions.truthy(not String(row.get("text", "")).begins_with("Cleric Heal") and String(row.get("text", "")).contains(expected["label"]), "%s increase has a visible prefix indicator" % expected["label"], failures)
		TestAssertions.truthy("improved" in String(row.get("accessible_text", "")).to_lower(), "%s increase exposes accessible benefit wording" % expected["label"], failures)

	var reduced := _healing_estimate(40.0, 0.75, 30.0, 10.0)
	var reduced_rows: Array = service.call(
		"compare", ResolvedStatSnapshot.new(), ResolvedStatSnapshot.new(), GameCatalog.STAT_CATALOG,
		[current], [reduced],
	)
	for stat_id: StringName in [
		&"action:cleric_heal:healing_amount",
		&"action:cleric_heal:uses_per_second",
		&"action:cleric_heal:estimated_hps",
	]:
		var row := _row(reduced_rows, stat_id)
		TestAssertions.equal(row.get("direction"), -1, "%s decrease is harmful" % stat_id, failures)
		TestAssertions.truthy(not String(row.get("text", "")).begins_with("Cleric Heal"), "%s decrease has a visible prefix indicator" % stat_id, failures)
		TestAssertions.truthy("reduced" in String(row.get("accessible_text", "")).to_lower(), "%s decrease exposes accessible loss wording" % stat_id, failures)

	var geometry_only := _healing_estimate(50.0, 1.0, 50.0, 12.0)
	var geometry_rows: Array = service.call(
		"compare", ResolvedStatSnapshot.new(), ResolvedStatSnapshot.new(), GameCatalog.STAT_CATALOG,
		[current], [geometry_only],
	)
	TestAssertions.truthy(not _row(geometry_rows, &"action:cleric_heal:range").is_empty(), "geometry-only healing change keeps its range row", failures)
	for stat_id: StringName in [
		&"action:cleric_heal:healing_amount",
		&"action:cleric_heal:uses_per_second",
		&"action:cleric_heal:estimated_hps",
	]:
		TestAssertions.truthy(_row(geometry_rows, stat_id).is_empty(), "geometry-only healing change does not invent %s drift" % stat_id, failures)


func _healing_estimate(healing_amount: float, uses_per_second: float, hps: float, action_range: float) -> ActionCombatEstimate:
	var result := ActionCombatEstimate.new()
	result.action_id = &"cleric_heal"
	result.display_name = "Cleric Heal"
	result.available = true
	result.is_healing = true
	result.healing_amount = healing_amount
	result.attacks_per_second = uses_per_second
	result.estimated_hps = hps
	result.range = action_range
	return result


func _definition(id: StringName, display_name: String, direction: int) -> StatDefinition:
	var result := StatDefinition.new()
	result.id = id
	result.display_name = display_name
	result.ui_group = &"test"
	result.keyword_id = id
	result.precision = 1
	result.comparison_direction = direction
	return result


func _snapshot(values: Dictionary) -> ResolvedStatSnapshot:
	var result := ResolvedStatSnapshot.new()
	for stat_id: Variant in values:
		result.set_resolved(StringName(String(stat_id)), float(values[stat_id]), [])
	return result


func _activation(active_ids: Array[String], disabled: Dictionary) -> EquipmentActivationResult:
	var raw := ResolvedStatSnapshot.new()
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		raw.set_resolved(attribute_id, 0.0, [])
	return EquipmentActivationResult.success(
		active_ids,
		disabled,
		raw,
		StatModifierSource.create(&"equipment_member_1", &"equipment", "Equipment", 1, []),
	)


func _row(rows: Array, stat_id: StringName) -> Dictionary:
	for value: Variant in rows:
		if value is Dictionary and StringName(String((value as Dictionary).get("stat_id", ""))) == stat_id:
			return value as Dictionary
	return {}


func _has_property(object: Object, property_name: StringName) -> bool:
	return object != null and object.get_property_list().any(
		func(property: Dictionary) -> bool: return property.get("name") == property_name
	)
