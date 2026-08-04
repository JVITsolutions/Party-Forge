extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    _test_effective_capacity(failures)
    _test_hud_summary_at_developer_capacity(failures)
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.configure_identity(1337, catalog.generic_name_pool)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal(party.members.size(), 1, "leader occupies one slot", failures)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "duplicate fighter recruits", failures)
    TestAssertions.truthy(not party.members[0].character_name.is_empty(), "leader receives a stored name", failures)
    TestAssertions.truthy(party.members[1].character_name != party.members[0].character_name, "duplicate class recruit avoids the used name", failures)
    var repeated_party := PartyManager.new()
    repeated_party.configure_identity(1337, catalog.generic_name_pool)
    repeated_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    repeated_party.recruit(catalog.class_by_id(&"fighter"))
    TestAssertions.equal(repeated_party.members[0].character_name, party.members[0].character_name, "leader identity is deterministic", failures)
    TestAssertions.equal(repeated_party.members[1].character_name, party.members[1].character_name, "recruit identity is deterministic", failures)
    repeated_party.free()
    TestAssertions.equal(party.trait_count(&"martial"), 2, "duplicate counts for martial", failures)
    TestAssertions.equal(party.active_tier(&"vanguard"), 2, "vanguard tier two", failures)
    party.recruit(catalog.class_by_id(&"ranger"))
    party.recruit(catalog.class_by_id(&"ranger"))
    TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"cleric")), "fifth member rejected", failures)
    party.rank_up(&"fighter")
    TestAssertions.equal(party.get_class_rank(&"fighter"), 2, "shared fighter rank", failures)
    TestAssertions.equal(party.active_tier(&"ranged"), 2, "duplicate rangers overlap", failures)
    party.free()

    var legacy_definition := ClassDefinition.new()
    legacy_definition.id = &"legacy_fixture"
    var legacy_party := PartyManager.new()
    var no_traits: Array[TraitDefinition] = []
    legacy_party.initialize(legacy_definition, no_traits)
    TestAssertions.equal(legacy_party.members[0].character_name, "", "unconfigured legacy party with no pools stays unnamed", failures)
    legacy_party.free()

    var five_stack_trait := TraitDefinition.new()
    five_stack_trait.id = &"martial"
    five_stack_trait.tiers = {5: 0.5}
    var five_stack_traits: Array[TraitDefinition] = [five_stack_trait]
    var extended_party := PartyManager.new()
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    extended_party.initialize(fighter, five_stack_traits)
    for member_id: int in range(2, 6):
        extended_party.members.append(PartyMemberState.new(member_id, fighter, false))
    extended_party.call("_recalculate_traits")
    TestAssertions.equal(extended_party.trait_count(&"martial"), 5, "trait count iterates beyond ordinary cap", failures)
    TestAssertions.equal(extended_party.active_tier(&"martial"), 5, "trait tier supports threshold above four", failures)
    extended_party.free()

    _test_resolved_party_stats(failures)
    _test_replace_member_source(failures)
    _test_party_actor_stats_signal_lifecycle(failures)
    return failures

func _test_effective_capacity(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    for method_name: StringName in [&"configure_capacity", &"capacity", &"can_recruit"]:
        TestAssertions.truthy(party.has_method(method_name), "party manager exposes %s" % method_name, failures)
    if not party.has_method(&"configure_capacity") or not party.has_method(&"capacity") or not party.has_method(&"can_recruit"):
        party.free()
        return

    TestAssertions.equal(int(party.call("capacity")), PartyManager.MAX_PARTY_SIZE, "unconfigured party uses production capacity", failures)
    party.call("configure_capacity", PartyCapacityPolicy.new(1))
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal(int(party.call("capacity")), 1, "capacity policy can reserve only the leader slot", failures)
    TestAssertions.truthy(not bool(party.call("can_recruit")), "capacity-one party cannot recruit", failures)
    TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"fighter")), "capacity-one party rejects member two", failures)
    party.call("configure_capacity", null)
    TestAssertions.equal(int(party.call("capacity")), PartyManager.MAX_PARTY_SIZE, "null capacity policy restores production default", failures)
    party.free()

    var developer_party := PartyManager.new()
    developer_party.call("configure_capacity", PartyCapacityPolicy.new(24))
    developer_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(bool(developer_party.call("can_recruit", 23)), "developer capacity reserves all remaining slots", failures)
    for index: int in range(23):
        TestAssertions.truthy(developer_party.recruit(catalog.class_by_id(&"fighter")), "developer capacity accepts member %d" % (index + 2), failures)
    TestAssertions.equal(developer_party.members.size(), 24, "party reaches developer ceiling", failures)
    TestAssertions.truthy(not bool(developer_party.call("can_recruit")), "full developer party reports no recruit slot", failures)
    TestAssertions.truthy(not developer_party.recruit(catalog.class_by_id(&"fighter")), "member 25 is rejected", failures)
    developer_party.free()

