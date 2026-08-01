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
	_assert_ranged_enemy_profiles(catalog, failures)
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

func _assert_ranged_enemy_profiles(catalog: GameCatalog, failures: Array[String]) -> void:
	var boltcaster := catalog.enemies.filter(func(definition: EnemyDefinition) -> bool: return definition != null and definition.id == &"boltcaster")
	TestAssertions.equal(boltcaster.size(), 1, "default catalog loads Boltcaster", failures)
	if boltcaster.size() == 1:
		var definition := boltcaster[0] as EnemyDefinition
		TestAssertions.equal(definition.behavior, EnemyDefinition.Behavior.BOLTCASTER, "Boltcaster uses appended behavior", failures)
		TestAssertions.truthy(definition.attack_by_id(&"boltcaster_bolt") != null, "Boltcaster attack resolves", failures)
		TestAssertions.truthy(definition.projectile_profile != null, "Boltcaster profile resolves", failures)
		if definition.projectile_profile != null:
			TestAssertions.equal(definition.projectile_profile.movement, EnemyProjectileProfile.Movement.LINEAR, "Boltcaster projectile is linear", failures)
			TestAssertions.equal(definition.projectile_profile.color, Color(1.0, 0.08, 0.05, 1.0), "Boltcaster projectile is red", failures)
			TestAssertions.near(definition.projectile_profile.tell_duration, 0.35, 0.001, "Boltcaster tell lasts 0.35 seconds", failures)
	var spitter := catalog.enemies.filter(func(definition: EnemyDefinition) -> bool: return definition != null and definition.id == &"spitter")
	TestAssertions.equal(spitter.size(), 1, "default catalog loads Spitter", failures)
	if spitter.size() == 1:
		var definition := spitter[0] as EnemyDefinition
		TestAssertions.truthy(definition.projectile_profile != null, "Spitter profile resolves", failures)
		if definition.projectile_profile != null:
			TestAssertions.equal(definition.projectile_profile.movement, EnemyProjectileProfile.Movement.HOMING, "Spitter projectile is homing", failures)
			TestAssertions.equal(definition.projectile_profile.color, Color(0.75, 0.15, 1.0, 1.0), "Spitter projectile is purple", failures)

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
