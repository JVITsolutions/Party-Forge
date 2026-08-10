extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const REPORT_PATH := "res://scripts/items/item_generation_balance_report.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	var foundation := load(FOUNDATION_PATH) as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null, "balance report equipment catalog loads", failures)
	TestAssertions.truthy(foundation != null, "balance report foundation catalog loads", failures)
	if equipment == null or foundation == null:
		return failures
	var report_script := load(REPORT_PATH) as Script
	TestAssertions.truthy(report_script != null, "balance report service exists", failures)
	if report_script == null:
		return failures
	_test_input_validation(report_script, equipment, foundation, failures)
	var requests: Array[ItemGenerationRequest] = report_script.call(&"production_requests", foundation)
	TestAssertions.equal(requests.size(), 82, "production report has exactly 82 orthogonal scenario rows", failures)
	var first: Dictionary = report_script.call(&"build", equipment, foundation, requests)
	_test_canonical_rendering(report_script, first, failures)
	_test_exact_accounting(first, failures)
	_test_manifest_and_reachability(first, failures)
	_test_broad_balance_trends(first, failures)
	return failures

func _test_input_validation(
	report_script: Script,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	failures: Array[String]
) -> void:
	var no_requests: Array[ItemGenerationRequest] = []
	var missing_equipment: Dictionary = report_script.call(&"build", null, foundation, no_requests)
	TestAssertions.equal(missing_equipment.get("status", ""), "error", "missing equipment is rejected", failures)
	TestAssertions.equal((missing_equipment.get("summary", {}) as Dictionary).get("attempted", -1), 0, "missing equipment attempts no samples", failures)
	var missing_foundation: Dictionary = report_script.call(&"build", equipment, null, no_requests)
	TestAssertions.equal(missing_foundation.get("status", ""), "error", "missing foundation is rejected", failures)
	var empty_requests: Array[ItemGenerationRequest] = []
	var missing_requests: Dictionary = report_script.call(&"build", equipment, foundation, empty_requests)
	TestAssertions.equal(missing_requests.get("status", ""), "error", "empty request matrix is rejected", failures)
	var invalid := ItemGenerationRequest.create(19, 0, 0, &"ordinary_enemy", &"ordinary_drop", [&"common"])
	var invalid_requests: Array[ItemGenerationRequest] = [invalid]
	var invalid_report: Dictionary = report_script.call(&"build", equipment, foundation, invalid_requests)
	TestAssertions.equal(invalid_report.get("status", ""), "error", "invalid request is rejected before sampling", failures)
	TestAssertions.equal((invalid_report.get("summary", {}) as Dictionary).get("attempted", -1), 0, "invalid request attempts no samples", failures)

func _test_canonical_rendering(report_script: Script, first: Dictionary, failures: Array[String]) -> void:
	var first_json: String = report_script.call(&"to_json", first)
	var second_json: String = report_script.call(&"to_json", first)
	TestAssertions.equal(second_json, first_json, "full 164,000-attempt report renders byte-identically", failures)
	TestAssertions.truthy(first_json.begins_with("{\n  \"aggregates\""), "JSON uses canonical sorted keys and two-space indentation", failures)
	TestAssertions.truthy(first_json.ends_with("\n"), "canonical JSON has one terminal newline", failures)
	TestAssertions.truthy(JSON.parse_string(first_json) is Dictionary, "canonical JSON parses as a dictionary", failures)
	var first_markdown: String = report_script.call(&"to_markdown", first)
	var second_markdown: String = report_script.call(&"to_markdown", first)
	TestAssertions.equal(second_markdown, first_markdown, "Markdown replays byte-identically from the same report dictionary", failures)
	TestAssertions.truthy(first_markdown.begins_with("# Weighted Loot Production Balance Report\n"), "Markdown has the stable report title", failures)
	TestAssertions.truthy(first_markdown.contains("| Scenario | Attempts | Successes | Failures |"), "Markdown includes scenario accounting", failures)

