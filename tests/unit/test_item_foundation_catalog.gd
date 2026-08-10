extends RefCounted

const EXPECTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"exotic", &"ascendant", &"divine", &"eternal"]
const EXPECTED_ORDINARY: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_PRODUCTION_AFFIX_COUNT := 195
const EXPECTED_AFFIXES: Array[Dictionary] = [
	{"id": &"stout", "name": "Stout", "kind": "prefix", "stat": &"constitution", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"keen", "name": "Keen", "kind": "prefix", "stat": &"dexterity", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"wise", "name": "Wise", "kind": "prefix", "stat": &"wisdom", "operation": StatModifier.Operation.FLAT, "minimum": [1.0, 4.0, 7.0], "maximum": [3.0, 6.0, 10.0]},
	{"id": &"of_embers", "name": "of Embers", "kind": "suffix", "stat": &"fire_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_rime", "name": "of Rime", "kind": "suffix", "stat": &"cold_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"of_reach", "name": "of Reach", "kind": "suffix", "stat": &"attack_range", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
	{"id": &"tempered_edge", "name": "Tempered Edge", "kind": "implicit", "stat": &"physical_damage", "operation": StatModifier.Operation.INCREASED, "minimum": [0.05, 0.11, 0.21], "maximum": [0.1, 0.2, 0.3]},
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
	TestAssertions.equal(catalog.affixes.size(), EXPECTED_PRODUCTION_AFFIX_COUNT, "exact production affix count", failures)
	var ordered_ids: Array[StringName] = []
	for definition: ItemAffixDefinition in catalog.affixes:
		if definition != null:
			ordered_ids.append(definition.id)
	var sorted_ids := ordered_ids.duplicate()
	sorted_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	TestAssertions.equal(ordered_ids, sorted_ids, "production affixes use stable id order", failures)
	for expected: Dictionary in EXPECTED_AFFIXES:
		var affix_id: StringName = expected["id"]
		var definition := catalog.affix(affix_id)
		TestAssertions.truthy(definition != null, "%s fixture affix resolves" % affix_id, failures)
		if definition == null:
			continue
		TestAssertions.equal(definition.resource_path, "res://data/items/affixes/fixtures/%s.tres" % affix_id, "%s retained fixture path" % affix_id, failures)
		TestAssertions.equal(definition.display_name, expected["name"], "%s retained display name" % affix_id, failures)
		TestAssertions.equal(definition.affix_kind, expected["kind"], "%s retained affix kind" % affix_id, failures)
		TestAssertions.equal(definition.effects.size(), 1, "%s effect count" % affix_id, failures)
		if definition.effects.size() == 1:
			TestAssertions.equal(definition.effects[0].stat_id, expected["stat"], "%s stat id" % affix_id, failures)
			TestAssertions.equal(definition.effects[0].operation, expected["operation"], "%s operation" % affix_id, failures)
		TestAssertions.equal(definition.tiers.size(), 12, "%s production tier count" % affix_id, failures)
		var expected_minimum: Array = expected["minimum"]
		var expected_maximum: Array = expected["maximum"]
		for tier_index: int in expected_minimum.size():
			var tier := tier_index + 1
			var expected_bounds := Vector2(expected_minimum[tier_index], expected_maximum[tier_index])
			TestAssertions.equal(definition.roll_bounds(tier), expected_bounds, "%s tier %d bounds" % [affix_id, tier], failures)
		TestAssertions.equal(definition.roll_bounds(0), Vector2(INF, -INF), "%s tier below range sentinel" % affix_id, failures)
		TestAssertions.equal(definition.roll_bounds(13), Vector2(INF, -INF), "%s tier above range sentinel" % affix_id, failures)
	_assert_rarity_ceilings(catalog, failures)

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

	var missing_production_affix := catalog.duplicate(true) as ItemFoundationCatalog
	missing_production_affix.affixes.pop_back()
	TestAssertions.truthy(not missing_production_affix.validate(stats, equipment).is_empty(), "production affix total is exact", failures)

	var unsorted_affinity := catalog.duplicate(true) as ItemFoundationCatalog
	var affinity_index := _first_affix_with_affinity(unsorted_affinity)
	TestAssertions.truthy(affinity_index >= 0, "production catalog contains authored affinity", failures)
	if affinity_index >= 0:
		_duplicate_affix_at(unsorted_affinity, affinity_index)
		unsorted_affinity.affixes[affinity_index].set(&"affinity_tags", [&"ranged", &"melee"])
		TestAssertions.truthy(not unsorted_affinity.validate(stats, equipment).is_empty(), "affinity tags must be sorted and known", failures)

	var duplicate_affinity := catalog.duplicate(true) as ItemFoundationCatalog
	affinity_index = _first_affix_with_affinity(duplicate_affinity)
	if affinity_index >= 0:
		_duplicate_affix_at(duplicate_affinity, affinity_index)
		var affinity_tags: Array = duplicate_affinity.affixes[affinity_index].get(&"affinity_tags")
		var affinity: StringName = affinity_tags[0]
		duplicate_affinity.affixes[affinity_index].set(&"affinity_tags", [affinity, affinity])
		TestAssertions.truthy(not duplicate_affinity.validate(stats, equipment).is_empty(), "affinity tags must be unique", failures)

func _assert_rarity_ceilings(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	var expected_by_tier := {
		1: EXPECTED_ORDINARY, 2: EXPECTED_ORDINARY, 3: EXPECTED_ORDINARY,
		4: [&"uncommon", &"rare", &"epic", &"legendary"], 5: [&"uncommon", &"rare", &"epic", &"legendary"],
		6: [&"rare", &"epic", &"legendary"], 7: [&"rare", &"epic", &"legendary"], 8: [&"rare", &"epic", &"legendary"],
		9: [&"epic", &"legendary"], 10: [&"epic", &"legendary"],
		11: [&"legendary"], 12: [&"legendary"],
	}
	for definition: ItemAffixDefinition in catalog.affixes:
		if definition == null:
			continue
		TestAssertions.equal(definition.tiers.size(), 12, "%s has exactly twelve tiers" % definition.id, failures)
		for tier: ItemAffixTierDefinition in definition.tiers:
			if tier != null:
				TestAssertions.equal(tier.allowed_rarity_ids, expected_by_tier.get(tier.tier, []), "%s tier %d exact rarity ceiling" % [definition.id, tier.tier], failures)

func _first_affix_with_affinity(catalog: ItemFoundationCatalog) -> int:
	for index: int in catalog.affixes.size():
		var definition := catalog.affixes[index]
		if definition != null and &"affinity_tags" in _property_names(definition) and not (definition.get(&"affinity_tags") as Array).is_empty():
			return index
	return -1

func _property_names(resource: Resource) -> Array[StringName]:
	var result: Array[StringName] = []
	for property: Dictionary in resource.get_property_list():
		result.append(StringName(property["name"] as String))
	return result

func _duplicate_affix_at(catalog: ItemFoundationCatalog, index: int) -> void:
	catalog.affixes[index] = catalog.affixes[index].duplicate(true) as ItemAffixDefinition
