extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const REPORT_PATH := "res://scripts/items/item_generation_balance_report.gd"
const EVIDENCE_PATH := "res://docs/validation/evidence/2026-08-10-weighted-loot-production-balance.json"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	var report_script := load(REPORT_PATH) as Script
	TestAssertions.truthy(equipment != null, "balance report equipment catalog loads", failures)
	TestAssertions.truthy(foundation != null, "balance report foundation catalog loads", failures)
	TestAssertions.truthy(report_script != null, "balance report service loads", failures)
	if equipment == null or foundation == null or report_script == null:
		return failures
	_test_markdown_table_escaping(report_script, failures)
	var required_methods: Array[StringName] = [
		&"build_bounded", &"percentile_summary", &"production_evidence_errors", &"scenario_identity",
	]
	for method: StringName in required_methods:
		TestAssertions.truthy(report_script.has_method(method), "balance report exposes %s" % method, failures)
	if required_methods.any(func(method: StringName) -> bool: return not report_script.has_method(method)):
		return failures
	_test_input_validation(report_script, equipment, foundation, failures)
	_test_percentile_convention(report_script, failures)
	_test_scenario_identity(report_script, equipment, foundation, failures)
	_test_production_evidence_validator_regressions(report_script, failures)
	_test_bounded_repeat_and_unique_ids(report_script, equipment, foundation, failures)
	_test_live_reachability_and_natural_order(report_script, equipment, foundation, failures)
	_test_generated_charisma_evidence(report_script, equipment, foundation, failures)
	return failures

func _test_input_validation(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var no_requests: Array[ItemGenerationRequest] = []
	var missing_equipment: Dictionary = report_script.call(&"build_bounded", null, foundation, no_requests, 1)
	TestAssertions.equal(missing_equipment.get("status", ""), "error", "missing equipment is rejected", failures)
	TestAssertions.equal((missing_equipment.get("summary", {}) as Dictionary).get("attempted", -1), 0, "missing equipment attempts no samples", failures)
	var missing_foundation: Dictionary = report_script.call(&"build_bounded", equipment, null, no_requests, 1)
	TestAssertions.equal(missing_foundation.get("status", ""), "error", "missing foundation is rejected", failures)
	var missing_requests: Dictionary = report_script.call(&"build_bounded", equipment, foundation, no_requests, 1)
	TestAssertions.equal(missing_requests.get("status", ""), "error", "empty request matrix is rejected", failures)
	var invalid := ItemGenerationRequest.create(19, 0, 0, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	var invalid_requests: Array[ItemGenerationRequest] = [invalid]
	var invalid_report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, invalid_requests, 1)
	TestAssertions.equal(invalid_report.get("status", ""), "error", "invalid request is rejected before sampling", failures)
	TestAssertions.equal((invalid_report.get("summary", {}) as Dictionary).get("attempted", -1), 0, "invalid request attempts no samples", failures)
	var oversized_requests: Array[ItemGenerationRequest] = [_request(91, 0.0, 0.0)]
	var oversized_report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, oversized_requests, 2001)
	TestAssertions.equal(oversized_report.get("status", ""), "error", "bounded reports reject production-exceeding row sizes", failures)

func _test_markdown_table_escaping(report_script: Script, failures: Array[String]) -> void:
	var scenario_key := "alpha|beta\\gamma\nnext"
	var report := {
		"aggregates": {},
		"configuration": {"scenario_count": 1, "sequences_per_row": 1},
		"manifest": {},
		"scenarios": [{
			"attempted": 1,
			"average_explicit_tier": 1.0,
			"failed": 0,
			"key": scenario_key,
			"label": scenario_key,
			"succeeded": 1,
			"weapon_damage_percentiles": {"sample_count": 0},
		}],
		"schema_version": 2,
		"status": "ok",
		"summary": {"attempted": 1, "failed": 0, "succeeded": 1},
	}
	var markdown: String = report_script.call(&"to_markdown", report)
	TestAssertions.truthy(markdown.contains("alpha\\|beta\\\\gamma<br>next"), "Markdown escapes pipes, backslashes, and newlines in cells", failures)
	var lines := markdown.split("\n")
	var header_columns := -1
	var scenario_rows := 0
	for line: String in lines:
		if line.begins_with("| Scenario |"):
			header_columns = _markdown_column_count(line)
		elif header_columns > 0 and line.begins_with("| ") and not line.begins_with("|---"):
			if line.contains("alpha"):
				scenario_rows += 1
				TestAssertions.equal(_markdown_column_count(line), header_columns, "escaped scenario row preserves header column count", failures)
	TestAssertions.equal(scenario_rows, 1, "escaped scenario renders on exactly one table row", failures)

