extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_selection_opportunities(failures)
	_test_request_reachability(failures)
	return failures

func _test_selection_opportunities(failures: Array[String]) -> void:
	var trace := ItemGenerationTrace.new()
	trace.record(&"affix:prefix:0", [&"b", &"a"], {&"z": "blocked"}, {&"a": 1.0, &"b": 3.0}, &"b", {"slot": 0})
	trace.record(&"affix:prefix:1", [], {}, {}, &"")
	var opportunities := ItemGenerationAnalysis.selection_opportunities(trace)
	TestAssertions.equal(opportunities.size(), 2, "every trace selection row is normalized", failures)
	if opportunities.size() != 2:
		return
	var weighted := opportunities[0]
	TestAssertions.equal(weighted.get("stage", ""), "affix:prefix:0", "stage is canonical", failures)
	TestAssertions.equal(weighted.get("eligible", []), ["a", "b"], "eligible ids remain canonical", failures)
	TestAssertions.equal(weighted.get("rejected", {}), {"z": "blocked"}, "rejections remain canonical", failures)
	TestAssertions.equal(weighted.get("weights", {}), {"a": 1.0, "b": 3.0}, "weights remain exact", failures)
	TestAssertions.near(float((weighted.get("expected", {}) as Dictionary).get("a", -1.0)), 0.25, 0.000001, "expected a probability is normalized", failures)
	TestAssertions.near(float((weighted.get("expected", {}) as Dictionary).get("b", -1.0)), 0.75, 0.000001, "expected b probability is normalized", failures)
	TestAssertions.equal(weighted.get("selected", ""), "b", "selected id is retained", failures)
	TestAssertions.equal(weighted.get("details", {}), {"slot": 0}, "details are retained", failures)
	TestAssertions.truthy(bool(weighted.get("valid", false)), "positive finite opportunity is valid", failures)

	var empty := opportunities[1]
	TestAssertions.truthy(not bool(empty.get("valid", true)), "empty weight opportunity is explicitly invalid", failures)
	TestAssertions.equal(empty.get("expected", {"unexpected": true}), {}, "invalid opportunity has no expected probabilities", failures)
	TestAssertions.equal(empty.get("invalid_reason", ""), "no_positive_finite_weight", "invalid opportunity has a stable reason", failures)
	var exposed := opportunities
	(exposed[0]["expected"] as Dictionary)["a"] = 9.0
	TestAssertions.near(float((ItemGenerationAnalysis.selection_opportunities(trace)[0]["expected"] as Dictionary)["a"]), 0.25, 0.000001, "opportunity results are defensive", failures)
	TestAssertions.equal(ItemGenerationAnalysis.selection_opportunities(null), [], "missing trace has no opportunities", failures)

