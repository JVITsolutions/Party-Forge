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
    _test_atomic_equipment_source_batch_contract(failures)
    _test_two_pass_cache_isolation_and_preview_inputs(failures)
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
    _continue_effective_capacity(failures, party, catalog)

func _test_atomic_equipment_source_batch_contract(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "equipment batch fixture recruits member two", failures)
    TestAssertions.truthy(party.has_method(&"replace_member_equipment_sources_atomically"), "party manager exposes the narrow equipment-source batch API", failures)
    TestAssertions.truthy(not party.has_method(&"replace_member_sources_atomically"), "party manager removes the arbitrary source batch bypass", failures)
    if not party.has_method(&"replace_member_equipment_sources_atomically"):
        party.free()
        return

    var action_tags: Array[StringName] = [&"ranged", &"physical"]
    var member_one_before := party.stats_for(1)
    var member_two_before := party.stats_for(2)
    var member_two_action_before := party.stats_for_action(2, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var equipment_one := _equipment_source(1, 2.0)
    var equipment_two := _equipment_source(2, 3.0)
    TestAssertions.equal(
        int(party.call(&"replace_member_equipment_sources_atomically", {2: equipment_two, 1: equipment_one})),
        0,
        "canonical equipment batch succeeds",
        failures,
    )
    TestAssertions.equal(events, [1, 2], "equipment batch emits deterministic member order", failures)
    TestAssertions.equal(party.stat_revision(), revision_before + 1, "equipment batch advances one shared revision", failures)
    TestAssertions.truthy(not is_same(party.stats_for(1), member_one_before), "equipment batch replaces member-one base cache", failures)
    TestAssertions.truthy(not is_same(party.stats_for(2), member_two_before), "equipment batch replaces member-two base cache", failures)
    TestAssertions.truthy(not is_same(party.stats_for_action(2, action_tags), member_two_action_before), "equipment batch replaces affected action cache", failures)

    var sources_before := {
        1: _member_source_documents(party.member_by_id(1)),
        2: _member_source_documents(party.member_by_id(2)),
    }
    var member_one_cache := party.stats_for(1)
    var member_two_cache := party.stats_for(2)
    var member_two_action_cache := party.stats_for_action(2, action_tags)
    var stable_revision := party.stat_revision()
    events.clear()
    var invalid_cases: Array[Dictionary] = [
        {
            "label": "arbitrary core source",
            "batch": {1: StatModifierSource.create(&"character_growth_1", &"character_growth", "Growth", 1, [])},
            "rejected_member": 1,
        },
        {
            "label": "wrong source type",
            "batch": {1: StatModifierSource.create(&"equipment_member_1", &"character_growth", "Not Equipment", 1, [])},
            "rejected_member": 1,
        },
        {
            "label": "wrong canonical source ID",
            "batch": {1: StatModifierSource.create(&"equipment_member_2", &"equipment", "Wrong ID", 1, [])},
            "rejected_member": 1,
        },
        {
            "label": "wrong source owner",
            "batch": {1: StatModifierSource.create(&"equipment_member_1", &"equipment", "Wrong Owner", 2, [])},
            "rejected_member": 1,
        },
        {
            "label": "mixed valid and invalid batch",
            "batch": {1: _equipment_source(1, 9.0), 2: StatModifierSource.create(&"equipment_member_2", &"equipment", "Wrong Owner", 1, [])},
            "rejected_member": 2,
        },
        {
            "label": "null source",
            "batch": {1: _equipment_source(1, 9.0), 2: null},
            "rejected_member": 2,
        },
        {
            "label": "wrong source value type",
            "batch": {1: "not a stat source"},
            "rejected_member": 1,
        },
        {
            "label": "duplicate source ownership",
            "batch": {1: equipment_one, 2: equipment_one},
            "rejected_member": 2,
        },
    ]
    for test_case: Dictionary in invalid_cases:
        TestAssertions.equal(
            int(party.call(&"replace_member_equipment_sources_atomically", test_case["batch"])),
            int(test_case["rejected_member"]),
            "%s returns the stable rejected member" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before[1], "%s preserves member-one sources" % test_case["label"], failures)
        TestAssertions.equal(_member_source_documents(party.member_by_id(2)), sources_before[2], "%s preserves member-two sources" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), stable_revision, "%s preserves the revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), member_one_cache), "%s preserves member-one cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(2), member_two_cache), "%s preserves member-two cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(2, action_tags), member_two_action_cache), "%s preserves action-cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no stat signal" % test_case["label"], failures)

    var two_invalid := {
        2: StatModifierSource.create(&"wrong_two", &"equipment", "Wrong Two", 2, []),
        1: StatModifierSource.create(&"wrong_one", &"equipment", "Wrong One", 1, []),
    }
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", two_invalid)), 1, "batch validation rejects the lowest member ID deterministically", failures)
    TestAssertions.equal(party.stat_revision(), stable_revision, "deterministic rejection preserves revision", failures)
    TestAssertions.equal(events, [], "deterministic rejection emits no stat signal", failures)
    party.free()

