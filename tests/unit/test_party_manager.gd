extends RefCounted

const ACTION_ONLY_TAG := &"task10d_action_only"

class CoordinatorProbe extends RefCounted:
    func refresh(_member_id: int, _source: StatModifierSource) -> bool:
        return false

class NodeCoordinatorProbe extends Node:
    func refresh(_member_id: int, _source: StatModifierSource) -> bool:
        return false

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
    _test_unbound_effective_source_collision_invariants(failures)
    _test_foreign_owner_candidate_normalization(failures)
    _test_foreign_owner_source_reuse_is_member_local(failures)
    _test_unbound_owned_action_overflow_preflight(failures)
    _test_unbound_finite_action_source_matches_only_owned_action(failures)
    _test_atomic_equipment_source_batch_contract(failures)
    _test_unbound_complete_candidate_equipment_invariants(failures)
    _test_atomic_batch_rejects_corrupted_equipment_prestate(failures)
    _test_coordinated_source_authority_contract(failures)
    _test_member_equipment_source_authority_contract(failures)
    _test_dead_coordinator_binding_fails_closed(failures)
    _test_two_pass_cache_isolation_and_preview_inputs(failures)
    _test_party_actor_stats_signal_lifecycle(failures)
    return failures

func _test_unbound_effective_source_collision_invariants(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var cases: Array[Dictionary] = []
    for source_id: StringName in [&"class_rank_fighter", &"attribute_projection_1"]:
        cases.append({"label": "%s add" % source_id, "method": &"add_member_source", "source_id": source_id, "seed_owned": false})
        cases.append({"label": "%s replace" % source_id, "method": &"replace_member_source", "source_id": source_id, "seed_owned": true})
    for source_id: StringName in [&"party_upgrades", &"active_traits"]:
        cases.append({"label": "%s add" % source_id, "method": &"add_member_source", "source_id": source_id, "seed_owned": false})
    for test_case: Dictionary in cases:
        var party := PartyManager.new()
        party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
        var base := party.stats_for(1)
        var action_tags: Array[StringName] = [&"melee", &"physical"]
        var action := party.stats_for_action(1, action_tags)
        if bool(test_case["seed_owned"]):
            party.member_by_id(1)._owned_modifier_sources().append(
                _growth_source(1, test_case["source_id"], 1.0)
            )
        var before := _member_source_documents(party.member_by_id(1))
        var revision := party.stat_revision()
        var events: Array[int] = []
        party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
        TestAssertions.truthy(
            not bool(party.call(test_case["method"], 1, _growth_source(1, test_case["source_id"], 2.0))),
            "%s rejects effective graph collision" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), before, "%s preserves owned source documents" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), revision, "%s preserves stat revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), base), "%s preserves base cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action), "%s preserves action cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no stat signal" % test_case["label"], failures)
        party.free()

    var upgraded_party := PartyManager.new()
    upgraded_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(UpgradeApplicationService.apply(&"vanguard_wall", catalog, upgraded_party), "dynamic party-upgrade collision fixture applies a live generated source", failures)
    var generated_id := &"upgrade:vanguard_wall:party"
    var upgraded_before := _member_source_documents(upgraded_party.member_by_id(1))
    var upgraded_revision := upgraded_party.stat_revision()
    var upgraded_cache := upgraded_party.stats_for(1)
    var upgraded_events: Array[int] = []
    upgraded_party.stats_changed.connect(func(member_id: int) -> void: upgraded_events.append(member_id))
    TestAssertions.truthy(not upgraded_party.add_member_source(1, _growth_source(1, generated_id, 3.0)), "live generated party-upgrade source ID collision rejects", failures)
    TestAssertions.equal(_member_source_documents(upgraded_party.member_by_id(1)), upgraded_before, "party-upgrade collision preserves source documents", failures)
    TestAssertions.equal(upgraded_party.stat_revision(), upgraded_revision, "party-upgrade collision preserves revision", failures)
    TestAssertions.truthy(is_same(upgraded_party.stats_for(1), upgraded_cache), "party-upgrade collision preserves cache identity", failures)
    TestAssertions.equal(upgraded_events, [], "party-upgrade collision emits no stat signal", failures)
    upgraded_party.free()

    var legitimate := PartyManager.new()
    legitimate.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(legitimate.add_member_source(1, _growth_source(1, &"task10p_custom", 1.0)), "legitimate unbound custom source add succeeds", failures)
    TestAssertions.truthy(legitimate.replace_member_source(1, _growth_source(1, &"task10p_custom", 2.0)), "legitimate unbound custom source replace succeeds", failures)
    TestAssertions.truthy(legitimate.add_member_source(1, _equipment_source(1, 2.0)), "legitimate unbound canonical equipment source succeeds", failures)
    legitimate.free()

