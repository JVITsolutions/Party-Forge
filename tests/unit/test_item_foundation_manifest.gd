extends RefCounted

const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const FOUNDATION_PATH := "res://data/items/core_item_foundation_catalog.tres"
const EXPECTED_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic", &"exotic", &"ascendant", &"divine", &"eternal"]
const EXPECTED_ORDINARY: Array[StringName] = [&"common", &"uncommon", &"rare", &"epic", &"legendary"]
const EXPECTED_SOURCES: Array[StringName] = [&"ordinary_enemy", &"boss", &"developer"]
const ROWS_PATH := "res://tools/weighted_loot_content_rows.gd"
const EXPECTED_PATTERN_ROWS: Array[Dictionary] = [
	{"id": &"common_zero", "prefix": 0, "suffix": 0, "weight": 1.0},
	{"id": &"uncommon_prefix", "prefix": 1, "suffix": 0, "weight": 1.0},
	{"id": &"uncommon_suffix", "prefix": 0, "suffix": 1, "weight": 1.0},
	{"id": &"rare_two_prefix", "prefix": 2, "suffix": 0, "weight": 1.0},
	{"id": &"rare_balanced", "prefix": 1, "suffix": 1, "weight": 2.0},
	{"id": &"rare_two_suffix", "prefix": 0, "suffix": 2, "weight": 1.0},
	{"id": &"epic_prefix_heavy", "prefix": 2, "suffix": 1, "weight": 1.0},
	{"id": &"epic_suffix_heavy", "prefix": 1, "suffix": 2, "weight": 1.0},
	{"id": &"legendary_prefix_heavy", "prefix": 3, "suffix": 1, "weight": 1.0},
	{"id": &"legendary_balanced", "prefix": 2, "suffix": 2, "weight": 2.0},
	{"id": &"legendary_suffix_heavy", "prefix": 1, "suffix": 3, "weight": 1.0},
]
const EXPECTED_RARITY_ROWS: Array[Dictionary] = [
	{"id": &"common", "rank": 1, "weight": 1000.0, "ordinary": true, "patterns": [&"common_zero"], "unlock": [], "reserved": 0},
	{"id": &"uncommon", "rank": 2, "weight": 450.0, "ordinary": true, "patterns": [&"uncommon_prefix", &"uncommon_suffix"], "unlock": [], "reserved": 0},
	{"id": &"rare", "rank": 3, "weight": 180.0, "ordinary": true, "patterns": [&"rare_two_prefix", &"rare_balanced", &"rare_two_suffix"], "unlock": [&"rarity_rare_unlocked"], "reserved": 0},
	{"id": &"epic", "rank": 4, "weight": 55.0, "ordinary": true, "patterns": [&"epic_prefix_heavy", &"epic_suffix_heavy"], "unlock": [&"rarity_epic_unlocked"], "reserved": 0},
	{"id": &"legendary", "rank": 5, "weight": 10.0, "ordinary": true, "patterns": [&"legendary_prefix_heavy", &"legendary_balanced", &"legendary_suffix_heavy"], "unlock": [&"rarity_legendary_unlocked"], "reserved": 1},
	{"id": &"mythic", "rank": 6, "weight": 1.0, "ordinary": false, "patterns": [], "unlock": [], "reserved": 0},
	{"id": &"exotic", "rank": 7, "weight": 1.0, "ordinary": false, "patterns": [], "unlock": [], "reserved": 0},
	{"id": &"ascendant", "rank": 8, "weight": 1.0, "ordinary": false, "patterns": [], "unlock": [], "reserved": 0},
	{"id": &"divine", "rank": 9, "weight": 1.0, "ordinary": false, "patterns": [], "unlock": [], "reserved": 0},
	{"id": &"eternal", "rank": 10, "weight": 1.0, "ordinary": false, "patterns": [], "unlock": [], "reserved": 0},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load(FOUNDATION_PATH) as ItemFoundationCatalog
	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	TestAssertions.truthy(catalog != null, "item foundation manifest loads", failures)
	TestAssertions.truthy(equipment != null, "equipment catalog loads for manifest", failures)
	if catalog == null or equipment == null:
		return failures
	TestAssertions.equal(catalog.known_source_ids, EXPECTED_SOURCES, "exact source registry", failures)
	TestAssertions.equal(catalog.supported_rarity_ids(), EXPECTED_RARITIES, "all ten rarities support item instances", failures)
	TestAssertions.equal(catalog.ordinary_rarity_ids(), EXPECTED_ORDINARY, "only first five rarities allow ordinary generation", failures)
	_assert_rarities(catalog, failures)
	_assert_patterns(catalog, failures)
	_assert_external_affixes(catalog, failures)
	_assert_production_affixes_and_bases(catalog, equipment, failures)
	_assert_equipment_tag_registry(catalog, equipment, failures)
	_assert_upper_rarity_issuance(catalog, equipment, failures)
	_assert_bridge_removed(failures)
	return failures

func _assert_rarities(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	TestAssertions.equal(catalog.rarities.size(), EXPECTED_RARITY_ROWS.size(), "exact rarity resource count", failures)
	for index: int in mini(catalog.rarities.size(), EXPECTED_RARITY_ROWS.size()):
		var definition := catalog.rarities[index]
		var expected: Dictionary = EXPECTED_RARITY_ROWS[index]
		TestAssertions.truthy(definition.resource_path.begins_with("res://data/items/rarities/"), "%s is an external rarity resource" % definition.id, failures)
		TestAssertions.equal(definition.id, expected["id"], "rarity %d id" % index, failures)
		TestAssertions.equal(definition.rarity_rank, expected["rank"], "%s rank" % definition.id, failures)
		TestAssertions.truthy(definition.instance_supported, "%s supports item instances" % definition.id, failures)
		TestAssertions.equal(definition.ordinary_generation_enabled, expected["ordinary"], "%s ordinary flag" % definition.id, failures)
		TestAssertions.equal(definition.base_weight, expected["weight"], "%s base weight" % definition.id, failures)
		TestAssertions.equal(definition.required_unlock_tags, expected["unlock"], "%s unlock tags" % definition.id, failures)
		TestAssertions.equal(definition.reserved_special_slots, expected["reserved"], "%s reserved specials" % definition.id, failures)
		var pattern_ids: Array[StringName] = []
		for pattern: ItemAffixPatternDefinition in definition.patterns:
			pattern_ids.append(pattern.id)
		TestAssertions.equal(pattern_ids, expected["patterns"], "%s pattern order" % definition.id, failures)

func _assert_patterns(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	var actual: Array[ItemAffixPatternDefinition] = []
	for rarity: ItemRarityDefinition in catalog.rarities:
		actual.append_array(rarity.patterns)
	TestAssertions.equal(actual.size(), EXPECTED_PATTERN_ROWS.size(), "exact active pattern count", failures)
	for index: int in mini(actual.size(), EXPECTED_PATTERN_ROWS.size()):
		var pattern := actual[index]
		var expected: Dictionary = EXPECTED_PATTERN_ROWS[index]
		TestAssertions.truthy(pattern.resource_path.begins_with("res://data/items/patterns/"), "%s is an external pattern resource" % pattern.id, failures)
		TestAssertions.equal(pattern.id, expected["id"], "pattern %d id" % index, failures)
		TestAssertions.equal(pattern.prefix_count, expected["prefix"], "%s prefix count" % pattern.id, failures)
		TestAssertions.equal(pattern.suffix_count, expected["suffix"], "%s suffix count" % pattern.id, failures)
		TestAssertions.equal(pattern.weight, expected["weight"], "%s weight" % pattern.id, failures)

func _assert_external_affixes(catalog: ItemFoundationCatalog, failures: Array[String]) -> void:
	TestAssertions.equal(catalog.affixes.size(), 195, "exact external production affix count", failures)
	for definition: ItemAffixDefinition in catalog.affixes:
		TestAssertions.truthy(definition.resource_path.begins_with("res://data/items/affixes/"), "%s is an external manifest resource" % definition.id, failures)

func _assert_production_affixes_and_bases(
	catalog: ItemFoundationCatalog,
	equipment: EquipmentCatalog,
	failures: Array[String]
) -> void:
	var rows := load(ROWS_PATH) as Script
	TestAssertions.truthy(rows != null, "weighted loot rows load for production manifest", failures)
	if rows == null:
		return
	var explicit_rows: Array = rows.call(&"explicit_rows")
	var implicit_rows: Array = rows.call(&"implicit_rows", equipment)
	var profile_rows: Array = rows.call(&"weapon_profile_rows")
	TestAssertions.equal(explicit_rows.size(), 96, "exact explicit production row count", failures)
	TestAssertions.equal(implicit_rows.size(), 99, "exact implicit production row count", failures)
	TestAssertions.equal(profile_rows.size(), 11, "exact weapon profile row count", failures)

	var expected_paths: Dictionary = {}
	var expected_families: Array[StringName] = []
	var category_counts := {"focused": 0, "standard_hybrid": 0, "premium_hybrid": 0, "implicit": 0}
	for row_variant: Variant in explicit_rows + implicit_rows:
		var row := row_variant as Dictionary
		var id: StringName = row["id"]
		expected_paths[id] = String(row["output_path"])
		var category := String(row["category"])
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		for family_id: StringName in row["modifier_family_ids"]:
			if family_id not in expected_families:
				expected_families.append(family_id)
	expected_families.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	TestAssertions.equal(category_counts, {"focused": 64, "standard_hybrid": 24, "premium_hybrid": 8, "implicit": 99}, "exact production affix category counts", failures)
	TestAssertions.equal(catalog.modifier_family_ids, expected_families, "exact sorted production modifier family registry", failures)
	var side_counts := {"prefix": 0, "suffix": 0, "implicit": 0}
	var affinity_property_exists := &"affinity_tags" in _property_names(ItemAffixDefinition.new())
	TestAssertions.truthy(affinity_property_exists, "production affix schema exposes affinity tags", failures)
	for definition: ItemAffixDefinition in catalog.affixes:
		if definition == null:
			continue
		side_counts[definition.affix_kind] = int(side_counts.get(definition.affix_kind, 0)) + 1
		TestAssertions.equal(definition.resource_path, expected_paths.get(definition.id, ""), "%s exact production output path" % definition.id, failures)
		TestAssertions.equal(definition.tiers.size(), 12, "%s exact production tier count" % definition.id, failures)
		if affinity_property_exists:
			var affinity_tags: Array = definition.get(&"affinity_tags")
			var sorted_affinities := affinity_tags.duplicate()
			sorted_affinities.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
			TestAssertions.equal(affinity_tags, sorted_affinities, "%s affinities are sorted" % definition.id, failures)
			for affinity: StringName in affinity_tags:
				TestAssertions.truthy(affinity in catalog.known_item_tags, "%s affinity %s is a known live tag" % [definition.id, affinity], failures)
	TestAssertions.equal(side_counts, {"prefix": 48, "suffix": 48, "implicit": 99}, "exact production affix side counts", failures)

	var implicit_ids: Array[StringName] = []
	var profile_by_base: Dictionary = {}
	for row_variant: Variant in profile_rows:
		var row := row_variant as Dictionary
		profile_by_base[row["base"]] = row
	var support_ids: Array = rows.call(&"support_base_ids")
	TestAssertions.equal(support_ids.size(), 7, "exact explicit support base count", failures)
	for base: EquipmentBaseDefinition in equipment.definitions:
		TestAssertions.equal(base.implicit_affix_ids.size(), 1, "%s has one production implicit" % base.id, failures)
		if base.implicit_affix_ids.size() == 1:
			var implicit_id := base.implicit_affix_ids[0]
			TestAssertions.truthy(implicit_id not in implicit_ids, "%s implicit assignment is unique" % base.id, failures)
			implicit_ids.append(implicit_id)
			TestAssertions.equal(catalog.affix(implicit_id).affix_kind if catalog.affix(implicit_id) != null else "", "implicit", "%s assigned affix is implicit" % base.id, failures)
		if profile_by_base.has(base.id):
			var profile_row := profile_by_base[base.id] as Dictionary
			TestAssertions.truthy(base.weapon_damage_profile != null, "%s exact damage profile link exists" % base.id, failures)
			if base.weapon_damage_profile != null:
				TestAssertions.equal(base.weapon_damage_profile.id, profile_row["id"], "%s exact damage profile id" % base.id, failures)
				TestAssertions.equal(base.weapon_damage_profile.resource_path, profile_row["output_path"], "%s exact external damage profile path" % base.id, failures)
		elif base.id in support_ids:
			TestAssertions.equal(base.weapon_damage_profile, null, "%s support base intentionally has no damage profile" % base.id, failures)
		else:
			TestAssertions.equal(base.weapon_damage_profile, null, "%s non-weapon base has no damage profile" % base.id, failures)
	TestAssertions.equal(implicit_ids.size(), 99, "all 99 bases have distinct implicit assignments", failures)
	TestAssertions.equal(equipment.validate(), PackedStringArray(), "production equipment catalog validates exact links", failures)

func _assert_equipment_tag_registry(catalog: ItemFoundationCatalog, equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var live_tags: Array[StringName] = []
	for definition: EquipmentBaseDefinition in equipment.definitions:
		for tag: StringName in definition.normalized_generation_tags():
			if tag not in live_tags:
				live_tags.append(tag)
	live_tags.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	TestAssertions.equal(catalog.known_item_tags, live_tags, "manifest registry is exact normalized equipment tag union", failures)

func _assert_upper_rarity_issuance(catalog: ItemFoundationCatalog, equipment: EquipmentCatalog, failures: Array[String]) -> void:
	for index: int in range(5, EXPECTED_RARITIES.size()):
		var rarity_id := EXPECTED_RARITIES[index]
		var issued := ItemInstanceIssuer.issue(
			"manifest:upper-rarity",
			index,
			"manifest_test",
			4402,
			{"affixes": [], "base_definition_id": "forge_vanguard_sword", "base_damage_components": [], "item_level": 500, "rarity_id": String(rarity_id)},
			equipment,
			catalog
		)
		TestAssertions.truthy(issued.ok(), "%s can issue a schema-one item instance" % rarity_id, failures)

func _assert_bridge_removed(failures: Array[String]) -> void:
	var rarity_properties := _property_names(ItemRarityDefinition.new())
	for property_name: StringName in [&"functional", &"minimum_affixes", &"maximum_affixes"]:
		TestAssertions.truthy(property_name not in rarity_properties, "rarity bridge property %s is removed" % property_name, failures)
	var affix_properties := _property_names(ItemAffixDefinition.new())
	for property_name: StringName in [&"minimum_tier", &"maximum_tier", &"stat_id", &"operation", &"minimum_roll_by_tier", &"maximum_roll_by_tier", &"required_tags"]:
		TestAssertions.truthy(property_name not in affix_properties, "affix bridge property %s is removed" % property_name, failures)

func _property_names(resource: Resource) -> Array[StringName]:
	var names: Array[StringName] = []
	for property: Dictionary in resource.get_property_list():
		names.append(StringName(property["name"] as String))
	return names
