extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_base_rejections(failures)
	_test_rarity_rejections(failures)
	_test_pattern_rejections(failures)
	_test_affix_rejections(failures)
	_test_eligible_tiers(failures)
	return failures

func _test_base_rejections(failures: Array[String]) -> void:
	var request := _request()
	var base := _base(&"test_base", [&"melee"], 10.0)
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(null, request), "missing_base", "missing base is rejected", failures)
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(base, request), "", "eligible base passes", failures)

	request.forced_base_id = &"other_base"
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(base, request), "forced_base_mismatch", "forced base filter is shared", failures)
	request.forced_base_id = &""
	request.required_base_tags = [&"caster"]
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(base, request), "missing_required_tag", "required base tag gate is shared", failures)
	request.required_base_tags = []
	request.excluded_base_tags = [&"melee"]
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(base, request), "excluded_tag", "excluded base tag gate is shared", failures)
	request.excluded_base_tags = []
	base.generation_weight = 0.0
	TestAssertions.equal(ItemGenerationEligibility.base_rejection(base, request), "invalid_weight", "invalid base weight is shared", failures)

func _test_rarity_rejections(failures: Array[String]) -> void:
	var request := _request()
	request.permitted_rarity_ids = [&"rare"]
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rare_unlocked"]
	var rarity := _rarity()
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(null, request), "missing_rarity", "missing rarity is rejected", failures)

	rarity.instance_supported = false
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "instance_unsupported", "instance support is first rarity gate", failures)
	rarity.instance_supported = true
	request.permitted_rarity_ids = [&"common"]
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "not_permitted", "request permission precedes ordinary support", failures)
	request.permitted_rarity_ids = [&"rare"]
	rarity.ordinary_generation_enabled = false
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "ordinary_generation_disabled", "ordinary support precedes unlock", failures)
	rarity.ordinary_generation_enabled = true
	request.unlock_tags = []
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "missing_unlock_tag", "unlock precedes forced rarity", failures)
	request.unlock_tags = [&"rare_unlocked"]
	request.forced_rarity_id = &"common"
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "forced_rarity_mismatch", "forced rarity filter is shared", failures)
	request.forced_rarity_id = &"rare"
	rarity.base_weight = 0.0
	TestAssertions.equal(ItemGenerationEligibility.rarity_rejection(rarity, request), "invalid_weight", "invalid rarity weight is shared", failures)

func _test_pattern_rejections(failures: Array[String]) -> void:
	var request := _request()
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"one_prefix"
	pattern.weight = 1.0
	TestAssertions.equal(ItemGenerationEligibility.pattern_rejection(null, request), "missing_pattern", "missing pattern is rejected", failures)
	pattern.allowed_generation_domains = [&"boss_drop"]
	TestAssertions.equal(ItemGenerationEligibility.pattern_rejection(pattern, request), "domain_not_allowed", "pattern domain gate is shared", failures)
	pattern.allowed_generation_domains = []
	pattern.weight = NAN
	TestAssertions.equal(ItemGenerationEligibility.pattern_rejection(pattern, request), "invalid_weight", "invalid pattern weight is shared", failures)
	pattern.weight = 1.0
	TestAssertions.equal(ItemGenerationEligibility.pattern_rejection(pattern, request), "", "eligible pattern passes", failures)

func _test_affix_rejections(failures: Array[String]) -> void:
	var request := _request()
	request.unlock_tags = [&"affix_unlocked"]
	var definition := _affix()
	var base_tags: Array[StringName] = [&"melee", &"weapon"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(null, request, base_tags, &"rare", {}, {}), "missing_affix", "missing affix is rejected", failures)
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {definition.id: true}, {}), "duplicate_definition", "duplicate definition is first affix gate", failures)
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {&"fire_damage": true}), "blocked_family", "blocked family precedes tag gates", failures)

	definition.required_item_tags = [&"caster"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "missing_required_item_tag", "required item tag gate is shared", failures)
	definition.required_item_tags = []
	definition.excluded_item_tags = [&"weapon"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "excluded_item_tag", "excluded item tag gate is shared", failures)
	definition.excluded_item_tags = []
	request.required_affix_tags = [&"caster"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "missing_required_request_tag", "required request tag gate is shared", failures)
	request.required_affix_tags = []
	request.excluded_affix_tags = [&"melee"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "excluded_request_tag", "excluded request tag gate is shared", failures)
	request.excluded_affix_tags = []
	definition.allowed_generation_domains = [&"boss_drop"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "domain_not_allowed", "affix domain gate is shared", failures)
	definition.allowed_generation_domains = []
	definition.allowed_source_ids = [&"boss"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "source_not_allowed", "affix source gate is shared", failures)
	definition.allowed_source_ids = []
	definition.allowed_rarity_ids = [&"epic"]
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "rarity_not_allowed", "affix rarity gate is shared", failures)
	definition.allowed_rarity_ids = []
	request.unlock_tags = []
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "missing_unlock_tag", "affix unlock gate is shared", failures)
	request.unlock_tags = [&"affix_unlocked"]
	definition.tiers[0].minimum_item_level = request.item_level + 1
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "no_eligible_tier", "tier availability is the final hard gate", failures)
	definition.tiers[0].minimum_item_level = 1
	TestAssertions.equal(ItemGenerationEligibility.affix_rejection(definition, request, base_tags, &"rare", {}, {}), "", "eligible affix passes every hard gate", failures)

func _test_eligible_tiers(failures: Array[String]) -> void:
	var request := _request()
	request.item_level = 50
	var definition := _affix()
	var level_blocked := _tier(4, 51, 1.0)
	var rarity_blocked := _tier(2, 1, 1.0)
	rarity_blocked.allowed_rarity_ids = [&"epic"]
	var source_blocked := _tier(3, 1, 1.0)
	source_blocked.allowed_source_ids = [&"boss"]
	var domain_blocked := _tier(5, 1, 1.0)
	domain_blocked.allowed_generation_domains = [&"boss_drop"]
	var invalid_weight := _tier(6, 1, 0.0)
	var higher_first := _tier(7, 1, 1.0)
	definition.tiers = [higher_first, level_blocked, rarity_blocked, source_blocked, domain_blocked, invalid_weight, _tier(1, 1, 1.0)]
	var eligible := ItemGenerationEligibility.eligible_tiers(definition, request, &"rare")
	TestAssertions.equal(eligible.map(func(tier: ItemAffixTierDefinition) -> int: return tier.tier), [1, 7], "tier gates filter and sort eligible tiers", failures)

func _request() -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(77, 3, 20, &"ordinary_enemy", &"ordinary_drop", [&"common"] as Array[StringName])
	return request

func _base(id: StringName, tags: Array[StringName], weight: float) -> EquipmentBaseDefinition:
	var base := EquipmentBaseDefinition.new()
	base.id = id
	base.generation_tags = tags.duplicate()
	base.generation_weight = weight
	return base

func _rarity() -> ItemRarityDefinition:
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"rare"
	rarity.base_weight = 1.0
	rarity.required_unlock_tags = [&"rare_unlocked"]
	return rarity

func _affix() -> ItemAffixDefinition:
	var definition := ItemAffixDefinition.new()
	definition.id = &"flame"
	definition.modifier_family_ids = [&"fire_damage"]
	definition.required_unlock_tags = [&"affix_unlocked"]
	definition.tiers = [_tier(1, 1, 1.0)]
	return definition

func _tier(tier_number: int, minimum_level: int, weight: float) -> ItemAffixTierDefinition:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = tier_number
	tier.minimum_item_level = minimum_level
	tier.base_weight = weight
	return tier