func _test_foreign_owner_candidate_normalization(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    for test_case: Dictionary in [
        {"label": "add", "method": &"add_member_source", "seed": false},
        {"label": "replace", "method": &"replace_member_source", "seed": true},
    ]:
        var party := PartyManager.new()
        party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
        var source_id := StringName("task10q_owner77_overflow_%s" % test_case["label"])
        if bool(test_case["seed"]):
            TestAssertions.truthy(
                party.add_member_source(1, _growth_source(1, source_id, 1.0)),
                "%s overflow fixture installs replace target" % test_case["label"],
                failures,
            )
        var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
        var actor := actor_scene.instantiate() as PartyActor
        actor.configure(party.member_by_id(1))
        actor.configure_combat(party)
        var health := actor.get_node("HealthComponent") as HealthComponent
        var health_before := Vector2(health.current_health, health.max_health)
        var sources_before := _member_source_documents(party.member_by_id(1))
        var base_before := party.stats_for(1)
        var action_tags: Array[StringName] = [&"melee", &"physical"]
        var action_before := party.stats_for_action(1, action_tags)
        var revision_before := party.stat_revision()
        var events: Array[int] = []
        party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
        var candidate := _aggregate_overflow_source(77, source_id)
        var candidate_before := _modifier_source_document(candidate)

        TestAssertions.truthy(
            not bool(party.call(test_case["method"], 1, candidate)),
            "%s normalizes owner 77 before rejecting aggregate overflow" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_modifier_source_document(candidate), candidate_before, "%s preserves exact caller source bytes" % test_case["label"], failures)
        TestAssertions.equal(candidate.owner_member_id, 77, "%s preserves caller owner" % test_case["label"], failures)
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "%s preserves owned source documents" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), revision_before, "%s preserves stat revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), base_before), "%s preserves base cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "%s preserves action cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no stat signal" % test_case["label"], failures)
        TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "%s preserves actor health" % test_case["label"], failures)
        actor.free()
        party.free()

func _test_foreign_owner_source_reuse_is_member_local(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "owner-77 reuse fixture recruits member two", failures)
    var shared := _growth_source(77, &"task10q_shared_owner77", 2.0)
    var shared_before := _modifier_source_document(shared)
    TestAssertions.truthy(party.add_member_source(1, shared), "finite owner-77 source applies to member one", failures)
    TestAssertions.truthy(party.add_member_source(2, shared), "same finite owner-77 source applies to member two", failures)
    var member_one_source := party.member_by_id(1)._owned_modifier_sources().filter(
        func(source: StatModifierSource) -> bool: return source.id == shared.id
    )[0] as StatModifierSource
    var member_two_source := party.member_by_id(2)._owned_modifier_sources().filter(
        func(source: StatModifierSource) -> bool: return source.id == shared.id
    )[0] as StatModifierSource
    TestAssertions.equal(member_one_source.owner_member_id, 1, "member one receives normalized ownership", failures)
    TestAssertions.equal(member_two_source.owner_member_id, 2, "member two receives normalized ownership", failures)
    TestAssertions.truthy(not is_same(member_one_source, shared), "member one stores a defensive source copy", failures)
    TestAssertions.truthy(not is_same(member_two_source, shared), "member two stores a defensive source copy", failures)
    TestAssertions.truthy(not is_same(member_one_source, member_two_source), "members own independent source copies", failures)
    TestAssertions.truthy(not is_same(member_one_source.modifiers[0], shared.modifiers[0]), "member one stores a defensive modifier copy", failures)
    TestAssertions.truthy(not is_same(member_two_source.modifiers[0], shared.modifiers[0]), "member two stores a defensive modifier copy", failures)
    TestAssertions.truthy(not is_same(member_one_source.modifiers[0], member_two_source.modifiers[0]), "members own independent modifier copies", failures)
    TestAssertions.equal(_modifier_source_document(shared), shared_before, "source reuse preserves exact caller bytes", failures)
    TestAssertions.equal(shared.owner_member_id, 77, "source reuse preserves caller owner", failures)
    party.free()

