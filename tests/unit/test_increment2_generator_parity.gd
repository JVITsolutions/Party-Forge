extends RefCounted

const TypedCombatMigration := preload("res://tools/migrate_typed_combat_data.gd")
const StatFoundationData := preload("res://tools/create_stat_foundation_data.gd")
const UpgradeRows := preload("res://tools/character_upgrade_content_rows.gd")
const CharacterUpgradeData := preload("res://tools/create_character_upgrade_data.gd")
const DefaultData := preload("res://tools/create_default_data.gd")
const ExpansionRows := preload("res://tools/class_expansion_rows.gd")
const ExpansionMigration := preload("res://tools/migrate_class_expansion_data.gd")

const CANONICAL_STAT_COUNT := 37
const CANONICAL_KEYWORD_COUNT := 81
const CASTER_ATTACK_IDS: Array[StringName] = [
	&"mage_burst",
	&"cleric_bolt",
	&"frost_shard",
	&"warlock_bolt",
]
const WEIGHTED_LOOT_COMBINED_SHA256 := "599658e415cd662fec2a4544db763869db4db88fa7001549f0b2c5ef44aa0045"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_attack_authoring_parity(failures)
	_test_expansion_class_capability_parity(failures)
	_test_stat_catalog_generator_parity(failures)
	_test_keyword_catalog_generator_parity(failures)
	_test_weighted_loot_byte_parity(failures)
	return failures

func _test_weighted_loot_byte_parity(failures: Array[String]) -> void:
	var equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	var foundation := load("res://data/items/core_item_foundation_catalog.tres") as ItemFoundationCatalog
	TestAssertions.truthy(equipment != null and foundation != null, "weighted loot parity catalogs load", failures)
	if equipment == null or foundation == null:
		return
	var request := ItemGenerationRequest.create(424242, 7, 750, &"ordinary_enemy", &"ordinary_drop", [&"rare"] as Array[StringName])
	request.forced_base_id = &"forge_vanguard_sword"
	request.forced_rarity_id = &"rare"
	request.unlock_tags = [&"rarity_rare_unlocked", &"rarity_epic_unlocked", &"rarity_legendary_unlocked"]
	var result := ItemGenerationService.generate(request, "generation:test", 103, equipment, foundation)
	TestAssertions.truthy(result != null and result.ok(), "weighted loot parity generation succeeds", failures)
	if result == null or not result.ok():
		return
	var item_bytes := ItemInstanceCodec.encode(result.item)
	var trace_bytes := JSON.stringify(result.trace.stages)
	TestAssertions.equal((item_bytes + "\n" + trace_bytes).sha256_text(), WEIGHTED_LOOT_COMBINED_SHA256, "weighted loot item and trace bytes remain exact", failures)

func _test_expansion_class_capability_parity(failures: Array[String]) -> void:
	TestAssertions.equal(ExpansionRows.CLASS_ROWS.size(), 5, "expansion generator exposes exactly five class rows", failures)
	var row_matcher := Callable(ExpansionMigration, &"class_matches_row")
	TestAssertions.truthy(row_matcher.is_valid(), "class expansion generator exposes a deterministic no-op matcher", failures)
	for row: Dictionary in ExpansionRows.CLASS_ROWS:
		var class_id := StringName(row.get("id", &""))
		var relative_path := String(row.get("path", "")).trim_prefix("res://")
		var canonical := load(_canonical_path(relative_path)) as ClassDefinition
		var persisted := load(String(row.get("path", ""))) as ClassDefinition
		TestAssertions.truthy(canonical != null, "canonical %s class loads" % class_id, failures)
		TestAssertions.truthy(persisted != null, "persisted %s class loads" % class_id, failures)
		if canonical == null or persisted == null:
			continue
		var generator_tags: Array[StringName] = []
		generator_tags.assign(row.get("tags", []))
		TestAssertions.equal(generator_tags, canonical.capability_tags, "%s generator capabilities exactly equal canonical capabilities" % class_id, failures)
		TestAssertions.equal(persisted.capability_tags, canonical.capability_tags, "%s persisted capabilities exactly equal canonical capabilities" % class_id, failures)
		if row_matcher.is_valid():
			TestAssertions.truthy(bool(row_matcher.call(canonical, row, canonical.primary_attack)), "%s canonical class is a byte-preserving generator no-op" % class_id, failures)
			var stale_projection := canonical.duplicate(true) as ClassDefinition
			stale_projection.capability_tags = canonical.capability_tags.slice(0, maxi(0, canonical.capability_tags.size() - 1))
			TestAssertions.truthy(not bool(row_matcher.call(stale_projection, row, stale_projection.primary_attack)), "%s stale capabilities require generator save" % class_id, failures)
		var generated_projection := canonical.duplicate(true) as ClassDefinition
		generated_projection.capability_tags.assign(generator_tags)
		var loadout: Dictionary = {}
		for entry: EquipmentLoadoutEntry in generated_projection.visual_profile.default_equipment:
			if entry == null or entry.item == null:
				continue
			TestAssertions.equal(
				EquipmentEligibility.validate_structure(entry.item, generated_projection, entry.slot_id, loadout),
				PackedStringArray(),
				"%s generated capabilities permit real starter item %s" % [class_id, entry.item.id],
				failures,
			)
			loadout[entry.slot_id] = entry.item