func _test_hud_summary_at_developer_capacity(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    if not party.has_method(&"configure_capacity"):
        party.free()
        return
    party.call("configure_capacity", PartyCapacityPolicy.new(24))
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    for index: int in range(23):
        party.recruit(catalog.class_by_id(&"fighter"))
    var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
    hud.call("configure", null, party, null)
    hud.call("_refresh_party")
    var entries := hud.get_node("Margin/Status/PartyEntries") as VBoxContainer
    TestAssertions.equal(entries.get_child_count(), 4, "developer party keeps the existing four-entry HUD summary", failures)
    TestAssertions.truthy(not (entries.get_node("Party4") as Label).text.is_empty(), "fourth HUD summary entry remains readable", failures)
    hud.free()
    party.free()

func _test_resolved_party_stats(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var fighter := catalog.class_by_id(&"fighter")
    var party := PartyManager.new()
    party.initialize(fighter, catalog.traits)
    var leader_id := party.members[0].member_id
    TestAssertions.truthy(party.upgrade_party_stat(&"max_health"), "health stat upgrade succeeds", failures)
    TestAssertions.truthy(party.upgrade_party_stat(&"move_speed"), "movement stat upgrade succeeds", failures)
    var leader_stats := party.stats_for(leader_id)
    TestAssertions.near(leader_stats.value(&"max_health"), 273.0, 0.001, "health upgrade resolves from class base", failures)
    TestAssertions.near(leader_stats.value(&"move_speed"), 6.39, 0.001, "movement upgrade resolves and rounds from class base", failures)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "recruit succeeds after snapshot", failures)
    TestAssertions.equal(party.members[0].member_id, leader_id, "recruitment preserves leader identity", failures)
    TestAssertions.equal(party.stats_for(leader_id).value(&"max_health"), 273.0, "recruitment preserves leader snapshot value", failures)
    party.free()

func _test_replace_member_source(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var member_id := party.members[0].member_id
    TestAssertions.truthy(party.has_method(&"replace_member_source"), "party manager exposes replace_member_source", failures)
    if not party.has_method(&"replace_member_source"):
        party.free()
        return

    var changed: Array[int] = []
    party.stats_changed.connect(func(changed_member_id: int) -> void: changed.append(changed_member_id))
    var source_id := &"character_growth_1"
    var first := StatModifierSource.create(source_id, &"character_growth", "Class Growth", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, source_id, "Class Growth"),
    ])
    TestAssertions.truthy(bool(party.call(&"replace_member_source", member_id, first)), "first stable source succeeds", failures)
    TestAssertions.equal(changed, [member_id], "successful source replacement emits exactly once", failures)
    TestAssertions.near(party.stats_for(member_id).value(&"strength"), 1.0, 0.001, "first source resolves", failures)

    changed.clear()
    var replacement := StatModifierSource.create(source_id, &"character_growth", "Class Growth", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, 3.0, source_id, "Class Growth"),
    ])
    TestAssertions.truthy(bool(party.call(&"replace_member_source", member_id, replacement)), "same stable source replaces", failures)
    TestAssertions.equal(changed, [member_id], "replacement emits exactly once", failures)
    TestAssertions.near(party.stats_for(member_id).value(&"strength"), 3.0, 0.001, "replacement does not append", failures)
    TestAssertions.equal(party.members[0].modifier_sources.filter(func(source: StatModifierSource) -> bool: return source.id == source_id).size(), 1, "stable source ID remains unique", failures)

    changed.clear()
    var invalid := StatModifierSource.create(source_id, &"character_growth", "Class Growth", member_id, [
        StatModifier.create(&"unknown_attribute", StatModifier.Operation.FLAT, 99.0, source_id, "Class Growth"),
    ])
    TestAssertions.truthy(not bool(party.call(&"replace_member_source", member_id, invalid)), "unknown stat replacement fails", failures)
    TestAssertions.equal(changed, [], "failed replacement emits no stats signal", failures)
    TestAssertions.near(party.stats_for(member_id).value(&"strength"), 3.0, 0.001, "failed replacement preserves resolved values", failures)
    TestAssertions.equal(party.members[0].modifier_sources[0].modifiers[0].stat_id, &"strength", "failed replacement preserves owned source", failures)
    party.free()

func _test_party_actor_stats_signal_lifecycle(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var fighter := catalog.class_by_id(&"fighter")
    var first_party := PartyManager.new()
    first_party.initialize(fighter, catalog.traits)
    var second_party := PartyManager.new()
    second_party.initialize(fighter, catalog.traits)
    var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
    var actor := actor_scene.instantiate() as PartyActor
    actor.configure(first_party.members[0])
    var stats_callback := Callable(actor, "_on_stats_changed")

    actor.configure_combat(first_party)
    TestAssertions.truthy(first_party.stats_changed.is_connected(stats_callback), "actor connects stats signal", failures)
    actor.configure_combat(first_party)
    TestAssertions.equal(first_party.stats_changed.get_connections().size(), 1, "actor does not duplicate stats signal", failures)
    actor.configure_combat(second_party)
    TestAssertions.truthy(not first_party.stats_changed.is_connected(stats_callback), "actor disconnects old stats signal", failures)
    TestAssertions.truthy(second_party.stats_changed.is_connected(stats_callback), "actor connects replacement stats signal", failures)

    actor.free()
    first_party.free()
    second_party.free()