func _test_request_reachability(failures: Array[String]) -> void:
	var request := ItemGenerationRequest.create(91, 0, 10, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.forced_base_id = &"melee_base"
	request.forced_rarity_id = &"rare"
	var equipment := EquipmentCatalog.new()
	var base := EquipmentBaseDefinition.new()
	base.id = &"melee_base"
	base.generation_tags = [&"melee", &"weapon"]
	base.generation_weight = 1.0
	equipment.definitions = [base]

	var viable_pattern := _pattern(&"one_prefix", 1)
	var impossible_pattern := _pattern(&"two_prefixes", 2)
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"rare"
	rarity.base_weight = 1.0
	rarity.patterns = [impossible_pattern, viable_pattern]

	var reachable := _affix(&"reachable", 1, [], [])
	var level_blocked := _affix(&"level_blocked", 50, [], [])
	var domain_blocked := _affix(&"boss_only", 1, [&"boss_drop"], [])
	var foundation := ItemFoundationCatalog.new()
	foundation.known_source_ids = [&"ordinary_enemy"]
	foundation.known_item_tags = [&"melee", &"weapon"]
	foundation.modifier_family_ids = [&"family_boss", &"family_level", &"family_reachable"]
	foundation.rarities = [rarity]
	foundation.affixes = [domain_blocked, level_blocked, reachable]

	var reachability := ItemGenerationAnalysis.request_reachability(request, equipment, foundation)
	TestAssertions.equal(reachability.get("error", "unexpected"), "", "valid reachability request succeeds", failures)
	TestAssertions.truthy("reachable" in (reachability.get("reachable_affixes", []) as Array), "reachable affix remains structurally reachable without any observed sample", failures)
	TestAssertions.truthy(_has_row(reachability.get("structurally_unreachable", []) as Array, "affix", "level_blocked", "no_generation_path"), "level-gated affix is structurally unreachable", failures)
	TestAssertions.truthy(_has_row(reachability.get("not_applicable", []) as Array, "affix", "boss_only", "domain_not_allowed"), "request-domain exclusion is separately not applicable", failures)

	var viable_row := _row(reachability.get("pattern_rows", []) as Array, "pattern_id", "one_prefix")
	TestAssertions.truthy(bool(viable_row.get("viable", false)), "one-prefix pattern has enough candidates", failures)
	var impossible_row := _row(reachability.get("pattern_rows", []) as Array, "pattern_id", "two_prefixes")
	TestAssertions.truthy(not bool(impossible_row.get("viable", true)), "two-prefix pattern is impossible with one candidate", failures)
	TestAssertions.truthy("insufficient_prefix_candidates" in (impossible_row.get("reasons", []) as Array), "impossible pattern identifies prefix shortage", failures)
	TestAssertions.equal((impossible_row.get("eligible_candidate_counts", {}) as Dictionary).get("prefix", -1), 1, "pattern row records eligible prefix count", failures)

	var reachable_tier := _tier_row(reachability.get("tier_rows", []) as Array, "reachable", 1)
	TestAssertions.truthy(bool(reachable_tier.get("eligible", false)), "request-eligible tier is marked eligible", failures)
	var blocked_tier := _tier_row(reachability.get("tier_rows", []) as Array, "level_blocked", 1)
	TestAssertions.truthy(not bool(blocked_tier.get("eligible", true)), "item-level unavailable tier is marked ineligible", failures)
	TestAssertions.equal(blocked_tier.get("rejection", ""), "tier_gate", "ineligible tier has stable gate reason", failures)

	var malformed := ItemGenerationAnalysis.request_reachability(null, equipment, foundation)
	TestAssertions.truthy(not String(malformed.get("error", "")).is_empty(), "missing request returns an explicit analysis error", failures)

func _pattern(id: StringName, prefix_count: int) -> ItemAffixPatternDefinition:
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = id
	pattern.prefix_count = prefix_count
	pattern.weight = 1.0
	return pattern

func _affix(id: StringName, minimum_level: int, domains: Array[StringName], unlocks: Array[StringName]) -> ItemAffixDefinition:
	var definition := ItemAffixDefinition.new()
	definition.id = id
	definition.affix_kind = "prefix"
	definition.base_weight = 1.0
	match id:
		&"boss_only": definition.modifier_family_ids = [&"family_boss"]
		&"level_blocked": definition.modifier_family_ids = [&"family_level"]
		_: definition.modifier_family_ids = [&"family_reachable"]
	definition.allowed_generation_domains = domains.duplicate()
	definition.required_unlock_tags = unlocks.duplicate()
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = minimum_level
	tier.base_weight = 1.0
	definition.tiers = [tier]
	return definition

func _row(rows: Array, key: String, value: String) -> Dictionary:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		if row.get(key, "") == value:
			return row
	return {}

func _tier_row(rows: Array, affix_id: String, tier_number: int) -> Dictionary:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		if row.get("affix_id", "") == affix_id and int(row.get("tier", 0)) == tier_number:
			return row
	return {}

func _has_row(rows: Array, kind: String, id: String, reason: String) -> bool:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		if row.get("kind", "") == kind and row.get("id", "") == id and row.get("reason", "") == reason:
			return true
	return false
