extends RefCounted

const EXPECTED_FUNCTIONAL: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_FUTURE: Array[StringName] = [&"mythic", &"eternal"]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(catalog != null, "item foundation catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(stats), PackedStringArray(), "item foundation catalog validates", failures)
	TestAssertions.equal(catalog.functional_rarity_ids(), EXPECTED_FUNCTIONAL, "functional rarity order", failures)
	for rarity_id: StringName in EXPECTED_FUTURE:
		TestAssertions.truthy(catalog.rarity(rarity_id) != null and not catalog.rarity(rarity_id).functional, "%s remains future" % rarity_id, failures)
	TestAssertions.truthy(catalog.affix(&"stout") != null, "stout fixture affix resolves", failures)
	TestAssertions.truthy(catalog.affix(&"of_embers") != null, "fire fixture affix resolves", failures)
	_assert_invalid_copies(catalog, stats, failures)
	return failures

func _assert_invalid_copies(catalog: ItemFoundationCatalog, stats: StatCatalog, failures: Array[String]) -> void:
	var duplicate_rarity := catalog.duplicate(true) as ItemFoundationCatalog
	duplicate_rarity.rarities.append(duplicate_rarity.rarities[0])
	TestAssertions.truthy(not duplicate_rarity.validate(stats).is_empty(), "duplicate rarity id is rejected", failures)

	var duplicate_affix := catalog.duplicate(true) as ItemFoundationCatalog
	duplicate_affix.affixes.append(duplicate_affix.affixes[0])
	TestAssertions.truthy(not duplicate_affix.validate(stats).is_empty(), "duplicate affix id is rejected", failures)

	var unknown_stat := catalog.duplicate(true) as ItemFoundationCatalog
	unknown_stat.affixes[0].stat_id = &"unknown_stat"
	TestAssertions.truthy(not unknown_stat.validate(stats).is_empty(), "unknown affix stat is rejected", failures)

	var invalid_operation := catalog.duplicate(true) as ItemFoundationCatalog
	invalid_operation.affixes[0].operation = 999
	TestAssertions.truthy(not invalid_operation.validate(stats).is_empty(), "unsupported affix operation is rejected", failures)

	var invalid_tier_range := catalog.duplicate(true) as ItemFoundationCatalog
	invalid_tier_range.affixes[0].minimum_tier = 0
	TestAssertions.truthy(not invalid_tier_range.validate(stats).is_empty(), "tier range below one is rejected", failures)

	var inverted_roll := catalog.duplicate(true) as ItemFoundationCatalog
	inverted_roll.affixes[0].minimum_roll_by_tier[0] = inverted_roll.affixes[0].maximum_roll_by_tier[0] + 1.0
	TestAssertions.truthy(not inverted_roll.validate(stats).is_empty(), "minimum roll above maximum is rejected", failures)
