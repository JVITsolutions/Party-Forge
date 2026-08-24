extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_pattern_contract(failures)
	_test_multi_effect_tiers(failures)
	_test_affix_cross_references(failures)
	_test_rarity_validation(failures)
	_test_effect_validation(failures)
	_test_roll_step_validation(failures)
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

func _test_roll_step_validation(failures: Array[String]) -> void:
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	var effect := ItemModifierEffectDefinition.new()
	effect.stat_id = &"crit_chance"
	var properties := _property_names(effect)
	TestAssertions.truthy(&"roll_step" in properties, "modifier effects expose an optional roll step", failures)
	if &"roll_step" not in properties:
		return
	TestAssertions.equal(float(effect.get(&"roll_step")), 0.0, "roll step defaults to continuous rolling", failures)
	effect.set(&"roll_step", NAN)
	TestAssertions.truthy(_has_diagnostic(effect.validate(stats), "roll step must be finite and nonnegative"), "nonfinite roll step fails", failures)
	effect.set(&"roll_step", -0.01)
	TestAssertions.truthy(_has_diagnostic(effect.validate(stats), "roll step must be finite and nonnegative"), "negative roll step fails", failures)

	var no_grid := _valid_affix()
	no_grid.effects[0].stat_id = &"crit_chance"
	no_grid.effects[0].set(&"roll_step", 0.01)
	no_grid.tiers[0].minimum_rolls = [0.011]
	no_grid.tiers[0].maximum_rolls = [0.019]
	TestAssertions.truthy(
		_has_diagnostic(no_grid.validate(stats, [&"caster_power"], [&"ordinary_drop"], [], [&"rare"], [&"caster"]), "contains no legal roll grid point"),
		"positive roll step rejects a tier range with no legal grid point",
		failures,
	)

	var interior_grid := _valid_affix()
	interior_grid.effects[0].stat_id = &"crit_chance"
	interior_grid.effects[0].set(&"roll_step", 0.01)
	interior_grid.tiers[0].minimum_rolls = [0.011]
	interior_grid.tiers[0].maximum_rolls = [0.021]
	TestAssertions.equal(
		interior_grid.validate(stats, [&"caster_power"], [&"ordinary_drop"], [], [&"rare"], [&"caster"]),
		PackedStringArray(),
		"positive roll step accepts an interior grid point when neither bound is on-grid",
		failures,
	)

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
	var empty_known: Array[StringName] = []

	var empty_effects := _valid_affix()
	empty_effects.effects.clear()
	TestAssertions.truthy(_has_diagnostic(empty_effects.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "requires at least one effect"), "empty effects fail", failures)

	var empty_families := _valid_affix()
	empty_families.modifier_family_ids.clear()
	TestAssertions.truthy(_has_diagnostic(empty_families.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "requires at least one modifier family"), "empty families fail", failures)

	var duplicate_families := _valid_affix()
	duplicate_families.modifier_family_ids.append(&"caster_power")
	TestAssertions.truthy(_has_diagnostic(duplicate_families.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "duplicate modifier family caster_power"), "duplicate families fail", failures)

	var duplicate_tiers := _valid_affix()
	duplicate_tiers.tiers.append(_valid_tier(1, 2, 3.0, 5.0))
	TestAssertions.truthy(_has_diagnostic(duplicate_tiers.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "duplicate tier 1"), "duplicate tier numbers fail", failures)

	var descending_tiers := _valid_affix()
	descending_tiers.tiers.append(_valid_tier(0, 2, 3.0, 5.0))
	TestAssertions.truthy(_has_diagnostic(descending_tiers.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "tier numbers must ascend"), "nonascending tier numbers fail", failures)

	var descending_levels := _valid_affix()
	descending_levels.tiers.append(_valid_tier(2, 1, 3.0, 5.0))
	TestAssertions.truthy(_has_diagnostic(descending_levels.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "tier minimum item levels must ascend"), "nonascending item levels fail", failures)

	var unknown_family := _valid_affix()
	unknown_family.modifier_family_ids = [&"unknown_family"]
	TestAssertions.truthy(_has_diagnostic(unknown_family.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown modifier family unknown_family"), "unknown family fails", failures)

	var unknown_domain := _valid_affix()
	unknown_domain.allowed_generation_domains = [&"unknown_domain"]
	TestAssertions.truthy(_has_diagnostic(unknown_domain.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown generation domain unknown_domain"), "unknown domain diagnostic", failures)

	var unknown_source := _valid_affix()
	unknown_source.allowed_source_ids = [&"unknown_source"]
	TestAssertions.truthy(_has_diagnostic(unknown_source.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown source unknown_source"), "unknown source fails", failures)

	var unknown_rarity := _valid_affix()
	unknown_rarity.allowed_rarity_ids = [&"unknown_rarity"]
	TestAssertions.truthy(_has_diagnostic(unknown_rarity.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown rarity unknown_rarity"), "unknown rarity fails", failures)

	var unknown_item_tag := _valid_affix()
	unknown_item_tag.required_item_tags = [&"unknown_tag"]
	TestAssertions.truthy(_has_diagnostic(unknown_item_tag.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown required item tag unknown_tag"), "unknown item tag fails", failures)

	var empty_family_manifest := _valid_affix()
	TestAssertions.truthy(_has_diagnostic(empty_family_manifest.validate(stats, empty_known, known_domains, known_sources, known_rarities, known_item_tags), "unknown modifier family caster_power"), "explicit family fails against empty manifest", failures)

	var empty_domain_manifest := _valid_affix()
	TestAssertions.truthy(_has_diagnostic(empty_domain_manifest.validate(stats, known_families, empty_known, known_sources, known_rarities, known_item_tags), "unknown generation domain ordinary_drop"), "explicit domain fails against empty manifest", failures)

	var empty_source_manifest := _valid_affix()
	empty_source_manifest.allowed_source_ids = [&"enemy"]
	TestAssertions.truthy(_has_diagnostic(empty_source_manifest.validate(stats, known_families, known_domains, empty_known, known_rarities, known_item_tags), "unknown source enemy"), "explicit source fails against empty manifest", failures)

	var empty_rarity_manifest := _valid_affix()
	TestAssertions.truthy(_has_diagnostic(empty_rarity_manifest.validate(stats, known_families, known_domains, known_sources, empty_known, known_item_tags), "unknown rarity rare"), "explicit rarity fails against empty manifest", failures)

	var empty_item_tag_manifest := _valid_affix()
	TestAssertions.truthy(_has_diagnostic(empty_item_tag_manifest.validate(stats, known_families, known_domains, known_sources, known_rarities, empty_known), "unknown required item tag caster"), "explicit item tag fails against empty manifest", failures)

	var unknown_tier_reference := _valid_affix()
	unknown_tier_reference.tiers[0].allowed_generation_domains = [&"unknown_domain"]
	TestAssertions.truthy(_has_diagnostic(unknown_tier_reference.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "unknown tier generation domain unknown_domain"), "unknown tier references fail", failures)

	var overlapping_tags := _valid_affix()
	overlapping_tags.excluded_item_tags = [&"caster"]
	TestAssertions.truthy(not overlapping_tags.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags).is_empty(), "overlapping required and excluded tags fail", failures)

	var descending_maximums := _valid_affix()
	descending_maximums.tiers.append(_valid_tier(2, 2, 0.5, 2.0))
	TestAssertions.truthy(_has_diagnostic(descending_maximums.validate(stats, known_families, known_domains, known_sources, known_rarities, known_item_tags), "maximum descends"), "later tier maximum below earlier maximum fails", failures)

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

func _has_diagnostic(errors: PackedStringArray, expected: String) -> bool:
	return expected in "\n".join(errors)

func _property_names(resource: Resource) -> Array[StringName]:
	var result: Array[StringName] = []
	for property: Dictionary in resource.get_property_list():
		result.append(StringName(property.get("name", "")))
	return result
