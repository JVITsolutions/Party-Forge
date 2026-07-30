extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var game := GameCatalog.load_defaults()
	var types := game.damage_types
	TestAssertions.truthy(types != null, "damage catalog loads", failures)
	if types == null:
		return failures
	TestAssertions.equal(types.validate(PartyManager.STAT_CATALOG), PackedStringArray(), "damage catalog validates", failures)
	var expected: Array[Dictionary] = [
		{"id": &"physical", "display": "Physical", "keyword": &"physical", "offense": &"physical_damage", "defense": &"armor", "rule": DamageTypeDefinition.MitigationRule.ARMOR, "color": Color(0.847059, 0.823529, 0.768627, 1)},
		{"id": &"fire", "display": "Fire", "keyword": &"fire", "offense": &"fire_damage", "defense": &"fire_resistance", "rule": DamageTypeDefinition.MitigationRule.RESISTANCE, "color": Color(1, 0.419608, 0.239216, 1)},
		{"id": &"cold", "display": "Cold", "keyword": &"cold", "offense": &"cold_damage", "defense": &"cold_resistance", "rule": DamageTypeDefinition.MitigationRule.RESISTANCE, "color": Color(0.439216, 0.784314, 1, 1)},
		{"id": &"lightning", "display": "Lightning", "keyword": &"lightning", "offense": &"lightning_damage", "defense": &"lightning_resistance", "rule": DamageTypeDefinition.MitigationRule.RESISTANCE, "color": Color(1, 0.890196, 0.419608, 1)},
		{"id": &"chaos", "display": "Chaos", "keyword": &"chaos", "offense": &"chaos_damage", "defense": &"chaos_resistance", "rule": DamageTypeDefinition.MitigationRule.RESISTANCE, "color": Color(0.709804, 0.423529, 1, 1)},
	]
	var definitions := types.all()
	TestAssertions.equal(definitions.size(), expected.size(), "damage type count", failures)
	for index: int in mini(definitions.size(), expected.size()):
		var definition := definitions[index]
		var row := expected[index]
		TestAssertions.equal(definition.id, row["id"], "damage type %d id and order" % index, failures)
		TestAssertions.equal(definition.display_name, row["display"], "%s display" % row["id"], failures)
		TestAssertions.equal(definition.keyword_id, row["keyword"], "%s keyword" % row["id"], failures)
		TestAssertions.equal(definition.offense_stat_id, row["offense"], "%s offense stat" % row["id"], failures)
		TestAssertions.equal(definition.defense_stat_id, row["defense"], "%s defense stat" % row["id"], failures)
		TestAssertions.equal(definition.mitigation_rule, row["rule"], "%s mitigation" % row["id"], failures)
		TestAssertions.equal(definition.presentation_color, row["color"], "%s color" % row["id"], failures)

	var duplicate := DamageTypeCatalog.new()
	duplicate.definitions = [types.definition(&"fire"), types.definition(&"fire")]
	TestAssertions.truthy(duplicate.validate(PartyManager.STAT_CATALOG).has("PARTY_FORGE_DAMAGE_ERROR type=fire reason=duplicate id"), "duplicate diagnostic", failures)
	var missing := DamageTypeDefinition.new()
	missing.id = &"radiant"
	missing.display_name = "Radiant"
	missing.keyword_id = &"radiant"
	missing.offense_stat_id = &"missing_damage"
	missing.defense_stat_id = &"missing_resistance"
	missing.mitigation_rule = DamageTypeDefinition.MitigationRule.RESISTANCE
	var custom := DamageTypeCatalog.new()
	custom.definitions = [missing]
	TestAssertions.equal(custom.validate(PartyManager.STAT_CATALOG), PackedStringArray([
		"PARTY_FORGE_DAMAGE_ERROR type=radiant stat=missing_damage reason=unknown offense stat",
		"PARTY_FORGE_DAMAGE_ERROR type=radiant stat=missing_resistance reason=unknown defense stat",
	]), "missing stat diagnostics", failures)
	return failures
