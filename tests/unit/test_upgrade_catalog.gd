extends RefCounted

const CARD_ROWS: Array[Dictionary] = [
	{"id": &"hold_the_line", "name": "Hold the Line", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"fighter"], "summary": "Stand firm with greater health and armor.", "effects": [[&"max_health", StatModifier.Operation.INCREASED, 0.20, [], []], [&"armor", StatModifier.Operation.FLAT, 5.0, [], []]]},
	{"id": &"quickdraw", "name": "Quickdraw", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"ranger"], "summary": "Loose faster arrows with greater projectile velocity.", "effects": [[&"attack_speed", StatModifier.Operation.INCREASED, 0.20, [], []], [&"projectile_speed", StatModifier.Operation.INCREASED, 0.25, [], []]]},
	{"id": &"living_flame", "name": "Living Flame", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"mage"], "summary": "Intensify fire magic and expanding blasts.", "effects": [[&"fire_damage", StatModifier.Operation.INCREASED, 0.25, [], []], [&"area_size", StatModifier.Operation.INCREASED, 0.20, [], []]]},
	{"id": &"sacred_conduit", "name": "Sacred Conduit", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"cleric"], "summary": "Channel stronger healing and lightning.", "effects": [[&"healing_power", StatModifier.Operation.INCREASED, 0.25, [], []], [&"lightning_damage", StatModifier.Operation.INCREASED, 0.25, [], []]]},
	{"id": &"consecrated_bulwark", "name": "Consecrated Bulwark", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"paladin"], "summary": "Block more attacks and recover health steadily.", "effects": [[&"block_chance", StatModifier.Operation.FLAT, 0.10, [], []], [&"health_regeneration", StatModifier.Operation.FLAT, 1.5, [], []]]},
	{"id": &"cutthroat_instinct", "name": "Cutthroat Instinct", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"rogue"], "summary": "Strike critically and steal life from wounded foes.", "effects": [[&"crit_chance", StatModifier.Operation.FLAT, 0.10, [], []], [&"crit_multiplier", StatModifier.Operation.FLAT, 0.25, [], []], [&"life_steal", StatModifier.Operation.FLAT, 0.05, [], []]]},
	{"id": &"heart_of_winter", "name": "Heart of Winter", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"frost_mage"], "summary": "Deepen cold magic and widen frozen bursts.", "effects": [[&"cold_damage", StatModifier.Operation.INCREASED, 0.25, [], []], [&"area_size", StatModifier.Operation.INCREASED, 0.20, [], []]]},
	{"id": &"blood_covenant", "name": "Blood Covenant", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"warlock"], "summary": "Trade vitality for chaos power and life steal.", "effects": [[&"chaos_damage", StatModifier.Operation.INCREASED, 0.30, [], []], [&"life_steal", StatModifier.Operation.FLAT, 0.08, [], []], [&"max_health", StatModifier.Operation.REDUCED, 0.15, [], []]]},
	{"id": &"deadeye", "name": "Deadeye", "scope": UpgradeDefinition.Scope.CLASS_SPECIFIC, "max": 1, "classes": [&"marksman"], "summary": "Trade attack speed for devastating long-range physical shots.", "effects": [[&"physical_damage", StatModifier.Operation.MORE, 0.30, [], []], [&"attack_range", StatModifier.Operation.INCREASED, 0.20, [], []], [&"crit_multiplier", StatModifier.Operation.FLAT, 0.25, [], []], [&"attack_speed", StatModifier.Operation.LESS, 0.15, [], []]]},
	{"id": &"martial_training", "name": "Martial Training", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"martial"], "summary": "Reinforce martial offense and armor.", "effects": [[&"physical_damage", StatModifier.Operation.INCREASED, 0.08, [], []], [&"armor", StatModifier.Operation.FLAT, 1.0, [], []]]},
	{"id": &"ranged_calibration", "name": "Ranged Calibration", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"ranged"], "summary": "Extend range and accelerate projectiles.", "effects": [[&"attack_range", StatModifier.Operation.INCREASED, 0.10, [], []], [&"projectile_speed", StatModifier.Operation.INCREASED, 0.10, [], []]]},
	{"id": &"caster_discipline", "name": "Caster Discipline", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"caster"], "summary": "Cast harder and faster.", "effects": [[&"damage", StatModifier.Operation.INCREASED, 0.08, [], []], [&"attack_speed", StatModifier.Operation.INCREASED, 0.08, [], []]]},
	{"id": &"skirmishers_rhythm", "name": "Skirmisher's Rhythm", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"skirmisher"], "summary": "Evade attacks while moving more quickly.", "effects": [[&"dodge_chance", StatModifier.Operation.FLAT, 0.04, [], []], [&"move_speed", StatModifier.Operation.INCREASED, 0.05, [], []]]},
	{"id": &"projectile_mastery", "name": "Projectile Mastery", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"projectile"], "summary": "Empower projectiles and the attacks that launch them.", "effects": [[&"projectile_speed", StatModifier.Operation.INCREASED, 0.12, [], []], [&"damage", StatModifier.Operation.INCREASED, 0.08, [], [&"projectile"]]]},
	{"id": &"expanding_power", "name": "Expanding Power", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "all": [&"area"], "summary": "Enlarge area effects and their damage.", "effects": [[&"area_size", StatModifier.Operation.INCREASED, 0.10, [], []], [&"damage", StatModifier.Operation.INCREASED, 0.08, [], [&"area"]]]},
	{"id": &"elemental_attunement", "name": "Elemental Attunement", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 3, "any": [&"fire", &"cold", &"lightning", &"chaos"], "summary": "Strengthen every element the character can wield.", "effects": [[&"fire_damage", StatModifier.Operation.INCREASED, 0.12, [&"fire"], []], [&"cold_damage", StatModifier.Operation.INCREASED, 0.12, [&"cold"], []], [&"lightning_damage", StatModifier.Operation.INCREASED, 0.12, [&"lightning"], []], [&"chaos_damage", StatModifier.Operation.INCREASED, 0.12, [&"chaos"], []]]},
	{"id": &"vanguard_wall", "name": "Vanguard Wall", "scope": UpgradeDefinition.Scope.TRAIT, "max": 1, "all": [&"vanguard"], "summary": "Fortify every Vanguard, including later recruits.", "effects": [[&"armor", StatModifier.Operation.FLAT, 3.0, [], []], [&"max_health", StatModifier.Operation.INCREASED, 0.10, [], []]]},
	{"id": &"arcane_convergence", "name": "Arcane Convergence", "scope": UpgradeDefinition.Scope.TRAIT, "max": 1, "all": [&"arcane"], "summary": "Expand and empower every Arcane member's elements, including later recruits.", "effects": [[&"area_size", StatModifier.Operation.INCREASED, 0.12, [], []], [&"fire_damage", StatModifier.Operation.INCREASED, 0.10, [&"fire"], []], [&"cold_damage", StatModifier.Operation.INCREASED, 0.10, [&"cold"], []], [&"lightning_damage", StatModifier.Operation.INCREASED, 0.10, [&"lightning"], []], [&"chaos_damage", StatModifier.Operation.INCREASED, 0.10, [&"chaos"], []]]},
	{"id": &"divine_covenant", "name": "Divine Covenant", "scope": UpgradeDefinition.Scope.TRAIT, "max": 1, "all": [&"divine"], "summary": "Improve healing and regeneration for every Divine member, including later recruits.", "effects": [[&"healing_power", StatModifier.Operation.INCREASED, 0.15, [], []], [&"health_regeneration", StatModifier.Operation.FLAT, 1.0, [], []]]},
	{"id": &"vitality", "name": "Vitality", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Build greater maximum health.", "effects": [[&"max_health", StatModifier.Operation.INCREASED, 0.08, [], []]]},
	{"id": &"tempered_armor", "name": "Tempered Armor", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Add reliable armor.", "effects": [[&"armor", StatModifier.Operation.FLAT, 2.0, [], []]]},
	{"id": &"ferocity", "name": "Ferocity", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Deal greater damage.", "effects": [[&"damage", StatModifier.Operation.INCREASED, 0.08, [], []]]},
	{"id": &"alacrity", "name": "Alacrity", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Attack more quickly.", "effects": [[&"attack_speed", StatModifier.Operation.INCREASED, 0.06, [], []]]},
	{"id": &"fleetfoot", "name": "Fleetfoot", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Move more quickly.", "effects": [[&"move_speed", StatModifier.Operation.INCREASED, 0.05, [], []]]},
	{"id": &"precision", "name": "Precision", "scope": UpgradeDefinition.Scope.CHARACTER, "max": 5, "summary": "Gain critical strike chance.", "effects": [[&"crit_chance", StatModifier.Operation.FLAT, 0.03, [], []]]},
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	_assert_distribution(catalog, failures)
	_assert_authored_rows(catalog, failures)
	_assert_keywords(catalog, failures)
	_assert_invalid_definitions(failures)
	_assert_required_and_optional_loading(failures)
	return failures

func _assert_distribution(catalog: GameCatalog, failures: Array[String]) -> void:
	TestAssertions.equal(catalog.upgrades.size(), 25, "twenty-five authored upgrades", failures)
	TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC).size(), 9, "nine signatures", failures)
	TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CHARACTER and (not card.required_any_tags.is_empty() or not card.required_all_tags.is_empty())).size(), 7, "seven shared character cards", failures)
	TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.TRAIT).size(), 3, "three matching-party synergies", failures)
	TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CHARACTER and card.required_any_tags.is_empty() and card.required_all_tags.is_empty()).size(), 6, "six universal character cards", failures)
	for class_definition: ClassDefinition in catalog.classes:
		TestAssertions.equal(catalog.upgrades.filter(func(card: UpgradeDefinition) -> bool: return card.scope == UpgradeDefinition.Scope.CLASS_SPECIFIC and class_definition.id in card.allowed_class_ids).size(), 1, "%s has one signature" % class_definition.id, failures)
	TestAssertions.equal(catalog.upgrade_by_id(&"deadeye").max_rank, 1, "Deadeye one-time", failures)
	TestAssertions.near((catalog.upgrade_by_id(&"deadeye").effects[0] as StatUpgradeEffect).value_for_rank(1), 0.30, 0.001, "Deadeye thirty percent more", failures)
	TestAssertions.equal(catalog.keywords.validate().size(), 0, "keywords validate", failures)
	TestAssertions.equal(catalog.generic_name_pool.names.size(), 12, "generic fallback count", failures)
	TestAssertions.equal(catalog.validate().size(), 0, "expanded catalog validates", failures)
	TestAssertions.equal(catalog.upgrades.all(func(card: UpgradeDefinition) -> bool: return card.rarity == UpgradeDefinition.Rarity.COMMON), true, "reserved rarity is inert common metadata", failures)