func _test_unbound_owned_action_overflow_preflight(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    for test_case: Dictionary in [
        {"label": "add configured damage types", "method": &"add_member_source", "seed": false, "configure_combat": true},
        {"label": "replace canonical damage fallback", "method": &"replace_member_source", "seed": true, "configure_combat": false},
    ]:
        var party := _party_with_action_only_owned_actions(catalog)
        if bool(test_case["configure_combat"]):
            party.configure_combat(CombatRng.new(10101), catalog.damage_types)
        var source_id := StringName("task10r_action_overflow_%s" % String(test_case["method"]))
        if bool(test_case["seed"]):
            TestAssertions.truthy(
                party.add_member_source(1, _finite_action_source(1, source_id, 0.10)),
                "%s fixture installs replace target" % test_case["label"],
                failures,
            )
        var action_tags := DamageResolver.action_tags_for(party.member_by_id(1).class_definition.primary_attack)
        var actor_scene := load("res://scenes/characters/leader.tscn") as PackedScene
        var actor := actor_scene.instantiate() as PartyActor
        actor.configure(party.member_by_id(1))
        actor.configure_combat(party)
        var health := actor.get_node("HealthComponent") as HealthComponent
        health.apply_damage(40.0)
        var health_before := Vector2(health.current_health, health.max_health)
        var sources_before := _member_source_documents(party.member_by_id(1))
        var base_before := party.stats_for(1)
        var action_before := party.stats_for_action(1, action_tags)
        var revision_before := party.stat_revision()
        var events: Array[int] = []
        party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
        var candidate := _action_overflow_source(77, source_id)
        var candidate_before := _modifier_source_document(candidate)

        TestAssertions.truthy(
            not bool(party.call(test_case["method"], 1, candidate)),
            "%s rejects matching owned-action overflow" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "%s preserves exact owned source documents" % test_case["label"], failures)
        TestAssertions.equal(_modifier_source_document(candidate), candidate_before, "%s preserves exact caller source bytes" % test_case["label"], failures)
        TestAssertions.equal(candidate.owner_member_id, 77, "%s preserves caller owner" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), revision_before, "%s preserves stat revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), base_before), "%s preserves base cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "%s preserves matching-action cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no stat signal" % test_case["label"], failures)
        TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before, "%s preserves actor health" % test_case["label"], failures)
        actor.free()
        party.free()

