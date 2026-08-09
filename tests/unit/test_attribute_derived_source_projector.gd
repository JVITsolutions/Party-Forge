extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tuning_script := load("res://scripts/stats/attribute_projection_tuning.gd") as Script
	var projector_script := load("res://scripts/stats/attribute_derived_source_projector.gd") as Script
	var default_tuning := load("res://data/stats/default_attribute_projection.tres") as Resource
	TestAssertions.truthy(tuning_script != null and tuning_script.can_instantiate(), "attribute projection tuning script is valid", failures)
	TestAssertions.truthy(projector_script != null and projector_script.can_instantiate(), "attribute projector script is valid", failures)
	TestAssertions.truthy(default_tuning != null, "default attribute projection tuning loads", failures)
	if (
		tuning_script == null
		or not tuning_script.can_instantiate()
		or projector_script == null
		or not projector_script.can_instantiate()
		or default_tuning == null
	):
		return failures
	var raw := _raw_attributes()
	var projection: Variant = projector_script.project(7, raw, default_tuning)
	TestAssertions.truthy(projection != null and projection.ok(), "valid attributes project", failures)
	if projection != null and projection.ok():
		TestAssertions.equal(projection.source.id, &"attribute_projection_7", "projection source has stable ID", failures)
		TestAssertions.equal(projection.source.owner_member_id, 7, "projection source belongs to member", failures)
		_assert_modifier(projection.source, &"melee_damage", 0.20, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"armor", 2.5, StatModifier.Operation.FLAT, failures)
		_assert_modifier(projection.source, &"ranged_damage", 0.16, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"attack_speed", 0.04, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"dodge_chance", 0.008, StatModifier.Operation.FLAT, failures)
		_assert_modifier(projection.source, &"max_health", 18.0, StatModifier.Operation.FLAT, failures)
		_assert_modifier(projection.source, &"health_regeneration", 0.30, StatModifier.Operation.FLAT, failures)
		_assert_modifier(projection.source, &"caster_damage", 0.08, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"area_size", 0.03, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"healing_power", 0.04, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"cooldown_rate", 0.01, StatModifier.Operation.INCREASED, failures)
		_assert_modifier(projection.source, &"party_influence", 3.0, StatModifier.Operation.FLAT, failures)

	_assert_projection_error(projector_script.project(0, raw, default_tuning), "zero member ID is rejected", failures)
	_assert_projection_error(projector_script.project(7, null, default_tuning), "missing raw snapshot is rejected", failures)

	var non_finite_raw := _raw_attributes()
	non_finite_raw.set_resolved(&"wisdom", INF, [])
	_assert_projection_error(projector_script.project(7, non_finite_raw, default_tuning), "non-finite attribute is rejected", failures)

	var negative_tuning: Resource = tuning_script.new()
	negative_tuning.melee_damage_per_strength = -0.01
	_assert_projection_error(projector_script.project(7, raw, negative_tuning), "negative tuning is rejected", failures)
	var non_finite_tuning: Resource = tuning_script.new()
	non_finite_tuning.armor_per_strength = NAN
	_assert_projection_error(projector_script.project(7, raw, non_finite_tuning), "non-finite tuning is rejected", failures)

	var invalid_modifier := StatModifier.create(
		&"strength",
		StatModifier.Operation.FLAT,
		1.0,
		&"attribute_projection_7_strength",
		"Attribute Projection",
	)
	var invalid_source := StatModifierSource.create(
		&"attribute_projection_7",
		&"attribute_projection",
		"Attribute Projection",
		7,
		[invalid_modifier],
	)
	var source_error: String = projector_script.validate_source(invalid_source)
	TestAssertions.truthy(
		source_error.begins_with("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR"),
		"projector source cannot target a core attribute",
		failures,
	)
	return failures

func _raw_attributes() -> ResolvedStatSnapshot:
	var raw := ResolvedStatSnapshot.new()
	raw.set_resolved(&"strength", 10.0, [])
	raw.set_resolved(&"dexterity", 8.0, [])
	raw.set_resolved(&"constitution", 6.0, [])
	raw.set_resolved(&"intelligence", 4.0, [])
	raw.set_resolved(&"wisdom", 2.0, [])
	raw.set_resolved(&"charisma", 3.0, [])
	return raw

func _assert_modifier(
	source: StatModifierSource,
	stat_id: StringName,
	expected_value: float,
	expected_operation: StatModifier.Operation,
	failures: Array[String],
) -> void:
	var modifier := _modifier(source, stat_id)
	TestAssertions.truthy(modifier != null, "%s modifier exists" % stat_id, failures)
	if modifier == null:
		return
	TestAssertions.near(modifier.value, expected_value, 0.0001, "%s projects approved value" % stat_id, failures)
	TestAssertions.equal(modifier.operation, expected_operation, "%s uses approved operation" % stat_id, failures)
	TestAssertions.equal(
		modifier.source_id,
		StringName("attribute_projection_7_%s" % stat_id),
		"%s modifier has stable ID" % stat_id,
		failures,
	)

func _modifier(source: StatModifierSource, stat_id: StringName) -> StatModifier:
	for modifier: StatModifier in source.modifiers:
		if modifier != null and modifier.stat_id == stat_id:
			return modifier
	return null

func _assert_projection_error(result: Variant, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(result != null, "%s returns a result" % label, failures)
	if result == null:
		return
	TestAssertions.truthy(not result.ok(), label, failures)
	TestAssertions.truthy(result.source == null, "%s returns no source" % label, failures)
	TestAssertions.truthy(
		result.error.begins_with("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR"),
		"%s uses stable error marker" % label,
		failures,
	)
