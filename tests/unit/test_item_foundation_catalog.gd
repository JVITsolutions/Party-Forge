extends RefCounted

const EXPECTED_FUNCTIONAL: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_FUTURE: Array[StringName] = [&"mythic", &"eternal"]
const EXPECTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"eternal"]
const EXPECTED_AFFIXES: Array[Dictionary] = [
	{"id": &"stout", "stat": &"constitution", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"keen", "stat": &"dexterity", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"wise", "stat": &"wisdom", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"of_embers", "stat": &"fire_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_rime", "stat": &"cold_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_reach", "stat": &"attack_range", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(catalog != null, "item foundation catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(stats), PackedStringArray(), "item foundation catalog validates", failures)
	_assert_rarity_contract(catalog, failures)
	TestAssertions.equal(catalog.functional_rarity_ids(), EXPECTED_FUNCTIONAL, "functional rarity order", failures)
	for rarity_id: StringName in EXPECTED_FUTURE:
		TestAssertions.truthy(catalog.rarity(rarity_id) != null and not catalog.rarity(rarity_id).functional, "%s remains future" % rarity_id, failures)
	_assert_affix_contract(catalog, failures)
	_assert_invalid_copies(catalog, stats, failures)
	return failures

func _assert_rarity_contract(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	var rarity_ids: Array[StringName] = []
	for definition: ItemRarityDefinition in catalog.rarities:
		rarity_ids.append(definition.id if definition != null else &"<null>")
	TestAssertions.equal(rarity_ids, EXPECTED_RARITIES, "complete rarity order", failures)

func _assert_affix_contract(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	TestAssertions.equal(catalog.affixes.size(), EXPECTED_AFFIXES.size(), "exact fixture affix count", failures)
	for index: int in EXPECTED_AFFIXES.size():
		var expected: Dictionary = EXPECTED_AFFIXES[index]
		var affix_id: StringName = expected["id"]
		var definition := catalog.affix(affix_id)
		TestAssertions.truthy(definition != null, "%s fixture affix resolves" % affix_id, failures)
		if definition == null:
			continue
		if index < catalog.affixes.size():
			TestAssertions.equal(catalog.affixes[index].id, affix_id, "%s fixture order" % affix_id, failures)
		TestAssertions.equal(definition.stat_id, expected["stat"], "%s stat id" % affix_id, failures)
		TestAssertions.equal(definition.operation, expected["operation"], "%s operation" % affix_id, failures)
		TestAssertions.equal(definition.minimum_tier, 1, "%s minimum tier" % affix_id, failures)
		TestAssertions.equal(definition.maximum_tier, 3, "%s maximum tier" % affix_id, failures)
		TestAssertions.equal(definition.minimum_roll_by_tier.size(), 3, "%s minimum roll count" % affix_id, failures)
		TestAssertions.equal(definition.maximum_roll_by_tier.size(), 3, "%s maximum roll count" % affix_id, failures)
		var expected_minimum: Array = expected["minimum"]
		var expected_maximum: Array = expected["maximum"]
		for tier_index: int in expected_minimum.size():
			var tier := tier_index + 1
			var expected_bounds := Vector2(expected_minimum[tier_index], expected_maximum[tier_index])
			TestAssertions.equal(definition.roll_bounds(tier), expected_bounds, "%s tier %d bounds" % [affix_id, tier], failures)
		TestAssertions.equal(definition.roll_bounds(0), Vector2(INF, -INF), "%s tier below range sentinel" % affix_id, failures)
		TestAssertions.equal(definition.roll_bounds(4), Vector2(INF, -INF), "%s tier above range sentinel" % affix_id, failures)

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