func _test_percentile_convention(report_script: Script, failures: Array[String]) -> void:
	var even: Dictionary = report_script.call(&"percentile_summary", [1.0, 3.0])
	TestAssertions.near(float(even.get("minimum", -1.0)), 1.0, 0.000001, "P0 uses the minimum", failures)
	TestAssertions.near(float(even.get("median", -1.0)), 2.0, 0.000001, "even median uses linear interpolation", failures)
	TestAssertions.near(float(even.get("high", -1.0)), 2.8, 0.000001, "P90 uses linear interpolation", failures)
	var odd: Dictionary = report_script.call(&"percentile_summary", [3.0, 1.0, 2.0])
	TestAssertions.near(float(odd.get("median", -1.0)), 2.0, 0.000001, "odd median selects the center", failures)
	TestAssertions.near(float(odd.get("high", -1.0)), 2.8, 0.000001, "odd P90 interpolates adjacent ranks", failures)

func _test_scenario_identity(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var original := _request(701, 0.0, 0.0)
	var identities: Array[String] = [String(report_script.call(&"scenario_identity", original))]
	var variants: Array[ItemGenerationRequest] = []
	var seed_variant := original.copy_with_sequence(original.generation_sequence)
	seed_variant.seed += 1
	variants.append(seed_variant)
	var sequence_variant := original.copy_with_sequence(original.generation_sequence + 1)
	TestAssertions.equal(report_script.call(&"scenario_identity", sequence_variant), identities[0], "report-owned sample sequence is normalized out of scenario identity", failures)
	var level_variant := original.copy_with_sequence(original.generation_sequence)
	level_variant.item_level += 1
	variants.append(level_variant)
	var source_variant := original.copy_with_sequence(original.generation_sequence)
	source_variant.source_id = &"boss"
	variants.append(source_variant)
	var domain_variant := original.copy_with_sequence(original.generation_sequence)
	domain_variant.generation_domain = &"boss_drop"
	variants.append(domain_variant)
	var difficulty_variant := original.copy_with_sequence(original.generation_sequence)
	difficulty_variant.difficulty_id = &"hard"
	variants.append(difficulty_variant)
	var heat_variant := original.copy_with_sequence(original.generation_sequence)
	heat_variant.heat = 25.0
	variants.append(heat_variant)
	var rarity_variant := original.copy_with_sequence(original.generation_sequence)
	rarity_variant.permitted_rarity_ids = [&"uncommon"]
	variants.append(rarity_variant)
	var charisma_variant := original.copy_with_sequence(original.generation_sequence)
	charisma_variant.charisma_value = 100.0
	variants.append(charisma_variant)
	var tags_variant := original.copy_with_sequence(original.generation_sequence)
	tags_variant.party_archetype_tags = [&"melee"]
	variants.append(tags_variant)
	var unlock_variant := original.copy_with_sequence(original.generation_sequence)
	unlock_variant.unlock_tags = [&"rarity_rare_unlocked"]
	variants.append(unlock_variant)
	var required_base_variant := original.copy_with_sequence(original.generation_sequence)
	required_base_variant.required_base_tags = [&"weapon"]
	variants.append(required_base_variant)
	var excluded_base_variant := original.copy_with_sequence(original.generation_sequence)
	excluded_base_variant.excluded_base_tags = [&"shield"]
	variants.append(excluded_base_variant)
	var required_affix_variant := original.copy_with_sequence(original.generation_sequence)
	required_affix_variant.required_affix_tags = [&"weapon"]
	variants.append(required_affix_variant)
	var excluded_affix_variant := original.copy_with_sequence(original.generation_sequence)
	excluded_affix_variant.excluded_affix_tags = [&"shield"]
	variants.append(excluded_affix_variant)
	var forced_base_variant := original.copy_with_sequence(original.generation_sequence)
	forced_base_variant.forced_base_id = &"forge_vanguard_hammer"
	variants.append(forced_base_variant)
	var forced_rarity_variant := original.copy_with_sequence(original.generation_sequence)
	forced_rarity_variant.forced_rarity_id = &"rare"
	variants.append(forced_rarity_variant)
	for variant: ItemGenerationRequest in variants:
		identities.append(String(report_script.call(&"scenario_identity", variant)))
	var unique: Dictionary = {}
	for identity: String in identities:
		unique[identity] = true
	TestAssertions.equal(unique.size(), identities.size(), "identity changes independently for every canonical request field that affects report generation", failures)
	var reordered := original.copy_with_sequence(original.generation_sequence)
	reordered.permitted_rarity_ids = [&"rare", &"uncommon"]
	var canonical_order := original.copy_with_sequence(original.generation_sequence)
	canonical_order.permitted_rarity_ids = [&"uncommon", &"rare"]
	TestAssertions.equal(report_script.call(&"scenario_identity", reordered), report_script.call(&"scenario_identity", canonical_order), "identity normalizes collection order", failures)
	var duplicates: Array[ItemGenerationRequest] = [original, original.copy_with_sequence(original.generation_sequence)]
	var duplicate_report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, duplicates, 2)
	TestAssertions.equal(duplicate_report.get("status", ""), "error", "duplicate exact scenario identities are rejected", failures)
	TestAssertions.truthy(String((duplicate_report.get("errors", []) as Array)[0]).contains("duplicate scenario identity"), "duplicate rejection names canonical identity", failures)
	var sequence_duplicates: Array[ItemGenerationRequest] = [original, sequence_variant]
	var sequence_duplicate_report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, sequence_duplicates, 2)
	TestAssertions.equal(sequence_duplicate_report.get("status", ""), "error", "requests differing only in report-owned input sequence are rejected as duplicate sample streams", failures)
	var sequence_duplicate_errors := sequence_duplicate_report.get("errors", []) as Array
	TestAssertions.truthy(not sequence_duplicate_errors.is_empty() and str(sequence_duplicate_errors[0]).contains("duplicate scenario identity"), "sequence-only duplicate rejection names canonical identity", failures)

