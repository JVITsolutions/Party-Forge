extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const PROFILE_IDS := {
	&"fighter": &"forge_vanguard", &"paladin": &"paladin", &"ranger": &"ranger", &"marksman": &"marksman", &"rogue": &"rogue",
	&"mage": &"mage", &"frost_mage": &"frost_mage", &"cleric": &"cleric", &"warlock": &"warlock",
}
const EQUIPMENT_CAPABILITIES := {
	&"fighter": [&"armour_heavy", &"one_hand_sword", &"shield"],
	&"paladin": [&"armour_heavy", &"one_hand_hammer", &"shield"],
	&"ranger": [&"armour_light", &"armour_medium", &"bow_light_medium"],
	&"marksman": [&"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"],
	&"rogue": [&"armour_light", &"dagger", &"dual_wield"],
	&"mage": [&"armour_light", &"caster_wand", &"caster_focus"],
	&"frost_mage": [&"armour_light", &"caster_staff"],
	&"cleric": [&"armour_light", &"armour_medium", &"divine_sceptre", &"divine_tome"],
	&"warlock": [&"armour_light", &"occult_wand", &"occult_grimoire"],
}
const ATTACK_ACTIONS := {
	&"fighter_cleave": [&"attack_slash", &"impact"],
	&"paladin_smite": [&"paladin_hammer_smite", &"impact"],
	&"ranger_shot": [&"ranger_quick_bow_shot", &"release"],
	&"marksman_heavy_shot": [&"marksman_heavy_bow_shot", &"release"],
	&"rogue_flurry": [&"rogue_dagger_flurry", &"impact"],
	&"mage_burst": [&"mage_fire_burst", &"release"],
	&"frost_shard": [&"frost_staff_shard", &"release"],
	&"cleric_bolt": [&"cleric_lightning_bolt", &"release"],
	&"cleric_heal": [&"cleric_healing_blessing", &"release"],
	&"warlock_bolt": [&"warlock_chaos_bolt", &"release"],
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var definitions: Dictionary = {}
	var all_profiles := true
	for class_path: String in GameCatalog.CLASS_PATHS:
		var definition := load(class_path) as ClassDefinition
		definitions[definition.id] = definition
		TestAssertions.truthy(definition.visual_profile != null, "%s has a real presentation profile" % definition.id, failures)
		all_profiles = all_profiles and definition.visual_profile != null
		for capability: StringName in EQUIPMENT_CAPABILITIES[definition.id]:
			TestAssertions.truthy(capability in definition.capability_tags, "%s capability %s is wired" % [definition.id, capability], failures)
	if not all_profiles: return failures
	_assert_profile_contracts(definitions, failures)
	_assert_actor_activation(definitions, failures)
	_assert_live_release_gate(definitions, failures)
	return failures

func _assert_profile_contracts(definitions: Dictionary, failures: Array[String]) -> void:
	for class_id: StringName in PROFILE_IDS:
		var definition := definitions[class_id] as ClassDefinition
		var profile := definition.visual_profile
		TestAssertions.equal(profile.id, PROFILE_IDS[class_id], "%s profile id" % class_id, failures)
		TestAssertions.equal(profile.presentation_scene.resource_path, "res://scenes/characters/presentation/forge_humanoid_model.tscn", "%s uses reusable humanoid" % class_id, failures)
		TestAssertions.truthy(profile.validate().is_empty(), "%s profile validates" % class_id, failures)
		TestAssertions.truthy(definition.validate(GameCatalog.DAMAGE_TYPES).is_empty(), "%s class and starter loadout validate" % class_id, failures)
		var expected_count := 10 if class_id == &"frost_mage" else 11
		TestAssertions.equal(profile.default_equipment.size(), expected_count, "%s starter slot count" % class_id, failures)
		var loadout: Dictionary = {}
		for entry: EquipmentLoadoutEntry in profile.default_equipment:
			TestAssertions.truthy(entry != null and entry.item != null, "%s starter entry is populated" % class_id, failures)
			if entry == null or entry.item == null: continue
			TestAssertions.truthy(EquipmentEligibility.validate_equip(entry.item, definition, entry.slot_id, loadout).is_empty(), "%s starter %s is eligible" % [class_id, entry.item.id], failures)
			loadout[entry.slot_id] = entry.item
		if class_id == &"frost_mage":
			TestAssertions.truthy(not loadout.has(&"off_hand"), "Frost Mage keeps reserved offhand empty", failures)
		var attacks: Array[AttackDefinition] = [definition.primary_attack]
		if definition.support_action != null: attacks.append(definition.support_action)
		for attack: AttackDefinition in attacks:
			var visual := profile.resolve_attack_presentation(attack.id, profile.default_equipment[-1].item.weapon_family_id if class_id == &"frost_mage" else profile.default_equipment[9].item.weapon_family_id)
			TestAssertions.truthy(visual != null, "%s maps attack %s" % [class_id, attack.id], failures)
			if visual != null:
				TestAssertions.equal([visual.action_id, visual.required_event_name], ATTACK_ACTIONS[attack.id], "%s synchronized action mapping" % attack.id, failures)
				TestAssertions.truthy(visual.validate(attack).is_empty(), "%s presentation timing validates" % attack.id, failures)
	var invalid_frost := (definitions[&"frost_mage"] as ClassDefinition).duplicate() as ClassDefinition
	invalid_frost.visual_profile = invalid_frost.visual_profile.duplicate() as CharacterVisualProfile
	var starter_entries: Array[EquipmentLoadoutEntry] = []
	for original_entry: EquipmentLoadoutEntry in invalid_frost.visual_profile.default_equipment: starter_entries.append(original_entry)
	var forbidden_offhand := EquipmentLoadoutEntry.new()
	forbidden_offhand.slot_id = &"off_hand"
	forbidden_offhand.item = load("res://data/equipment/bases/storm_chaplain/storm_chaplain_holy_tome.tres") as EquipmentBaseDefinition
	starter_entries.append(forbidden_offhand)
	invalid_frost.visual_profile.default_equipment = starter_entries
	var invalid_errors := invalid_frost.validate(GameCatalog.DAMAGE_TYPES)
	var has_reservation_error := false
	for reason: String in invalid_errors:
		if "offhand reserved" in reason: has_reservation_error = true
	TestAssertions.truthy(has_reservation_error, "class validation rejects starter offhand reserved by two-hand staff", failures)

func _assert_actor_activation(definitions: Dictionary, failures: Array[String]) -> void:
	var root := _new_root("PlayableClassPresentationActivationTest")
	for class_id: StringName in PROFILE_IDS:
		for actor_scene: PackedScene in [LEADER_SCENE, COMPANION_SCENE]:
			var actor := actor_scene.instantiate() as PartyActor
			root.add_child(actor)
			actor.configure(PartyMemberState.new(100, definitions[class_id], actor_scene == LEADER_SCENE))
			var presentation := actor.get_node("Presentation") as CharacterPresentation
			var fallback := actor.get_node("MeshInstance3D") as MeshInstance3D
			TestAssertions.truthy(presentation.active_profile != null and presentation.active_profile.id == PROFILE_IDS[class_id], "%s activates on %s" % [class_id, actor.name], failures)
			TestAssertions.truthy(not fallback.visible, "%s hides %s fallback capsule" % [class_id, actor.name], failures)
			TestAssertions.truthy(presentation.set_body_preset(&"masculine") and presentation.set_body_preset(&"feminine"), "%s switches both reusable body presets" % class_id, failures)
			var model := presentation.active_model as ForgeHumanoidModel
			TestAssertions.truthy(model != null, "%s instantiates reusable humanoid model" % class_id, failures)
			if model != null:
				TestAssertions.equal(model.equipped_definitions.size(), 10 if class_id == &"frost_mage" else 11, "%s equipment is applied independently" % class_id, failures)
				TestAssertions.truthy(model.get_node_or_null("FeedbackAnimationPlayer") != null, "%s retains independent hit/flinch layer" % class_id, failures)
			TestAssertions.truthy(actor.get_node_or_null("AttackSequenceController") is AttackSequenceController, "%s uses sequence controller" % class_id, failures)
			var controller := actor.get_node("AttackController") as AttackController
			TestAssertions.truthy(controller.attack_ready.is_connected(Callable(actor, "_on_attack_requested")), "%s primary routes through release gate" % class_id, failures)
			TestAssertions.truthy(not controller.attack_ready.is_connected(Callable(actor.attack_executor, "execute")), "%s has no direct executor bypass" % class_id, failures)
			actor.free()
	root.free()

func _assert_live_release_gate(definitions: Dictionary, failures: Array[String]) -> void:
	var root := _new_root("PlayableClassLiveReleaseGateTest")
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new(); root.add_child(party)
	party.initialize(definitions[&"fighter"], catalog.traits)
	party.call("configure_combat", CombatRng.new(951), catalog.damage_types)
	var fighter := LEADER_SCENE.instantiate() as PartyActor; root.add_child(fighter)
	fighter.configure(party.members[0]); fighter.configure_combat(party, root)
	var hostile := COMPANION_SCENE.instantiate() as PartyActor; hostile.team_id = 2; root.add_child(hostile)
	hostile.configure(PartyMemberState.new(99, definitions[&"fighter"], false)); hostile.position = Vector3(1.0, 0.0, 0.0)
	var hostile_health := hostile.get_node("HealthComponent") as HealthComponent
	var before := hostile_health.current_health
	var combatants: Array[Node3D] = [hostile]
	fighter.attack_executor.call("configure", fighter, party, root, combatants)
	fighter.call("_on_attack_requested", definitions[&"fighter"].primary_attack, hostile.get_combat_target())
	TestAssertions.near(hostile_health.current_health, before, 0.001, "live attack does no damage before authored impact", failures)
	var presentation := fighter.get_node("Presentation") as CharacterPresentation
	presentation.active_model.call("emit_action_event", &"impact")
	TestAssertions.truthy(hostile_health.current_health < before, "live attack damages exactly on authored impact", failures)
	root.free()

func _new_root(root_name: String) -> Node3D:
	var root := Node3D.new(); root.name = root_name
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root