func _test_exact_accounting(report: Dictionary, failures: Array[String]) -> void:
	TestAssertions.equal(report.get("status", ""), "ok", "production report succeeds", failures)
	var configuration := report.get("configuration", {}) as Dictionary
	TestAssertions.equal(configuration.get("sequences_per_row", 0), 2000, "each row uses exactly 2,000 sequences", failures)
	TestAssertions.equal(configuration.get("scenario_count", 0), 82, "report records exactly 82 rows", failures)
	TestAssertions.equal(configuration.get("matrix_row_counts", {}), {
		"archetype_party_bias": 8,
		"charisma_heat": 9,
		"level_rarity": 65,
	}, "matrix has exact orthogonal row counts", failures)
	TestAssertions.equal(configuration.get("expected_attempt_count", 0), 164000, "matrix declares exactly 164,000 attempts", failures)
	var summary := report.get("summary", {}) as Dictionary
	var attempted := int(summary.get("attempted", -1))
	var succeeded := int(summary.get("succeeded", -1))
	var failed := int(summary.get("failed", -1))
	TestAssertions.equal(attempted, 164000, "report performs exactly 164,000 generation attempts", failures)
	TestAssertions.equal(succeeded + failed, attempted, "success and failure accounting closes exactly", failures)
	TestAssertions.equal(failed, 0, "canonical production matrix has no generation failures", failures)
	var scenarios := report.get("scenarios", []) as Array
	TestAssertions.equal(scenarios.size(), 82, "report retains one aggregate row per scenario", failures)
	var keys: Array[String] = []
	for scenario_value: Variant in scenarios:
		var scenario := scenario_value as Dictionary
		keys.append(String(scenario.get("key", "")))
		TestAssertions.equal(scenario.get("attempted", 0), 2000, "scenario %s has exact attempt count" % scenario.get("key", ""), failures)
		TestAssertions.equal(int(scenario.get("succeeded", 0)) + int(scenario.get("failed", 0)), 2000, "scenario %s accounting closes" % scenario.get("key", ""), failures)
	var sorted_keys := keys.duplicate()
	sorted_keys.sort()
	TestAssertions.equal(keys, sorted_keys, "scenario keys use stable lexical order", failures)

func _test_manifest_and_reachability(report: Dictionary, failures: Array[String]) -> void:
	var manifest := report.get("manifest", {}) as Dictionary
	var counts := manifest.get("counts", {}) as Dictionary
	TestAssertions.equal(counts.get("bases", 0), 99, "manifest records all 99 bases", failures)
	TestAssertions.equal(counts.get("weapon_profile_bases", 0), 11, "manifest records all eleven weapon profiles", failures)
	TestAssertions.equal(counts.get("affixes", 0), 195, "manifest records all 195 affixes", failures)
	TestAssertions.equal(counts.get("explicit_affixes", 0), 96, "manifest records all 96 explicit affixes", failures)
	TestAssertions.equal(counts.get("implicit_affixes", 0), 99, "manifest records all 99 implicit affixes", failures)
	TestAssertions.equal(counts.get("prefixes", 0), 48, "manifest records all 48 prefixes", failures)
	TestAssertions.equal(counts.get("suffixes", 0), 48, "manifest records all 48 suffixes", failures)
	var reachability := manifest.get("reachability", []) as Array
	TestAssertions.equal(reachability.size(), 195, "reachability records every affix", failures)
	for row_value: Variant in reachability:
		var row := row_value as Dictionary
		TestAssertions.truthy(bool(row.get("reachable", false)), "affix %s has a live base and rarity path" % row.get("id", ""), failures)
	var exclusions := manifest.get("exclusions", {}) as Dictionary
	TestAssertions.equal(exclusions.get("ordinary_rarity_ids", []), ["common", "epic", "legendary", "rare", "uncommon"], "ordinary rarity reachability is exact", failures)
	TestAssertions.equal(exclusions.get("ordinary_disabled_rarity_ids", []), ["ascendant", "divine", "eternal", "exotic", "mythic"], "nonordinary rarity exclusions are exact", failures)

