extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_implicits_and_exact_pattern_counts(failures)
	_test_hard_filters_run_before_weights(failures)
	_test_request_affix_tag_filters(failures)
	_test_definition_and_family_blocking(failures)
	_test_tier_order_and_exact_rolls(failures)
	_test_high_level_broadens_without_guaranteeing_top_tier(failures)
	_test_charisma_improves_roll_quality_within_bounds(failures)
	_test_nonfinite_aggregate_weights_fail_all_or_nothing(failures)
	_test_all_or_nothing_failures(failures)
	return failures

func _test_implicits_and_exact_pattern_counts(failures: Array[String]) -> void:
	var implicit := _affix(&"tempered_edge", "implicit", [&"edge_family"], [_tier(1, 1, 10.0, 2.0, 4.0)])
	var prefix := _affix(&"stout", "prefix", [&"health_family"], [_tier(1, 1, 10.0, 1.0, 3.0)])
	var suffix := _affix(&"of_reach", "suffix", [&"range_family"], [_tier(1, 1, 10.0, 0.1, 0.2)])
	var special := _affix(&"active_special", "special", [&"special_family"], [_tier(1, 1, 10.0, 5.0, 7.0)])
	var base := _base([&"melee", &"weapon"], [&"tempered_edge"])
	var rarity := _rarity(&"legendary", 5, 1)
	var pattern := _pattern(1, 1, 1)
	var result := ItemAffixAssembler.assemble(
		_request(250), base, rarity, pattern, _foundation([suffix, special, implicit, prefix]), ItemGenerationTrace.new()
	)
	TestAssertions.truthy(result.ok(), "complete implicit and explicit assembly succeeds", failures)
	TestAssertions.equal(result.error_code, &"", "successful assembly has no error code", failures)
	TestAssertions.equal(result.affixes.size(), 4, "implicit does not consume any exact pattern slot", failures)
	if result.affixes.size() == 4:
		TestAssertions.equal(_kinds(result.affixes), ["implicit", "prefix", "suffix", "special"], "assembly order is implicit, prefix, suffix, special", failures)
		TestAssertions.equal(result.affixes[0].definition_id, &"tempered_edge", "base implicit is assembled first", failures)
		TestAssertions.equal(_count_kind(result.affixes, "special"), 1, "reserved Legendary special is not filled as an active special", failures)

