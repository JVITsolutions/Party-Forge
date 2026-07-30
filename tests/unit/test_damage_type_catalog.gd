extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var game := GameCatalog.load_defaults()
	var types := game.damage_types
	TestAssertions.truthy(types != null, "damage catalog loads", failures)
	if types == null:
		return failures
	TestAssertions.equal(types.validate(PartyManager.STAT_CATALOG), PackedStringArray(), "damage catalog validates", failures)
	TestAssertions.equal(types.all().map(func(entry: DamageTypeDefinition) -> StringName: return entry.id), [&"physical", &"fire", &"cold", &"lightning", &"chaos"], "damage type order", failures)
	TestAssertions.equal(types.definition(&"physical").mitigation_rule, DamageTypeDefinition.MitigationRule.ARMOR, "physical uses armor", failures)
	TestAssertions.equal(types.definition(&"fire").defense_stat_id, &"fire_resistance", "fire resistance mapping", failures)

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
