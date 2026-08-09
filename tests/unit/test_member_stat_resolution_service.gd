extends RefCounted

const DEFAULT_TUNING: AttributeProjectionTuning = preload("res://data/stats/default_attribute_projection.tres")
const STAT_CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")

func run() -> Array[String]:
	var failures: Array[String] = []
	var service_path := "res://scripts/stats/member_stat_resolution_service.gd"
	TestAssertions.truthy(ResourceLoader.exists(service_path), "member stat resolution service exists", failures)
	if not ResourceLoader.exists(service_path):
		return failures
	var service_script := load(service_path) as Script
	TestAssertions.truthy(service_script != null and service_script.can_instantiate(), "member stat resolution service script is valid", failures)
	if service_script == null or not service_script.can_instantiate():
		return failures
	_test_two_pass_resolution_has_no_attribute_feedback(service_script, failures)
	_test_aggregate_raw_and_final_values_must_be_finite(service_script, failures)
	_test_generated_source_id_collision_is_rejected(service_script, failures)
	_test_derived_source_rejects_core_attributes(failures)
	_test_source_validation_contract(failures)
	return failures

func _test_two_pass_resolution_has_no_attribute_feedback(service_script: Script, failures: Array[String]) -> void:
	var source := StatModifierSource.create(&"growth_1", &"growth", "Growth", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 5.0, &"growth_1_strength", "Growth"),
		StatModifier.create(&"melee_damage", StatModifier.Operation.INCREASED, 0.10, &"direct_melee", "Direct"),
	])
	var capabilities: Array[StringName] = [&"melee"]
	var sources: Array[StatModifierSource] = [source]
	var action_tags: Array[StringName] = [&"melee"]
	var result: Variant = service_script.resolve(
		1,
		STAT_CATALOG,
		{},
		capabilities,
		sources,
		action_tags,
		4,
		DEFAULT_TUNING,
	)
	TestAssertions.truthy(result.ok(), "two-pass result is valid", failures)
	if not result.ok():
		return
	TestAssertions.near(result.raw_attributes.value(&"strength"), 5.0, 0.0001, "pass one resolves raw strength", failures)
	TestAssertions.near(result.raw_attributes.value(&"melee_damage"), 1.10, 0.0001, "pass one contains only direct melee scaling", failures)
	TestAssertions.near(result.final_stats.value(&"strength"), 5.0, 0.0001, "pass two does not feed derived values into attributes", failures)
	TestAssertions.near(result.final_stats.value(&"melee_damage"), 1.20, 0.0001, "pass two combines direct and derived melee scaling", failures)
	TestAssertions.equal(result.raw_attributes.revision, 4, "raw snapshot carries the requested revision", failures)
	TestAssertions.equal(result.final_stats.revision, 4, "final snapshot carries the requested revision", failures)
	for modifier: StatModifier in result.derived_source.modifiers:
		TestAssertions.truthy(
			modifier == null or modifier.stat_id not in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
			"resolved derived source contains no core attributes",
			failures,
		)

func _test_aggregate_raw_and_final_values_must_be_finite(service_script: Script, failures: Array[String]) -> void:
	var capabilities: Array[StringName] = []
	var action_tags: Array[StringName] = []
	var raw_sources := _overflowing_more_sources(&"max_health", 1.0e100, 4, &"raw_overflow")
	var raw_snapshot := StatResolver.resolve(7, STAT_CATALOG, {}, capabilities, raw_sources, action_tags, 6)
	var raw_result: Variant = service_script.resolve(
		7, STAT_CATALOG, {}, capabilities, raw_sources, action_tags, 6, DEFAULT_TUNING,
	)
	TestAssertions.truthy(not raw_result.ok(), "finite modifiers whose raw aggregate overflows are rejected", failures)
	TestAssertions.equal(
		raw_result.error,
		_resolution_error(7, &"max_health", "raw", raw_snapshot.value(&"max_health")),
		"raw aggregate overflow returns stable member/stat/stage/value context",
		failures,
	)
	TestAssertions.truthy(
		raw_result.raw_attributes == null and raw_result.derived_source == null and raw_result.final_stats == null,
		"raw aggregate overflow returns no partial resolution",
		failures,
	)

	var final_sources := _overflowing_more_sources(&"max_health", 1.0e30, 4, &"final_overflow")
	var base_values := {&"constitution": 1.0e200}
	var raw_final_snapshot := StatResolver.resolve(8, STAT_CATALOG, base_values, capabilities, final_sources, action_tags, 7)
	var projection := AttributeDerivedSourceProjector.project(8, raw_final_snapshot, DEFAULT_TUNING)
	var combined_sources := final_sources.duplicate()
	combined_sources.append(projection.source)
	var expected_final_snapshot := StatResolver.resolve(8, STAT_CATALOG, base_values, capabilities, combined_sources, action_tags, 7)
	TestAssertions.truthy(is_finite(raw_final_snapshot.value(&"max_health")), "final-stage fixture remains finite before derived projection", failures)
	TestAssertions.truthy(not is_finite(expected_final_snapshot.value(&"max_health")), "final-stage fixture overflows only after derived projection", failures)
	var final_result: Variant = service_script.resolve(
		8, STAT_CATALOG, base_values, capabilities, final_sources, action_tags, 7, DEFAULT_TUNING,
	)
	TestAssertions.truthy(not final_result.ok(), "finite modifiers whose final aggregate overflows are rejected", failures)
	TestAssertions.equal(
		final_result.error,
		_resolution_error(8, &"max_health", "final", expected_final_snapshot.value(&"max_health")),
		"final aggregate overflow returns stable member/stat/stage/value context",
		failures,
	)
	TestAssertions.truthy(
		final_result.raw_attributes == null and final_result.derived_source == null and final_result.final_stats == null,
		"final aggregate overflow returns no partial resolution",
		failures,
	)

