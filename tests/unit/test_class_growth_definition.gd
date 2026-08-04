extends RefCounted

const EXPECTED_CLASS_IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	for class_id: StringName in EXPECTED_CLASS_IDS:
		var definition := catalog.class_by_id(class_id)
		TestAssertions.truthy(definition != null, "%s class loads" % class_id, failures)
		if definition == null:
			continue
		TestAssertions.truthy(definition.growth_definition != null, "%s growth loads" % class_id, failures)
		if definition.growth_definition == null:
			continue
		TestAssertions.equal(definition.growth_definition.validate(), PackedStringArray(), "%s growth validates" % class_id, failures)
		for level: int in range(2, 14):
			TestAssertions.truthy(
				definition.growth_definition.guaranteed_attribute_for_level(level) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
				"%s level %d guaranteed attribute is core" % [class_id, level], failures,
			)
		TestAssertions.truthy(
			definition.growth_definition.milestone_attribute_for_roll(0.0) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
			"%s first weighted result is core" % class_id, failures,
		)
		TestAssertions.truthy(
			definition.growth_definition.milestone_attribute_for_roll(0.999999) in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS,
			"%s last weighted result is core" % class_id, failures,
		)
	var invalid := ClassGrowthDefinition.new()
	invalid.guaranteed_cycle = [&"damage"]
	invalid.milestone_weights = {&"strength": 0.0}
	TestAssertions.equal(invalid.validate(), PackedStringArray([
		"PARTY_FORGE_GROWTH_ERROR field=guaranteed_cycle value=damage reason=unknown core attribute",
		"PARTY_FORGE_GROWTH_ERROR field=milestone_weights reason=no positive weights",
	]), "invalid growth fails closed", failures)
	return failures
