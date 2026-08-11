class_name ItemGenerationBalanceReport
extends RefCounted

const SCHEMA_VERSION := 2
const SEQUENCES_PER_ROW := 2000
const MAX_AUDITED_ATTEMPTS := 200000
const LEVELS: Array[int] = [1, 10, 30, 60, 100, 160, 240, 340, 460, 600, 770, 950, 1000]
const ORDINARY_RARITY_IDS: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const ARCHETYPE_IDS: Array[StringName] = [&"caster", &"global", &"melee", &"ranged"]
const CHARISMA_VALUES: Array[int] = [0, 100, 1000]
const HEAT_VALUES: Array[int] = [0, 25, 100]
const ORDINARY_UNLOCK_TAGS: Array[StringName] = [
	&"rarity_rare_unlocked", &"rarity_epic_unlocked", &"rarity_legendary_unlocked",
]
const LEVEL_SEED_BASE := 111000
const ARCHETYPE_SEED_BASE := 211000
const CHARISMA_SEED_BASE := 311000

static func production_scenario_specs(_foundation: ItemFoundationCatalog = null) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var level_row := 0
	for level_index: int in LEVELS.size():
		var level := LEVELS[level_index]
		for rarity_index: int in ORDINARY_RARITY_IDS.size():
			var rarity_id := ORDINARY_RARITY_IDS[rarity_index]
			var request := _ordinary_request(LEVEL_SEED_BASE + level_row, level)
			request.permitted_rarity_ids = [rarity_id]
			request.forced_rarity_id = rarity_id
			specs.append(_spec(request, "level_rarity", "Level %d / %s" % [level, String(rarity_id).capitalize()], [0, level_index, rarity_index], "", false))
			level_row += 1
	for archetype_index: int in ARCHETYPE_IDS.size():
		for biased_index: int in 2:
			var request := _ordinary_request(ARCHETYPE_SEED_BASE + archetype_index * 2 + biased_index, 600)
			if biased_index == 1:
				request.party_archetype_tags = [ARCHETYPE_IDS[archetype_index]]
			var mode := "Biased" if biased_index == 1 else "Neutral"
			specs.append(_spec(request, "archetype_party_bias", "%s / %s" % [String(ARCHETYPE_IDS[archetype_index]).capitalize(), mode], [1, archetype_index, biased_index], String(ARCHETYPE_IDS[archetype_index]), biased_index == 1))
	for charisma_index: int in CHARISMA_VALUES.size():
		for heat_index: int in HEAT_VALUES.size():
			var request := _ordinary_request(CHARISMA_SEED_BASE + charisma_index * 3 + heat_index, 1)
			request.charisma_value = float(CHARISMA_VALUES[charisma_index])
			request.heat = float(HEAT_VALUES[heat_index])
			specs.append(_spec(request, "charisma_heat", "Charisma %d / Heat %d" % [CHARISMA_VALUES[charisma_index], HEAT_VALUES[heat_index]], [2, charisma_index, heat_index], "", false))
	return specs

static func production_requests(foundation: ItemFoundationCatalog = null) -> Array[ItemGenerationRequest]:
	var requests: Array[ItemGenerationRequest] = []
	for spec: Dictionary in production_scenario_specs(foundation):
		requests.append(spec["request"] as ItemGenerationRequest)
	return requests

static func build(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest]
) -> Dictionary:
	return _build(equipment, foundation, requests, SEQUENCES_PER_ROW)

static func build_bounded(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest],
	sequences_per_row: int
) -> Dictionary:
	return _build(equipment, foundation, requests, sequences_per_row)

static func scenario_identity(request: ItemGenerationRequest) -> String:
	if request == null:
		return ""
	var canonical := request.canonical_document().duplicate(true)
	if canonical.is_empty():
		return ""
	# Report sampling owns the local 0..N-1 sequence and replaces the caller's
	# input sequence before generation, so it cannot distinguish sample streams.
	canonical["generation_sequence"] = 0
	return JSON.stringify(ItemGenerationTrace.canonical_json_copy(canonical), "", false)