func _overflowing_more_sources(
	stat_id: StringName,
	value: float,
	count: int,
	prefix: StringName,
) -> Array[StatModifierSource]:
	var modifiers: Array[StatModifier] = []
	for index: int in count:
		modifiers.append(StatModifier.create(
			stat_id,
			StatModifier.Operation.MORE,
			value,
			StringName("%s_modifier_%d" % [prefix, index]),
			"Aggregate Overflow",
		))
	return [StatModifierSource.create(prefix, &"test", "Aggregate Overflow", 7 if prefix == &"raw_overflow" else 8, modifiers)]

func _resolution_error(member_id: int, stat_id: StringName, stage: String, value: float) -> String:
	return "PARTY_FORGE_STAT_RESOLUTION_ERROR member=%d stat=%s stage=%s value=%s reason=resolved value is non-finite" % [
		member_id, stat_id, stage, str(value),
	]

func _test_generated_source_id_collision_is_rejected(service_script: Script, failures: Array[String]) -> void:
	var colliding_source := StatModifierSource.create(&"attribute_projection_1", &"growth", "Colliding Growth", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"colliding_strength", "Colliding Growth"),
	])
	var capabilities: Array[StringName] = []
	var sources: Array[StatModifierSource] = [colliding_source]
	var action_tags: Array[StringName] = []
	var result: Variant = service_script.resolve(
		1,
		STAT_CATALOG,
		{},
		capabilities,
		sources,
		action_tags,
		5,
		DEFAULT_TUNING,
	)
	TestAssertions.truthy(not result.ok(), "generated source ID collision is rejected", failures)
	TestAssertions.equal(
		result.error,
		"PARTY_FORGE_STAT_ERROR source=attribute_projection_1 stat=<unknown> reason=duplicate source id",
		"generated source ID collision returns the stable validation error",
		failures,
	)
	TestAssertions.truthy(
		result.raw_attributes == null and result.derived_source == null and result.final_stats == null,
		"generated source ID collision returns no partial resolution",
		failures,
	)

func _test_derived_source_rejects_core_attributes(failures: Array[String]) -> void:
	var malicious_source := StatModifierSource.create(&"attribute_projection_1", &"attribute_projection", "Malicious Projection", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 999.0, &"attribute_projection_1_strength", "Malicious Projection"),
	])
	var error := AttributeDerivedSourceProjector.validate_source(malicious_source)
	TestAssertions.truthy(not error.is_empty(), "malicious derived source cannot target an attribute", failures)
	TestAssertions.truthy(error.begins_with("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR"), "malicious derived source returns a structured error", failures)


func _test_source_validation_contract(failures: Array[String]) -> void:
	var valid_modifier := StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"shared_legacy_id", "Valid")
	var valid_source := StatModifierSource.create(&"valid", &"growth", "Valid", 1, [valid_modifier])
	TestAssertions.equal(StatResolver.validate_sources(STAT_CATALOG, [valid_source]), PackedStringArray(), "valid source passes strengthened validation", failures)

	var repeated_modifier_id_source := StatModifierSource.create(&"legacy_repeated", &"legacy", "Legacy", 1, [
		StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"shared_legacy_id", "Legacy"),
		StatModifier.create(&"dexterity", StatModifier.Operation.FLAT, 1.0, &"shared_legacy_id", "Legacy"),
	])
	TestAssertions.equal(
		StatResolver.validate_sources(STAT_CATALOG, [valid_source, repeated_modifier_id_source]),
		PackedStringArray(),
		"legacy repeated modifier source IDs remain supported",
		failures,
	)

	var empty_source := StatModifierSource.create(&"", &"growth", "Empty", 1, [])
	_assert_validation_error(StatResolver.validate_sources(STAT_CATALOG, [empty_source]), "empty source id", "empty source IDs are rejected", failures)
	var duplicate_source := StatModifierSource.create(&"valid", &"growth", "Duplicate", 1, [])
	_assert_validation_error(StatResolver.validate_sources(STAT_CATALOG, [valid_source, duplicate_source]), "duplicate source id", "duplicate source IDs are rejected", failures)

	var empty_modifier_id := StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"", "Empty Modifier ID")
	var empty_modifier_source := StatModifierSource.create(&"empty_modifier", &"growth", "Empty Modifier", 1, [empty_modifier_id])
	_assert_validation_error(StatResolver.validate_sources(STAT_CATALOG, [empty_modifier_source]), "empty modifier source id", "empty modifier source IDs are rejected", failures)

	var unsupported := StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"unsupported", "Unsupported")
	unsupported.operation = 99
	var unsupported_source := StatModifierSource.create(&"unsupported", &"growth", "Unsupported", 1, [unsupported])
	_assert_validation_error(StatResolver.validate_sources(STAT_CATALOG, [unsupported_source]), "unsupported operation", "unsupported operations are rejected", failures)

	var non_finite := StatModifier.create(&"strength", StatModifier.Operation.FLAT, INF, &"non_finite", "Non-finite")
	var non_finite_source := StatModifierSource.create(&"non_finite", &"growth", "Non-finite", 1, [non_finite])
	_assert_validation_error(StatResolver.validate_sources(STAT_CATALOG, [non_finite_source]), "non-finite value", "non-finite values are rejected", failures)

	_assert_validation_error(StatResolver.validate_sources(null, [valid_source]), "catalog is null", "null catalogs are rejected", failures)

func _assert_validation_error(errors: PackedStringArray, expected_reason: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not errors.is_empty(), label, failures)
	if errors.is_empty():
		return
	TestAssertions.truthy(errors[0].contains(expected_reason), "%s uses the expected diagnostic" % label, failures)