func _test_attack_authoring_parity(failures: Array[String]) -> void:
	_assert_attack_table(TypedCombatMigration.ROWS, "typed combat migration", failures)
	_assert_attack_table(DefaultData.ATTACK_ROWS, "default data generator", failures)
	_assert_attack_table(ExpansionRows.ATTACK_ROWS, "class expansion migration", failures)

func _test_stat_catalog_generator_parity(failures: Array[String]) -> void:
	var generated := StatFoundationData.build_catalog() as StatCatalog
	var canonical := load(_canonical_path("data/stats/core_stats.tres")) as StatCatalog
	var persisted := load("res://data/stats/core_stats.tres") as StatCatalog
	_assert_stat_catalog(generated, canonical, "stat source table", failures)
	_assert_stat_catalog(persisted, canonical, "persisted stat generator output", failures)

func _test_keyword_catalog_generator_parity(failures: Array[String]) -> void:
	var canonical := load(_canonical_path("data/keywords/core_keywords.tres")) as KeywordCatalog
	var persisted := load("res://data/keywords/core_keywords.tres") as KeywordCatalog
	_assert_keyword_rows(UpgradeRows.KEYWORD_ROWS, canonical, failures)
	var builder := Callable(CharacterUpgradeData, &"build_keyword_catalog")
	TestAssertions.truthy(builder.is_valid(), "keyword generator exposes its behavioral catalog builder", failures)
	if builder.is_valid():
		_assert_keyword_catalog(builder.call() as KeywordCatalog, canonical, "keyword source table", failures)
	_assert_keyword_catalog(persisted, canonical, "persisted keyword generator output", failures)

