extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal(party.members.size(), 1, "leader occupies one slot", failures)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "duplicate fighter recruits", failures)
    TestAssertions.equal(party.trait_count(&"martial"), 2, "duplicate counts for martial", failures)
    TestAssertions.equal(party.active_tier(&"vanguard"), 2, "vanguard tier two", failures)
    party.recruit(catalog.class_by_id(&"ranger"))
    party.recruit(catalog.class_by_id(&"ranger"))
    TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"cleric")), "fifth member rejected", failures)
    party.rank_up(&"fighter")
    TestAssertions.equal(party.get_class_rank(&"fighter"), 2, "shared fighter rank", failures)
    TestAssertions.equal(party.active_tier(&"ranged"), 2, "duplicate rangers overlap", failures)
    party.free()

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
    _test_party_actor_stats_signal_lifecycle(failures)
    return failures

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