func _assert_authored_rows(catalog: GameCatalog, failures: Array[String]) -> void:
	for row: Dictionary in CARD_ROWS:
		var card := catalog.upgrade_by_id(row["id"])
		TestAssertions.truthy(card != null, "upgrade %s loads" % row["id"], failures)
		if card == null:
			continue
		TestAssertions.equal(card.display_name, row["name"], "%s display name" % card.id, failures)
		TestAssertions.equal(card.summary, row["summary"], "%s summary" % card.id, failures)
		TestAssertions.equal(card.description, row["summary"], "%s description mirrors narrative" % card.id, failures)
		TestAssertions.equal(card.scope, row["scope"], "%s scope" % card.id, failures)
		TestAssertions.equal(card.max_rank, row["max"], "%s maximum rank" % card.id, failures)
		TestAssertions.near(card.selection_weight, 1.0, 0.001, "%s selection weight" % card.id, failures)
		TestAssertions.equal(card.allowed_class_ids, row.get("classes", []), "%s allowed classes" % card.id, failures)
		TestAssertions.equal(card.required_all_tags, row.get("all", []), "%s required-all tags" % card.id, failures)
		TestAssertions.equal(card.required_any_tags, row.get("any", []), "%s required-any tags" % card.id, failures)
		var expected_effects: Array = row["effects"]
		TestAssertions.equal(card.effects.size(), expected_effects.size(), "%s effect count" % card.id, failures)
		for index: int in mini(card.effects.size(), expected_effects.size()):
			var effect := card.effects[index] as StatUpgradeEffect
			var expected: Array = expected_effects[index]
			TestAssertions.truthy(effect != null, "%s effect %d is stat effect" % [card.id, index], failures)
			if effect == null:
				continue
			TestAssertions.equal(effect.stat_id, expected[0], "%s effect %d stat" % [card.id, index], failures)
			TestAssertions.equal(effect.operation, expected[1], "%s effect %d operation" % [card.id, index], failures)
			TestAssertions.near(effect.value_per_rank, expected[2], 0.001, "%s effect %d value" % [card.id, index], failures)
			TestAssertions.equal(effect.required_capability_tags, expected[3], "%s effect %d capability gate" % [card.id, index], failures)
			TestAssertions.equal(effect.required_action_tags, expected[4], "%s effect %d action gate" % [card.id, index], failures)