func _equipment_source(member_id: int, strength: float) -> StatModifierSource:
    var source_id := StringName("equipment_member_%d" % member_id)
    return StatModifierSource.create(source_id, &"equipment", "Equipment", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, strength, StringName("equipment_strength_%d" % member_id), "Equipment"),
    ])

func _member_source_documents(member: PartyMemberState) -> String:
    var documents: Array[Dictionary] = []
    for source: StatModifierSource in member.modifier_sources:
        var modifiers: Array[Dictionary] = []
        for modifier: StatModifier in source.modifiers:
            modifiers.append({
                "stat_id": String(modifier.stat_id),
                "operation": modifier.operation,
                "value": modifier.value,
                "source_id": String(modifier.source_id),
                "source_label": modifier.source_label,
                "required_tags": modifier.required_tags,
                "excluded_tags": modifier.excluded_tags,
                "required_capability_tags": modifier.required_capability_tags,
                "excluded_capability_tags": modifier.excluded_capability_tags,
                "required_action_tags": modifier.required_action_tags,
                "excluded_action_tags": modifier.excluded_action_tags,
            })
        documents.append({
            "id": String(source.id),
            "source_type": String(source.source_type),
            "label": source.label,
            "owner_member_id": source.owner_member_id,
            "modifiers": modifiers,
        })
    return JSON.stringify(documents)

func _continue_effective_capacity(failures: Array[String], party: PartyManager, catalog: GameCatalog) -> void:

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

func _test_two_pass_cache_isolation_and_preview_inputs(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "cache isolation fixture recruits member two", failures)
    var first_id := party.members[0].member_id
    var second_id := party.members[1].member_id

    for method_name: StringName in [&"member_base_values", &"member_capabilities", &"member_sources_without_equipment", &"stat_revision"]:
        TestAssertions.truthy(party.has_method(method_name), "party manager exposes %s" % method_name, failures)
    if (
        not party.has_method(&"member_base_values")
        or not party.has_method(&"member_capabilities")
        or not party.has_method(&"member_sources_without_equipment")
        or not party.has_method(&"stat_revision")
    ):
        party.free()
        return

    var first_snapshot := party.stats_for(first_id)
    var second_snapshot := party.stats_for(second_id)
    TestAssertions.truthy(is_same(first_snapshot, party.stats_for(first_id)), "repeated member resolution uses the cache", failures)
    TestAssertions.truthy(is_same(second_snapshot, party.stats_for(second_id)), "second member resolution uses its own cache entry", failures)

    var growth_source := StatModifierSource.create(&"cache_growth_1", &"growth", "Growth", first_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, 5.0, &"cache_growth_1_strength", "Growth"),
    ])
    TestAssertions.truthy(party.add_member_source(first_id, growth_source), "member one source invalidates successfully", failures)
    var refreshed_first := party.stats_for(first_id)
    TestAssertions.truthy(not is_same(first_snapshot, refreshed_first), "invalidated member receives a replacement snapshot", failures)
    TestAssertions.truthy(is_same(second_snapshot, party.stats_for(second_id)), "invalidating member one preserves member two snapshot identity", failures)
    TestAssertions.near(refreshed_first.value(&"melee_damage"), 1.10, 0.0001, "party manager uses attribute-derived melee scaling", failures)
    TestAssertions.equal(refreshed_first.revision, int(party.call(&"stat_revision")), "party manager exposes the active stat revision", failures)

    var base_values: Dictionary = party.call(&"member_base_values", first_id)
    var original_health := float(base_values.get(&"max_health", 0.0))
    base_values[&"max_health"] = -999.0
    TestAssertions.near(float((party.call(&"member_base_values", first_id) as Dictionary).get(&"max_health", 0.0)), original_health, 0.0001, "member base values are defensive", failures)

    var capabilities: Array[StringName] = party.call(&"member_capabilities", first_id)
    capabilities.append(&"mutated")
    TestAssertions.truthy(&"mutated" not in (party.call(&"member_capabilities", first_id) as Array[StringName]), "member capabilities are defensive", failures)

    var equipment_source := StatModifierSource.create(&"preview_equipment", &"equipment", "Equipment", first_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, 2.0, &"preview_equipment_strength", "Equipment"),
    ])
    TestAssertions.truthy(party.add_member_source(first_id, equipment_source), "equipment preview fixture source is accepted", failures)
    var without_equipment: Array[StatModifierSource] = party.call(&"member_sources_without_equipment", first_id)
    TestAssertions.truthy(without_equipment.all(func(source: StatModifierSource) -> bool: return source.source_type != &"equipment"), "preview sources exclude only equipment", failures)
    TestAssertions.truthy(without_equipment.any(func(source: StatModifierSource) -> bool: return source.id == &"cache_growth_1"), "preview sources retain ordinary member sources", failures)
    var preview_count := without_equipment.size()
    without_equipment.clear()
    TestAssertions.equal((party.call(&"member_sources_without_equipment", first_id) as Array[StatModifierSource]).size(), preview_count, "preview source arrays are defensive", failures)
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
