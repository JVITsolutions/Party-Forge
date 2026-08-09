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