func _assert_keywords(catalog: GameCatalog, failures: Array[String]) -> void:
	var required_ids: Array[StringName] = [&"increased", &"reduced", &"more", &"less"]
	for definition: StatDefinition in GameCatalog.STAT_CATALOG.definitions:
		required_ids.append(definition.keyword_id)
	for definition: DamageTypeDefinition in catalog.damage_types.definitions:
		required_ids.append(definition.keyword_id)
	for definition: ClassDefinition in catalog.classes:
		required_ids.append_array(definition.normalized_eligibility_tags())
	for definition: TraitDefinition in catalog.traits:
		required_ids.append(definition.id)
	for id: StringName in required_ids:
		var keyword := catalog.keywords.definition(id)
		TestAssertions.truthy(keyword != null, "keyword %s resolves" % id, failures)
		if keyword != null:
			TestAssertions.truthy(not keyword.explanation.strip_edges().is_empty(), "keyword %s explains itself" % id, failures)

func _assert_invalid_definitions(failures: Array[String]) -> void:
	var invalid_cards: Array[UpgradeDefinition] = []
	invalid_cards.append(_card(&"", "Empty ID", "Summary", [&"armor"], [_effect(&"armor")]))
	invalid_cards.append(_card(&"duplicate", "Duplicate A", "Summary", [&"armor"], [_effect(&"armor")]))
	invalid_cards.append(_card(&"duplicate", "Duplicate B", "Summary", [&"armor"], [_effect(&"armor")]))
	invalid_cards.append(_card(&"missing_summary", "Missing Summary", "", [&"armor"], [_effect(&"armor")]))
	invalid_cards.append(_card(&"missing_keywords", "Missing Keywords", "Summary", [], [_effect(&"armor")]))
	invalid_cards.append(_card(&"unknown_keyword", "Unknown Keyword", "Summary", [&"void_keyword"], [_effect(&"armor")]))
	invalid_cards.append(_card(&"unknown_stat", "Unknown Stat", "Summary", [&"armor"], [_effect(&"void_stat")]))
	var unknown_class := _card(&"unknown_class", "Unknown Class", "Summary", [&"armor"], [_effect(&"armor")])
	unknown_class.scope = UpgradeDefinition.Scope.CLASS_SPECIFIC
	unknown_class.allowed_class_ids = [&"void_class"]
	invalid_cards.append(unknown_class)
	var unknown_tag := _card(&"unknown_tag", "Unknown Tag", "Summary", [&"armor"], [_effect(&"armor")])
	unknown_tag.required_all_tags = [&"void_tag"]
	invalid_cards.append(unknown_tag)
	var contradictory := _card(&"contradictory", "Contradictory", "Summary", [&"armor"], [_effect(&"armor")])
	contradictory.required_all_tags = [&"martial"]
	contradictory.excluded_tags = [&"martial"]
	invalid_cards.append(contradictory)
	var invalid_rank := _card(&"invalid_rank", "Invalid Rank", "Summary", [&"armor"], [_effect(&"armor")])
	invalid_rank.max_rank = 0
	invalid_cards.append(invalid_rank)
	var invalid_weight := _card(&"invalid_weight", "Invalid Weight", "Summary", [&"armor"], [_effect(&"armor")])
	invalid_weight.selection_weight = 0.0
	invalid_cards.append(invalid_weight)
	var nonfinite_weight := _card(&"nonfinite_weight", "Nonfinite Weight", "Summary", [&"armor"], [_effect(&"armor")])
	nonfinite_weight.selection_weight = NAN
	invalid_cards.append(nonfinite_weight)
	var unsupported_type := _card(&"unsupported_type", "Unsupported Type", "Summary", [&"armor"], [UpgradeEffectDefinition.new()])
	unsupported_type.effects[0].effect_type = 99
	invalid_cards.append(unsupported_type)
	var unsupported_operation := _card(&"unsupported_operation", "Unsupported Operation", "Summary", [&"armor"], [_effect(&"armor")])
	(unsupported_operation.effects[0] as StatUpgradeEffect).operation = 99
	invalid_cards.append(unsupported_operation)
	var nonfinite_value := _card(&"nonfinite_value", "Nonfinite Value", "Summary", [&"armor"], [_effect(&"armor")])
	(nonfinite_value.effects[0] as StatUpgradeEffect).value_per_rank = INF
	invalid_cards.append(nonfinite_value)
	var catalog := GameCatalog.load_defaults()
	catalog.upgrades = invalid_cards
	var errors := catalog.validate()
	TestAssertions.truthy(errors.size() >= invalid_cards.size(), "invalid upgrades report diagnostics", failures)
	for error: String in errors:
		if error.begins_with("PARTY_FORGE_UPGRADE_ERROR"):
			TestAssertions.truthy(error.contains(" path="), "upgrade error includes path: %s" % error, failures)
			TestAssertions.truthy(error.contains(" reason="), "upgrade error includes reason: %s" % error, failures)
	for id: StringName in [&"<empty>", &"duplicate", &"missing_summary", &"missing_keywords", &"unknown_keyword", &"unknown_stat", &"unknown_class", &"unknown_tag", &"contradictory", &"invalid_rank", &"invalid_weight", &"nonfinite_weight", &"unsupported_type", &"unsupported_operation", &"nonfinite_value"]:
		TestAssertions.truthy(_has_error_prefix(errors, "PARTY_FORGE_UPGRADE_ERROR id=%s path=" % id), "%s has structured upgrade error" % id, failures)

