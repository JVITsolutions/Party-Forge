extends RefCounted

const EXPECTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"exotic", &"ascendant", &"divine", &"eternal"]
const EXPECTED_ORDINARY: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_AFFIXES: Array[Dictionary] = [
	{"id": &"stout", "stat": &"constitution", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"keen", "stat": &"dexterity", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"wise", "stat": &"wisdom", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"of_embers", "stat": &"fire_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_rime", "stat": &"cold_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_reach", "stat": &"attack_range", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"tempered_edge", "stat": &"physical_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	var stats := load("res://data/stats/core_stats.tres") as StatCatalog
	var equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	TestAssertions.truthy(catalog != null, "item foundation catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(stats, equipment), PackedStringArray(), "item foundation catalog validates", failures)
	TestAssertions.equal(catalog.supported_rarity_ids(), EXPECTED_RARITIES, "supported rarity order", failures)
	TestAssertions.equal(catalog.ordinary_rarity_ids(), EXPECTED_ORDINARY, "ordinary rarity order", failures)
	_assert_affix_contract(catalog, failures)
	_assert_invalid_copies(catalog, stats, equipment, failures)
	return failures

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
		TestAssertions.equal(definition.effects.size(), 1, "%s effect count" % affix_id, failures)
		if definition.effects.size() == 1:
			TestAssertions.equal(definition.effects[0].stat_id, expected["stat"], "%s stat id" % affix_id, failures)
			TestAssertions.equal(definition.effects[0].operation, expected["operation"], "%s operation" % affix_id, failures)
		TestAssertions.equal(definition.tiers.size(), 3, "%s tier count" % affix_id, failures)
		var expected_minimum: Array = expected["minimum"]
		var expected_maximum: Array = expected["maximum"]
		for tier_index: int in expected_minimum.size():
			var tier := tier_index + 1
			var expected_bounds := Vector2(expected_minimum[tier_index], expected_maximum[tier_index])
			TestAssertions.equal(definition.roll_bounds(tier), expected_bounds, "%s tier %d bounds" % [affix_id, tier], failures)
		TestAssertions.equal(definition.roll_bounds(0), Vector2(INF, -INF), "%s tier below range sentinel" % affix_id, failures)
		TestAssertions.equal(definition.roll_bounds(4), Vector2(INF, -INF), "%s tier above range sentinel" % affix_id, failures)

func _assert_invalid_copies(
	catalog: ItemFoundationCatalog,
	stats: StatCatalog,
	equipment: EquipmentCatalog,
	failures: Array[String]
) -> void:
	var duplicate_rarity := catalog.duplicate(true) as ItemFoundationCatalog
	duplicate_rarity.rarities.append(duplicate_rarity.rarities[0])
	TestAssertions.truthy(not duplicate_rarity.validate(stats, equipment).is_empty(), "duplicate rarity id and path are rejected", failures)

	var duplicate_affix := catalog.duplicate(true) as ItemFoundationCatalog
	duplicate_affix.affixes.append(duplicate_affix.affixes[0])
	TestAssertions.truthy(not duplicate_affix.validate(stats, equipment).is_empty(), "duplicate affix id and path are rejected", failures)

	var unknown_stat := catalog.duplicate(true) as ItemFoundationCatalog
	_duplicate_affix_at(unknown_stat, 0)
	unknown_stat.affixes[0].effects[0].stat_id = &"unknown_stat"
	TestAssertions.truthy(not unknown_stat.validate(stats, equipment).is_empty(), "unknown affix stat is rejected", failures)

	var invalid_operation := catalog.duplicate(true) as ItemFoundationCatalog
	_duplicate_affix_at(invalid_operation, 0)
	invalid_operation.affixes[0].effects[0].operation = 999
	TestAssertions.truthy(not invalid_operation.validate(stats, equipment).is_empty(), "unsupported affix operation is rejected", failures)

	var inverted_roll := catalog.duplicate(true) as ItemFoundationCatalog
	_duplicate_affix_at(inverted_roll, 0)
	inverted_roll.affixes[0].tiers[0].minimum_rolls[0] = inverted_roll.affixes[0].tiers[0].maximum_rolls[0] + 1.0
	TestAssertions.truthy(not inverted_roll.validate(stats, equipment).is_empty(), "minimum roll above maximum is rejected", failures)

	var embedded_rarity := catalog.duplicate(true) as ItemFoundationCatalog
	embedded_rarity.rarities[0] = ItemRarityDefinition.new()
	embedded_rarity.rarities[0].id = &"common"
	embedded_rarity.rarities[0].display_name = "Common"
	TestAssertions.truthy(not embedded_rarity.validate(stats, equipment).is_empty(), "embedded rarity is rejected", failures)

	var embedded_affix := catalog.duplicate(true) as ItemFoundationCatalog
	embedded_affix.affixes[0] = ItemAffixDefinition.new()
	embedded_affix.affixes[0].id = &"stout"
	embedded_affix.affixes[0].display_name = "Stout"
	TestAssertions.truthy(not embedded_affix.validate(stats, equipment).is_empty(), "embedded affix is rejected", failures)

	var impossible_ordinary := catalog.duplicate(true) as ItemFoundationCatalog
	impossible_ordinary.rarities[0] = impossible_ordinary.rarities[0].duplicate(true) as ItemRarityDefinition
	impossible_ordinary.rarities[0].patterns.clear()
	TestAssertions.truthy(not impossible_ordinary.validate(stats, equipment).is_empty(), "ordinary-enabled rarity without a pattern is rejected", failures)

	var invalid_order := catalog.duplicate(true) as ItemFoundationCatalog
	var first := invalid_order.rarities[0]
	invalid_order.rarities[0] = invalid_order.rarities[1]
	invalid_order.rarities[1] = first
	TestAssertions.truthy(not invalid_order.validate(stats, equipment).is_empty(), "rarity resource order is rejected", failures)

	var missing_equipment_tag := catalog.duplicate(true) as ItemFoundationCatalog
	missing_equipment_tag.known_item_tags.erase(&"helmet")
	TestAssertions.truthy(not missing_equipment_tag.validate(stats, equipment).is_empty(), "missing current equipment item type is rejected", failures)

func _duplicate_affix_at(catalog: ItemFoundationCatalog, index: int) -> void:
	catalog.affixes[index] = catalog.affixes[index].duplicate(true) as ItemAffixDefinition
