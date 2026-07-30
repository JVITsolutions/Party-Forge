extends RefCounted

const CLASS_IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	TestAssertions.equal(catalog.classes.size(), 9, "nine playable classes", failures)
	TestAssertions.equal(catalog.traits.size(), 13, "thirteen overlapping traits", failures)
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "expanded catalog validates", failures)
	var actual_ids: Array[StringName] = []
	for definition: ClassDefinition in catalog.classes:
		actual_ids.append(definition.id)
		for trait_id: StringName in definition.traits:
			TestAssertions.truthy(catalog.trait_by_id(trait_id) != null, "%s trait %s resolves" % [definition.id, trait_id], failures)
	TestAssertions.equal(actual_ids, CLASS_IDS, "class order is stable", failures)
	for leader_id: StringName in CLASS_IDS:
		var leader_definition := catalog.class_by_id(leader_id)
		TestAssertions.truthy(leader_definition != null, "%s catalog definition exists" % leader_id, failures)
		if leader_definition == null:
			continue
		var party := PartyManager.new()
		party.initialize(leader_definition, catalog.traits)
		TestAssertions.equal(party.members[0].class_definition.id, leader_id, "%s can lead" % leader_id, failures)
		for recruit_id: StringName in CLASS_IDS:
			var choice := UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, recruit_id, "Recruit")
			TestAssertions.truthy(choice.is_valid_for(party), "%s recruit choice valid" % recruit_id, failures)
		party.free()
	var ranger_definition := catalog.class_by_id(&"ranger")
	var marksman_definition := catalog.class_by_id(&"marksman")
	TestAssertions.truthy(ranger_definition != null, "Ranger comparison definition exists", failures)
	TestAssertions.truthy(marksman_definition != null, "Marksman comparison definition exists", failures)
	if ranger_definition != null and marksman_definition != null:
		var ranger := ranger_definition.primary_attack
		var marksman := marksman_definition.primary_attack
		TestAssertions.truthy(marksman.cooldown > ranger.cooldown, "Marksman attacks slower than Ranger", failures)
		TestAssertions.truthy(marksman.damage_components[0].base_amount > ranger.damage_components[0].base_amount, "Marksman hits harder than Ranger", failures)
		TestAssertions.truthy(marksman.range > ranger.range, "Marksman reaches farther than Ranger", failures)
	_test_missing_trait_reference(catalog, failures)
	return failures

func _test_missing_trait_reference(catalog: GameCatalog, failures: Array[String]) -> void:
	var broken := ClassDefinition.new()
	broken.id = &"broken_trait_class"
	broken.display_name = "Broken Trait Class"
	broken.traits = [&"missing_trait"]
	broken.primary_attack = catalog.class_by_id(&"fighter").primary_attack
	var invalid := GameCatalog.new()
	invalid.damage_types = catalog.damage_types
	invalid.classes = [broken]
	invalid.traits = catalog.traits
	var errors := invalid.validate()
	var found := false
	for error: String in errors:
		if error.contains("class=broken_trait_class trait=missing_trait"):
			found = true
			break
	TestAssertions.truthy(found, "missing class trait has grep-friendly validation", failures)
