class_name ItemGenerationBalanceReport
extends RefCounted

const SCHEMA_VERSION := 1
const SEQUENCES_PER_ROW := 2000
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

static func production_requests(_foundation: ItemFoundationCatalog = null) -> Array[ItemGenerationRequest]:
	var requests: Array[ItemGenerationRequest] = []
	var level_row := 0
	for level: int in LEVELS:
		for rarity_id: StringName in ORDINARY_RARITY_IDS:
			var request := _ordinary_request(LEVEL_SEED_BASE + level_row, level)
			request.permitted_rarity_ids = [rarity_id]
			request.forced_rarity_id = rarity_id
			requests.append(request)
			level_row += 1
	for archetype_index: int in ARCHETYPE_IDS.size():
		for biased_index: int in 2:
			var request := _ordinary_request(ARCHETYPE_SEED_BASE + archetype_index * 2 + biased_index, 600)
			if biased_index == 1:
				request.party_archetype_tags = [ARCHETYPE_IDS[archetype_index]]
			requests.append(request)
	for charisma_index: int in CHARISMA_VALUES.size():
		for heat_index: int in HEAT_VALUES.size():
			var request := _ordinary_request(CHARISMA_SEED_BASE + charisma_index * HEAT_VALUES.size() + heat_index, 1)
			request.charisma_value = float(CHARISMA_VALUES[charisma_index])
			request.heat = float(HEAT_VALUES[heat_index])
			requests.append(request)
	return requests