func _test_broad_balance_trends(report: Dictionary, failures: Array[String]) -> void:
	var aggregates := report.get("aggregates", {}) as Dictionary
	var bands := aggregates.get("weight_bands", {}) as Dictionary
	TestAssertions.equal(bands.keys(), ["0025_premium_hybrid", "0150_standard_hybrid", "0500_specialized_focused", "1000_core_focused"], "all four weight-band keys are stable and present", failures)
	for key: String in bands:
		var band := bands[key] as Dictionary
		TestAssertions.truthy(int(band.get("definition_count", 0)) > 0, "%s has authored definitions" % key, failures)
		TestAssertions.truthy(int(band.get("selected_count", 0)) > 0, "%s is observed without pinning an individual roll" % key, failures)
	TestAssertions.truthy(int((bands["0025_premium_hybrid"] as Dictionary).get("selected_count", 0)) < int((bands["0150_standard_hybrid"] as Dictionary).get("selected_count", 0)), "premium hybrids remain scarcer than standard hybrids", failures)
	var tier_trend := aggregates.get("tier_trend", {}) as Dictionary
	TestAssertions.truthy(float(tier_trend.get("level_1000_average", 0.0)) > float(tier_trend.get("level_1_average", 0.0)) + 1.0, "higher item levels trend to materially higher tiers", failures)
	var fill_rates := aggregates.get("fill_rates", {}) as Dictionary
	TestAssertions.equal((fill_rates.get("rarities", {}) as Dictionary).get("observed_count", 0), 5, "all five ordinary rarities are observed", failures)
	TestAssertions.equal((fill_rates.get("tiers", {}) as Dictionary).get("observed_count", 0), 12, "all twelve tiers are observed", failures)
	var party_bias := aggregates.get("party_bias", {}) as Dictionary
	for archetype: String in ["caster", "global", "melee", "ranged"]:
		var row := party_bias.get(archetype, {}) as Dictionary
		TestAssertions.truthy(float(row.get("biased_match_proportion", 0.0)) > float(row.get("neutral_match_proportion", 0.0)) + 0.10, "%s party bias materially raises matching bases" % archetype, failures)
		TestAssertions.truthy(int(row.get("biased_off_count", 0)) > 0, "%s party bias never eliminates off-party bases" % archetype, failures)
	var charisma := aggregates.get("charisma", {}) as Dictionary
	var low := charisma.get("0", {}) as Dictionary
	var moderate := charisma.get("100", {}) as Dictionary
	var extreme := charisma.get("1000", {}) as Dictionary
	var first_gain := float(moderate.get("diminishing_value", 0.0)) - float(low.get("diminishing_value", 0.0))
	var second_gain := float(extreme.get("diminishing_value", 0.0)) - float(moderate.get("diminishing_value", 0.0))
	TestAssertions.truthy(first_gain > second_gain, "Charisma gains diminish at the extreme", failures)
	TestAssertions.equal(extreme.get("maximum_observed_tier", 0), 1, "extreme Charisma cannot bypass the level-one tier gate", failures)
	var heat := aggregates.get("heat", {}) as Dictionary
	TestAssertions.truthy(float((heat.get("100", {}) as Dictionary).get("upper_rarity_proportion", 0.0)) > float((heat.get("0", {}) as Dictionary).get("upper_rarity_proportion", 0.0)), "Heat raises rare-or-better frequency", failures)
	var weapon := aggregates.get("weapon_damage_percentiles", {}) as Dictionary
	TestAssertions.truthy(int(weapon.get("sample_count", 0)) > 0, "weapon percentile population is nonempty", failures)
	for key: String in ["minimum_damage", "maximum_damage"]:
		var percentiles := weapon.get(key, {}) as Dictionary
		TestAssertions.truthy(float(percentiles.get("minimum", -1.0)) <= float(percentiles.get("median", -1.0)), "%s minimum does not exceed median" % key, failures)
		TestAssertions.truthy(float(percentiles.get("median", -1.0)) <= float(percentiles.get("high", -1.0)), "%s median does not exceed high percentile" % key, failures)
