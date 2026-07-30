extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_same_class_members_keep_distinct_identity_and_cards(failures)
	_test_matching_synergy_reaches_later_recruit(failures)
	_test_tooltip_values_match_resolved_values(failures)
	_test_actual_attack_tags_gate_action_only_damage(failures)
	return failures

func _test_same_class_members_keep_distinct_identity_and_cards(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_identity(2468, catalog.generic_name_pool)
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "second same-class member recruits", failures)
	var first := party.members[0]
	var second := party.members[1]
	TestAssertions.truthy(not first.character_name.is_empty(), "first same-class member has stored name", failures)
	TestAssertions.truthy(not second.character_name.is_empty(), "second same-class member has stored name", failures)
	TestAssertions.truthy(first.character_name != second.character_name, "same-class members keep distinct stored names", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vitality", catalog, party, first.member_id), "first same-class member receives Vitality", failures)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"tempered_armor", catalog, party, second.member_id), "second same-class member receives Tempered Armor", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", first.member_id), 1, "first member owns its exact personal card", failures)
	TestAssertions.equal(party.upgrade_rank(&"vitality", second.member_id), 0, "second member does not inherit first personal card", failures)
	TestAssertions.equal(party.upgrade_rank(&"tempered_armor", first.member_id), 0, "first member does not inherit second personal card", failures)
	TestAssertions.equal(party.upgrade_rank(&"tempered_armor", second.member_id), 1, "second member owns its exact personal card", failures)
	party.free()

func _test_matching_synergy_reaches_later_recruit(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter")
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	TestAssertions.truthy(UpgradeApplicationService.apply(&"vanguard_wall", catalog, party), "matching Vanguard synergy applies", failures)
	TestAssertions.truthy(party.recruit(fighter), "later matching Vanguard recruits", failures)
	var later := party.members[1]
	var resolved := party.stats_for(later.member_id)
	TestAssertions.near(resolved.value(&"armor"), fighter.armor + 3.0, 0.001, "later recruit inherits matching flat armor", failures)
	TestAssertions.near(resolved.value(&"max_health"), fighter.max_health * 1.10, 0.001, "later recruit inherits matching increased health", failures)
	party.free()

func _test_tooltip_values_match_resolved_values(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"marksman"), catalog.traits)
	var member_id := party.members[0].member_id
	var deadeye := catalog.upgrade_by_id(&"deadeye")
	var tooltip := UpgradePresentationService.tooltip(deadeye, 1, PartyManager.STAT_CATALOG, catalog.keywords)
	var lines: Array = tooltip.get("effect_lines", [])
	var before := party.stats_for(member_id)
	TestAssertions.truthy(UpgradeApplicationService.apply(deadeye.id, catalog, party, member_id), "Deadeye applies for resolver comparison", failures)
	var after := party.stats_for(member_id)
	TestAssertions.truthy("30% more Physical Damage." in lines, "tooltip exposes Deadeye multiplicative benefit", failures)
	TestAssertions.truthy("15% less Attack Speed." in lines, "tooltip exposes Deadeye trade-off", failures)
	TestAssertions.truthy("+0.25 Critical Strike Multiplier." in lines, "tooltip exposes Deadeye flat multiplier", failures)
	TestAssertions.near(after.value(&"physical_damage"), before.value(&"physical_damage") * 1.30, 0.001, "tooltip more value equals resolved physical damage", failures)
	TestAssertions.near(after.value(&"attack_range"), before.value(&"attack_range") * 1.20, 0.001, "tooltip increased value equals resolved attack range", failures)
	TestAssertions.near(after.value(&"crit_multiplier"), before.value(&"crit_multiplier") + 0.25, 0.001, "tooltip flat value equals resolved critical multiplier", failures)
	TestAssertions.near(after.value(&"attack_speed"), before.value(&"attack_speed") * 0.85, 0.001, "tooltip less value equals resolved attack speed", failures)
	party.free()

func _test_actual_attack_tags_gate_action_only_damage(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	var member_id := party.members[0].member_id
	TestAssertions.truthy(UpgradeApplicationService.apply(&"projectile_mastery", catalog, party, member_id), "Projectile Mastery applies to Ranger", failures)
	var attack := ranger.primary_attack
	var actual_tags := DamageResolver.action_tags_for(attack)
	TestAssertions.truthy(&"projectile" in actual_tags, "actual Ranger attack carries projectile action tag", failures)
	var actor := (load("res://scenes/characters/companion.tscn") as PackedScene).instantiate() as PartyActor
	actor.configure(party.members[0])
	actor.configure_combat(party)
	var actual_source := actor.get_combat_adapter(actual_tags)
	var packet := DamageResolver.prepare(attack, actual_source, CombatRng.new(7711), catalog.damage_types)
	TestAssertions.truthy(packet.valid, "actual tagged Ranger attack prepares valid damage", failures)
	TestAssertions.equal(packet.action_tags, actual_tags, "prepared packet retains actual attack tags", failures)
	TestAssertions.near(party.stats_for(member_id).value(&"damage"), 1.0, 0.001, "action-only damage stays out of context-free stats", failures)
	TestAssertions.near(actual_source.stat_value(&"damage"), 1.08, 0.001, "actual projectile action activates action-only damage", failures)
	if not packet.components.is_empty():
		TestAssertions.near(packet.components[0].global_scaled, attack.damage_components[0].base_amount * 1.08, 0.001, "prepared damage uses action-gated resolved value", failures)
	actor.free()
	party.free()