func _test_unbound_finite_action_source_matches_only_owned_action(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := _party_with_action_only_owned_actions(catalog)
    var member := party.member_by_id(1)
    var matching_tags := DamageResolver.action_tags_for(member.class_definition.primary_attack)
    var other_tags := DamageResolver.action_tags_for(member.class_definition.support_action)
    var base_before := party.stats_for(1).value(&"damage")
    var matching_before := party.stats_for_action(1, matching_tags).value(&"damage")
    var other_before := party.stats_for_action(1, other_tags).value(&"damage")
    var source := _finite_action_source(77, &"task10r_finite_action", 0.25)
    var source_before := _modifier_source_document(source)

    TestAssertions.truthy(party.add_member_source(1, source), "finite action-tagged source applies through unbound action preflight", failures)
    TestAssertions.near(party.stats_for(1).value(&"damage"), base_before, 0.0001, "finite action source leaves base snapshot unchanged", failures)
    TestAssertions.near(party.stats_for_action(1, matching_tags).value(&"damage"), matching_before * 1.25, 0.0001, "finite action source affects the matching owned action", failures)
    TestAssertions.near(party.stats_for_action(1, other_tags).value(&"damage"), other_before, 0.0001, "finite action source leaves the other owned action unchanged", failures)
    var stored := member._owned_modifier_sources().filter(func(candidate: StatModifierSource) -> bool: return candidate.id == source.id)[0] as StatModifierSource
    TestAssertions.equal(stored.owner_member_id, 1, "finite action source normalizes stored owner", failures)
    TestAssertions.truthy(not is_same(stored, source) and not is_same(stored.modifiers[0], source.modifiers[0]), "finite action source and modifier are defensive copies", failures)
    TestAssertions.equal(_modifier_source_document(source), source_before, "finite action success preserves exact caller source bytes", failures)
    TestAssertions.equal(source.owner_member_id, 77, "finite action success preserves caller owner", failures)
    party.free()

func _test_unbound_complete_candidate_equipment_invariants(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var cases: Array[Dictionary] = [
        {
            "label": "rogue equipment add",
            "setup": Callable(),
            "method": &"add_member_source",
            "candidate": StatModifierSource.create(&"rogue_equipment", &"equipment", "Rogue", 1, []),
        },
        {
            "label": "mismatched equipment replace",
            "setup": func(party: PartyManager) -> void: party.add_member_source(1, _equipment_source(1, 2.0)),
            "method": &"replace_member_source",
            "candidate": StatModifierSource.create(&"equipment_member_2", &"equipment", "Mismatched", 1, []),
        },
        {
            "label": "wrong-owner equipment replace",
            "setup": func(party: PartyManager) -> void: party.add_member_source(1, _equipment_source(1, 2.0)),
            "method": &"replace_member_source",
            "candidate": StatModifierSource.create(&"equipment_member_1", &"equipment", "Wrong Owner", 2, []),
        },
    ]
    for test_case: Dictionary in cases:
        var party := PartyManager.new()
        party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
        var setup := test_case["setup"] as Callable
        if setup.is_valid():
            setup.call(party)
        var before := _member_source_documents(party.member_by_id(1))
        var revision := party.stat_revision()
        var base := party.stats_for(1)
        var action_tags: Array[StringName] = [&"melee", &"physical"]
        var action := party.stats_for_action(1, action_tags)
        var events: Array[int] = []
        party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
        TestAssertions.truthy(
            not bool(party.call(test_case["method"], 1, test_case["candidate"])),
            "%s rejects atomically" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), before, "%s preserves source documents" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), revision, "%s preserves revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), base), "%s preserves base cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action), "%s preserves action cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no stat signal" % test_case["label"], failures)
        party.free()

    var duplicate_party := PartyManager.new()
    duplicate_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(duplicate_party.add_member_source(1, _equipment_source(1, 2.0)), "unbound canonical equipment initialization remains supported", failures)
    var duplicate_before := _member_source_documents(duplicate_party.member_by_id(1))
    var duplicate_revision := duplicate_party.stat_revision()
    var duplicate_base := duplicate_party.stats_for(1)
    var duplicate_events: Array[int] = []
    duplicate_party.stats_changed.connect(func(member_id: int) -> void: duplicate_events.append(member_id))
    TestAssertions.truthy(not duplicate_party.add_member_source(1, _equipment_source(1, 3.0)), "second canonical equipment source rejects", failures)
    TestAssertions.equal(_member_source_documents(duplicate_party.member_by_id(1)), duplicate_before, "duplicate canonical rejection preserves source documents", failures)
    TestAssertions.equal(duplicate_party.stat_revision(), duplicate_revision, "duplicate canonical rejection preserves revision", failures)
    TestAssertions.truthy(is_same(duplicate_party.stats_for(1), duplicate_base), "duplicate canonical rejection preserves cache identity", failures)
    TestAssertions.equal(duplicate_events, [], "duplicate canonical rejection emits no signal", failures)
    duplicate_party.free()

