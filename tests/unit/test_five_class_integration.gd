extends RefCounted

const IDS: Array[StringName] = [
	&"fighter", &"ranger", &"mage", &"cleric", &"paladin",
	&"rogue", &"frost_mage", &"warlock", &"marksman",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "final catalog validates", failures)
	for class_id: StringName in IDS:
		var definition := catalog.class_by_id(class_id)
		TestAssertions.truthy(definition != null, "%s registered" % class_id, failures)
		if definition == null:
			continue
		var party := PartyManager.new()
		party.initialize(definition, catalog.traits)
		party.configure_combat(CombatRng.new(1337), catalog.damage_types)
		var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
		actor.configure(party.members[0])
		actor.configure_combat(party)
		TestAssertions.equal(actor.member_state.class_definition.id, class_id, "%s actor configures" % class_id, failures)
		var attack := definition.primary_attack
		var source := actor.get_combat_adapter(DamageResolver.action_tags_for(attack))
		var prepared := DamageResolver.prepare(
			attack,
			source,
			party.combat_rng,
			catalog.damage_types,
		)
		TestAssertions.truthy(prepared.valid, "%s attack prepares" % class_id, failures)
		actor.free()
		party.free()
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
	main.call("_ready")
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	TestAssertions.equal(selector.grid.get_child_count(), 9, "main selector owns nine buttons", failures)
	main.free()
	return failures