func _assert_attack_table(rows: Array[Dictionary], label: String, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var attack_id := StringName(row.get("id", &""))
		TestAssertions.truthy(not attack_id.is_empty(), "%s row id is not empty" % label, failures)
		TestAssertions.truthy(not seen.has(attack_id), "%s row id %s is unique" % [label, attack_id], failures)
		seen[attack_id] = true
		var relative_path := String(row.get("path", "data/attacks/%s.tres" % attack_id)).trim_prefix("res://")
		var canonical := load(_canonical_path(relative_path)) as AttackDefinition
		var persisted := load("res://%s" % relative_path) as AttackDefinition
		TestAssertions.truthy(canonical != null, "%s canonical %s loads" % [label, attack_id], failures)
		TestAssertions.truthy(persisted != null, "%s persisted %s loads" % [label, attack_id], failures)
		if canonical == null:
			continue
		_assert_attack_row(row, canonical, "%s row %s" % [label, attack_id], failures)
		if persisted != null:
			_assert_attack_definition(persisted, canonical, "%s persisted %s" % [label, attack_id], failures)

func _assert_attack_row(row: Dictionary, canonical: AttackDefinition, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(StringName(row.get("id", &"")), canonical.id, "%s id parity" % label, failures)
	TestAssertions.equal(int(row.get("kind", -1)), int(canonical.kind), "%s kind parity" % label, failures)
	TestAssertions.near(float(row.get("power", NAN)), canonical.power, 0.0001, "%s power parity" % label, failures)
	TestAssertions.near(float(row.get("cooldown", NAN)), canonical.cooldown, 0.0001, "%s cooldown parity" % label, failures)
	TestAssertions.near(float(row.get("range", NAN)), canonical.range, 0.0001, "%s range parity" % label, failures)
	TestAssertions.near(float(row.get("speed", NAN)), canonical.projectile_speed, 0.0001, "%s projectile speed parity" % label, failures)
	TestAssertions.near(float(row.get("area", NAN)), canonical.area_radius, 0.0001, "%s area parity" % label, failures)
	TestAssertions.equal(bool(row.get("crit", false)), canonical.can_crit, "%s critical parity" % label, failures)
	var tags: Array[StringName] = []
	tags.assign(row.get("tags", []))
	TestAssertions.equal(tags, canonical.action_tags, "%s exact ordered tag parity" % label, failures)
	if canonical.id in CASTER_ATTACK_IDS:
		TestAssertions.equal(tags, canonical.normalized_action_tags(), "%s caster tags remain sorted and unique" % label, failures)
	var expected_type := &""
	var expected_amount := 0.0
	if canonical.damage_components.size() == 1:
		expected_type = canonical.damage_components[0].damage_type_id
		expected_amount = canonical.damage_components[0].base_amount
	TestAssertions.equal(StringName(row.get("type", &"")), expected_type, "%s damage type parity" % label, failures)
	TestAssertions.near(float(row.get("amount", NAN)), expected_amount, 0.0001, "%s damage amount parity" % label, failures)

func _assert_attack_definition(actual: AttackDefinition, expected: AttackDefinition, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(actual.id, expected.id, "%s id parity" % label, failures)
	TestAssertions.equal(actual.kind, expected.kind, "%s kind parity" % label, failures)
	TestAssertions.near(actual.power, expected.power, 0.0001, "%s power parity" % label, failures)
	TestAssertions.near(actual.cooldown, expected.cooldown, 0.0001, "%s cooldown parity" % label, failures)
	TestAssertions.near(actual.range, expected.range, 0.0001, "%s range parity" % label, failures)
	TestAssertions.near(actual.projectile_speed, expected.projectile_speed, 0.0001, "%s projectile speed parity" % label, failures)
	TestAssertions.near(actual.area_radius, expected.area_radius, 0.0001, "%s area parity" % label, failures)
	TestAssertions.equal(actual.action_tags, expected.action_tags, "%s exact ordered tag parity" % label, failures)
	TestAssertions.equal(actual.can_crit, expected.can_crit, "%s critical parity" % label, failures)
	TestAssertions.equal(actual.damage_components.size(), expected.damage_components.size(), "%s component count parity" % label, failures)
	for index: int in mini(actual.damage_components.size(), expected.damage_components.size()):
		TestAssertions.equal(actual.damage_components[index].damage_type_id, expected.damage_components[index].damage_type_id, "%s component %d type parity" % [label, index], failures)
		TestAssertions.near(actual.damage_components[index].base_amount, expected.damage_components[index].base_amount, 0.0001, "%s component %d amount parity" % [label, index], failures)

func _assert_stat_catalog(actual: StatCatalog, expected: StatCatalog, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(actual != null, "%s loads" % label, failures)
	TestAssertions.truthy(expected != null, "%s canonical catalog loads" % label, failures)
	if actual == null or expected == null:
		return
	TestAssertions.equal(expected.definitions.size(), CANONICAL_STAT_COUNT, "%s canonical stat count" % label, failures)
	TestAssertions.equal(actual.validate(), PackedStringArray(), "%s validates" % label, failures)
	TestAssertions.equal(_stat_ids(actual), _stat_ids(expected), "%s exact ordered IDs" % label, failures)
	TestAssertions.equal(actual.definitions.size(), expected.definitions.size(), "%s definition count" % label, failures)
	for index: int in mini(actual.definitions.size(), expected.definitions.size()):
		_assert_stat_definition(actual.definitions[index], expected.definitions[index], "%s index %d" % [label, index], failures)

func _assert_stat_definition(actual: StatDefinition, expected: StatDefinition, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(actual != null, "%s exists" % label, failures)
	TestAssertions.truthy(expected != null, "%s canonical definition exists" % label, failures)
	if actual == null or expected == null:
		return
	TestAssertions.equal(actual.id, expected.id, "%s id parity" % label, failures)
	TestAssertions.equal(actual.display_name, expected.display_name, "%s display parity" % label, failures)
	TestAssertions.equal(actual.ui_group, expected.ui_group, "%s group parity" % label, failures)
	TestAssertions.equal(actual.value_format, expected.value_format, "%s format parity" % label, failures)
	TestAssertions.equal(actual.precision, expected.precision, "%s precision parity" % label, failures)
	TestAssertions.near(actual.default_value, expected.default_value, 0.0001, "%s default parity" % label, failures)
	TestAssertions.equal(actual.has_minimum, expected.has_minimum, "%s minimum flag parity" % label, failures)
	TestAssertions.near(actual.minimum, expected.minimum, 0.0001, "%s minimum parity" % label, failures)
	TestAssertions.equal(actual.has_maximum, expected.has_maximum, "%s maximum flag parity" % label, failures)
	TestAssertions.near(actual.maximum, expected.maximum, 0.0001, "%s maximum parity" % label, failures)
	TestAssertions.equal(actual.visibility, expected.visibility, "%s visibility parity" % label, failures)
	TestAssertions.equal(actual.capability_tags, expected.capability_tags, "%s capability parity" % label, failures)
	TestAssertions.equal(actual.keyword_id, expected.keyword_id, "%s keyword parity" % label, failures)
	TestAssertions.equal(actual.comparison_direction, expected.comparison_direction, "%s comparison parity" % label, failures)

func _assert_keyword_rows(rows: Array[Dictionary], canonical: KeywordCatalog, failures: Array[String]) -> void:
	TestAssertions.truthy(canonical != null, "keyword rows canonical catalog loads", failures)
	if canonical == null:
		return
	TestAssertions.equal(canonical.definitions.size(), CANONICAL_KEYWORD_COUNT, "canonical keyword count", failures)
	TestAssertions.equal(rows.size(), canonical.definitions.size(), "keyword source row count", failures)
	var row_ids: Array[StringName] = []
	for row: Dictionary in rows:
		row_ids.append(StringName(row.get("id", &"")))
	TestAssertions.equal(row_ids, _keyword_ids(canonical), "keyword source exact ordered IDs", failures)
	for index: int in mini(rows.size(), canonical.definitions.size()):
		var row: Dictionary = rows[index]
		var expected := canonical.definitions[index]
		TestAssertions.equal(StringName(row.get("id", &"")), expected.id, "keyword row %d id parity" % index, failures)
		TestAssertions.equal(String(row.get("name", "")), expected.display_name, "keyword row %d display parity" % index, failures)
		TestAssertions.equal(String(row.get("explanation", "")), expected.explanation, "keyword row %d explanation parity" % index, failures)
		TestAssertions.equal(bool(row.get("capability", false)), expected.is_capability_tag, "keyword row %d capability parity" % index, failures)

func _assert_keyword_catalog(actual: KeywordCatalog, expected: KeywordCatalog, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(actual != null, "%s loads" % label, failures)
	TestAssertions.truthy(expected != null, "%s canonical catalog loads" % label, failures)
	if actual == null or expected == null:
		return
	TestAssertions.equal(actual.validate(), PackedStringArray(), "%s validates" % label, failures)
	TestAssertions.equal(_keyword_ids(actual), _keyword_ids(expected), "%s exact ordered IDs" % label, failures)
	TestAssertions.equal(actual.definitions.size(), expected.definitions.size(), "%s definition count" % label, failures)
	for index: int in mini(actual.definitions.size(), expected.definitions.size()):
		var actual_definition := actual.definitions[index]
		var expected_definition := expected.definitions[index]
		TestAssertions.truthy(actual_definition != null, "%s index %d exists" % [label, index], failures)
		if actual_definition == null or expected_definition == null:
			continue
		TestAssertions.equal(actual_definition.id, expected_definition.id, "%s index %d id parity" % [label, index], failures)
		TestAssertions.equal(actual_definition.display_name, expected_definition.display_name, "%s index %d display parity" % [label, index], failures)
		TestAssertions.equal(actual_definition.explanation, expected_definition.explanation, "%s index %d explanation parity" % [label, index], failures)
		TestAssertions.equal(actual_definition.is_capability_tag, expected_definition.is_capability_tag, "%s index %d capability parity" % [label, index], failures)

func _stat_ids(catalog: StatCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: StatDefinition in catalog.definitions:
		result.append(definition.id if definition != null else &"")
	return result

func _keyword_ids(catalog: KeywordCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: KeywordDefinition in catalog.definitions:
		result.append(definition.id if definition != null else &"")
	return result

func _canonical_path(relative_path: String) -> String:
	var root := OS.get_environment("PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT").strip_edges().trim_suffix("/")
	return "res://%s" % relative_path if root.is_empty() else root.path_join(relative_path)