func _test_atomic_batch_rejects_corrupted_equipment_prestate(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    for corruption: String in ["rogue", "duplicate"]:
        var party := PartyManager.new()
        party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
        var base := party.stats_for(1)
        var action_tags: Array[StringName] = [&"melee", &"physical"]
        var action := party.stats_for_action(1, action_tags)
        var owned := party.member_by_id(1)._owned_modifier_sources()
        if corruption == "rogue":
            owned.append(StatModifierSource.create(&"rogue_equipment", &"equipment", "Rogue", 1, []))
        else:
            owned.append(_equipment_source(1, 1.0))
            owned.append(_equipment_source(1, 2.0))
        var before := _member_source_documents(party.member_by_id(1))
        var revision := party.stat_revision()
        var events: Array[int] = []
        party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
        var probe := CoordinatorProbe.new()
        var callback := Callable(probe, "refresh")
        var authority := party.bind_member_source_refresh_coordinator(callback)
        TestAssertions.truthy(authority != null, "%s corrupted batch fixture binds authority" % corruption, failures)
        TestAssertions.equal(
            party.replace_member_equipment_sources_atomically({1: _equipment_source(1, 5.0)}, authority),
            1,
            "%s corrupted prestate rejects the complete candidate batch" % corruption,
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), before, "%s batch rejection preserves source documents" % corruption, failures)
        TestAssertions.equal(party.stat_revision(), revision, "%s batch rejection preserves revision" % corruption, failures)
        TestAssertions.truthy(is_same(party.stats_for(1), base), "%s batch rejection preserves base cache" % corruption, failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action), "%s batch rejection preserves action cache" % corruption, failures)
        TestAssertions.equal(events, [], "%s batch rejection emits no signal" % corruption, failures)
        party.unbind_member_source_refresh_coordinator(callback, authority)
        party.free()

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
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = party.bind_member_source_refresh_coordinator(coordinator)
    var method_argument_count := _method_argument_count(party, &"replace_member_equipment_sources_atomically")
    TestAssertions.equal(method_argument_count, 2, "equipment batch requires explicit authority", failures)
    TestAssertions.truthy(authority_value is RefCounted, "equipment batch fixture receives opaque authority", failures)
    if method_argument_count != 2 or not authority_value is RefCounted:
        party.free()
        return

    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {}, authority_value)), -1, "empty equipment batch returns the stable batch rejection", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {"1": _equipment_source(1, 1.0)}, authority_value)), -1, "non-integer equipment batch key is rejected", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {99: _equipment_source(99, 1.0)}, authority_value)), 99, "unknown positive member returns its contextual ID", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {0: _equipment_source(0, 1.0)}, authority_value)), -1, "zero member key is rejected at batch scope", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {-1: _equipment_source(-1, 1.0)}, authority_value)), -1, "negative member key is rejected at batch scope", failures)

    var action_tags: Array[StringName] = [&"ranged", &"physical"]
    var member_one_before := party.stats_for(1)
    var member_two_before := party.stats_for(2)
    var member_two_action_before := party.stats_for_action(2, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var equipment_one := _equipment_source(1, 2.0)
    var equipment_two := _equipment_source(2, 3.0)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {1: equipment_one})), -1, "missing equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {1: equipment_one}, RefCounted.new())), -1, "wrong equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), "[]", "authority rejection preserves initial member sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "authority rejection preserves initial revision", failures)
    TestAssertions.equal(events, [], "authority rejection emits no stat signal", failures)
    TestAssertions.equal(
        int(party.call(&"replace_member_equipment_sources_atomically", {2: equipment_two, 1: equipment_one}, authority_value)),
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
            int(party.call(&"replace_member_equipment_sources_atomically", test_case["batch"], authority_value)),
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
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", two_invalid, authority_value)), 1, "batch validation rejects the lowest member ID deterministically", failures)
    TestAssertions.equal(party.stat_revision(), stable_revision, "deterministic rejection preserves revision", failures)
    TestAssertions.equal(events, [], "deterministic rejection emits no stat signal", failures)
    party.unbind_member_source_refresh_coordinator(coordinator, authority_value)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_sources_atomically", {1: _equipment_source(1, 11.0)}, authority_value)), -1, "stale equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before[1], "stale batch authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), stable_revision, "stale batch authority preserves revision", failures)
    TestAssertions.equal(events, [], "stale batch authority emits no stat signal", failures)
    party.free()

func _test_coordinated_source_authority_contract(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var method_argument_count := _method_argument_count(party, &"replace_member_source_with_equipment_atomically")
    TestAssertions.equal(method_argument_count, 4, "coordinated source commit requires explicit authority", failures)
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = party.bind_member_source_refresh_coordinator(coordinator)
    TestAssertions.truthy(authority_value is RefCounted, "coordinator binding issues opaque authority", failures)
    var member_source := StatModifierSource.create(&"task10k_authority_growth", &"character_growth", "Authority Growth", 1, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, 1.0, &"task10k_authority_strength", "Authority Growth"),
    ])
    var equipment_source := _equipment_source(1, 2.0)
    var sources_before := _member_source_documents(party.member_by_id(1))
    var base_before := party.stats_for(1)
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var action_before := party.stats_for_action(1, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))

    var wrong_rejected := false
    if method_argument_count == 4:
        wrong_rejected = not bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, RefCounted.new()))
    TestAssertions.truthy(wrong_rejected, "wrong coordinator authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "wrong authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "wrong authority preserves revision", failures)
    TestAssertions.equal(events, [], "wrong authority emits no stat signal", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_before), "wrong authority preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "wrong authority preserves action cache identity", failures)

    var exact_committed := false
    if method_argument_count == 4 and authority_value is RefCounted:
        exact_committed = bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, authority_value))
    TestAssertions.truthy(exact_committed, "exact bound coordinator authority commits", failures)
    TestAssertions.equal(events, [1] if exact_committed else [], "exact authority emits one member-local stat signal", failures)
    var committed_sources := _member_source_documents(party.member_by_id(1))
    var committed_base := party.stats_for(1)
    var committed_action := party.stats_for_action(1, action_tags)
    var committed_revision := party.stat_revision()
    events.clear()
    if authority_value is RefCounted:
        party.call(&"unbind_member_source_refresh_coordinator", coordinator, authority_value)
    var stale_rejected := false
    if method_argument_count == 4 and authority_value is RefCounted:
        stale_rejected = not bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, authority_value))
    TestAssertions.truthy(stale_rejected, "unbound coordinator authority becomes stale", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), committed_sources, "stale authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), committed_revision, "stale authority preserves revision", failures)
    TestAssertions.equal(events, [], "stale authority emits no stat signal", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), committed_base), "stale authority preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), committed_action), "stale authority preserves action cache identity", failures)
    party.free()