static func percentile_summary(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	for value: Variant in sorted:
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return {"high": 0.0, "median": 0.0, "minimum": 0.0}
	sorted.sort()
	if sorted.is_empty():
		return {"high": 0.0, "median": 0.0, "minimum": 0.0}
	return {
		"high": _rounded(_linear_percentile(sorted, 0.90)),
		"median": _rounded(_linear_percentile(sorted, 0.50)),
		"minimum": _rounded(float(sorted[0])),
	}

static func production_evidence_errors(report: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var configuration := report.get("configuration", {}) as Dictionary
	var summary := report.get("summary", {}) as Dictionary
	if report.get("status", "") != "ok":
		errors.append("status must be ok")
	if int(configuration.get("scenario_count", 0)) != 82:
		errors.append("scenario count must equal 82")
	if int(configuration.get("sequences_per_row", 0)) != SEQUENCES_PER_ROW:
		errors.append("sequences per row must equal 2000")
	if configuration.get("matrix_row_counts", {}) != {"archetype_party_bias": 8, "charisma_heat": 9, "level_rarity": 65}:
		errors.append("matrix rows must equal 65/8/9")
	if int(summary.get("attempted", 0)) != 164000:
		errors.append("attempt count must equal 164000")
	if int(summary.get("succeeded", 0)) + int(summary.get("failed", 0)) != int(summary.get("attempted", 0)):
		errors.append("success and failure accounting must close")
	if int(summary.get("failed", 0)) != 0:
		errors.append("production matrix must have zero failures")
	if int(summary.get("unique_instance_id_count", 0)) != 164000 or int(summary.get("duplicate_instance_id_count", -1)) != 0:
		errors.append("all 164000 issued instance IDs must be unique")
	if int(summary.get("origin_identity_mismatch_count", -1)) != 0:
		errors.append("all issued origins must match their scenario identity")
	var scenarios := report.get("scenarios", []) as Array
	if scenarios.size() != 82:
		errors.append("report must contain 82 scenario rows")
	var identities: Dictionary = {}
	var namespaces: Dictionary = {}
	for scenario_value: Variant in scenarios:
		var scenario := scenario_value as Dictionary
		var identity := str(scenario.get("identity", ""))
		var issuer_namespace := str(scenario.get("issuer_namespace", ""))
		if identity.is_empty() or identities.has(identity):
			errors.append("scenario identities must be nonempty and unique")
		identities[identity] = true
		if issuer_namespace.is_empty() or namespaces.has(issuer_namespace):
			errors.append("issuer namespaces must be nonempty and unique per scenario")
		namespaces[issuer_namespace] = true
		if int(scenario.get("attempted", 0)) != SEQUENCES_PER_ROW:
			errors.append("every production scenario must contain 2000 attempts")
	var aggregates := report.get("aggregates", {}) as Dictionary
	var fill_rates := aggregates.get("fill_rates", {}) as Dictionary
	if float((fill_rates.get("rarities", {}) as Dictionary).get("fill_rate", 0.0)) != 1.0:
		errors.append("production evidence must observe every eligible rarity")
	if float((fill_rates.get("tiers", {}) as Dictionary).get("fill_rate", 0.0)) != 1.0:
		errors.append("production evidence must observe every eligible tier")
	var bands := aggregates.get("weight_bands", {}) as Dictionary
	var selected_band_total := 0
	var expected_probability_total := 0.0
	for key: String in bands:
		var band := bands[key] as Dictionary
		if int(band.get("explicit_affix_selection_denominator", 0)) != 285070:
			errors.append("weight band %s denominator must equal 285070 explicit-affix selections" % key)
		if int(band.get("selected_explicit_affix_count", 0)) <= 0:
			errors.append("weight band %s must be selected in generated evidence" % key)
		if int(band.get("selection_opportunity_denominator", 0)) <= 0 or float(band.get("effective_weight_sum", 0.0)) <= 0.0:
			errors.append("weight band %s must expose live effective-policy evidence" % key)
		selected_band_total += int(band.get("selected_explicit_affix_count", 0))
		expected_probability_total += float(band.get("expected_effective_selection_proportion", 0.0))
	if bands.size() != 4 or selected_band_total != 285070:
		errors.append("the four live weight bands must account for all 285070 explicit-affix selections")
	for key: String in bands:
		if int((bands[key] as Dictionary).get("selection_opportunity_denominator", -1)) != selected_band_total:
			errors.append("weight band %s selection-opportunity denominator must equal the selected explicit-affix count" % key)
	if not is_equal_approx(expected_probability_total, 1.0):
		errors.append("live expected weight-band selection proportions must sum to one")
	var premium_band := bands.get("0025_premium_hybrid", {}) as Dictionary
	var standard_band := bands.get("0150_standard_hybrid", {}) as Dictionary
	var specialized_band := bands.get("0500_specialized_focused", {}) as Dictionary
	var core_band := bands.get("1000_core_focused", {}) as Dictionary
	if not (
		int(premium_band.get("selected_explicit_affix_count", 0)) < int(specialized_band.get("selected_explicit_affix_count", 0))
		and int(specialized_band.get("selected_explicit_affix_count", 0)) < int(standard_band.get("selected_explicit_affix_count", 0))
		and int(standard_band.get("selected_explicit_affix_count", 0)) < int(core_band.get("selected_explicit_affix_count", 0))
	):
		errors.append("generated selections must preserve premium scarcity and core prevalence")
	var tier_trend := aggregates.get("tier_trend", {}) as Dictionary
	if float(tier_trend.get("level_1000_average", 0.0)) <= float(tier_trend.get("level_1_average", 0.0)):
		errors.append("level 1000 explicit tiers must trend above level 1")
	var charisma := aggregates.get("charisma", {}) as Dictionary
	var low := charisma.get("0", {}) as Dictionary
	var moderate := charisma.get("100", {}) as Dictionary
	var extreme := charisma.get("1000", {}) as Dictionary
	var low_uplift := float(low.get("average_selected_effective_weight_uplift", 0.0))
	var moderate_uplift := float(moderate.get("average_selected_effective_weight_uplift", 0.0))
	var extreme_uplift := float(extreme.get("average_selected_effective_weight_uplift", 0.0))
	if not (low_uplift < moderate_uplift and moderate_uplift < extreme_uplift and moderate_uplift - low_uplift > extreme_uplift - moderate_uplift):
		errors.append("generated Charisma uplift must rise with diminishing marginal gain")
	if int(extreme.get("maximum_observed_tier", 0)) != 1:
		errors.append("extreme Charisma must not bypass the level-one tier gate")
	if float(extreme.get("expected_premium_selection_proportion", 0.0)) <= float(low.get("expected_premium_selection_proportion", 0.0)):
		errors.append("live policy traces must show premium probability rising with Charisma")
	var heat := aggregates.get("heat", {}) as Dictionary
	var heat_0 := float((heat.get("0", {}) as Dictionary).get("upper_rarity_proportion", 0.0))
	var heat_25 := float((heat.get("25", {}) as Dictionary).get("upper_rarity_proportion", 0.0))
	var heat_100 := float((heat.get("100", {}) as Dictionary).get("upper_rarity_proportion", 0.0))
	if not (heat_0 < heat_25 and heat_25 < heat_100):
		errors.append("generated upper-rarity proportion must rise with Heat")
	for archetype: StringName in ARCHETYPE_IDS:
		var party := (aggregates.get("party_bias", {}) as Dictionary).get(String(archetype), {}) as Dictionary
		if float(party.get("biased_match_proportion", 0.0)) <= float(party.get("neutral_match_proportion", 0.0)):
			errors.append("%s party bias must improve generated archetype matching" % archetype)
		if int(party.get("biased_off_count", 0)) <= 0:
			errors.append("%s party bias must preserve off-archetype outcomes" % archetype)
	var manifest := report.get("manifest", {}) as Dictionary
	var manifest_counts := manifest.get("counts", {}) as Dictionary
	var expected_manifest_counts := {
		"affixes": 195,
		"bases": 99,
		"explicit_affixes": 96,
		"implicit_affixes": 99,
		"weapon_profile_bases": 11,
	}
	for key: String in expected_manifest_counts:
		var expected_count := int(expected_manifest_counts[key])
		if int(manifest_counts.get(key, -1)) != expected_count:
			errors.append("manifest count %s must equal %d" % [key, expected_count])
	if not (manifest.get("exclusions", {}) as Dictionary).get("unreachable_affix_ids", []).is_empty():
		errors.append("every affix definition must remain reachable")
	for row_value: Variant in manifest.get("reachability", []) as Array:
		var row := row_value as Dictionary
		if row.get("kind", "") == "implicit":
			continue
		if "common" in (row.get("eligible_rarity_ids", []) as Array):
			errors.append("explicit affix %s must exclude Common's zero-slot pattern" % row.get("id", ""))
		if "common" not in (row.get("excluded_rarity_ids", []) as Array):
			errors.append("explicit affix %s must publish its Common exclusion" % row.get("id", ""))
	var weapon_percentiles := aggregates.get("weapon_damage_percentiles", {}) as Dictionary
	if int(weapon_percentiles.get("sample_count", 0)) <= 0 or not str(weapon_percentiles.get("convention", "")).contains("linear interpolation"):
		errors.append("weapon damage evidence must include samples and the linear percentile convention")
	return errors

static func _build(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest],
	sequences_per_row: int
) -> Dictionary:
	var input_error := _input_error(equipment, foundation, requests, sequences_per_row)
	if not input_error.is_empty():
		return _error_report(input_error)
	var metadata_by_identity := _production_metadata_by_identity(foundation)
	var entries: Array[Dictionary] = []
	for request: ItemGenerationRequest in requests:
		entries.append(_scenario_entry(request, metadata_by_identity))
	entries.sort_custom(_scenario_entry_less)
	var matrix_counts := {
		"archetype_party_bias": 0,
		"charisma_heat": 0,
		"level_rarity": 0,
	}
	var scenarios: Array[Dictionary] = []
	var state := _initial_aggregate_state(foundation)
	for scenario_index: int in entries.size():
		var entry := entries[scenario_index]
		var request := entry["request"] as ItemGenerationRequest
		var matrix := String(entry["family"])
		matrix_counts[matrix] = int(matrix_counts.get(matrix, 0)) + 1
		var issuer_namespace := "balance-report:%03d:%s" % [scenario_index, String(entry["identity"]).sha256_text()]
		var scenario := _initial_scenario(request, entry, issuer_namespace, equipment, foundation)
		for sequence: int in sequences_per_row:
			var sample := request.copy_with_sequence(sequence)
			var result := ItemGenerationService.generate(sample, issuer_namespace, sequence, equipment, foundation)
			_record_result(scenario, state, result, sample, issuer_namespace, equipment, foundation)
		scenarios.append(_finalize_scenario(scenario))
	var attempted := int(state["attempted"])
	var succeeded := int(state["succeeded"])
	var failed := int(state["failed"])
	var report := {
		"aggregates": _finalize_aggregates(state, scenarios, foundation),
		"configuration": {
			"expected_attempt_count": requests.size() * sequences_per_row,
			"matrix_row_counts": matrix_counts,
			"scenario_count": requests.size(),
			"sequences_per_row": sequences_per_row,
		},
		"manifest": _manifest(equipment, foundation),
		"scenarios": scenarios,
		"schema_version": SCHEMA_VERSION,
		"status": "ok",
		"summary": {
			"attempted": attempted,
			"failed": failed,
			"failure_proportion": _ratio(failed, attempted),
			"duplicate_instance_id_count": int(state["duplicate_instance_id_count"]),
			"origin_identity_mismatch_count": int(state["origin_identity_mismatch_count"]),
			"succeeded": succeeded,
			"success_proportion": _ratio(succeeded, attempted),
			"unique_instance_id_count": (state["instance_ids"] as Dictionary).size(),
		},
	}
	return ItemGenerationTrace.canonical_json_copy(report) as Dictionary

static func to_json(report: Dictionary) -> String:
	if ItemGenerationTrace.json_value_error(report) != "":
		return ""
	var canonical := ItemGenerationTrace.canonical_json_copy(report) as Dictionary
	return JSON.stringify(canonical, "  ", false) + "\n"

static func to_markdown(report: Dictionary) -> String:
	if ItemGenerationTrace.json_value_error(report) != "":
		return ""
	var canonical := ItemGenerationTrace.canonical_json_copy(report) as Dictionary
	var lines: Array[String] = [
		"# Weighted Loot Production Balance Report",
		"",
		"Deterministic schema %d report. No timestamps, locale values, or environmental random inputs are included." % int(canonical.get("schema_version", 0)),
		"",
	]
	var configuration := canonical.get("configuration", {}) as Dictionary
	var summary := canonical.get("summary", {}) as Dictionary
	lines.append("## Sample accounting")
	lines.append("")
	lines.append("- Scenario rows: %d (65 level x rarity, 8 archetype and party-bias, 9 Charisma x Heat)" % int(configuration.get("scenario_count", 0)))
	lines.append("- Sequences per row: %d" % int(configuration.get("sequences_per_row", 0)))
	lines.append("- Attempts: %d; successes: %d; failures: %d" % [int(summary.get("attempted", 0)), int(summary.get("succeeded", 0)), int(summary.get("failed", 0))])
	lines.append("")
	_append_manifest_markdown(lines, canonical.get("manifest", {}) as Dictionary)
	_append_aggregate_markdown(lines, canonical.get("aggregates", {}) as Dictionary)
	lines.append("## Scenario accounting")
	lines.append("")
	lines.append(_markdown_row(["Scenario", "Attempts", "Successes", "Failures", "Average explicit tier", "Weapon samples"]))
	lines.append(_markdown_row(["---", "---:", "---:", "---:", "---:", "---:"]))
	for scenario_value: Variant in canonical.get("scenarios", []) as Array:
		var scenario := scenario_value as Dictionary
		var weapon := scenario.get("weapon_damage_percentiles", {}) as Dictionary
		lines.append(_markdown_row([
			String(scenario.get("label", scenario.get("key", ""))),
			int(scenario.get("attempted", 0)),
			int(scenario.get("succeeded", 0)),
			int(scenario.get("failed", 0)),
			_number(float(scenario.get("average_explicit_tier", 0.0))),
			int(weapon.get("sample_count", 0)),
		]))
	lines.append("")
	return "\n".join(lines)

static func _ordinary_request(seed: int, item_level: int) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(seed, 0, item_level, &"ordinary_enemy", &"ordinary_drop", ORDINARY_RARITY_IDS)
	request.unlock_tags = ORDINARY_UNLOCK_TAGS.duplicate()
	return request

static func _input_error(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest],
	sequences_per_row: int
) -> String:
	if equipment == null:
		return "equipment catalog is missing"
	if foundation == null:
		return "foundation catalog is missing"
	if equipment.definitions.is_empty():
		return "equipment catalog has no definitions"
	if foundation.affixes.is_empty() or foundation.ordinary_rarity_ids().is_empty():
		return "foundation catalog has no production generation content"
	if requests.is_empty():
		return "request matrix is empty"
	if sequences_per_row <= 0 or sequences_per_row > SEQUENCES_PER_ROW:
		return "sequences per row must be between 1 and %d" % SEQUENCES_PER_ROW
	if requests.size() * sequences_per_row > MAX_AUDITED_ATTEMPTS:
		return "identity audit exceeds bounded maximum of %d attempts" % MAX_AUDITED_ATTEMPTS
	var seen_keys: Dictionary = {}
	for index: int in requests.size():
		var request := requests[index]
		if request == null:
			return "request %d is missing" % index
		var request_error := request.validate(foundation)
		if not request_error.is_empty():
			return "request %d is invalid: %s" % [index, request_error]
		var key := scenario_identity(request)
		if seen_keys.has(key):
			return "request matrix has duplicate scenario identity %s" % key
		seen_keys[key] = true
	return ""