func _assert_required_and_optional_loading(failures: Array[String]) -> void:
	var required_fixture := GameCatalog.load_with_upgrade_paths(
		PackedStringArray(["res://data/upgrades/cards/vitality.tres", "res://data/upgrades/cards/required_missing.tres"]),
		PackedStringArray(),
	)
	TestAssertions.truthy(_contains_error(required_fixture.validate(), "PARTY_FORGE_UPGRADE_ERROR id=<missing> path=res://data/upgrades/cards/required_missing.tres reason=required resource failed to load"), "missing required upgrade blocks validation", failures)
	var optional_fixture := GameCatalog.load_with_upgrade_paths(
		PackedStringArray(["res://data/upgrades/cards/vitality.tres"]),
		PackedStringArray(["res://data/upgrades/cards/optional_missing.tres"]),
	)
	TestAssertions.equal(optional_fixture.upgrades.size(), 1, "missing optional upgrade is excluded", failures)
	TestAssertions.equal(optional_fixture.validate(), PackedStringArray(), "missing optional upgrade is safe", failures)

func _card(id: StringName, display_name: String, summary: String, keywords: Array[StringName], effects: Array[UpgradeEffectDefinition]) -> UpgradeDefinition:
	var card := UpgradeDefinition.new()
	card.id = id
	card.display_name = display_name
	card.summary = summary
	card.description = summary
	card.tooltip_keyword_ids = keywords
	card.effects = effects
	return card

func _effect(stat_id: StringName) -> StatUpgradeEffect:
	var effect := StatUpgradeEffect.new()
	effect.stat_id = stat_id
	effect.value_per_rank = 1.0
	effect.source_label = "Fixture"
	return effect

func _contains_error(errors: PackedStringArray, expected: String) -> bool:
	for error: String in errors:
		if error == expected:
			return true
	return false

func _has_error_prefix(errors: PackedStringArray, expected_prefix: String) -> bool:
	for error: String in errors:
		if error.begins_with(expected_prefix):
			return true
	return false