func _test_member_equipment_source_authority_contract(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var method_argument_count := _method_argument_count(party, &"replace_member_equipment_source_atomically")
    TestAssertions.equal(method_argument_count, 3, "member equipment commit requires explicit authority", failures)
    if method_argument_count != 3:
        party.free()
        return
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = party.bind_member_source_refresh_coordinator(coordinator)
    TestAssertions.truthy(authority_value is RefCounted, "member equipment fixture receives opaque authority", failures)
    if not authority_value is RefCounted:
        party.free()
        return
    var candidate := _equipment_source(1, 5.0)
    var sources_before := _member_source_documents(party.member_by_id(1))
    var base_before := party.stats_for(1)
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var action_before := party.stats_for_action(1, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))

    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_source_atomically", 1, candidate)), "missing member equipment authority is rejected", failures)
    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_source_atomically", 1, candidate, RefCounted.new())), "wrong member equipment authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "member authority rejection preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "member authority rejection preserves revision", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_before), "member authority rejection preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "member authority rejection preserves action cache identity", failures)
    TestAssertions.equal(events, [], "member authority rejection emits no stat signal", failures)

    TestAssertions.truthy(bool(party.call(&"replace_member_equipment_source_atomically", 1, candidate, authority_value)), "exact member equipment authority commits", failures)
    TestAssertions.equal(events, [1], "exact member equipment authority emits one signal", failures)
    var committed_sources := _member_source_documents(party.member_by_id(1))
    var committed_base := party.stats_for(1)
    var committed_action := party.stats_for_action(1, action_tags)
    var committed_revision := party.stat_revision()
    events.clear()
    party.unbind_member_source_refresh_coordinator(coordinator, authority_value)
    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_source_atomically", 1, _equipment_source(1, 9.0), authority_value)), "stale member equipment authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), committed_sources, "stale member authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), committed_revision, "stale member authority preserves revision", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), committed_base), "stale member authority preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), committed_action), "stale member authority preserves action cache identity", failures)
    TestAssertions.equal(events, [], "stale member authority emits no stat signal", failures)
    party.free()