func _test_production_evidence_validator_regressions(report_script: Script, failures: Array[String]) -> void:
	var file := FileAccess.open(EVIDENCE_PATH, FileAccess.READ)
	TestAssertions.truthy(file != null, "committed production evidence opens for validator regressions", failures)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	TestAssertions.truthy(parsed is Dictionary, "committed production evidence parses for validator regressions", failures)
	if not parsed is Dictionary:
		return
	var report := parsed as Dictionary
	(report.get("configuration", {}) as Dictionary)["matrix_row_counts"] = {
		"archetype_party_bias": 8,
		"charisma_heat": 9,
		"level_rarity": 65,
	}
	var baseline_errors := report_script.call(&"production_evidence_errors", report) as Array
	TestAssertions.equal(baseline_errors, [], "committed production evidence satisfies the production validator", failures)
	var bands := (report.get("aggregates", {}) as Dictionary).get("weight_bands", {}) as Dictionary
	for band_value: Variant in bands.values():
		(band_value as Dictionary)["selection_opportunity_denominator"] = 285069
	var partial_errors := report_script.call(&"production_evidence_errors", report) as Array
	TestAssertions.truthy(_has_error(partial_errors, "selection-opportunity denominator"), "validator rejects partial trace-derived selection-opportunity aggregation", failures)
	for band_value: Variant in bands.values():
		(band_value as Dictionary)["selection_opportunity_denominator"] = 285070
	var expected_counts := {
		"affixes": 195,
		"bases": 99,
		"explicit_affixes": 96,
		"implicit_affixes": 99,
		"weapon_profile_bases": 11,
	}
	var counts := (report.get("manifest", {}) as Dictionary).get("counts", {}) as Dictionary
	for key: String in expected_counts:
		var expected := int(expected_counts[key])
		counts.erase(key)
		var omission_errors := report_script.call(&"production_evidence_errors", report) as Array
		TestAssertions.truthy(_has_error(omission_errors, "manifest count %s" % key), "validator rejects omitted manifest count %s" % key, failures)
		counts[key] = expected + 1
		var mismatch_errors := report_script.call(&"production_evidence_errors", report) as Array
		TestAssertions.truthy(_has_error(mismatch_errors, "manifest count %s" % key), "validator rejects mismatched manifest count %s" % key, failures)
		counts[key] = expected

