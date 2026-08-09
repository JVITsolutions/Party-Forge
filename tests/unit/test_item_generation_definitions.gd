extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_pattern_contract(failures)
	_test_multi_effect_tiers(failures)
	_test_affix_cross_references(failures)
	_test_rarity_validation(failures)
	_test_effect_validation(failures)
	_test_tier_rejections(failures)
	_test_affix_rejections(failures)
	_test_generation_vocabulary(failures)
	return failures

func _test_pattern_contract(failures: Array[String]) -> void:
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"rare_balanced"
	pattern.prefix_count = 1
	pattern.suffix_count = 1
	pattern.weight = 2.0
	TestAssertions.equal(pattern.explicit_count(), 2, "pattern totals explicit slots", failures)
	TestAssertions.equal(pattern.validate(), PackedStringArray(), "valid pattern passes", failures)
	pattern.weight = NAN
	TestAssertions.truthy(not pattern.validate().is_empty(), "nonfinite pattern weight fails", failures)

func _test_multi_effect_tiers(failures: Array[String]) -> void:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 4
	tier.minimum_item_level = 250
	tier.base_weight = 30.0
	tier.minimum_rolls = [10.0, 0.08]
	tier.maximum_rolls = [18.0, 0.12]
	TestAssertions.equal(tier.validate(2), PackedStringArray(), "two-effect tier validates", failures)
	TestAssertions.equal(tier.roll_bounds(1), Vector2(0.08, 0.12), "second effect bounds resolve", failures)

func _test_affix_cross_references(failures: Array[String]) -> void:
	var affix := ItemAffixDefinition.new()
	affix.id = &"tempered_focus"
	affix.display_name = "Tempered Focus"
	affix.affix_kind = "prefix"
	affix.base_weight = 100.0
	affix.modifier_family_ids = [&"caster_power"]
	affix.allowed_generation_domains = [&"ordinary_drop"]
	affix.allowed_rarity_ids = [&"rare"]
	affix.required_item_tags = [&"caster"]
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"intelligence"
	effect.operation = StatModifier.Operation.FLAT
	affix.effects = [effect]
	var tier := ItemAffixTierDefinition.new()
	tier.tier = 1
	tier.minimum_item_level = 1
	tier.base_weight = 100.0
	tier.minimum_rolls = [1.0]
	tier.maximum_rolls = [3.0]
	affix.tiers = [tier]
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.equal(affix.validate(stats, [&"caster_power"], [&"ordinary_drop"], [&"enemy"], [&"rare"], [&"caster"]), PackedStringArray(), "valid affix validates", failures)
	affix.allowed_generation_domains = [&"unknown_domain"]
	TestAssertions.truthy(not affix.validate(stats, [&"caster_power"], [&"ordinary_drop"], [&"enemy"], [&"rare"], [&"caster"]).is_empty(), "unknown domain fails", failures)

func _test_rarity_validation(failures: Array[String]) -> void:
	var rarity := ItemRarityDefinition.new()
	rarity.id = &"rare"
	rarity.display_name = "Rare"
	rarity.rarity_rank = 3
	rarity.base_weight = 20.0
	var pattern := ItemAffixPatternDefinition.new()
	pattern.id = &"rare_balanced"
	pattern.prefix_count = 1
	pattern.suffix_count = 1
	rarity.patterns = [pattern]
	TestAssertions.equal(rarity.validate(), PackedStringArray(), "valid rarity validates", failures)
	rarity.rarity_rank = 0
	TestAssertions.truthy(not rarity.validate().is_empty(), "nonpositive rarity rank fails", failures)
	rarity.rarity_rank = 3
	rarity.base_weight = INF
	TestAssertions.truthy(not rarity.validate().is_empty(), "nonfinite rarity weight fails", failures)
	rarity.base_weight = 20.0
	rarity.patterns.append(pattern)
	TestAssertions.truthy(not rarity.validate().is_empty(), "duplicate rarity pattern fails", failures)

func _test_effect_validation(failures: Array[String]) -> void:
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"intelligence"
	TestAssertions.equal(effect.validate(stats), PackedStringArray(), "known effect stat validates", failures)
	effect.stat_id = &"unknown_stat"
	TestAssertions.truthy(not effect.validate(stats).is_empty(), "unknown effect stat fails", failures)
	effect.stat_id = &"intelligence"
	effect.operation = 999
	TestAssertions.truthy(not effect.validate(stats).is_empty(), "unsupported effect operation fails", failures)
	effect.operation = StatModifier.Operation.FLAT
	effect.required_tags = [&""]
	TestAssertions.truthy(not effect.validate(stats).is_empty(), "empty effect tag fails", failures)

func _test_tier_rejections(failures: Array[String]) -> void:
	var tier := _valid_tier(1, 1, 1.0, 3.0)
	TestAssertions.equal(tier.roll_bounds(-1), Vector2(INF, -INF), "negative effect index uses sentinel", failures)
	TestAssertions.equal(tier.roll_bounds(1), Vector2(INF, -INF), "missing effect index uses sentinel", failures)
	tier.maximum_rolls = []
	TestAssertions.truthy(not tier.validate(1).is_empty(), "tier range count mismatch fails", failures)
	tier.maximum_rolls = [0.5]
	TestAssertions.truthy(not tier.validate(1).is_empty(), "inverted tier range fails", failures)
	tier.maximum_rolls = [3.0]
	tier.base_weight = NAN
	TestAssertions.truthy(not tier.validate(1).is_empty(), "nonfinite tier weight fails", failures)