static func _error_report(message: String) -> Dictionary:
	return {
		"errors": [message],
		"schema_version": SCHEMA_VERSION,
		"status": "error",
		"summary": {
			"attempted": 0,
			"failed": 0,
			"failure_proportion": 0.0,
			"duplicate_instance_id_count": 0,
			"origin_identity_mismatch_count": 0,
			"succeeded": 0,
			"success_proportion": 0.0,
			"unique_instance_id_count": 0,
		},
	}

static func _spec(request: ItemGenerationRequest, family: String, label: String, sort_order: Array, target_archetype: String, party_biased: bool) -> Dictionary:
	return {"family": family, "identity": scenario_identity(request), "label": label, "party_biased": party_biased, "request": request, "sort_order": sort_order.duplicate(), "target_archetype": target_archetype}

static func _production_metadata_by_identity(foundation: ItemFoundationCatalog) -> Dictionary:
	var result: Dictionary = {}
	for spec: Dictionary in production_scenario_specs(foundation):
		var metadata := spec.duplicate()
		metadata.erase("request")
		result[spec["identity"]] = metadata
	return result

static func _scenario_entry(request: ItemGenerationRequest, metadata_by_identity: Dictionary) -> Dictionary:
	var identity := scenario_identity(request)
	var metadata := (metadata_by_identity.get(identity, {}) as Dictionary).duplicate(true)
	if metadata.is_empty():
		metadata = {"family": "custom", "identity": identity, "label": "Custom %s" % identity.sha256_text().left(12), "party_biased": not request.party_archetype_tags.is_empty(), "sort_order": [3, identity], "target_archetype": String(request.party_archetype_tags[0]) if not request.party_archetype_tags.is_empty() else ""}
	metadata["request"] = request
	return metadata

static func _scenario_entry_less(left: Dictionary, right: Dictionary) -> bool:
	var left_order := left["sort_order"] as Array
	var right_order := right["sort_order"] as Array
	for index: int in mini(left_order.size(), right_order.size()):
		if left_order[index] == right_order[index]:
			continue
		if typeof(left_order[index]) in [TYPE_INT, TYPE_FLOAT] and typeof(right_order[index]) in [TYPE_INT, TYPE_FLOAT]:
			return float(left_order[index]) < float(right_order[index])
		return String(left_order[index]) < String(right_order[index])
	return String(left["identity"]) < String(right["identity"])

static func _initial_aggregate_state(foundation: ItemFoundationCatalog) -> Dictionary:
	var band_rows := _weight_band_definitions(foundation)
	var band_counts: Dictionary = {}
	var expected_band_probability_sums: Dictionary = {}
	var effective_band_weight_sums: Dictionary = {}
	for key: String in band_rows:
		band_counts[key] = 0
		expected_band_probability_sums[key] = 0.0
		effective_band_weight_sums[key] = 0.0
	return {
		"attempted": 0,
		"band_counts": band_counts,
		"band_definitions": band_rows,
		"duplicate_instance_id_count": 0,
		"effective_band_weight_sums": effective_band_weight_sums,
		"expected_band_probability_sums": expected_band_probability_sums,
		"explicit_selection_opportunities": 0,
		"failed": 0,
		"failure_counts": {},
		"instance_ids": {},
		"origin_identity_mismatch_count": 0,
		"rarity_counts": {},
		"succeeded": 0,
		"tier_counts": {},
		"weapon_maximums": [],
		"weapon_minimums": [],
	}