static func build(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest]
) -> Dictionary:
	var input_error := _input_error(equipment, foundation, requests)
	if not input_error.is_empty():
		return _error_report(input_error)
	var sorted_requests := requests.duplicate()
	sorted_requests.sort_custom(func(left: ItemGenerationRequest, right: ItemGenerationRequest) -> bool:
		return _scenario_key(left) < _scenario_key(right)
	)
	var matrix_counts := {
		"archetype_party_bias": 0,
		"charisma_heat": 0,
		"level_rarity": 0,
	}
	var scenarios: Array[Dictionary] = []
	var state := _initial_aggregate_state(foundation)
	for request: ItemGenerationRequest in sorted_requests:
		var metadata := _scenario_metadata(request)
		var matrix := String(metadata["matrix"])
		matrix_counts[matrix] = int(matrix_counts.get(matrix, 0)) + 1
		var scenario := _initial_scenario(request, metadata, equipment, foundation)
		for sequence: int in SEQUENCES_PER_ROW:
			var sample := request.copy_with_sequence(sequence)
			var result := ItemGenerationService.generate(sample, "balance-report", sequence, equipment, foundation)
			_record_result(scenario, state, result, sample, equipment, foundation)
		scenarios.append(_finalize_scenario(scenario))
	var attempted := int(state["attempted"])
	var succeeded := int(state["succeeded"])
	var failed := int(state["failed"])
	var report := {
		"aggregates": _finalize_aggregates(state, scenarios, foundation),
		"configuration": {
			"expected_attempt_count": requests.size() * SEQUENCES_PER_ROW,
			"matrix_row_counts": matrix_counts,
			"scenario_count": requests.size(),
			"sequences_per_row": SEQUENCES_PER_ROW,
		},
		"manifest": _manifest(equipment, foundation),
		"scenarios": scenarios,
		"schema_version": SCHEMA_VERSION,
		"status": "ok",
		"summary": {
			"attempted": attempted,
			"failed": failed,
			"failure_proportion": _ratio(failed, attempted),
			"succeeded": succeeded,
			"success_proportion": _ratio(succeeded, attempted),
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
	lines.append("| Scenario | Attempts | Successes | Failures | Average explicit tier | Weapon samples |")
	lines.append("|---|---:|---:|---:|---:|---:|")
	for scenario_value: Variant in canonical.get("scenarios", []) as Array:
		var scenario := scenario_value as Dictionary
		var weapon := scenario.get("weapon_damage_percentiles", {}) as Dictionary
		lines.append("| %s | %d | %d | %d | %s | %d |" % [
			String(scenario.get("key", "")),
			int(scenario.get("attempted", 0)),
			int(scenario.get("succeeded", 0)),
			int(scenario.get("failed", 0)),
			_number(float(scenario.get("average_explicit_tier", 0.0))),
			int(weapon.get("sample_count", 0)),
		])
	lines.append("")
	return "\n".join(lines)

static func _ordinary_request(seed: int, item_level: int) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(seed, 0, item_level, &"ordinary_enemy", &"ordinary_drop", ORDINARY_RARITY_IDS)
	request.unlock_tags = ORDINARY_UNLOCK_TAGS.duplicate()
	return request

static func _input_error(
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	requests: Array[ItemGenerationRequest]
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
	var seen_keys: Dictionary = {}
	for index: int in requests.size():
		var request := requests[index]
		if request == null:
			return "request %d is missing" % index
		var request_error := request.validate(foundation)
		if not request_error.is_empty():
			return "request %d is invalid: %s" % [index, request_error]
		var key := _scenario_key(request)
		if seen_keys.has(key):
			return "request matrix has duplicate scenario key %s" % key
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
			"succeeded": 0,
			"success_proportion": 0.0,
		},
	}

static func _scenario_key(request: ItemGenerationRequest) -> String:
	return String(_scenario_metadata(request)["key"])

static func _scenario_metadata(request: ItemGenerationRequest) -> Dictionary:
	if request.seed >= LEVEL_SEED_BASE and request.seed < LEVEL_SEED_BASE + LEVELS.size() * ORDINARY_RARITY_IDS.size():
		return {
			"key": "level_rarity|level=%04d|rarity=%s" % [request.item_level, request.forced_rarity_id],
			"matrix": "level_rarity",
			"party_biased": false,
			"target_archetype": "",
		}
	if request.seed >= ARCHETYPE_SEED_BASE and request.seed < ARCHETYPE_SEED_BASE + ARCHETYPE_IDS.size() * 2:
		var offset := request.seed - ARCHETYPE_SEED_BASE
		var archetype := String(ARCHETYPE_IDS[offset / 2])
		var biased := offset % 2 == 1
		return {
			"key": "archetype_party_bias|archetype=%s|mode=%s" % [archetype, "biased" if biased else "neutral"],
			"matrix": "archetype_party_bias",
			"party_biased": biased,
			"target_archetype": archetype,
		}
	if request.seed >= CHARISMA_SEED_BASE and request.seed < CHARISMA_SEED_BASE + CHARISMA_VALUES.size() * HEAT_VALUES.size():
		return {
			"key": "charisma_heat|charisma=%04d|heat=%03d" % [int(request.charisma_value), int(request.heat)],
			"matrix": "charisma_heat",
			"party_biased": false,
			"target_archetype": "",
		}
	var canonical := request.canonical_document()
	return {
		"key": "custom|%s" % JSON.stringify(canonical).sha256_text(),
		"matrix": "custom",
		"party_biased": not request.party_archetype_tags.is_empty(),
		"target_archetype": String(request.party_archetype_tags[0]) if not request.party_archetype_tags.is_empty() else "",
	}

static func _initial_aggregate_state(foundation: ItemFoundationCatalog) -> Dictionary:
	var band_rows := _weight_band_definitions(foundation)
	var band_counts: Dictionary = {}
	for key: String in band_rows:
		band_counts[key] = 0
	return {
		"attempted": 0,
		"band_counts": band_counts,
		"band_definitions": band_rows,
		"failed": 0,
		"failure_counts": {},
		"rarity_counts": {},
		"succeeded": 0,
		"tier_counts": {},
		"weapon_maximums": [],
		"weapon_minimums": [],
	}

static func _initial_scenario(
	request: ItemGenerationRequest,
	metadata: Dictionary,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog
) -> Dictionary:
	return {
		"attempted": 0,
		"band_counts": {},
		"base_counts": {},
		"charisma": request.charisma_value,
		"expected_relative_weights": {
			"bases": _expected_base_weights(request, equipment),
			"rarities": _expected_rarity_weights(request, foundation),
		},
		"failed": 0,
		"failure_counts": {},
		"heat": request.heat,
		"item_level": request.item_level,
		"key": metadata["key"],
		"match_count": 0,
		"matrix": metadata["matrix"],
		"party_biased": metadata["party_biased"],
		"rarity_counts": {},
		"request": request.canonical_document(),
		"succeeded": 0,
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
	var base_id := String(item.base_definition_id)
	var rarity_id := String(item.rarity_id)
	_increment(scenario["base_counts"] as Dictionary, base_id)
	_increment(scenario["rarity_counts"] as Dictionary, rarity_id)
	_increment(state["rarity_counts"] as Dictionary, rarity_id)
	var target_archetype := String(scenario["target_archetype"])
	if not target_archetype.is_empty():
		var base := equipment.definition(item.base_definition_id)
		if base != null and StringName(target_archetype) in base.normalized_generation_tags():
			scenario["match_count"] = int(scenario["match_count"]) + 1
	for affix: ItemAffixInstance in item.affixes:
		if affix == null or affix.affix_kind == "implicit":
			continue
		var definition := foundation.affix(affix.definition_id)
		if definition == null:
			continue
		var band_key := _weight_band_key(definition.base_weight)
		_increment(scenario["band_counts"] as Dictionary, band_key)
		_increment(state["band_counts"] as Dictionary, band_key)
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
	var result := {
		"attempted": attempted,
		"average_explicit_tier": _rounded(tier_sum / tier_total if tier_total > 0 else 0.0),
		"charisma": scenario["charisma"],
		"failed": int(scenario["failed"]),
		"failure_counts": _sorted_counts(scenario["failure_counts"] as Dictionary),
		"heat": scenario["heat"],
		"item_level": int(scenario["item_level"]),
		"key": scenario["key"],
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
		"request": scenario["request"],
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
	for key: String in band_definitions:
		var authored := band_definitions[key] as Dictionary
		var selected := int(band_counts.get(key, 0))
		weight_bands[key] = {
			"authored_weight_share": authored["authored_weight_share"],
			"definition_count": authored["definition_count"],
			"expected_relative_weight": authored["expected_relative_weight"],
			"selected_count": selected,
			"selected_proportion": _ratio(selected, band_total),
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
	var minimum_level := ItemGenerationRequest.MAX_ITEM_LEVEL + 1
	var maximum_tier := 0
	for tier: ItemAffixTierDefinition in definition.tiers:
		if tier == null or tier.minimum_item_level < 1 or tier.minimum_item_level > ItemGenerationRequest.MAX_ITEM_LEVEL:
			continue
		minimum_level = mini(minimum_level, tier.minimum_item_level)
		maximum_tier = maxi(maximum_tier, tier.tier)
		for rarity_id: StringName in ORDINARY_RARITY_IDS:
			if not definition.allowed_rarity_ids.is_empty() and rarity_id not in definition.allowed_rarity_ids:
				continue
			if not tier.allowed_rarity_ids.is_empty() and rarity_id not in tier.allowed_rarity_ids:
				continue
			if rarity_id not in eligible_rarity_ids:
				eligible_rarity_ids.append(String(rarity_id))
	eligible_rarity_ids.sort()
	var reachable := not eligible_base_ids.is_empty() and not eligible_rarity_ids.is_empty() and minimum_level <= ItemGenerationRequest.MAX_ITEM_LEVEL
	return {
		"base_weight": definition.base_weight,
		"eligible_base_count": eligible_base_ids.size(),
		"eligible_base_ids": eligible_base_ids,
		"eligible_rarity_ids": eligible_rarity_ids,
		"excluded_base_count": equipment.definitions.size() - eligible_base_ids.size(),
		"excluded_rarity_ids": _difference(_ordinary_rarity_strings(), eligible_rarity_ids),
		"id": String(definition.id),
		"kind": definition.affix_kind,
		"maximum_tier": maximum_tier,
		"minimum_item_level": minimum_level if reachable else 0,
		"reachable": reachable,
		"weight_band": _weight_band_key(definition.base_weight) if definition.affix_kind != "implicit" else "implicit",
	}

static func _weight_band_definitions(foundation: ItemFoundationCatalog) -> Dictionary:
	var rows := {
		"0025_premium_hybrid": {"definition_count": 0, "expected_relative_weight": 0.025, "weight": 25},
		"0150_standard_hybrid": {"definition_count": 0, "expected_relative_weight": 0.15, "weight": 150},
		"0500_specialized_focused": {"definition_count": 0, "expected_relative_weight": 0.5, "weight": 500},
		"1000_core_focused": {"definition_count": 0, "expected_relative_weight": 1.0, "weight": 1000},
	}
	var authored_total := 0.0
	for definition: ItemAffixDefinition in foundation.affixes:
		if definition == null or definition.affix_kind == "implicit":
			continue
		var key := _weight_band_key(definition.base_weight)
		if not rows.has(key):
			continue
		var row := rows[key] as Dictionary
		row["definition_count"] = int(row["definition_count"]) + 1
		authored_total += definition.base_weight
	for key: String in rows:
		var row := rows[key] as Dictionary
		row["authored_weight_share"] = _rounded(float(row["weight"]) * int(row["definition_count"]) / authored_total) if authored_total > 0.0 else 0.0
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
		var maximum_tier := 0
		for scenario: Dictionary in scenarios:
			if scenario["matrix"] != "charisma_heat" or int(float(scenario["charisma"])) != charisma:
				continue
			var observed := scenario["observed"] as Dictionary
			var bands := observed["weight_bands"] as Dictionary
			for key: String in bands:
				explicit_count += int((bands[key] as Dictionary)["count"])
			premium_count += int((bands.get("0025_premium_hybrid", {}) as Dictionary).get("count", 0))
			var tiers := observed["tiers"] as Dictionary
			for tier_key: String in tiers:
				maximum_tier = maxi(maximum_tier, int(tier_key))
		result[str(charisma)] = {
			"diminishing_value": _rounded(ItemGenerationWeightPolicy.diminishing_charisma(float(charisma))),
			"maximum_observed_tier": maximum_tier,
			"premium_count": premium_count,
			"premium_proportion": _ratio(premium_count, explicit_count),
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
	var sorted_minimums := minimums.duplicate()
	var sorted_maximums := maximums.duplicate()
	sorted_minimums.sort()
	sorted_maximums.sort()
	return {
		"maximum_damage": _percentile_row(sorted_maximums),
		"minimum_damage": _percentile_row(sorted_minimums),
		"sample_count": mini(sorted_minimums.size(), sorted_maximums.size()),
	}

static func _percentile_row(values: Array) -> Dictionary:
	if values.is_empty():
		return {"high": 0.0, "median": 0.0, "minimum": 0.0}
	return {
		"high": _rounded(float(values[int(floor((values.size() - 1) * 0.90))])),
		"median": _rounded(float(values[int(floor((values.size() - 1) * 0.50))])),
		"minimum": _rounded(float(values[0])),
	}

static func _append_manifest_markdown(lines: Array[String], manifest: Dictionary) -> void:
	var counts := manifest.get("counts", {}) as Dictionary
	lines.append("## Exact manifest and exclusions")
	lines.append("")
	lines.append("| Bases | Weapon profiles | Affixes | Explicit | Implicit | Prefixes | Suffixes |")
	lines.append("|---:|---:|---:|---:|---:|---:|---:|")
	lines.append("| %d | %d | %d | %d | %d | %d | %d |" % [
		int(counts.get("bases", 0)), int(counts.get("weapon_profile_bases", 0)), int(counts.get("affixes", 0)),
		int(counts.get("explicit_affixes", 0)), int(counts.get("implicit_affixes", 0)),
		int(counts.get("prefixes", 0)), int(counts.get("suffixes", 0)),
	])
	var exclusions := manifest.get("exclusions", {}) as Dictionary
	lines.append("")
	lines.append("- Ordinary rarities: %s" % ", ".join(exclusions.get("ordinary_rarity_ids", []) as Array))
	lines.append("- Excluded nonordinary rarities: %s" % ", ".join(exclusions.get("ordinary_disabled_rarity_ids", []) as Array))
	lines.append("- Bases excluded from weapon percentiles: %d" % (exclusions.get("nonweapon_base_ids", []) as Array).size())
	lines.append("- Unreachable affixes: %d" % (exclusions.get("unreachable_affix_ids", []) as Array).size())
	lines.append("")
	lines.append("### Affix reachability")
	lines.append("")
	lines.append("| Affix | Kind | Weight | Band | Min level | Max tier | Eligible bases | Eligible rarities | Reachable |")
	lines.append("|---|---|---:|---|---:|---:|---:|---|---|")
	for row_value: Variant in manifest.get("reachability", []) as Array:
		var row := row_value as Dictionary
		lines.append("| %s | %s | %s | %s | %d | %d | %d | %s | %s |" % [
			row.get("id", ""), row.get("kind", ""), _number(float(row.get("base_weight", 0.0))), row.get("weight_band", ""),
			int(row.get("minimum_item_level", 0)), int(row.get("maximum_tier", 0)), int(row.get("eligible_base_count", 0)),
			", ".join(row.get("eligible_rarity_ids", []) as Array), "yes" if bool(row.get("reachable", false)) else "no",
		])
	lines.append("")

static func _append_aggregate_markdown(lines: Array[String], aggregates: Dictionary) -> void:
	lines.append("## Distribution findings")
	lines.append("")
	lines.append("### Explicit weight bands")
	lines.append("")
	lines.append("| Band | Definitions | Relative weight | Selected | Selected proportion |")
	lines.append("|---|---:|---:|---:|---:|")
	for key: String in aggregates.get("weight_bands", {}):
		var row := (aggregates["weight_bands"] as Dictionary)[key] as Dictionary
		lines.append("| %s | %d | %s | %d | %s |" % [key, int(row["definition_count"]), _number(float(row["expected_relative_weight"])), int(row["selected_count"]), _number(float(row["selected_proportion"]))])
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
	lines.append("| Archetype | Neutral match | Biased match | Biased off-party count |")
	lines.append("|---|---:|---:|---:|")
	for archetype: String in aggregates.get("party_bias", {}):
		var row := (aggregates["party_bias"] as Dictionary)[archetype] as Dictionary
		lines.append("| %s | %s | %s | %d |" % [archetype, _number(float(row["neutral_match_proportion"])), _number(float(row["biased_match_proportion"])), int(row["biased_off_count"])])
	lines.append("")
	lines.append("### Charisma, Heat, and weapon damage")
	lines.append("")
	for charisma: String in aggregates.get("charisma", {}):
		var row := (aggregates["charisma"] as Dictionary)[charisma] as Dictionary
		lines.append("- Charisma %s: diminishing value %s, premium proportion %s, maximum observed tier %d." % [charisma, _number(float(row["diminishing_value"])), _number(float(row["premium_proportion"])), int(row["maximum_observed_tier"])])
	for heat: String in aggregates.get("heat", {}):
		var row := (aggregates["heat"] as Dictionary)[heat] as Dictionary
		lines.append("- Heat %s: rare-or-better proportion %s." % [heat, _number(float(row["upper_rarity_proportion"]))])
	var weapon := aggregates.get("weapon_damage_percentiles", {}) as Dictionary
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