func _test_affix_rejections(failures: Array[String]) -> void:
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	var known_families: Array[StringName] = [&"caster_power"]
	var known_domains: Array[StringName] = [&"ordinary_drop"]
	var known_sources: Array[StringName] = [&"enemy"]
	var known_rarities: Array[StringName] = [&"rare"]
	var known_item_tags: Array[StringName] = [&"caster"]

	var empty_effects := _valid_affix()
	empty_effects.effects.clear()
	TestAssertions.truthy(not empty_effects.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "empty effects fail", failures)

	var empty_families := _valid_affix()
	empty_families.modifier_family_ids.clear()
	TestAssertions.truthy(not empty_families.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "empty families fail", failures)

	var duplicate_families := _valid_affix()
	duplicate_families.modifier_family_ids.append(&"caster_power")
	TestAssertions.truthy(not duplicate_families.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "duplicate families fail", failures)

	var duplicate_tiers := _valid_affix()
	duplicate_tiers.tiers.append(_valid_tier(1, 2, 3.0, 5.0))
	TestAssertions.truthy(not duplicate_tiers.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "duplicate tier numbers fail", failures)

	var descending_tiers := _valid_affix()
	descending_tiers.tiers.append(_valid_tier(0, 2, 3.0, 5.0))
	TestAssertions.truthy(not descending_tiers.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "nonascending tier numbers fail", failures)

	var descending_levels := _valid_affix()
	descending_levels.tiers.append(_valid_tier(2, 1, 3.0, 5.0))
	TestAssertions.truthy(not descending_levels.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "nonascending item levels fail", failures)

	var unknown_references := _valid_affix()
	unknown_references.modifier_family_ids = [&"unknown_family"]
	unknown_references.allowed_source_ids = [&"unknown_source"]
	unknown_references.allowed_rarity_ids = [&"unknown_rarity"]
	unknown_references.required_item_tags = [&"unknown_tag"]
	TestAssertions.truthy(not unknown_references.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "unknown affix references fail", failures)

	var hybrid_unknown_family := _valid_affix()
	hybrid_unknown_family.effects.clear()
	hybrid_unknown_family.stat_id = &"intelligence"
	hybrid_unknown_family.modifier_family_ids = [&"unknown_family"]
	var hybrid_errors := hybrid_unknown_family.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags)
	TestAssertions.truthy("unknown modifier family" in " ".join(hybrid_errors), "bridge does not bypass explicit family references", failures)

	var hybrid_known_family := _valid_affix()
	hybrid_known_family.effects.clear()
	hybrid_known_family.stat_id = &"intelligence"
	TestAssertions.equal(hybrid_known_family.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), PackedStringArray(), "legacy effect bridge preserves authoritative tiers", failures)

	var unknown_tier_reference := _valid_affix()
	unknown_tier_reference.tiers[0].allowed_generation_domains = [&"unknown_domain"]
	TestAssertions.truthy(not unknown_tier_reference.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "unknown tier references fail", failures)

	var overlapping_tags := _valid_affix()
	overlapping_tags.excluded_item_tags = [&"caster"]
	TestAssertions.truthy(not overlapping_tags.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "overlapping required and excluded tags fail", failures)

	var descending_maximums := _valid_affix()
	descending_maximums.tiers.append(_valid_tier(2, 2, 0.5, 2.0))
	TestAssertions.truthy(not descending_maximums.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "later tier maximum below earlier maximum fails", failures)

func _test_generation_vocabulary(failures: Array[String]) -> void:
	TestAssertions.equal(ItemGenerationVocabulary.DOMAINS, [&"ordinary_drop", &"boss_drop", &"raid_drop", &"vendor", &"crafting", &"developer"], "generation domains stay stable", failures)
	TestAssertions.equal(ItemGenerationVocabulary.ARCHETYPES, [&"melee", &"ranged", &"caster", &"global"], "archetype vocabulary stays stable", failures)
	TestAssertions.equal(ItemGenerationVocabulary.AFFIX_KINDS, PackedStringArray(["implicit", "prefix", "suffix", "special"]), "affix kinds stay stable", failures)

func _valid_affix() -> ItemAffixDefinition:
	var affix := ItemAffixDefinition.new()
	affix.id = &"tempered_focus"
	affix.display_name = "Tempered Focus"
	affix.base_weight = 100.0
	affix.modifier_family_ids = [&"caster_power"]
	affix.required_item_tags = [&"caster"]
	affix.allowed_generation_domains = [&"ordinary_drop"]
	affix.allowed_rarity_ids = [&"rare"]
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"intelligence"
	affix.effects = [effect]
	affix.tiers = [_valid_tier(1, 1, 1.0, 3.0)]
	return affix

func _valid_tier(tier_number: int, minimum_level: int, minimum_roll: float, maximum_roll: float) -> ItemAffixTierDefinition:
	var tier := ItemAffixTierDefinition.new()
	tier.tier = tier_number
	tier.minimum_item_level = minimum_level
	tier.base_weight = 100.0
	tier.minimum_rolls = [minimum_roll]
	tier.maximum_rolls = [maximum_roll]
	return tier