static func _initial_scenario(
	request: ItemGenerationRequest,
	metadata: Dictionary,
	issuer_namespace: String,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> Dictionary:
	return {
		"attempted": 0,
		"band_counts": {},
		"base_counts": {},
		"charisma": request.charisma_value,
		"effective_band_weight_sums": {},
		"expected_band_probability_sums": {},
		"expected_relative_weights": {
			"bases": _expected_base_weights(request, equipment),
			"rarities": _expected_rarity_weights(request, foundation),
		},
		"failed": 0,
		"failure_counts": {},
		"family": metadata["family"],
		"heat": request.heat,
		"identity": metadata["identity"],
		"item_level": request.item_level,
		"issuer_namespace": issuer_namespace,
		"key": metadata["identity"],
		"label": metadata["label"],
		"match_count": 0,
		"matrix": metadata["family"],
		"party_biased": metadata["party_biased"],
		"rarity_counts": {},
		"request": request.canonical_document(),
		"succeeded": 0,
		"selected_effective_weight_uplift_sum": 0.0,
		"selected_explicit_affix_count": 0,
		"selection_opportunities": 0,
		"sort_order": (metadata["sort_order"] as Array).duplicate(),
		"target_archetype": metadata["target_archetype"],
		"tier_counts": {},
		"weapon_maximums": [],
		"weapon_minimums": [],
	}

static func _record_result(
	scenario: Dictionary,
	state: Dictionary,
	result: ItemGenerationResult,
	request: ItemGenerationRequest,
	issuer_namespace: String,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> void:
	scenario["attempted"] = int(scenario["attempted"]) + 1
	state["attempted"] = int(state["attempted"]) + 1
	if result == null or not result.ok():
		scenario["failed"] = int(scenario["failed"]) + 1
		state["failed"] = int(state["failed"]) + 1
		var failure_key := "invalid_result"
		if result != null and result.failure != null:
			failure_key = "%s/%s" % [result.failure.stage, result.failure.code]
		_increment(scenario["failure_counts"] as Dictionary, failure_key)
		_increment(state["failure_counts"] as Dictionary, failure_key)
		return
	scenario["succeeded"] = int(scenario["succeeded"]) + 1
	state["succeeded"] = int(state["succeeded"]) + 1
	var item := result.item
	var instance_ids := state["instance_ids"] as Dictionary
	if instance_ids.has(item.instance_id):
		state["duplicate_instance_id_count"] = int(state["duplicate_instance_id_count"]) + 1
	else:
		instance_ids[item.instance_id] = true
	if not _origin_matches(item, issuer_namespace, request):
		state["origin_identity_mismatch_count"] = int(state["origin_identity_mismatch_count"]) + 1
	var base_id := String(item.base_definition_id)
	var rarity_id := String(item.rarity_id)
	_increment(scenario["base_counts"] as Dictionary, base_id)
	_increment(scenario["rarity_counts"] as Dictionary, rarity_id)
	_increment(state["rarity_counts"] as Dictionary, rarity_id)
	var base := equipment.definition(item.base_definition_id)
	var target_archetype := String(scenario["target_archetype"])
	if not target_archetype.is_empty():
		if base != null and StringName(target_archetype) in base.normalized_generation_tags():
			scenario["match_count"] = int(scenario["match_count"]) + 1
	_record_expected_affix_weights(scenario, state, result.trace, foundation)
	var base_tags: Array[StringName] = base.normalized_generation_tags() if base != null else []
	for affix: ItemAffixInstance in item.affixes:
		if affix == null or affix.affix_kind == "implicit":
			continue
		var definition := foundation.affix(affix.definition_id)
		if definition == null:
			continue
		var band_key := _weight_band_key(definition.base_weight)
		_increment(scenario["band_counts"] as Dictionary, band_key)
		_increment(state["band_counts"] as Dictionary, band_key)
		var effective_weight := ItemGenerationWeightPolicy.affix_weight(definition, request, base_tags)
		if definition.base_weight > 0.0:
			scenario["selected_effective_weight_uplift_sum"] = float(scenario["selected_effective_weight_uplift_sum"]) + effective_weight / definition.base_weight
		scenario["selected_explicit_affix_count"] = int(scenario["selected_explicit_affix_count"]) + 1
		var tier_key := "%02d" % affix.tier
		_increment(scenario["tier_counts"] as Dictionary, tier_key)
		_increment(state["tier_counts"] as Dictionary, tier_key)
	if not item.base_damage_components.is_empty():
		var minimum_total := 0.0
		var maximum_total := 0.0
		for component: ItemBaseDamageComponent in item.base_damage_components:
			if component != null:
				minimum_total += component.minimum_damage
				maximum_total += component.maximum_damage
		(scenario["weapon_minimums"] as Array).append(minimum_total)
		(scenario["weapon_maximums"] as Array).append(maximum_total)
		(state["weapon_minimums"] as Array).append(minimum_total)
		(state["weapon_maximums"] as Array).append(maximum_total)

static func _finalize_scenario(scenario: Dictionary) -> Dictionary:
	var attempted := int(scenario["attempted"])
	var succeeded := int(scenario["succeeded"])
	var match_count := int(scenario["match_count"])
	var tier_counts := scenario["tier_counts"] as Dictionary
	var tier_total := 0
	var tier_sum := 0.0
	for key: Variant in tier_counts:
		var count := int(tier_counts[key])
		tier_total += count
		tier_sum += float(int(String(key))) * count
	var selection_opportunities := int(scenario["selection_opportunities"])
	var expected_band_probabilities: Dictionary = {}
	for key: String in scenario["expected_band_probability_sums"]:
		expected_band_probabilities[key] = _rounded(float((scenario["expected_band_probability_sums"] as Dictionary)[key]) / selection_opportunities) if selection_opportunities > 0 else 0.0
	var selected_explicit_count := int(scenario["selected_explicit_affix_count"])
	var result := {
		"attempted": attempted,
		"average_explicit_tier": _rounded(tier_sum / tier_total if tier_total > 0 else 0.0),
		"charisma": scenario["charisma"],
		"failed": int(scenario["failed"]),
		"failure_counts": _sorted_counts(scenario["failure_counts"] as Dictionary),
		"family": scenario["family"],
		"heat": scenario["heat"],
		"item_level": int(scenario["item_level"]),
		"identity": scenario["identity"],
		"issuer_namespace": scenario["issuer_namespace"],
		"key": scenario["key"],
		"label": scenario["label"],
		"matrix": scenario["matrix"],
		"observed": {
			"bases": _count_and_proportion_rows(scenario["base_counts"] as Dictionary),
			"rarities": _count_and_proportion_rows(scenario["rarity_counts"] as Dictionary),
			"tiers": _count_and_proportion_rows(tier_counts),
			"weight_bands": _count_and_proportion_rows(scenario["band_counts"] as Dictionary),
		},
		"party_bias": {
			"biased": bool(scenario["party_biased"]),
			"match_count": match_count,
			"match_proportion": _ratio(match_count, succeeded),
			"off_count": succeeded - match_count if not String(scenario["target_archetype"]).is_empty() else 0,
			"target_archetype": scenario["target_archetype"],
		},
		"policy_evidence": {
			"average_selected_effective_weight_uplift": _rounded(float(scenario["selected_effective_weight_uplift_sum"]) / selected_explicit_count) if selected_explicit_count > 0 else 0.0,
			"effective_band_weight_sums": _rounded_float_dictionary(scenario["effective_band_weight_sums"] as Dictionary),
			"expected_band_selection_proportions": expected_band_probabilities,
			"explicit_affix_selection_count": selected_explicit_count,
			"selection_opportunity_count": selection_opportunities,
			"selected_effective_weight_uplift_sum": _rounded(float(scenario["selected_effective_weight_uplift_sum"])),
		},
		"request": scenario["request"],
		"sort_order": scenario["sort_order"],
		"expected_relative_weights": scenario["expected_relative_weights"],
		"succeeded": succeeded,
		"weapon_damage_percentiles": _weapon_percentiles(
			scenario["weapon_minimums"] as Array,
			scenario["weapon_maximums"] as Array
		),
	}
	return ItemGenerationTrace.canonical_json_copy(result) as Dictionary

static func _finalize_aggregates(
	state: Dictionary,
	scenarios: Array[Dictionary],
	foundation: ItemFoundationCatalog
) -> Dictionary:
	var band_definitions := state["band_definitions"] as Dictionary
	var band_counts := state["band_counts"] as Dictionary
	var band_total := _count_total(band_counts)
	var weight_bands: Dictionary = {}
	var opportunity_count := int(state["explicit_selection_opportunities"])
	var expected_proportions: Dictionary = {}
	for key: String in band_definitions:
		expected_proportions[key] = _rounded(float((state["expected_band_probability_sums"] as Dictionary).get(key, 0.0)) / opportunity_count) if opportunity_count > 0 else 0.0
	var core_expected := float(expected_proportions.get("1000_core_focused", 0.0))
	for key: String in band_definitions:
		var authored := band_definitions[key] as Dictionary
		var selected := int(band_counts.get(key, 0))
		weight_bands[key] = {
			"definition_count": authored["definition_count"],
			"effective_weight_sum": _rounded(float((state["effective_band_weight_sums"] as Dictionary).get(key, 0.0))),
			"expected_effective_selection_proportion": expected_proportions[key],
			"expected_relative_to_core": _rounded(float(expected_proportions[key]) / core_expected) if core_expected > 0.0 else 0.0,
			"explicit_affix_selection_denominator": band_total,
			"selected_explicit_affix_count": selected,
			"selected_explicit_affix_proportion": _ratio(selected, band_total),
			"selection_opportunity_denominator": opportunity_count,
			"weight": authored["weight"],
		}
	var tier_counts := state["tier_counts"] as Dictionary
	var rarity_counts := state["rarity_counts"] as Dictionary
	return {
		"charisma": _charisma_aggregate(scenarios),
		"failure_counts": _sorted_counts(state["failure_counts"] as Dictionary),
		"fill_rates": {
			"rarities": {
				"eligible_count": ORDINARY_RARITY_IDS.size(),
				"fill_rate": _ratio(rarity_counts.size(), ORDINARY_RARITY_IDS.size()),
				"observed_count": rarity_counts.size(),
			},
			"tiers": {
				"eligible_count": 12,
				"fill_rate": _ratio(tier_counts.size(), 12),
				"observed_count": tier_counts.size(),
			},
		},
		"heat": _heat_aggregate(scenarios),
		"party_bias": _party_aggregate(scenarios),
		"rarity_counts": _count_and_proportion_rows(rarity_counts),
		"tier_counts": _count_and_proportion_rows(tier_counts),
		"tier_trend": {
			"level_1_average": _level_average_tier(scenarios, 1, "level_rarity"),
			"level_1000_average": _level_average_tier(scenarios, 1000, "level_rarity"),
		},
		"weapon_damage_percentiles": _weapon_percentiles(
			state["weapon_minimums"] as Array,
			state["weapon_maximums"] as Array
		),
		"weight_bands": weight_bands,
	}

static func _manifest(equipment: EquipmentCatalog, foundation: ItemFoundationCatalog) -> Dictionary:
	var base_ids: Array[String] = []
	var weapon_ids: Array[String] = []
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base == null:
			continue
		base_ids.append(String(base.id))
		if base.weapon_damage_profile != null:
			weapon_ids.append(String(base.id))
	base_ids.sort()
	weapon_ids.sort()
	var affix_ids: Array[String] = []
	var implicit_count := 0
	var prefix_count := 0
	var suffix_count := 0
	var reachability: Array[Dictionary] = []
	var sorted_affixes := foundation.affixes.duplicate()
	sorted_affixes.sort_custom(func(left: ItemAffixDefinition, right: ItemAffixDefinition) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		return String(left.id) < String(right.id)
	)
	var unreachable_ids: Array[String] = []
	for definition: ItemAffixDefinition in sorted_affixes:
		if definition == null:
			continue
		affix_ids.append(String(definition.id))
		match definition.affix_kind:
			"implicit": implicit_count += 1
			"prefix": prefix_count += 1
			"suffix": suffix_count += 1
		var row := _reachability_row(definition, equipment, foundation)
		reachability.append(row)
		if not bool(row["reachable"]):
			unreachable_ids.append(String(definition.id))
	var ordinary_ids: Array[String] = []
	var disabled_ids: Array[String] = []
	for rarity: ItemRarityDefinition in foundation.rarities:
		if rarity == null:
			continue
		if rarity.ordinary_generation_enabled:
			ordinary_ids.append(String(rarity.id))
		else:
			disabled_ids.append(String(rarity.id))
	ordinary_ids.sort()
	disabled_ids.sort()
	var nonweapon_ids := base_ids.duplicate()
	for weapon_id: String in weapon_ids:
		nonweapon_ids.erase(weapon_id)
	return {
		"affix_ids": affix_ids,
		"base_ids": base_ids,
		"counts": {
			"affixes": affix_ids.size(),
			"bases": base_ids.size(),
			"explicit_affixes": prefix_count + suffix_count,
			"implicit_affixes": implicit_count,
			"prefixes": prefix_count,
			"suffixes": suffix_count,
			"weapon_profile_bases": weapon_ids.size(),
		},
		"exclusions": {
			"nonweapon_base_ids": nonweapon_ids,
			"ordinary_disabled_rarity_ids": disabled_ids,
			"ordinary_rarity_ids": ordinary_ids,
			"unreachable_affix_ids": unreachable_ids,
		},
		"reachability": reachability,
		"weapon_profile_base_ids": weapon_ids,
	}

static func _reachability_row(
	definition: ItemAffixDefinition,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> Dictionary:
	var eligible_base_ids: Array[String] = []
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base == null:
			continue
		if definition.affix_kind == "implicit":
			if definition.id in base.implicit_affix_ids:
				eligible_base_ids.append(String(base.id))
			continue
		var tags := base.normalized_generation_tags()
		if definition.required_item_tags.any(func(tag: StringName) -> bool: return tag not in tags):
			continue
		if definition.excluded_item_tags.any(func(tag: StringName) -> bool: return tag in tags):
			continue
		eligible_base_ids.append(String(base.id))
	eligible_base_ids.sort()
	var eligible_rarity_ids: Array[String] = []
	var eligible_pattern_ids_by_rarity: Dictionary = {}
	var excluded_rarity_reasons: Dictionary = {}
	var minimum_level := ItemGenerationRequest.MAX_ITEM_LEVEL + 1
	var maximum_tier := 0
	for tier: ItemAffixTierDefinition in definition.tiers:
		if tier == null or tier.minimum_item_level < 1 or tier.minimum_item_level > ItemGenerationRequest.MAX_ITEM_LEVEL:
			continue
		minimum_level = mini(minimum_level, tier.minimum_item_level)
		maximum_tier = maxi(maximum_tier, tier.tier)
	for rarity_id: StringName in ORDINARY_RARITY_IDS:
		var rarity := foundation.rarity(rarity_id)
		var pattern_ids := _eligible_pattern_ids(rarity, definition.affix_kind, &"ordinary_drop")
		if definition.affix_kind != "implicit" and pattern_ids.is_empty():
			excluded_rarity_reasons[String(rarity_id)] = "no_%s_pattern_capacity" % definition.affix_kind
			continue
		if not _definition_has_reachable_tier(definition, rarity_id, &"ordinary_enemy", &"ordinary_drop"):
			excluded_rarity_reasons[String(rarity_id)] = "affix_or_tier_gate"
			continue
		if definition.required_unlock_tags.any(func(tag: StringName) -> bool: return tag not in ORDINARY_UNLOCK_TAGS):
			excluded_rarity_reasons[String(rarity_id)] = "missing_unlock_tag"
			continue
		eligible_rarity_ids.append(String(rarity_id))
		eligible_pattern_ids_by_rarity[String(rarity_id)] = pattern_ids
	eligible_rarity_ids.sort()
	var reachable := not eligible_base_ids.is_empty() and not eligible_rarity_ids.is_empty() and minimum_level <= ItemGenerationRequest.MAX_ITEM_LEVEL
	return {
		"base_weight": definition.base_weight,
		"eligible_base_count": eligible_base_ids.size(),
		"eligible_base_ids": eligible_base_ids,
		"eligible_pattern_ids_by_rarity": eligible_pattern_ids_by_rarity,
		"eligible_rarity_ids": eligible_rarity_ids,
		"excluded_base_count": equipment.definitions.size() - eligible_base_ids.size(),
		"excluded_rarity_ids": _difference(_ordinary_rarity_strings(), eligible_rarity_ids),
		"excluded_rarity_reasons": excluded_rarity_reasons,
		"id": String(definition.id),
		"kind": definition.affix_kind,
		"maximum_tier": maximum_tier,
		"minimum_item_level": minimum_level if reachable else 0,
		"reachable": reachable,
		"weight_band": _weight_band_key(definition.base_weight) if definition.affix_kind != "implicit" else "implicit",
	}

static func _eligible_pattern_ids(rarity: ItemRarityDefinition, affix_kind: String, domain: StringName) -> Array[String]:
	var result: Array[String] = []
	if rarity == null or affix_kind == "implicit":
		return result
	for pattern: ItemAffixPatternDefinition in rarity.patterns:
		if pattern == null:
			continue
		if not pattern.allowed_generation_domains.is_empty() and domain not in pattern.allowed_generation_domains:
			continue
		var capacity := 0
		match affix_kind:
			"prefix": capacity = pattern.prefix_count
			"suffix": capacity = pattern.suffix_count
			"special": capacity = pattern.special_count
		if capacity > 0:
			result.append(String(pattern.id))
	result.sort()
	return result

static func _definition_has_reachable_tier(definition: ItemAffixDefinition, rarity_id: StringName, source_id: StringName, domain: StringName) -> bool:
	if not definition.allowed_rarity_ids.is_empty() and rarity_id not in definition.allowed_rarity_ids:
		return false
	if not definition.allowed_source_ids.is_empty() and source_id not in definition.allowed_source_ids:
		return false
	if not definition.allowed_generation_domains.is_empty() and domain not in definition.allowed_generation_domains:
		return false
	for tier: ItemAffixTierDefinition in definition.tiers:
		if tier == null or tier.minimum_item_level < 1 or tier.minimum_item_level > ItemGenerationRequest.MAX_ITEM_LEVEL:
			continue
		if not tier.allowed_rarity_ids.is_empty() and rarity_id not in tier.allowed_rarity_ids:
			continue
		if not tier.allowed_source_ids.is_empty() and source_id not in tier.allowed_source_ids:
			continue
		if not tier.allowed_generation_domains.is_empty() and domain not in tier.allowed_generation_domains:
			continue
		return true
	return false

static func _weight_band_definitions(foundation: ItemFoundationCatalog) -> Dictionary:
	var rows := {
		"0025_premium_hybrid": {"definition_count": 0, "weight": 25},
		"0150_standard_hybrid": {"definition_count": 0, "weight": 150},
		"0500_specialized_focused": {"definition_count": 0, "weight": 500},
		"1000_core_focused": {"definition_count": 0, "weight": 1000},
	}
	for definition: ItemAffixDefinition in foundation.affixes:
		if definition == null or definition.affix_kind == "implicit":
			continue
		var key := _weight_band_key(definition.base_weight)
		if not rows.has(key):
			continue
		var row := rows[key] as Dictionary
		row["definition_count"] = int(row["definition_count"]) + 1
	return ItemGenerationTrace.canonical_json_copy(rows) as Dictionary

static func _weight_band_key(weight: float) -> String:
	if is_equal_approx(weight, 25.0):
		return "0025_premium_hybrid"
	if is_equal_approx(weight, 150.0):
		return "0150_standard_hybrid"
	if is_equal_approx(weight, 500.0):
		return "0500_specialized_focused"
	if is_equal_approx(weight, 1000.0):
		return "1000_core_focused"
	return "other_%s" % _number(weight)

static func _expected_base_weights(request: ItemGenerationRequest, equipment: EquipmentCatalog) -> Dictionary:
	var weights: Dictionary = {}
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base == null:
			continue
		if not request.forced_base_id.is_empty() and base.id != request.forced_base_id:
			continue
		var tags := base.normalized_generation_tags()
		if request.required_base_tags.any(func(tag: StringName) -> bool: return tag not in tags):
			continue
		if request.excluded_base_tags.any(func(tag: StringName) -> bool: return tag in tags):
			continue
		weights[String(base.id)] = ItemGenerationWeightPolicy.base_weight(base, request)
	return _normalized_weights(weights)

static func _expected_rarity_weights(request: ItemGenerationRequest, foundation: ItemFoundationCatalog) -> Dictionary:
	var weights: Dictionary = {}
	for rarity: ItemRarityDefinition in foundation.rarities:
		if rarity == null or not rarity.instance_supported or not rarity.ordinary_generation_enabled:
			continue
		if rarity.id not in request.permitted_rarity_ids:
			continue
		if not request.forced_rarity_id.is_empty() and rarity.id != request.forced_rarity_id:
			continue
		if rarity.required_unlock_tags.any(func(tag: StringName) -> bool: return tag not in request.unlock_tags):
			continue
		weights[String(rarity.id)] = ItemGenerationWeightPolicy.rarity_weight(rarity, request)
	return _normalized_weights(weights)

static func _normalized_weights(weights: Dictionary) -> Dictionary:
	var total := 0.0
	for value: Variant in weights.values():
		total += float(value)
	var normalized: Dictionary = {}
	var keys: Array[String] = []
	for key: Variant in weights:
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		normalized[key] = _rounded(float(weights[key]) / total) if total > 0.0 else 0.0
	return normalized

static func _count_and_proportion_rows(counts: Dictionary) -> Dictionary:
	var total := _count_total(counts)
	var result: Dictionary = {}
	var keys: Array[String] = []
	for key: Variant in counts:
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		var count := int(counts[key])
		result[key] = {"count": count, "proportion": _ratio(count, total)}
	return result

static func _sorted_counts(counts: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array[String] = []
	for key: Variant in counts:
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		result[key] = int(counts[key])
	return result

static func _count_total(counts: Dictionary) -> int:
	var total := 0
	for value: Variant in counts.values():
		total += int(value)
	return total

static func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

static func _add_float(values: Dictionary, key: String, amount: float) -> void:
	values[key] = float(values.get(key, 0.0)) + amount

static func _origin_matches(item: ItemInstance, issuer_namespace: String, request: ItemGenerationRequest) -> bool:
	if item == null:
		return false
	var origin := item.origin
	if origin.get("issuer_namespace", "") != issuer_namespace or int(origin.get("sequence", -1)) != request.generation_sequence or int(origin.get("seed", -1)) != request.seed:
		return false
	var source := origin.get("source", {}) as Dictionary
	var generation := source.get("generation", {}) as Dictionary
	if not (
		int(generation.get("request_sequence", -1)) == request.generation_sequence
		and int(generation.get("item_level", -1)) == request.item_level
		and generation.get("source_id", "") == String(request.source_id)
		and generation.get("domain", "") == String(request.generation_domain)
		and int(generation.get("generator_version", -1)) == ItemGenerationService.GENERATOR_VERSION
		and generation.get("selected_base_id", "") == String(item.base_definition_id)
		and generation.get("selected_rarity_id", "") == String(item.rarity_id)
	):
		return false
	if not request.forced_base_id.is_empty() and generation.get("forced_base_id", "") != String(request.forced_base_id):
		return false
	if not request.forced_rarity_id.is_empty() and generation.get("forced_rarity_id", "") != String(request.forced_rarity_id):
		return false
	return true

static func _record_expected_affix_weights(
	scenario: Dictionary,
	state: Dictionary,
	trace: ItemGenerationTrace,
	foundation: ItemFoundationCatalog
) -> void:
	if trace == null:
		return
	for opportunity: Dictionary in ItemGenerationAnalysis.selection_opportunities(trace):
		if not String(opportunity.get("stage", "")).begins_with("affix:"):
			continue
		if not bool(opportunity.get("valid", false)):
			continue
		var weights := opportunity.get("weights", {}) as Dictionary
		var total := 0.0
		var band_sums: Dictionary = {}
		for affix_id: String in weights:
			var weight := float(weights[affix_id])
			var definition := foundation.affix(StringName(affix_id))
			if definition == null or weight <= 0.0 or not is_finite(weight):
				continue
			var band_key := _weight_band_key(definition.base_weight)
			_add_float(band_sums, band_key, weight)
			total += weight
		if total <= 0.0 or not is_finite(total):
			continue
		scenario["selection_opportunities"] = int(scenario["selection_opportunities"]) + 1
		state["explicit_selection_opportunities"] = int(state["explicit_selection_opportunities"]) + 1
		for band_key: String in state["band_definitions"]:
			var effective_weight := float(band_sums.get(band_key, 0.0))
			var probability := effective_weight / total
			_add_float(scenario["effective_band_weight_sums"] as Dictionary, band_key, effective_weight)
			_add_float(state["effective_band_weight_sums"] as Dictionary, band_key, effective_weight)
			_add_float(scenario["expected_band_probability_sums"] as Dictionary, band_key, probability)
			_add_float(state["expected_band_probability_sums"] as Dictionary, band_key, probability)

static func _rounded_float_dictionary(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array[String] = []
	for key: Variant in values:
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		result[key] = _rounded(float(values[key]))
	return result

static func _party_aggregate(scenarios: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for archetype: StringName in ARCHETYPE_IDS:
		var neutral: Dictionary = {}
		var biased: Dictionary = {}
		for scenario: Dictionary in scenarios:
			if scenario["matrix"] != "archetype_party_bias":
				continue
			var party := scenario["party_bias"] as Dictionary
			if party["target_archetype"] != String(archetype):
				continue
			if bool(party["biased"]):
				biased = party
			else:
				neutral = party
		result[String(archetype)] = {
			"biased_match_count": int(biased.get("match_count", 0)),
			"biased_match_proportion": float(biased.get("match_proportion", 0.0)),
			"biased_off_count": int(biased.get("off_count", 0)),
			"neutral_match_count": int(neutral.get("match_count", 0)),
			"neutral_match_proportion": float(neutral.get("match_proportion", 0.0)),
		}
	return result

static func _charisma_aggregate(scenarios: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for charisma: int in CHARISMA_VALUES:
		var premium_count := 0
		var explicit_count := 0
		var expected_premium_sum := 0.0
		var opportunity_count := 0
		var maximum_tier := 0
		var uplift_sum := 0.0
		for scenario: Dictionary in scenarios:
			if scenario["matrix"] != "charisma_heat" or int(float(scenario["charisma"])) != charisma:
				continue
			var observed := scenario["observed"] as Dictionary
			var bands := observed["weight_bands"] as Dictionary
			for key: String in bands:
				explicit_count += int((bands[key] as Dictionary)["count"])
			premium_count += int((bands.get("0025_premium_hybrid", {}) as Dictionary).get("count", 0))
			var policy := scenario.get("policy_evidence", {}) as Dictionary
			var scenario_opportunities := int(policy.get("selection_opportunity_count", 0))
			opportunity_count += scenario_opportunities
			expected_premium_sum += float((policy.get("expected_band_selection_proportions", {}) as Dictionary).get("0025_premium_hybrid", 0.0)) * scenario_opportunities
			uplift_sum += float(policy.get("selected_effective_weight_uplift_sum", 0.0))
			var tiers := observed["tiers"] as Dictionary
			for tier_key: String in tiers:
				maximum_tier = maxi(maximum_tier, int(tier_key))
		result[str(charisma)] = {
			"average_selected_effective_weight_uplift": _rounded(uplift_sum / explicit_count) if explicit_count > 0 else 0.0,
			"diminishing_value": _rounded(ItemGenerationWeightPolicy.diminishing_charisma(float(charisma))),
			"expected_premium_selection_proportion": _rounded(expected_premium_sum / opportunity_count) if opportunity_count > 0 else 0.0,
			"explicit_affix_selection_count": explicit_count,
			"maximum_observed_tier": maximum_tier,
			"premium_count": premium_count,
			"premium_proportion": _ratio(premium_count, explicit_count),
			"selection_opportunity_count": opportunity_count,
		}
	return result

static func _heat_aggregate(scenarios: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for heat: int in HEAT_VALUES:
		var rarity_counts: Dictionary = {}
		for scenario: Dictionary in scenarios:
			if scenario["matrix"] != "charisma_heat" or int(float(scenario["heat"])) != heat:
				continue
			var observed := scenario["observed"] as Dictionary
			for rarity_id: String in observed["rarities"]:
				var row := (observed["rarities"] as Dictionary)[rarity_id] as Dictionary
				rarity_counts[rarity_id] = int(rarity_counts.get(rarity_id, 0)) + int(row["count"])
		var total := _count_total(rarity_counts)
		var upper := int(rarity_counts.get("rare", 0)) + int(rarity_counts.get("epic", 0)) + int(rarity_counts.get("legendary", 0))
		result[str(heat)] = {
			"rarity_counts": _sorted_counts(rarity_counts),
			"upper_rarity_count": upper,
			"upper_rarity_proportion": _ratio(upper, total),
		}
	return result

static func _level_average_tier(scenarios: Array[Dictionary], level: int, matrix: String) -> float:
	var tier_sum := 0.0
	var tier_count := 0
	for scenario: Dictionary in scenarios:
		if scenario["matrix"] != matrix or int(scenario["item_level"]) != level:
			continue
		var tiers := (scenario["observed"] as Dictionary)["tiers"] as Dictionary
		for tier_key: String in tiers:
			var count := int((tiers[tier_key] as Dictionary)["count"])
			tier_count += count
			tier_sum += int(tier_key) * count
	return _rounded(tier_sum / tier_count if tier_count > 0 else 0.0)

static func _weapon_percentiles(minimums: Array, maximums: Array) -> Dictionary:
	return {
		"convention": "linear interpolation at rank (n - 1) * p; P0 minimum, P50 median, P90 high",
		"maximum_damage": percentile_summary(maximums),
		"minimum_damage": percentile_summary(minimums),
		"sample_count": mini(minimums.size(), maximums.size()),
	}

static func _linear_percentile(sorted_values: Array, percentile: float) -> float:
	var rank := float(sorted_values.size() - 1) * clampf(percentile, 0.0, 1.0)
	var lower := int(floor(rank))
	var upper := int(ceil(rank))
	if lower == upper:
		return float(sorted_values[lower])
	return lerpf(float(sorted_values[lower]), float(sorted_values[upper]), rank - lower)

static func _append_manifest_markdown(lines: Array[String], manifest: Dictionary) -> void:
	var counts := manifest.get("counts", {}) as Dictionary
	lines.append("## Exact manifest and exclusions")
	lines.append("")
	lines.append(_markdown_row(["Bases", "Weapon profiles", "Affixes", "Explicit", "Implicit", "Prefixes", "Suffixes"]))
	lines.append(_markdown_row(["---:", "---:", "---:", "---:", "---:", "---:", "---:"]))
	lines.append(_markdown_row([
		int(counts.get("bases", 0)), int(counts.get("weapon_profile_bases", 0)), int(counts.get("affixes", 0)),
		int(counts.get("explicit_affixes", 0)), int(counts.get("implicit_affixes", 0)),
		int(counts.get("prefixes", 0)), int(counts.get("suffixes", 0)),
	]))
	var exclusions := manifest.get("exclusions", {}) as Dictionary
	lines.append("")
	lines.append("- Ordinary rarities: %s" % ", ".join(exclusions.get("ordinary_rarity_ids", []) as Array))
	lines.append("- Excluded nonordinary rarities: %s" % ", ".join(exclusions.get("ordinary_disabled_rarity_ids", []) as Array))
	lines.append("- Bases excluded from weapon percentiles: %d" % (exclusions.get("nonweapon_base_ids", []) as Array).size())
	lines.append("- Unreachable affixes: %d" % (exclusions.get("unreachable_affix_ids", []) as Array).size())
	lines.append("")
	lines.append("### Affix reachability")
	lines.append("")
	lines.append(_markdown_row(["Affix", "Kind", "Weight", "Band", "Min level", "Max tier", "Eligible bases", "Eligible rarities", "Reachable"]))
	lines.append(_markdown_row(["---", "---", "---:", "---", "---:", "---:", "---:", "---", "---"]))
	for row_value: Variant in manifest.get("reachability", []) as Array:
		var row := row_value as Dictionary
		lines.append(_markdown_row([
			row.get("id", ""), row.get("kind", ""), _number(float(row.get("base_weight", 0.0))), row.get("weight_band", ""),
			int(row.get("minimum_item_level", 0)), int(row.get("maximum_tier", 0)), int(row.get("eligible_base_count", 0)),
			", ".join(row.get("eligible_rarity_ids", []) as Array), "yes" if bool(row.get("reachable", false)) else "no",
		]))
	lines.append("")

static func _append_aggregate_markdown(lines: Array[String], aggregates: Dictionary) -> void:
	lines.append("## Distribution findings")
	lines.append("")
	lines.append("### Explicit weight bands")
	lines.append("")
	lines.append("Each count below is an explicit-affix selection, not an item. Expected proportions are averaged from the live effective candidate weights recorded at every explicit selection opportunity; relative-to-core divides each expected proportion by the core-focused expected proportion.")
	lines.append("")
	lines.append(_markdown_row(["Band", "Definitions", "Expected effective proportion", "Expected relative to core", "Selected explicit affixes", "Explicit-affix denominator", "Selected proportion"]))
	lines.append(_markdown_row(["---", "---:", "---:", "---:", "---:", "---:", "---:"]))
	for key: String in aggregates.get("weight_bands", {}):
		var row := (aggregates["weight_bands"] as Dictionary)[key] as Dictionary
		lines.append(_markdown_row([key, int(row["definition_count"]), _number(float(row["expected_effective_selection_proportion"])), _number(float(row["expected_relative_to_core"])), int(row["selected_explicit_affix_count"]), int(row["explicit_affix_selection_denominator"]), _number(float(row["selected_explicit_affix_proportion"]))]))
	var tier_trend := aggregates.get("tier_trend", {}) as Dictionary
	var fill_rates := aggregates.get("fill_rates", {}) as Dictionary
	lines.append("")
	lines.append("- Average explicit tier at level 1: %s; at level 1000: %s." % [_number(float(tier_trend.get("level_1_average", 0.0))), _number(float(tier_trend.get("level_1000_average", 0.0)))])
	lines.append("- Rarity fill: %d/%d; tier fill: %d/%d." % [
		int((fill_rates.get("rarities", {}) as Dictionary).get("observed_count", 0)), int((fill_rates.get("rarities", {}) as Dictionary).get("eligible_count", 0)),
		int((fill_rates.get("tiers", {}) as Dictionary).get("observed_count", 0)), int((fill_rates.get("tiers", {}) as Dictionary).get("eligible_count", 0)),
	])
	lines.append("")
	lines.append("### Party bias")
	lines.append("")
	lines.append(_markdown_row(["Archetype", "Neutral match", "Biased match", "Biased off-party count"]))
	lines.append(_markdown_row(["---", "---:", "---:", "---:"]))
	for archetype: String in aggregates.get("party_bias", {}):
		var row := (aggregates["party_bias"] as Dictionary)[archetype] as Dictionary
		lines.append(_markdown_row([archetype, _number(float(row["neutral_match_proportion"])), _number(float(row["biased_match_proportion"])), int(row["biased_off_count"])]))
	lines.append("")
	lines.append("### Charisma, Heat, and weapon damage")
	lines.append("")
	for charisma: String in _numeric_string_keys(aggregates.get("charisma", {}) as Dictionary):
		var row := (aggregates["charisma"] as Dictionary)[charisma] as Dictionary
		lines.append("- Charisma %s: generated selected effective/base-weight uplift %s, expected premium selection proportion %s, observed premium proportion %s, maximum observed tier %d." % [charisma, _number(float(row["average_selected_effective_weight_uplift"])), _number(float(row["expected_premium_selection_proportion"])), _number(float(row["premium_proportion"])), int(row["maximum_observed_tier"])])
	for heat: String in _numeric_string_keys(aggregates.get("heat", {}) as Dictionary):
		var row := (aggregates["heat"] as Dictionary)[heat] as Dictionary
		lines.append("- Heat %s: rare-or-better proportion %s." % [heat, _number(float(row["upper_rarity_proportion"]))])
	var weapon := aggregates.get("weapon_damage_percentiles", {}) as Dictionary
	lines.append("- Weapon percentile convention: %s." % weapon.get("convention", ""))
	for key: String in ["minimum_damage", "maximum_damage"]:
		var row := weapon.get(key, {}) as Dictionary
		lines.append("- Weapon %s percentiles: minimum %s, median %s, high (P90) %s." % [key.replace("_", " "), _number(float(row.get("minimum", 0.0))), _number(float(row.get("median", 0.0))), _number(float(row.get("high", 0.0)))])
	lines.append("")

static func _ordinary_rarity_strings() -> Array[String]:
	var result: Array[String] = []
	for id: StringName in ORDINARY_RARITY_IDS:
		result.append(String(id))
	result.sort()
	return result

static func _difference(all_values: Array[String], included: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in all_values:
		if value not in included:
			result.append(value)
	return result

static func _ratio(numerator: int, denominator: int) -> float:
	return _rounded(float(numerator) / float(denominator)) if denominator > 0 else 0.0

static func _rounded(value: float) -> float:
	return snappedf(value, 0.000001)

static func _number(value: float) -> String:
	return "%.6f" % value

static func _markdown_row(cells: Array) -> String:
	var rendered: Array[String] = []
	for cell: Variant in cells:
		rendered.append(_markdown_cell(cell))
	return "| %s |" % " | ".join(rendered)

static func _markdown_cell(value: Variant) -> String:
	var result := str(value)
	result = result.replace("\\", "\\\\")
	result = result.replace("|", "\\|")
	result = result.replace("\r\n", "<br>").replace("\r", "<br>").replace("\n", "<br>")
	return result

static func _numeric_string_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in values:
		keys.append(str(key))
	keys.sort_custom(func(left: String, right: String) -> bool: return int(left) < int(right))
	return keys