func _test_bounded_repeat_and_unique_ids(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var requests: Array[ItemGenerationRequest] = [_request(811, 0.0, 0.0), _request(812, 25.0, 25.0)]
	var first: Dictionary = report_script.call(&"build_bounded", equipment, foundation, requests, 16)
	var second: Dictionary = report_script.call(&"build_bounded", equipment, foundation, requests, 16)
	TestAssertions.equal(first.get("status", ""), "ok", "bounded report succeeds", failures)
	TestAssertions.equal(report_script.call(&"to_json", first), report_script.call(&"to_json", second), "independent bounded builds replay byte-identically", failures)
	var summary := first.get("summary", {}) as Dictionary
	TestAssertions.equal(summary.get("attempted", 0), 32, "bounded report uses requested sample count", failures)
	TestAssertions.equal(summary.get("unique_instance_id_count", 0), 32, "bounded report issues unique IDs across scenarios", failures)
	TestAssertions.equal(summary.get("duplicate_instance_id_count", -1), 0, "bounded report finds no ID collisions", failures)
	TestAssertions.equal(summary.get("origin_identity_mismatch_count", -1), 0, "bounded report origin identity is coherent", failures)

func _test_live_reachability_and_natural_order(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var production_requests: Array[ItemGenerationRequest] = report_script.call(&"production_requests", foundation)
	var report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, production_requests, 1)
	var apex := _reachability(report, "apex_force")
	TestAssertions.truthy("common" not in (apex.get("eligible_rarity_ids", []) as Array), "live explicit reachability respects Common's zero prefix capacity", failures)
	TestAssertions.truthy("common" in (apex.get("excluded_rarity_ids", []) as Array), "live reachability publishes Common exclusion", failures)
	var bands := (report.get("aggregates", {}) as Dictionary).get("weight_bands", {}) as Dictionary
	for band_value: Variant in bands.values():
		var band := band_value as Dictionary
		TestAssertions.truthy(band.has("expected_effective_selection_proportion"), "expected band proportions come from live effective weights", failures)
		TestAssertions.truthy(not band.has("expected_relative_weight") and not band.has("authored_weight_share"), "report omits hand-maintained expected weight fields", failures)
	var heat_order: Array[int] = []
	for scenario_value: Variant in report.get("scenarios", []) as Array:
		var scenario := scenario_value as Dictionary
		if scenario.get("family", "") == "charisma_heat" and int(float(scenario.get("charisma", -1))) == 0:
			heat_order.append(int(float(scenario.get("heat", -1))))
	TestAssertions.equal(heat_order, [0, 25, 100], "scenario ordering is natural numeric Heat order", failures)
	var markdown: String = report_script.call(&"to_markdown", report)
	var heat_zero := markdown.find("Heat 0:")
	var heat_25 := markdown.find("Heat 25:")
	var heat_100 := markdown.find("Heat 100:")
	TestAssertions.truthy(heat_zero >= 0 and heat_zero < heat_25 and heat_25 < heat_100, "Markdown uses natural numeric Heat order", failures)
	_assert_scenario_table_shape(markdown, (report.get("scenarios", []) as Array).size(), failures)

func _test_generated_charisma_evidence(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var all_requests: Array[ItemGenerationRequest] = report_script.call(&"production_requests", foundation)
	var charisma_requests: Array[ItemGenerationRequest] = []
	for request: ItemGenerationRequest in all_requests:
		if int(request.item_level) == 1 and request.forced_rarity_id.is_empty() and request.party_archetype_tags.is_empty():
			charisma_requests.append(request)
	var report: Dictionary = report_script.call(&"build_bounded", equipment, foundation, charisma_requests, 64)
	var charisma := (report.get("aggregates", {}) as Dictionary).get("charisma", {}) as Dictionary
	var low := charisma.get("0", {}) as Dictionary
	var moderate := charisma.get("100", {}) as Dictionary
	var extreme := charisma.get("1000", {}) as Dictionary
	var low_uplift := float(low.get("average_selected_effective_weight_uplift", 0.0))
	var moderate_uplift := float(moderate.get("average_selected_effective_weight_uplift", 0.0))
	var extreme_uplift := float(extreme.get("average_selected_effective_weight_uplift", 0.0))
	TestAssertions.truthy(low_uplift < moderate_uplift and moderate_uplift < extreme_uplift, "generated selected-affix uplift rises with Charisma", failures)
	TestAssertions.truthy(moderate_uplift - low_uplift > extreme_uplift - moderate_uplift, "generated selected-affix uplift demonstrates diminishing Charisma gain", failures)
	TestAssertions.equal(extreme.get("maximum_observed_tier", 0), 1, "generated extreme Charisma cannot bypass the level-one tier gate", failures)
	TestAssertions.truthy(float(extreme.get("expected_premium_selection_proportion", 0.0)) > float(low.get("expected_premium_selection_proportion", 0.0)), "live trace weights show Charisma premium-probability uplift", failures)

func _request(seed: int, charisma: float, heat: float) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(seed, 0, 1, &"ordinary_enemy", &"ordinary_drop", [&"uncommon", &"rare"])
	request.forced_rarity_id = &"uncommon"
	request.forced_base_id = &"forge_vanguard_sword"
	request.charisma_value = charisma
	request.heat = heat
	return request

func _reachability(report: Dictionary, id: String) -> Dictionary:
	for row_value: Variant in (report.get("manifest", {}) as Dictionary).get("reachability", []) as Array:
		var row := row_value as Dictionary
		if row.get("id", "") == id:
			return row
	return {}

func _assert_scenario_table_shape(markdown: String, expected_rows: int, failures: Array[String]) -> void:
	var header_columns := -1
	var row_count := 0
	var in_scenarios := false
	for line: String in markdown.split("\n"):
		if line.begins_with("| Scenario |"):
			in_scenarios = true
			header_columns = _markdown_column_count(line)
			continue
		if not in_scenarios or line.begins_with("| ---"):
			continue
		if not line.begins_with("|"):
			if row_count > 0:
				break
			continue
		row_count += 1
		TestAssertions.equal(_markdown_column_count(line), header_columns, "scenario Markdown row %d has header column count" % row_count, failures)
	TestAssertions.equal(row_count, expected_rows, "Markdown renders every scenario as exactly one row", failures)

func _markdown_column_count(line: String) -> int:
	var separators := 0
	for index: int in line.length():
		if line[index] != "|":
			continue
		var backslashes := 0
		var cursor := index - 1
		while cursor >= 0 and line[cursor] == "\\":
			backslashes += 1
			cursor -= 1
		if backslashes % 2 == 0:
			separators += 1
	return maxi(separators - 1, 0)

func _has_error(errors: Array, fragment: String) -> bool:
	for error: Variant in errors:
		if str(error).contains(fragment):
			return true
	return false