func _test_dead_coordinator_binding_fails_closed(failures: Array[String]) -> void:
    _assert_dead_coordinator_rejects_source_mutation(
        &"add_member_source",
        null,
        _equipment_source(1, 5.0),
        "dead coordinator direct equipment add",
        failures,
    )
    _assert_dead_coordinator_rejects_source_mutation(
        &"add_member_source",
        _equipment_source(1, 2.0),
        _equipment_source(1, 5.0),
        "dead coordinator duplicate equipment append",
        failures,
    )
    _assert_dead_coordinator_rejects_source_mutation(
        &"replace_member_source",
        _equipment_source(1, 2.0),
        _equipment_source(1, 5.0),
        "dead coordinator direct equipment replace",
        failures,
    )
    _assert_dead_coordinator_rejects_source_mutation(
        &"add_member_source",
        null,
        _growth_source(1, &"dead_callback_growth_add", 3.0),
        "dead coordinator non-equipment add",
        failures,
    )
    _assert_dead_coordinator_rejects_source_mutation(
        &"replace_member_source",
        _growth_source(1, &"dead_callback_growth_replace", 1.0),
        _growth_source(1, &"dead_callback_growth_replace", 3.0),
        "dead coordinator non-equipment replace",
        failures,
    )

func _assert_dead_coordinator_rejects_source_mutation(
    method_name: StringName,
    initial_source: StatModifierSource,
    candidate: StatModifierSource,
    label: String,
    failures: Array[String],
) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    if initial_source != null:
        TestAssertions.truthy(party.add_member_source(1, initial_source), "%s fixture installs the initial source" % label, failures)
    var source_documents := _member_source_documents(party.member_by_id(1))
    var base_snapshot := party.stats_for(1)
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var action_snapshot := party.stats_for_action(1, action_tags)
    var revision := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var probe := NodeCoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority := party.bind_member_source_refresh_coordinator(coordinator)
    TestAssertions.truthy(authority != null, "%s fixture binds authority" % label, failures)
    probe.free()
    TestAssertions.truthy(not coordinator.is_valid(), "%s fixture invalidates the callback target" % label, failures)
    var replacement_probe := NodeCoordinatorProbe.new()
    TestAssertions.truthy(
        party.bind_member_source_refresh_coordinator(Callable(replacement_probe, "refresh")) == null,
        "%s retains binding ownership after callback death" % label,
        failures,
    )

    TestAssertions.truthy(not bool(party.call(method_name, 1, candidate)), "%s rejects" % label, failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), source_documents, "%s preserves exact sources" % label, failures)
    TestAssertions.equal(party.stat_revision(), revision, "%s preserves revision" % label, failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_snapshot), "%s preserves base-cache identity" % label, failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_snapshot), "%s preserves action-cache identity" % label, failures)
    TestAssertions.equal(events, [], "%s emits no stat signal" % label, failures)
    replacement_probe.free()
    party.free()