func _test_hard_filters_run_before_weights(failures: Array[String]) -> void:
	var eligible := _affix(&"eligible", "prefix", [&"eligible_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	eligible.base_weight = 1.0
	var missing_tag := _affix(&"missing_tag", "prefix", [&"missing_tag_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	missing_tag.base_weight = 1000000.0
	missing_tag.required_item_tags = [&"caster"]
	var excluded_tag := _affix(&"excluded_tag", "prefix", [&"excluded_tag_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	excluded_tag.base_weight = 1000000.0
	excluded_tag.excluded_item_tags = [&"melee"]
	var wrong_domain := _affix(&"wrong_domain", "prefix", [&"wrong_domain_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	wrong_domain.base_weight = 1000000.0
	wrong_domain.allowed_generation_domains = [&"vendor"]
	var wrong_source := _affix(&"wrong_source", "prefix", [&"wrong_source_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	wrong_source.base_weight = 1000000.0
	wrong_source.allowed_source_ids = [&"boss"]
	var wrong_rarity := _affix(&"wrong_rarity", "prefix", [&"wrong_rarity_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	wrong_rarity.base_weight = 1000000.0
	wrong_rarity.allowed_rarity_ids = [&"legendary"]
	var locked := _affix(&"locked", "prefix", [&"locked_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	locked.base_weight = 1000000.0
	locked.required_unlock_tags = [&"locked_affix"]
	var tier_too_high := _affix(&"tier_too_high", "prefix", [&"tier_high_family"], [_tier(1, 500, 1.0, 1.0, 2.0)])
	tier_too_high.base_weight = 1000000.0
	var tier_wrong_domain := _affix(&"tier_wrong_domain", "prefix", [&"tier_domain_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	tier_wrong_domain.base_weight = 1000000.0
	tier_wrong_domain.tiers[0].allowed_generation_domains = [&"crafting"]
	var tier_wrong_source := _affix(&"tier_wrong_source", "prefix", [&"tier_source_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	tier_wrong_source.base_weight = 1000000.0
	tier_wrong_source.tiers[0].allowed_source_ids = [&"boss"]
	var tier_wrong_rarity := _affix(&"tier_wrong_rarity", "prefix", [&"tier_rarity_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	tier_wrong_rarity.base_weight = 1000000.0
	tier_wrong_rarity.tiers[0].allowed_rarity_ids = [&"legendary"]
	var invalid_weight := _affix(&"invalid_weight", "prefix", [&"invalid_weight_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	invalid_weight.base_weight = NAN
	var trace := ItemGenerationTrace.new()
	var result := ItemAffixAssembler.assemble(
		_request(100),
		_base([&"melee", &"weapon"]),
		_rarity(&"rare", 3),
		_pattern(1, 0, 0),
		_foundation([tier_wrong_rarity, wrong_source, locked, missing_tag, eligible, tier_too_high, wrong_domain, wrong_rarity, excluded_tag, tier_wrong_domain, tier_wrong_source, invalid_weight]),
		trace
	)
	TestAssertions.truthy(result.ok(), "one unrestricted candidate survives every hard gate", failures)
	if result.ok():
		TestAssertions.equal(result.affixes[0].definition_id, &"eligible", "ineligible high-weight candidates cannot re-enter through weighting", failures)
	var stage := _stage(trace, "affix:prefix:0")
	TestAssertions.equal(stage.get("eligible", []), ["eligible"], "only hard-filter survivors receive affix weights", failures)
	var rejected := stage.get("rejected", {}) as Dictionary
	for id: String in ["missing_tag", "excluded_tag", "wrong_domain", "wrong_source", "wrong_rarity", "locked", "tier_too_high", "tier_wrong_domain", "tier_wrong_source", "tier_wrong_rarity", "invalid_weight"]:
		TestAssertions.truthy(rejected.has(id), "%s records a hard-filter rejection" % id, failures)
	TestAssertions.equal(stage.get("weights", {}).keys(), ["eligible"], "no rejected candidate receives a weight", failures)

func _test_request_affix_tag_filters(failures: Array[String]) -> void:
	var eligible := _affix(&"eligible", "prefix", [&"family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	var request := _request(100)
	request.required_affix_tags = [&"melee"]
	var success := ItemAffixAssembler.assemble(
		request, _base([&"melee", &"weapon"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([eligible]), ItemGenerationTrace.new()
	)
	TestAssertions.truthy(success.ok(), "request required affix tags join the base tag requirement", failures)
	request.required_affix_tags = [&"caster"]
	var missing_required := ItemAffixAssembler.assemble(
		request, _base([&"melee", &"weapon"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([eligible]), ItemGenerationTrace.new()
	)
	TestAssertions.equal(missing_required.error_code, &"no_eligible_affix", "missing request affix tag empties the slot pool", failures)
	request.required_affix_tags = []
	request.excluded_affix_tags = [&"melee"]
	var excluded := ItemAffixAssembler.assemble(
		request, _base([&"melee", &"weapon"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([eligible]), ItemGenerationTrace.new()
	)
	TestAssertions.equal(excluded.error_code, &"no_eligible_affix", "request excluded affix tags reject matching base candidates", failures)

func _test_definition_and_family_blocking(failures: Array[String]) -> void:
	var hybrid_implicit := _affix(&"hybrid_guard", "implicit", [&"health_family", &"armor_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	var pure_health := _affix(&"pure_health", "prefix", [&"health_family"], [_tier(1, 1, 100000.0, 1.0, 2.0)])
	var pure_armor := _affix(&"pure_armor", "prefix", [&"armor_family"], [_tier(1, 1, 100000.0, 1.0, 2.0)])
	var safe := _affix(&"safe_speed", "prefix", [&"speed_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	var result := ItemAffixAssembler.assemble(
		_request(100),
		_base([&"melee"], [&"hybrid_guard"]),
		_rarity(&"rare", 3),
		_pattern(1, 0, 0),
		_foundation([pure_armor, safe, hybrid_implicit, pure_health]),
		ItemGenerationTrace.new()
	)
	TestAssertions.truthy(result.ok(), "hybrid implicit leaves a nonconflicting explicit candidate", failures)
	if result.ok():
		TestAssertions.equal(_ids(result.affixes), [&"hybrid_guard", &"safe_speed"], "every hybrid family blocks both pure candidates", failures)

	var one := _affix(&"one", "prefix", [&"one_family"], [_tier(1, 1, 100.0, 1.0, 2.0)])
	var two := _affix(&"two", "prefix", [&"two_family"], [_tier(1, 1, 100.0, 1.0, 2.0)])
	result = ItemAffixAssembler.assemble(
		_request(100), _base([&"melee"]), _rarity(&"rare", 3), _pattern(2, 0, 0), _foundation([one, two]), ItemGenerationTrace.new()
	)
	TestAssertions.truthy(result.ok(), "two distinct affixes can fill two slots", failures)
	if result.ok():
		TestAssertions.equal(result.affixes.size(), 2, "exact two-prefix pattern is filled", failures)
		TestAssertions.truthy(result.affixes[0].definition_id != result.affixes[1].definition_id, "a definition id cannot be selected twice", failures)

	var hybrid := _affix(&"a_hybrid", "prefix", [&"health_family", &"armor_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	hybrid.base_weight = 1000000000000.0
	pure_health = _affix(&"pure_health", "prefix", [&"health_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	pure_armor = _affix(&"pure_armor", "prefix", [&"armor_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	safe = _affix(&"z_safe", "prefix", [&"speed_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	result = ItemAffixAssembler.assemble(
		_request(100), _base([&"melee"]), _rarity(&"rare", 3), _pattern(2, 0, 0), _foundation([pure_health, safe, hybrid, pure_armor]), ItemGenerationTrace.new()
	)
	TestAssertions.truthy(result.ok(), "hybrid explicit leaves one nonconflicting second-slot candidate", failures)
	if result.ok():
		TestAssertions.equal(_ids(result.affixes), [&"a_hybrid", &"z_safe"], "every selected hybrid family blocks later pure candidates", failures)

	var duplicate_trace := ItemGenerationTrace.new()
	result = ItemAffixAssembler.assemble(
		_request(100), _base([&"melee"]), _rarity(&"rare", 3), _pattern(2, 0, 0), _foundation([one]), duplicate_trace
	)
	TestAssertions.equal(result.error_code, &"no_eligible_affix", "a single definition cannot fill the same kind twice", failures)
	TestAssertions.equal(result.affixes, [], "duplicate-definition exhaustion returns no partial first slot", failures)
	TestAssertions.equal(_stage(duplicate_trace, "affix:prefix:1").get("rejected", {}).get("one", ""), "duplicate_definition", "duplicate definition is rejected before second-slot weighting", failures)

func _test_tier_order_and_exact_rolls(failures: Array[String]) -> void:
	var effect := _effect(&"strength", StatModifier.Operation.FLAT, [&"melee"])
	var second_effect := _effect(&"fire_damage", StatModifier.Operation.INCREASED, [&"fire"])
	var tier_three := _tier(3, 300, 20.0, 30.0, 40.0)
	var tier_one := _tier(1, 1, 100.0, 10.0, 20.0)
	var tier_two := _tier(2, 100, 50.0, 20.0, 30.0)
	for tier: ItemAffixTierDefinition in [tier_three, tier_one, tier_two]:
		tier.minimum_rolls.append(0.1 * float(tier.tier))
		tier.maximum_rolls.append(0.1 * float(tier.tier) + 0.05)
	var affix := _affix(&"tiered", "prefix", [&"tiered_family"], [tier_three, tier_one, tier_two], [effect, second_effect])
	var request := _request(500)
	request.seed = 8128
	request.generation_sequence = 9
	var first_trace := ItemGenerationTrace.new()
	var first := ItemAffixAssembler.assemble(request, _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), first_trace)
	var repeated := ItemAffixAssembler.assemble(request, _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), ItemGenerationTrace.new())
	TestAssertions.truthy(first.ok(), "tiered affix assembly succeeds", failures)
	TestAssertions.equal(_documents(first.affixes), _documents(repeated.affixes), "same seed and sequence preserve exact tier and float rolls", failures)
	var tier_stage := _stage(first_trace, "tier:prefix:0:tiered")
	TestAssertions.equal(tier_stage.get("eligible", []), ["1", "2", "3"], "eligible tiers are recorded in ascending numeric order", failures)
	if first.ok():
		var selected_tier := first.affixes[0].tier
		var bounds := affix.roll_bounds(selected_tier, 0)
		var unit := ItemDeterministicRandom.unit(request.seed, request.generation_sequence, &"roll:prefix:0:tiered:0", 0)
		var expected := lerpf(bounds.x, bounds.y, ItemGenerationWeightPolicy.roll_quality(unit, request.charisma_value))
		TestAssertions.equal(first.affixes[0].rolls[0].value, expected, "roll stores the exact stage-salted floating-point value", failures)
		TestAssertions.equal(first.affixes[0].rolls[0].required_tags, [&"melee"], "roll copies effect required tags", failures)
		var second_bounds := affix.roll_bounds(selected_tier, 1)
		var second_unit := ItemDeterministicRandom.unit(request.seed, request.generation_sequence, &"roll:prefix:0:tiered:1", 0)
		var second_expected := lerpf(second_bounds.x, second_bounds.y, ItemGenerationWeightPolicy.roll_quality(second_unit, request.charisma_value))
		TestAssertions.equal(first.affixes[0].rolls[1].value, second_expected, "each effect uses its own deterministic roll salt", failures)
		TestAssertions.equal(first.affixes[0].rolls[1].required_tags, [&"fire"], "each roll copies its matching effect tags", failures)

func _test_high_level_broadens_without_guaranteeing_top_tier(failures: Array[String]) -> void:
	var affix := _affix(&"broad", "prefix", [&"broad_family"], [
		_tier(1, 1, 100.0, 1.0, 2.0),
		_tier(2, 500, 100.0, 2.0, 3.0),
		_tier(3, 1000, 100.0, 3.0, 4.0),
	])
	var low_trace := ItemGenerationTrace.new()
	var low := ItemAffixAssembler.assemble(_request(1), _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), low_trace)
	TestAssertions.truthy(low.ok(), "low-level assembly retains its reachable low tier", failures)
	TestAssertions.equal(_stage(low_trace, "tier:prefix:0:broad").get("eligible", []), ["1"], "low item level gates later tiers", failures)

	var selected_tiers: Dictionary = {}
	var high_trace := ItemGenerationTrace.new()
	for seed: int in 64:
		var request := _request(1000)
		request.seed = seed
		var trace := ItemGenerationTrace.new()
		var result := ItemAffixAssembler.assemble(request, _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), trace)
		if result.ok():
			selected_tiers[result.affixes[0].tier] = true
		if seed == 0:
			high_trace = trace
	TestAssertions.equal(_stage(high_trace, "tier:prefix:0:broad").get("eligible", []), ["1", "2", "3"], "high item level broadens the eligible tier pool", failures)
	TestAssertions.truthy(selected_tiers.has(3), "high item level can select the top tier", failures)
	TestAssertions.truthy(selected_tiers.keys().any(func(tier: Variant) -> bool: return int(tier) < 3), "high item level never guarantees the top tier", failures)

func _test_charisma_improves_roll_quality_within_bounds(failures: Array[String]) -> void:
	var affix := _affix(&"quality", "prefix", [&"quality_family"], [_tier(1, 1, 1.0, 10.0, 20.0)])
	var zero_request := _request(500)
	zero_request.seed = 451
	var high_request := _request(500)
	high_request.seed = 451
	high_request.charisma_value = 1000.0
	var zero := ItemAffixAssembler.assemble(zero_request, _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), ItemGenerationTrace.new())
	var high := ItemAffixAssembler.assemble(high_request, _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([affix]), ItemGenerationTrace.new())
	TestAssertions.truthy(zero.ok() and high.ok(), "both Charisma roll requests assemble", failures)
	if zero.ok() and high.ok():
		var zero_value := zero.affixes[0].rolls[0].value
		var high_value := high.affixes[0].rolls[0].value
		TestAssertions.truthy(zero_value >= 10.0 and zero_value <= 20.0, "zero-Charisma roll stays inside authored bounds", failures)
		TestAssertions.truthy(high_value >= 10.0 and high_value <= 20.0, "high-Charisma roll stays inside authored bounds", failures)
		TestAssertions.truthy(high_value >= zero_value, "Charisma shifts exact roll quality upward for the same unit draw", failures)

func _test_nonfinite_aggregate_weights_fail_all_or_nothing(failures: Array[String]) -> void:
	var implicit := _affix(&"tempered_edge", "implicit", [&"implicit_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	var huge_a := _affix(&"huge_a", "prefix", [&"huge_a_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	huge_a.base_weight = 1.0e308
	var huge_b := _affix(&"huge_b", "prefix", [&"huge_b_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	huge_b.base_weight = 1.0e308
	var affix_trace := ItemGenerationTrace.new()
	var result := ItemAffixAssembler.assemble(
		_request(1),
		_base([&"melee"], [&"tempered_edge"]),
		_rarity(&"rare", 3),
		_pattern(1, 0, 0),
		_foundation([huge_b, implicit, huge_a]),
		affix_trace
	)
	TestAssertions.truthy(not result.ok(), "overflowing aggregate affix weight fails assembly", failures)
	TestAssertions.equal(result.error_code, &"invalid_affix_weight_total", "aggregate affix overflow uses a stable structured code", failures)
	TestAssertions.equal(result.affixes, [], "aggregate affix overflow discards an already assembled implicit", failures)
	TestAssertions.equal(result.details, {"kind": "prefix", "slot": 0}, "aggregate affix overflow identifies its exact slot", failures)
	TestAssertions.equal(_stage(affix_trace, "affix:prefix:0").get("selected", "missing"), "", "overflowing affix pool never falls through to its last candidate", failures)

	var tiered := _affix(&"tier_overflow", "prefix", [&"tier_overflow_family"], [
		_tier(1, 1, 1.0e308, 1.0, 2.0),
		_tier(2, 2, 1.0e308, 2.0, 3.0),
	])
	var tier_trace := ItemGenerationTrace.new()
	result = ItemAffixAssembler.assemble(
		_request(2), _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 0, 0), _foundation([tiered]), tier_trace
	)
	TestAssertions.truthy(not result.ok(), "overflowing aggregate tier weight fails assembly", failures)
	TestAssertions.equal(result.error_code, &"invalid_tier_weight_total", "aggregate tier overflow uses a stable structured code", failures)
	TestAssertions.equal(result.affixes, [], "aggregate tier overflow returns no partial affix", failures)
	TestAssertions.equal(result.details, {"affix_id": "tier_overflow", "slot": "prefix:0"}, "aggregate tier overflow identifies its affix and slot", failures)
	TestAssertions.equal(_stage(tier_trace, "tier:prefix:0:tier_overflow").get("selected", "missing"), "", "overflowing tier pool never falls through to its last candidate", failures)

func _test_all_or_nothing_failures(failures: Array[String]) -> void:
	var prefix := _affix(&"only_prefix", "prefix", [&"prefix_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	var trace := ItemGenerationTrace.new()
	var result := ItemAffixAssembler.assemble(
		_request(100), _base([&"melee"]), _rarity(&"rare", 3), _pattern(1, 1, 0), _foundation([prefix]), trace
	)
	TestAssertions.truthy(not result.ok(), "an empty requested slot pool fails assembly", failures)
	TestAssertions.equal(result.error_code, &"no_eligible_affix", "empty requested slot pool returns the stable code", failures)
	TestAssertions.equal(result.affixes, [], "failed assembly returns no partial prefix", failures)
	TestAssertions.equal(result.details.get("kind", ""), "suffix", "failure details identify the empty slot kind", failures)
	TestAssertions.equal(result.details.get("slot", -1), 0, "failure details identify the empty slot index", failures)

	var not_implicit := _affix(&"not_implicit", "prefix", [&"wrong_kind_family"], [_tier(1, 1, 1.0, 1.0, 2.0)])
	result = ItemAffixAssembler.assemble(
		_request(100), _base([&"melee"], [&"not_implicit"]), _rarity(&"common", 1), _pattern(0, 0, 0), _foundation([not_implicit]), ItemGenerationTrace.new()
	)
	TestAssertions.truthy(not result.ok(), "a base implicit id must reference an implicit affix", failures)
	TestAssertions.equal(result.error_code, &"invalid_implicit_affix", "wrong-kind implicit returns a structured code", failures)
	TestAssertions.equal(result.affixes, [], "wrong-kind implicit failure returns no affixes", failures)

func _request(level: int) -> ItemGenerationRequest:
	return ItemGenerationRequest.create(991, 4, level, &"ordinary_enemy", &"ordinary_drop", [&"common", &"rare", &"legendary"])

func _base(tags: Array[StringName], implicit_ids: Array[StringName] = []) -> EquipmentBaseDefinition:
	var base := EquipmentBaseDefinition.new()
	base.id = &"test_base"
	base.display_name = "Test Base"
	base.item_type_id = &"main_hand"
	base.compatible_slot_ids = [&"main_hand"]
	base.weight_class_id = &"weapon"
	base.weapon_family_id = &"one_hand_sword"
	base.implicit_family_id = &"test"
	base.generation_tags = tags.duplicate()
	base.implicit_affix_ids = implicit_ids.duplicate()
	return base

func _rarity(id: StringName, rank: int, reserved_special_slots: int = 0) -> ItemRarityDefinition:
	var rarity := ItemRarityDefinition.new()
	rarity.id = id
	rarity.display_name = String(id)
	rarity.rarity_rank = rank
	rarity.reserved_special_slots = reserved_special_slots
	return rarity

func _pattern(prefixes: int, suffixes: int, specials: int) -> ItemAffixPatternDefinition:
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"test_pattern"
	pattern.prefix_count = prefixes
	pattern.suffix_count = suffixes
	pattern.special_count = specials
	return pattern

func _foundation(values: Array[ItemAffixDefinition]) -> ItemFoundationCatalog:
	var foundation := ItemFoundationCatalog.new()
	foundation.affixes = values
	return foundation

func _affix(
	id: StringName,
	kind: String,
	families: Array[StringName],
	tiers: Array[ItemAffixTierDefinition],
	effects: Array[ItemModifierEffectDefinition] = []
) -> ItemAffixDefinition:
	var affix := ItemAffixDefinition.new()
	affix.id = id
	affix.display_name = String(id)
	affix.affix_kind = kind
	affix.base_weight = 100.0
	affix.modifier_family_ids = families.duplicate()
	var resolved_effects: Array[ItemModifierEffectDefinition] = []
	if effects.is_empty():
		resolved_effects.append(_effect(&"strength", StatModifier.Operation.FLAT))
	else:
		for effect: ItemModifierEffectDefinition in effects:
			resolved_effects.append(effect)
	affix.effects = resolved_effects
	var resolved_tiers: Array[ItemAffixTierDefinition] = []
	for tier: ItemAffixTierDefinition in tiers:
		resolved_tiers.append(tier)
	affix.tiers = resolved_tiers
	return affix

func _tier(tier_number: int, minimum_level: int, weight: float, minimum: float, maximum: float) -> ItemAffixTierDefinition:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = tier_number
	tier.minimum_item_level = minimum_level
	tier.base_weight = weight
	tier.minimum_rolls = [minimum]
	tier.maximum_rolls = [maximum]
	return tier

func _effect(stat_id: StringName, operation: int, tags: Array[StringName] = []) -> ItemModifierEffectDefinition:
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = stat_id
	effect.operation = operation
	effect.required_tags = tags.duplicate()
	return effect

func _stage(trace: ItemGenerationTrace, stage_name: String) -> Dictionary:
	for stage: Dictionary in trace.stages:
		if stage.get("stage", "") == stage_name:
			return stage
	return {}

func _kinds(values: Array[ItemAffixInstance]) -> Array[String]:
	var result: Array[String] = []
	for value: ItemAffixInstance in values:
		result.append(value.affix_kind)
	return result

func _ids(values: Array[ItemAffixInstance]) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: ItemAffixInstance in values:
		result.append(value.definition_id)
	return result

func _count_kind(values: Array[ItemAffixInstance], kind: String) -> int:
	var count := 0
	for value: ItemAffixInstance in values:
		if value.affix_kind == kind:
			count += 1
	return count

func _documents(values: Array[ItemAffixInstance]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: ItemAffixInstance in values:
		result.append(value.to_dictionary())
	return result
