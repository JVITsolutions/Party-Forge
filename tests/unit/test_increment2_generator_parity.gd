extends RefCounted

const TypedCombatMigration := preload("res://tools/migrate_typed_combat_data.gd")
const StatFoundationData := preload("res://tools/create_stat_foundation_data.gd")
const UpgradeRows := preload("res://tools/character_upgrade_content_rows.gd")
const DefaultData := preload("res://tools/create_default_data.gd")
const ExpansionRows := preload("res://tools/class_expansion_rows.gd")

const INCREMENT_2_ATTACK_IDS: Array[StringName] = [
	&"mage_burst",
	&"cleric_bolt",
	&"frost_shard",
	&"warlock_bolt",
]
const INCREMENT_2_STAT_IDS: Array[StringName] = [
	&"melee_damage",
	&"ranged_damage",
	&"caster_damage",
	&"party_influence",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_attack_authoring_parity(failures)
	_test_stat_generator_parity(failures)
	_test_keyword_generator_parity(failures)
	_test_retained_generator_wiring(failures)
	return failures

func _test_attack_authoring_parity(failures: Array[String]) -> void:
	_assert_unique_row_ids(TypedCombatMigration.ROWS, "typed combat migration", failures)
	_assert_unique_row_ids(DefaultData.ATTACK_ROWS, "default attack generator", failures)
	_assert_unique_row_ids(ExpansionRows.ATTACK_ROWS, "class expansion migration", failures)

	_assert_attack_rows(
		TypedCombatMigration.ROWS,
		[&"mage_burst", &"cleric_bolt"],
		"typed combat migration",
		failures,
	)
	_assert_attack_rows(
		DefaultData.ATTACK_ROWS,
		INCREMENT_2_ATTACK_IDS,
		"default attack generator",
		failures,
	)
	_assert_attack_rows(
		ExpansionRows.ATTACK_ROWS,
		[&"frost_shard", &"warlock_bolt"],
		"class expansion migration",
		failures,
	)

func _test_stat_generator_parity(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string("res://tools/create_stat_foundation_data.gd")
	for stat_id: StringName in INCREMENT_2_STAT_IDS:
		TestAssertions.truthy(
			"_stat(&\"%s\"" % stat_id in source,
			"stat foundation generator authors %s" % stat_id,
			failures,
		)
	var exposes_catalog := "static func build_catalog() -> StatCatalog:" in source
	TestAssertions.truthy(exposes_catalog, "stat foundation generator exposes its authored catalog for parity", failures)
	if not exposes_catalog:
		return
	var generated := Callable(StatFoundationData, &"build_catalog").call() as StatCatalog
	TestAssertions.truthy(generated != null, "stat foundation generator builds a catalog", failures)
	if generated == null:
		return
	TestAssertions.equal(generated.validate(), PackedStringArray(), "generated stat catalog validates", failures)
	_assert_unique_stat_ids(generated, failures)
	var canonical := load(_canonical_path("data/stats/core_stats.tres")) as StatCatalog
	TestAssertions.truthy(canonical != null, "canonical stat catalog loads for generator parity", failures)
	if canonical == null:
		return
	var persisted := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(persisted != null, "persisted generated stat catalog loads", failures)
	var generated_increment_ids: Array[StringName] = []
	for definition: StatDefinition in generated.definitions:
		if definition != null and definition.id in INCREMENT_2_STAT_IDS:
			generated_increment_ids.append(definition.id)
	TestAssertions.equal(generated_increment_ids, INCREMENT_2_STAT_IDS, "generated Increment 2 stat order stays canonical", failures)
	for stat_id: StringName in INCREMENT_2_STAT_IDS:
		_assert_stat_definition(
			generated.definition(stat_id),
			canonical.definition(stat_id),
			"generated stat %s" % stat_id,
			failures,
		)
		if persisted != null:
			_assert_stat_definition(
				persisted.definition(stat_id),
				canonical.definition(stat_id),
				"persisted generated stat %s" % stat_id,
				failures,
			)

func _test_keyword_generator_parity(failures: Array[String]) -> void:
	_assert_unique_row_ids(UpgradeRows.KEYWORD_ROWS, "character upgrade keyword generator", failures)
	var canonical := load(_canonical_path("data/keywords/core_keywords.tres")) as KeywordCatalog
	TestAssertions.truthy(canonical != null, "canonical keyword catalog loads for generator parity", failures)
	if canonical == null:
		return
	var persisted := load("res://data/keywords/core_keywords.tres") as KeywordCatalog
	TestAssertions.truthy(persisted != null, "persisted generated keyword catalog loads", failures)
	var generated_increment_ids: Array[StringName] = []
	for row: Dictionary in UpgradeRows.KEYWORD_ROWS:
		var id := StringName(row.get("id", &""))
		if id in INCREMENT_2_STAT_IDS:
			generated_increment_ids.append(id)
	TestAssertions.equal(generated_increment_ids, INCREMENT_2_STAT_IDS, "generated Increment 2 keyword order stays canonical", failures)
	for keyword_id: StringName in INCREMENT_2_STAT_IDS:
		var matches := UpgradeRows.KEYWORD_ROWS.filter(
			func(row: Dictionary) -> bool: return StringName(row.get("id", &"")) == keyword_id
		)
		TestAssertions.equal(matches.size(), 1, "%s has one character-upgrade keyword row" % keyword_id, failures)
		if matches.size() != 1:
			continue
		var canonical_definition := canonical.definition(keyword_id)
		TestAssertions.truthy(canonical_definition != null, "%s canonical keyword exists" % keyword_id, failures)
		if canonical_definition == null:
			continue
		var row: Dictionary = matches[0]
		TestAssertions.equal(StringName(row.get("id", &"")), canonical_definition.id, "%s keyword id parity" % keyword_id, failures)
		TestAssertions.equal(String(row.get("name", "")), canonical_definition.display_name, "%s keyword display parity" % keyword_id, failures)
		TestAssertions.equal(String(row.get("explanation", "")), canonical_definition.explanation, "%s keyword explanation parity" % keyword_id, failures)
		TestAssertions.equal(bool(row.get("capability", false)), canonical_definition.is_capability_tag, "%s keyword capability parity" % keyword_id, failures)
		if persisted != null:
			var persisted_definition := persisted.definition(keyword_id)
			TestAssertions.truthy(persisted_definition != null, "%s persisted generated keyword exists" % keyword_id, failures)
			if persisted_definition != null:
				TestAssertions.equal(persisted_definition.id, canonical_definition.id, "%s persisted keyword id parity" % keyword_id, failures)
				TestAssertions.equal(persisted_definition.display_name, canonical_definition.display_name, "%s persisted keyword display parity" % keyword_id, failures)
				TestAssertions.equal(persisted_definition.explanation, canonical_definition.explanation, "%s persisted keyword explanation parity" % keyword_id, failures)
				TestAssertions.equal(persisted_definition.is_capability_tag, canonical_definition.is_capability_tag, "%s persisted keyword capability parity" % keyword_id, failures)

func _test_retained_generator_wiring(failures: Array[String]) -> void:
	var upgrade_source := FileAccess.get_file_as_string("res://tools/create_character_upgrade_data.gd")
	TestAssertions.truthy("for row: Dictionary in ContentRows.KEYWORD_ROWS" in upgrade_source, "character upgrade generator consumes retained keyword rows", failures)
	TestAssertions.truthy("res://data/keywords/core_keywords.tres" in upgrade_source, "character upgrade generator writes the canonical keyword catalog", failures)
	var default_source := FileAccess.get_file_as_string("res://tools/create_default_data.gd")
	TestAssertions.truthy("CharacterUpgradeData.generate()" in default_source, "default generator invokes the retained keyword generator", failures)
	var expansion_source := FileAccess.get_file_as_string("res://tools/migrate_class_expansion_data.gd")
	TestAssertions.truthy("for row: Dictionary in ExpansionRows.ATTACK_ROWS" in expansion_source, "class expansion migration consumes retained attack rows", failures)

func _assert_attack_rows(rows: Array[Dictionary], attack_ids: Array[StringName], label: String, failures: Array[String]) -> void:
	for attack_id: StringName in attack_ids:
		var matches := rows.filter(func(row: Dictionary) -> bool: return StringName(row.get("id", &"")) == attack_id)
		TestAssertions.equal(matches.size(), 1, "%s authors %s exactly once" % [label, attack_id], failures)
		if matches.size() != 1:
			continue
		var row: Dictionary = matches[0]
		var canonical := load(_canonical_path("data/attacks/%s.tres" % attack_id)) as AttackDefinition
		TestAssertions.truthy(canonical != null, "%s canonical attack loads" % attack_id, failures)
		if canonical == null:
			continue
		var persisted := load("res://data/attacks/%s.tres" % attack_id) as AttackDefinition
		TestAssertions.truthy(persisted != null, "%s persisted generated attack loads" % attack_id, failures)
		if persisted != null:
			_assert_attack_definition(persisted, canonical, "%s persisted %s" % [label, attack_id], failures)
		TestAssertions.equal(StringName(row.get("id", &"")), canonical.id, "%s %s id parity" % [label, attack_id], failures)
		TestAssertions.equal(int(row.get("kind", -1)), int(canonical.kind), "%s %s kind parity" % [label, attack_id], failures)
		TestAssertions.near(float(row.get("power", NAN)), canonical.power, 0.0001, "%s %s power parity" % [label, attack_id], failures)
		TestAssertions.near(float(row.get("cooldown", NAN)), canonical.cooldown, 0.0001, "%s %s cooldown parity" % [label, attack_id], failures)
		TestAssertions.near(float(row.get("range", NAN)), canonical.range, 0.0001, "%s %s range parity" % [label, attack_id], failures)
		TestAssertions.near(float(row.get("speed", NAN)), canonical.projectile_speed, 0.0001, "%s %s projectile speed parity" % [label, attack_id], failures)
		TestAssertions.near(float(row.get("area", NAN)), canonical.area_radius, 0.0001, "%s %s area parity" % [label, attack_id], failures)
		TestAssertions.equal(bool(row.get("crit", false)), canonical.can_crit, "%s %s critical parity" % [label, attack_id], failures)
		var tags: Array[StringName] = []
		tags.assign(row.get("tags", []))
		TestAssertions.equal(tags, canonical.action_tags, "%s %s exact ordered tag parity" % [label, attack_id], failures)
		TestAssertions.equal(tags, canonical.normalized_action_tags(), "%s %s tags remain sorted and unique" % [label, attack_id], failures)
		TestAssertions.equal(canonical.damage_components.size(), 1, "%s canonical attack has one component" % attack_id, failures)
		if canonical.damage_components.size() == 1:
			TestAssertions.equal(StringName(row.get("type", &"")), canonical.damage_components[0].damage_type_id, "%s %s damage type parity" % [label, attack_id], failures)
			TestAssertions.near(float(row.get("amount", NAN)), canonical.damage_components[0].base_amount, 0.0001, "%s %s damage amount parity" % [label, attack_id], failures)

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
	if actual.damage_components.size() == 1 and expected.damage_components.size() == 1:
		TestAssertions.equal(actual.damage_components[0].damage_type_id, expected.damage_components[0].damage_type_id, "%s damage type parity" % label, failures)
		TestAssertions.near(actual.damage_components[0].base_amount, expected.damage_components[0].base_amount, 0.0001, "%s damage amount parity" % label, failures)

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

func _assert_unique_row_ids(rows: Array[Dictionary], label: String, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var id := StringName(row.get("id", &""))
		TestAssertions.truthy(not id.is_empty(), "%s row id is not empty" % label, failures)
		TestAssertions.truthy(not seen.has(id), "%s row id %s is unique" % [label, id], failures)
		seen[id] = true

func _assert_unique_stat_ids(catalog: StatCatalog, failures: Array[String]) -> void:
	var seen: Dictionary = {}
	for definition: StatDefinition in catalog.definitions:
		if definition == null:
			TestAssertions.truthy(false, "generated stat definition is not null", failures)
			continue
		TestAssertions.truthy(not seen.has(definition.id), "generated stat id %s is unique" % definition.id, failures)
		seen[definition.id] = true

func _canonical_path(relative_path: String) -> String:
	var root := OS.get_environment("PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT").strip_edges().trim_suffix("/")
	return "res://%s" % relative_path if root.is_empty() else root.path_join(relative_path)