func _method_argument_count(instance: Object, method_name: StringName) -> int:
    for method: Dictionary in instance.get_method_list():
        if StringName(method.get("name", "")) == method_name:
            return (method.get("args", []) as Array).size()
    return -1

func _equipment_source(member_id: int, strength: float) -> StatModifierSource:
    var source_id := StringName("equipment_member_%d" % member_id)
    return StatModifierSource.create(source_id, &"equipment", "Equipment", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, strength, StringName("equipment_strength_%d" % member_id), "Equipment"),
    ])

func _growth_source(member_id: int, source_id: StringName, strength: float) -> StatModifierSource:
    return StatModifierSource.create(source_id, &"character_growth", "Growth", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, strength, source_id, "Growth"),
    ])

func _aggregate_overflow_source(member_id: int, source_id: StringName) -> StatModifierSource:
    return StatModifierSource.create(source_id, &"character_growth", "Overflow", member_id, [
        StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 1.0e308, StringName("%s_a" % source_id), "Overflow A"),
        StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 1.0e308, StringName("%s_b" % source_id), "Overflow B"),
    ])

func _party_with_action_only_owned_actions(catalog: GameCatalog) -> PartyManager:
    var fighter := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
    fighter.primary_attack = fighter.primary_attack.duplicate(true) as AttackDefinition
    fighter.primary_attack.action_tags = fighter.primary_attack.action_tags.duplicate()
    fighter.primary_attack.action_tags.append(ACTION_ONLY_TAG)
    fighter.support_action = fighter.primary_attack.duplicate(true) as AttackDefinition
    fighter.support_action.id = &"task10r_other_owned_action"
    fighter.support_action.action_tags = fighter.support_action.action_tags.filter(
        func(tag: StringName) -> bool: return tag != ACTION_ONLY_TAG
    )
    var party := PartyManager.new()
    party.initialize(fighter, catalog.traits)
    return party

func _action_overflow_source(member_id: int, source_id: StringName) -> StatModifierSource:
    var modifiers: Array[StatModifier] = []
    for index: int in 4:
        modifiers.append(StatModifier.create(
            &"cooldown_rate",
            StatModifier.Operation.MORE,
            1.0e100,
            StringName("%s_%d" % [source_id, index]),
            "Task 10R Action Overflow",
            [ACTION_ONLY_TAG],
        ))
    return StatModifierSource.create(source_id, &"character_growth", "Task 10R Action Overflow", member_id, modifiers)

func _finite_action_source(member_id: int, source_id: StringName, increased_damage: float) -> StatModifierSource:
    return StatModifierSource.create(source_id, &"character_growth", "Task 10R Finite Action", member_id, [
        StatModifier.create(
            &"damage",
            StatModifier.Operation.INCREASED,
            increased_damage,
            StringName("%s_damage" % source_id),
            "Task 10R Finite Action",
            [ACTION_ONLY_TAG],
        ),
    ])

func _modifier_source_document(source: StatModifierSource) -> String:
    var member := PartyMemberState.new(999, ClassDefinition.new(), false)
    member._owned_modifier_sources().append(source)
    return _member_source_documents(member)

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

    var equipment_source := StatModifierSource.create(&"equipment_member_1", &"equipment", "Equipment", first_id, [
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
