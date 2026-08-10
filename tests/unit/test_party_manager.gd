extends RefCounted

const ACTION_ONLY_TAG := &"task10d_action_only"

class CoordinatorProbe extends RefCounted:
    var party: PartyManager

    func refresh(_member_id: int, _source: StatModifierSource) -> bool:
        return false

    func validate(member_ids: Array[int]) -> bool:
        if party == null or member_ids.is_empty():
            return false
        var seen: Dictionary = {}
        for member_id: int in member_ids:
            if member_id <= 0 or seen.has(member_id):
                return false
            seen[member_id] = true
            var member := party.member_by_id(member_id)
            if member == null:
                return false
            var equipment_sources := member.modifier_sources.filter(func(source: StatModifierSource) -> bool:
                return source != null and source.source_type == &"equipment"
            )
            if equipment_sources.size() != 1:
                return false
            var source := equipment_sources[0] as StatModifierSource
            if source.id != StringName("equipment_member_%d" % member_id) or source.owner_member_id != member_id:
                return false
            var weapon := party.active_weapon_snapshot(member_id)
            if weapon != null and (weapon.member_id != member_id or weapon.revision != party.stat_revision() + 1):
                return false
        return true

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
    _test_caster_party_upgrade_rejects_future_mage_atomically(failures)
    _test_composition_trait_overflow_rejects_recruit_atomically(failures)
    _test_later_existing_member_failure_rejects_recruit_atomically(failures)
    _test_finite_party_upgrade_reaches_future_recruit(failures)
    _test_trait_tier_recruit_signal_order_and_single_invalidation(failures)
    _test_recruit_input_rejections_preserve_state(failures)
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
    _test_equipment_projection_requires_validator(failures)
    _test_atomic_weapon_projection_contract(failures)
    _test_twenty_four_member_weapon_projection_isolation(failures)
    _test_all_member_invalidations_restamp_equipped_weapons(failures)
    _test_all_member_invalidation_publishes_before_signals(failures)
    _test_member_local_revision_is_warm_cold_coherent(failures)
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
    var api_probe := PartyManager.new()
    if not api_probe.has_method(&"replace_member_equipment_projections_atomically"):
        TestAssertions.truthy(false, "party manager exposes projection batch validation for corrupted prestates", failures)
        api_probe.free()
        return
    api_probe.free()
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
        var authority := _bind_equipment_authority(party, callback)
        TestAssertions.truthy(authority != null, "%s corrupted batch fixture binds authority" % corruption, failures)
        TestAssertions.equal(
            party.replace_member_equipment_projections_atomically({1: {"source": _equipment_source(1, 5.0), "weapon": null}}, authority),
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
    TestAssertions.truthy(party.has_method(&"replace_member_equipment_projections_atomically"), "party manager exposes the narrow equipment-projection batch API", failures)
    TestAssertions.truthy(not party.has_method(&"replace_member_equipment_sources_atomically"), "party manager removes the source-only equipment batch bypass", failures)
    TestAssertions.truthy(not party.has_method(&"replace_member_sources_atomically"), "party manager removes the arbitrary source batch bypass", failures)
    if not party.has_method(&"replace_member_equipment_projections_atomically"):
        party.free()
        return
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = _bind_equipment_authority(party, coordinator)
    var method_argument_count := _method_argument_count(party, &"replace_member_equipment_projections_atomically")
    TestAssertions.equal(method_argument_count, 2, "equipment batch requires explicit authority", failures)
    TestAssertions.truthy(authority_value is RefCounted, "equipment batch fixture receives opaque authority", failures)
    if method_argument_count != 2 or not authority_value is RefCounted:
        party.free()
        return

    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {}, authority_value)), -1, "empty equipment batch returns the stable batch rejection", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {"1": {"source": _equipment_source(1, 1.0), "weapon": null}}, authority_value)), -1, "non-integer equipment batch key is rejected", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {99: {"source": _equipment_source(99, 1.0), "weapon": null}}, authority_value)), 99, "unknown positive member returns its contextual ID", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {0: {"source": _equipment_source(0, 1.0), "weapon": null}}, authority_value)), -1, "zero member key is rejected at batch scope", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {-1: {"source": _equipment_source(-1, 1.0), "weapon": null}}, authority_value)), -1, "negative member key is rejected at batch scope", failures)

    var action_tags: Array[StringName] = [&"ranged", &"physical"]
    var member_one_before := party.stats_for(1)
    var member_two_before := party.stats_for(2)
    var member_two_action_before := party.stats_for_action(2, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var equipment_one := _equipment_source(1, 2.0)
    var equipment_two := _equipment_source(2, 3.0)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {1: {"source": equipment_one, "weapon": null}})), -1, "missing equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {1: {"source": equipment_one, "weapon": null}}, RefCounted.new())), -1, "wrong equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), "[]", "authority rejection preserves initial member sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "authority rejection preserves initial revision", failures)
    TestAssertions.equal(events, [], "authority rejection emits no stat signal", failures)
    TestAssertions.equal(
        int(party.call(&"replace_member_equipment_projections_atomically", {2: {"source": equipment_two, "weapon": null}, 1: {"source": equipment_one, "weapon": null}}, authority_value)),
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
            "batch": {1: {"source": StatModifierSource.create(&"character_growth_1", &"character_growth", "Growth", 1, []), "weapon": null}},
            "rejected_member": 1,
        },
        {
            "label": "wrong source type",
            "batch": {1: {"source": StatModifierSource.create(&"equipment_member_1", &"character_growth", "Not Equipment", 1, []), "weapon": null}},
            "rejected_member": 1,
        },
        {
            "label": "wrong canonical source ID",
            "batch": {1: {"source": StatModifierSource.create(&"equipment_member_2", &"equipment", "Wrong ID", 1, []), "weapon": null}},
            "rejected_member": 1,
        },
        {
            "label": "wrong source owner",
            "batch": {1: {"source": StatModifierSource.create(&"equipment_member_1", &"equipment", "Wrong Owner", 2, []), "weapon": null}},
            "rejected_member": 1,
        },
        {
            "label": "mixed valid and invalid batch",
            "batch": {1: {"source": _equipment_source(1, 9.0), "weapon": null}, 2: {"source": StatModifierSource.create(&"equipment_member_2", &"equipment", "Wrong Owner", 1, []), "weapon": null}},
            "rejected_member": 2,
        },
        {
            "label": "null source",
            "batch": {1: {"source": _equipment_source(1, 9.0), "weapon": null}, 2: null},
            "rejected_member": 2,
        },
        {
            "label": "wrong source value type",
            "batch": {1: "not a projection"},
            "rejected_member": 1,
        },
        {
            "label": "duplicate source ownership",
            "batch": {1: {"source": equipment_one, "weapon": null}, 2: {"source": equipment_one, "weapon": null}},
            "rejected_member": 2,
        },
    ]
    for test_case: Dictionary in invalid_cases:
        TestAssertions.equal(
            int(party.call(&"replace_member_equipment_projections_atomically", test_case["batch"], authority_value)),
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
        2: {"source": StatModifierSource.create(&"wrong_two", &"equipment", "Wrong Two", 2, []), "weapon": null},
        1: {"source": StatModifierSource.create(&"wrong_one", &"equipment", "Wrong One", 1, []), "weapon": null},
    }
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", two_invalid, authority_value)), 1, "batch validation rejects the lowest member ID deterministically", failures)
    TestAssertions.equal(party.stat_revision(), stable_revision, "deterministic rejection preserves revision", failures)
    TestAssertions.equal(events, [], "deterministic rejection emits no stat signal", failures)
    party.unbind_member_source_refresh_coordinator(coordinator, authority_value)
    TestAssertions.equal(int(party.call(&"replace_member_equipment_projections_atomically", {1: {"source": _equipment_source(1, 11.0), "weapon": null}}, authority_value)), -1, "stale equipment batch authority is rejected at batch scope", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before[1], "stale batch authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), stable_revision, "stale batch authority preserves revision", failures)
    TestAssertions.equal(events, [], "stale batch authority emits no stat signal", failures)
    party.free()

func _test_coordinated_source_authority_contract(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var method_argument_count := _method_argument_count(party, &"replace_member_source_with_equipment_atomically")
    TestAssertions.equal(method_argument_count, 5, "coordinated source commit requires a weapon projection and explicit authority", failures)
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = _bind_equipment_authority(party, coordinator)
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
    if method_argument_count == 5:
        wrong_rejected = not bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, null, RefCounted.new()))
    TestAssertions.truthy(wrong_rejected, "wrong coordinator authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "wrong authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "wrong authority preserves revision", failures)
    TestAssertions.equal(events, [], "wrong authority emits no stat signal", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_before), "wrong authority preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "wrong authority preserves action cache identity", failures)

    var exact_committed := false
    if method_argument_count == 5 and authority_value is RefCounted:
        exact_committed = bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, null, authority_value))
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
    if method_argument_count == 5 and authority_value is RefCounted:
        stale_rejected = not bool(party.call(&"replace_member_source_with_equipment_atomically", 1, member_source, equipment_source, null, authority_value))
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
    var method_argument_count := _method_argument_count(party, &"replace_member_equipment_projection_atomically")
    TestAssertions.equal(method_argument_count, 4, "member equipment commit requires weapon projection and explicit authority", failures)
    if method_argument_count != 4:
        party.free()
        return
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority_value: Variant = _bind_equipment_authority(party, coordinator)
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

    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_projection_atomically", 1, candidate, null)), "missing member equipment authority is rejected", failures)
    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_projection_atomically", 1, candidate, null, RefCounted.new())), "wrong member equipment authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "member authority rejection preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "member authority rejection preserves revision", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_before), "member authority rejection preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "member authority rejection preserves action cache identity", failures)
    TestAssertions.equal(events, [], "member authority rejection emits no stat signal", failures)

    TestAssertions.truthy(bool(party.call(&"replace_member_equipment_projection_atomically", 1, candidate, null, authority_value)), "exact member equipment authority commits", failures)
    TestAssertions.equal(events, [1], "exact member equipment authority emits one signal", failures)
    var committed_sources := _member_source_documents(party.member_by_id(1))
    var committed_base := party.stats_for(1)
    var committed_action := party.stats_for_action(1, action_tags)
    var committed_revision := party.stat_revision()
    events.clear()
    party.unbind_member_source_refresh_coordinator(coordinator, authority_value)
    TestAssertions.truthy(not bool(party.call(&"replace_member_equipment_projection_atomically", 1, _equipment_source(1, 9.0), null, authority_value)), "stale member equipment authority is rejected", failures)
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), committed_sources, "stale member authority preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), committed_revision, "stale member authority preserves revision", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), committed_base), "stale member authority preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), committed_action), "stale member authority preserves action cache identity", failures)
    TestAssertions.equal(events, [], "stale member authority emits no stat signal", failures)
    party.free()


func _test_equipment_projection_requires_validator(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority := party.bind_member_source_refresh_coordinator(coordinator)
    TestAssertions.truthy(authority != null, "coordinator-only binding still issues non-equipment authority", failures)
    var source := _equipment_source(1, 3.0)
    var growth := _growth_source(1, &"validator_required_growth", 2.0)
    var sources_before := _member_source_documents(party.member_by_id(1))
    var base_before := party.stats_for(1)
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var action_before := party.stats_for_action(1, action_tags)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    TestAssertions.truthy(
        not party.replace_member_equipment_projection_atomically(1, source, null, authority),
        "coordinator-only authority cannot publish one equipment projection",
        failures,
    )
    TestAssertions.equal(
        party.replace_member_equipment_projections_atomically({1: {"source": source, "weapon": null}}, authority),
        -1,
        "coordinator-only authority cannot publish an equipment batch",
        failures,
    )
    TestAssertions.truthy(
        not party.replace_member_source_with_equipment_atomically(1, growth, source, null, authority),
        "coordinator-only authority cannot publish a coordinated equipment projection",
        failures,
    )
    TestAssertions.equal(_member_source_documents(party.member_by_id(1)), sources_before, "missing validator preserves exact sources", failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "missing validator preserves revision", failures)
    TestAssertions.truthy(is_same(party.stats_for(1), base_before), "missing validator preserves base cache identity", failures)
    TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), action_before), "missing validator preserves action cache identity", failures)
    TestAssertions.equal(events, [], "missing validator emits no stat signal", failures)
    party.unbind_member_source_refresh_coordinator(coordinator, authority)
    party.free()


func _test_atomic_weapon_projection_contract(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(party.has_method(&"active_weapon_snapshot"), "party manager exposes active weapon snapshots", failures)
    TestAssertions.truthy(party.has_method(&"replace_member_equipment_projection_atomically"), "party manager exposes member-local equipment projection publication", failures)
    if not party.has_method(&"active_weapon_snapshot") or not party.has_method(&"replace_member_equipment_projection_atomically"):
        party.free()
        return
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority := _bind_equipment_authority(party, coordinator)
    var revision_before := party.stat_revision()
    var base_before := party.stats_for(1)
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var action_before := party.stats_for_action(1, action_tags)
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var source := _equipment_source(1, 2.0)
    var weapon := _weapon_snapshot(1, "weapon-owned-1", &"forge_vanguard_sword", revision_before + 1)
    TestAssertions.truthy(
        bool(party.call(&"replace_member_equipment_projection_atomically", 1, source, weapon, authority)),
        "valid source and weapon publish together",
        failures,
    )
    TestAssertions.equal(party.stat_revision(), revision_before + 1, "source and weapon publication advances one revision", failures)
    TestAssertions.equal(events, [1], "source and weapon publication emits one signal", failures)
    var published: ActiveWeaponDamageSnapshot = party.call(&"active_weapon_snapshot", 1)
    TestAssertions.equal(_weapon_document(published), _weapon_document(weapon), "published weapon preserves exact identity and ranges", failures)
    if published != null:
        var exposed := published.components
        exposed[0].minimum_damage = 999.0
        TestAssertions.near((party.call(&"active_weapon_snapshot", 1) as ActiveWeaponDamageSnapshot).components[0].minimum_damage, 4.0, 0.0001, "active weapon getter is defensive", failures)

    var stable_sources := _member_source_documents(party.member_by_id(1))
    var stable_weapon := _weapon_document(party.call(&"active_weapon_snapshot", 1))
    var stable_base := party.stats_for(1)
    var stable_action := party.stats_for_action(1, action_tags)
    var stable_revision := party.stat_revision()
    events.clear()
    var invalid_cases: Array[Dictionary] = [
        {"label": "missing authority", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(1, "weapon-next", &"forge_vanguard_sword", stable_revision + 1), "authority": null},
        {"label": "wrong authority", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(1, "weapon-next", &"forge_vanguard_sword", stable_revision + 1), "authority": RefCounted.new()},
        {"label": "wrong canonical source", "source": StatModifierSource.create(&"equipment_member_2", &"equipment", "Wrong", 1, []), "weapon": _weapon_snapshot(1, "weapon-next", &"forge_vanguard_sword", stable_revision + 1), "authority": authority},
        {"label": "wrong source owner", "source": StatModifierSource.create(&"equipment_member_1", &"equipment", "Wrong", 2, []), "weapon": _weapon_snapshot(1, "weapon-next", &"forge_vanguard_sword", stable_revision + 1), "authority": authority},
        {"label": "wrong weapon member", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(2, "weapon-next", &"forge_vanguard_sword", stable_revision + 1), "authority": authority},
        {"label": "wrong weapon revision", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(1, "weapon-next", &"forge_vanguard_sword", stable_revision), "authority": authority},
        {"label": "empty weapon item identity", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(1, "", &"forge_vanguard_sword", stable_revision + 1), "authority": authority},
        {"label": "unknown weapon base identity", "source": _equipment_source(1, 3.0), "weapon": _weapon_snapshot(1, "weapon-next", &"missing_weapon_base", stable_revision + 1), "authority": authority},
        {"label": "invalid weapon components", "source": _equipment_source(1, 3.0), "weapon": ActiveWeaponDamageSnapshot.create(1, "weapon-next", &"forge_vanguard_sword", [ItemBaseDamageComponent.create(&"missing_type", 1.0, 2.0)], stable_revision + 1), "authority": authority},
    ]
    for test_case: Dictionary in invalid_cases:
        TestAssertions.truthy(
            not bool(party.call(&"replace_member_equipment_projection_atomically", 1, test_case["source"], test_case["weapon"], test_case["authority"])),
            "%s is rejected" % test_case["label"],
            failures,
        )
        TestAssertions.equal(_member_source_documents(party.member_by_id(1)), stable_sources, "%s preserves sources" % test_case["label"], failures)
        TestAssertions.equal(_weapon_document(party.call(&"active_weapon_snapshot", 1)), stable_weapon, "%s preserves weapon snapshot" % test_case["label"], failures)
        TestAssertions.equal(party.stat_revision(), stable_revision, "%s preserves revision" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for(1), stable_base), "%s preserves base cache identity" % test_case["label"], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(1, action_tags), stable_action), "%s preserves action cache identity" % test_case["label"], failures)
        TestAssertions.equal(events, [], "%s emits no signal" % test_case["label"], failures)

    TestAssertions.truthy(
        bool(party.call(&"replace_member_equipment_projection_atomically", 1, _equipment_source(1, 4.0), null, authority)),
        "weapon removal publishes the equipment source and null snapshot together",
        failures,
    )
    TestAssertions.equal(party.call(&"active_weapon_snapshot", 1), null, "weapon removal clears the active snapshot", failures)
    party.unbind_member_source_refresh_coordinator(coordinator, authority)
    party.free()


func _test_twenty_four_member_weapon_projection_isolation(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.configure_capacity(PartyCapacityPolicy.new(24))
    for _index: int in range(1, 24):
        TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "weapon isolation fixture recruits all 24 members", failures)
    if party.members.size() != 24 or not party.has_method(&"replace_member_equipment_projection_atomically"):
        party.free()
        return
    var caches: Dictionary = {}
    var source_documents: Dictionary = {}
    for member: PartyMemberState in party.members:
        caches[member.member_id] = party.stats_for(member.member_id)
        source_documents[member.member_id] = _member_source_documents(member)
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority := _bind_equipment_authority(party, coordinator)
    var revision_before := party.stat_revision()
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))
    var selected_member_id := 17
    var weapon := _weapon_snapshot(selected_member_id, "weapon-member-17", &"forge_vanguard_sword", revision_before + 1)
    TestAssertions.truthy(
        bool(party.call(&"replace_member_equipment_projection_atomically", selected_member_id, _equipment_source(selected_member_id, 7.0), weapon, authority)),
        "one selected member publishes at developer capacity",
        failures,
    )
    TestAssertions.equal(events, [selected_member_id], "24-member publication emits only the selected member", failures)
    TestAssertions.equal(party.stat_revision(), revision_before + 1, "24-member publication advances one revision", failures)
    for member: PartyMemberState in party.members:
        if member.member_id == selected_member_id:
            TestAssertions.equal(_weapon_document(party.call(&"active_weapon_snapshot", member.member_id)), _weapon_document(weapon), "selected member owns its weapon projection", failures)
            TestAssertions.truthy(not is_same(party.stats_for(member.member_id), caches[member.member_id]), "selected member cache is invalidated", failures)
        else:
            TestAssertions.equal(_member_source_documents(member), source_documents[member.member_id], "member %d sources remain exact" % member.member_id, failures)
            TestAssertions.equal(party.call(&"active_weapon_snapshot", member.member_id), null, "member %d weapon remains absent" % member.member_id, failures)
            TestAssertions.truthy(is_same(party.stats_for(member.member_id), caches[member.member_id]), "member %d cache identity remains exact" % member.member_id, failures)
    party.unbind_member_source_refresh_coordinator(coordinator, authority)
    party.free()

func _test_all_member_invalidations_restamp_equipped_weapons(failures: Array[String]) -> void:
    var fixture := _two_equipped_member_fixture(failures, "all-member")
    var party := fixture.get("party") as PartyManager
    if party == null:
        return
    var events: Array[int] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append(member_id))

    var caches := _warm_party_caches(party)
    var revision_before := party.stat_revision()
    TestAssertions.truthy(party.rank_up(&"fighter"), "rank-up revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "rank up", failures)

    events.clear()
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    TestAssertions.truthy(party.upgrade_party_stat(&"damage"), "party-stat revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "party stat upgrade", failures)

    events.clear()
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    TestAssertions.truthy(party.upgrade_trait(&"vanguard"), "trait-upgrade revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "trait upgrade", failures)

    events.clear()
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    var upgrade := _task10t_party_upgrade(&"revision_party_upgrade", [
        _task10t_effect(&"damage", StatModifier.Operation.INCREASED, 0.05),
    ])
    var upgrade_source := StatModifierSource.create(&"upgrade:revision_party_upgrade:party", &"upgrade", "Revision Party Upgrade", 0, [
        StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.05, &"revision_party_upgrade", "Revision Party Upgrade"),
    ])
    TestAssertions.truthy(bool(party.call(&"_commit_party_upgrade", upgrade, 1, upgrade_source)), "party-upgrade revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "party upgrade commit", failures)

    events.clear()
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    TestAssertions.truthy(party.recruit(GameCatalog.load_defaults().class_by_id(&"fighter")), "ordinary recruit revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "recruit without trait-tier change", failures)

    events.clear()
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    TestAssertions.truthy(party.recruit(GameCatalog.load_defaults().class_by_id(&"fighter")), "trait-tier recruit revision fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "recruit with trait-tier change", failures)

    events.clear()
    party.active_tiers = {}
    caches = _warm_party_caches(party)
    revision_before = party.stat_revision()
    TestAssertions.truthy(bool(party.call(&"_recalculate_traits")), "direct trait recalculation fixture mutates", failures)
    _assert_all_member_revision_state(party, revision_before, caches, events, "trait recalculation", failures)

    party.unbind_member_source_refresh_coordinator(fixture["coordinator"], fixture["authority"])
    party.free()

func _test_all_member_invalidation_publishes_before_signals(failures: Array[String]) -> void:
    var fixture := _two_equipped_member_fixture(failures, "signal-time publication")
    var party := fixture.get("party") as PartyManager
    if party == null:
        return
    var member_two := party.member_by_id(2)
    var action_tags: Array[StringName] = member_two.class_definition.primary_attack.action_tags
    var damage_before := party.stats_for(2).value(&"damage")
    var action_damage_before := party.stats_for_action(2, action_tags).value(&"damage")
    var revision_before := party.stat_revision()
    var outer_revision := revision_before + 1
    var nested_revision := outer_revision + 1
    var events: Array[int] = []
    var observations: Dictionary = {}
    var control := {"nested_started": false}
    party.stats_changed.connect(func(member_id: int) -> void:
        events.append(member_id)
        if member_id == 1 and not bool(control["nested_started"]):
            control["nested_started"] = true
            var cold_base := party.stats_for(2)
            var warm_base := party.stats_for(2)
            var cold_action := party.stats_for_action(2, action_tags)
            var warm_action := party.stats_for_action(2, action_tags)
            var weapon := party.active_weapon_snapshot(2)
            observations["cold_base_revision"] = cold_base.revision
            observations["cold_action_revision"] = cold_action.revision
            observations["warm_base_is_same"] = is_same(cold_base, warm_base)
            observations["warm_action_is_same"] = is_same(cold_action, warm_action)
            observations["base_damage"] = cold_base.value(&"damage")
            observations["action_damage"] = cold_action.value(&"damage")
            observations["weapon_revision"] = weapon.revision if weapon != null else -1
            observations["nested_committed"] = _commit_member_one_growth(fixture)
        elif member_id == 2:
            observations["later_signal_base_revision"] = party.stats_for(2).revision
            observations["later_signal_action_revision"] = party.stats_for_action(2, action_tags).revision
            var later_weapon := party.active_weapon_snapshot(2)
            observations["later_signal_weapon_revision"] = later_weapon.revision if later_weapon != null else -1
    )

    TestAssertions.truthy(party.rank_up(&"fighter"), "signal-time fixture mutates every member", failures)
    TestAssertions.equal(observations.get("cold_base_revision", -1), outer_revision, "first signal sees later member cold base at the complete outer revision", failures)
    TestAssertions.equal(observations.get("cold_action_revision", -1), outer_revision, "first signal sees later member cold action at the complete outer revision", failures)
    TestAssertions.truthy(bool(observations.get("warm_base_is_same", false)), "first signal reuses later member warm base cache", failures)
    TestAssertions.truthy(bool(observations.get("warm_action_is_same", false)), "first signal reuses later member warm action cache", failures)
    TestAssertions.truthy(float(observations.get("base_damage", damage_before)) > damage_before, "first signal sees later member new base stat values", failures)
    TestAssertions.truthy(float(observations.get("action_damage", action_damage_before)) > action_damage_before, "first signal sees later member new action stat values", failures)
    TestAssertions.equal(observations.get("weapon_revision", -1), outer_revision, "first signal sees later member weapon at the complete outer revision", failures)
    TestAssertions.truthy(bool(observations.get("nested_committed", false)), "first signal commits a reentrant member-local transition", failures)
    TestAssertions.equal(party.stat_revision(), nested_revision, "reentrant mutation advances a distinct global revision", failures)
    TestAssertions.equal(party.stats_for(1).revision, nested_revision, "reentrant member owns the nested revision", failures)
    TestAssertions.equal(party.active_weapon_snapshot(1).revision, nested_revision, "reentrant member weapon owns the nested revision", failures)
    TestAssertions.equal(party.stats_for(2).revision, outer_revision, "outer transition does not stamp later member base with nested revision", failures)
    TestAssertions.equal(party.stats_for_action(2, action_tags).revision, outer_revision, "outer transition does not stamp later member action with nested revision", failures)
    TestAssertions.equal(party.active_weapon_snapshot(2).revision, outer_revision, "outer transition does not stamp later member weapon with nested revision", failures)
    TestAssertions.equal(observations.get("later_signal_base_revision", -1), outer_revision, "later outer signal observes its own base revision", failures)
    TestAssertions.equal(observations.get("later_signal_action_revision", -1), outer_revision, "later outer signal observes its own action revision", failures)
    TestAssertions.equal(observations.get("later_signal_weapon_revision", -1), outer_revision, "later outer signal observes its own weapon revision", failures)
    TestAssertions.equal(events, [1, 1, 2], "outer and nested transitions retain distinct signal order", failures)

    party.unbind_member_source_refresh_coordinator(fixture["coordinator"], fixture["authority"])
    party.free()

func _test_member_local_revision_is_warm_cold_coherent(failures: Array[String]) -> void:
    var warm_fixture := _two_equipped_member_fixture(failures, "warm")
    var cold_fixture := _two_equipped_member_fixture(failures, "cold")
    var warm_party := warm_fixture.get("party") as PartyManager
    var cold_party := cold_fixture.get("party") as PartyManager
    if warm_party == null or cold_party == null:
        if warm_party != null:
            warm_party.free()
        if cold_party != null:
            cold_party.free()
        return
    var action_tags: Array[StringName] = [&"melee", &"physical"]
    var warm_second_base := warm_party.stats_for(2)
    var warm_second_action := warm_party.stats_for_action(2, action_tags)
    var warm_second_weapon_before := _weapon_document(warm_party.active_weapon_snapshot(2))
    var warm_revision_before := warm_party.stat_revision()
    var cold_revision_before := cold_party.stat_revision()
    var warm_events: Array[int] = []
    var cold_events: Array[int] = []
    warm_party.stats_changed.connect(func(member_id: int) -> void: warm_events.append(member_id))
    cold_party.stats_changed.connect(func(member_id: int) -> void: cold_events.append(member_id))
    TestAssertions.truthy(_commit_member_one_growth(warm_fixture), "warm member-local mutation commits", failures)
    TestAssertions.truthy(_commit_member_one_growth(cold_fixture), "cold member-local mutation commits", failures)
    TestAssertions.equal(warm_party.stat_revision(), warm_revision_before + 1, "warm member-local mutation advances global revision once", failures)
    TestAssertions.equal(cold_party.stat_revision(), cold_revision_before + 1, "cold member-local mutation advances global revision once", failures)
    TestAssertions.equal(warm_events, [1], "warm member-local mutation signals only member one", failures)
    TestAssertions.equal(cold_events, [1], "cold member-local mutation signals only member one", failures)
    TestAssertions.truthy(is_same(warm_party.stats_for(2), warm_second_base), "warm member-two base cache identity remains exact", failures)
    TestAssertions.truthy(is_same(warm_party.stats_for_action(2, action_tags), warm_second_action), "warm member-two action cache identity remains exact", failures)
    TestAssertions.equal(_weapon_document(warm_party.active_weapon_snapshot(2)), warm_second_weapon_before, "warm member-two weapon remains byte-equivalent", failures)
    var cold_second_base := cold_party.stats_for(2)
    var cold_second_action := cold_party.stats_for_action(2, action_tags)
    var warm_second_weapon := warm_party.active_weapon_snapshot(2)
    var cold_second_weapon := cold_party.active_weapon_snapshot(2)
    TestAssertions.equal(cold_second_base.revision, warm_second_base.revision, "cold member-two base uses the same effective revision as warm cache", failures)
    TestAssertions.equal(cold_second_action.revision, warm_second_action.revision, "cold member-two action uses the same effective revision as warm cache", failures)
    TestAssertions.equal(cold_second_base.revision, cold_second_weapon.revision, "cold member-two base and weapon revisions agree", failures)
    TestAssertions.equal(cold_second_action.revision, cold_second_weapon.revision, "cold member-two action and weapon revisions agree", failures)
    TestAssertions.equal(_resolved_snapshot_document(cold_second_base), _resolved_snapshot_document(warm_second_base), "cold and warm member-two base snapshots are identical", failures)
    TestAssertions.equal(_resolved_snapshot_document(cold_second_action), _resolved_snapshot_document(warm_second_action), "cold and warm member-two action snapshots are identical", failures)
    TestAssertions.equal(_weapon_document(cold_second_weapon), _weapon_document(warm_second_weapon), "cold and warm member-two weapons are identical", failures)
    for party: PartyManager in [warm_party, cold_party]:
        var member_one_weapon := party.active_weapon_snapshot(1)
        TestAssertions.equal(member_one_weapon.revision, party.stat_revision(), "changed member-one weapon is restamped to the new global revision", failures)
        TestAssertions.equal(party.stats_for(1).revision, member_one_weapon.revision, "changed member-one base and weapon revisions agree", failures)
        TestAssertions.equal(party.stats_for_action(1, action_tags).revision, member_one_weapon.revision, "changed member-one action and weapon revisions agree", failures)
    warm_party.unbind_member_source_refresh_coordinator(warm_fixture["coordinator"], warm_fixture["authority"])
    cold_party.unbind_member_source_refresh_coordinator(cold_fixture["coordinator"], cold_fixture["authority"])
    warm_party.free()
    cold_party.free()

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

func _two_equipped_member_fixture(failures: Array[String], label: String) -> Dictionary:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    if not party.recruit(catalog.class_by_id(&"fighter")):
        TestAssertions.truthy(false, "%s revision fixture recruits member two" % label, failures)
        party.free()
        return {}
    var probe := CoordinatorProbe.new()
    var coordinator := Callable(probe, "refresh")
    var authority := _bind_equipment_authority(party, coordinator)
    var candidate_revision := party.stat_revision() + 1
    var accepted := party.replace_member_equipment_projections_atomically({
        1: {
            "source": _equipment_source(1, 2.0),
            "weapon": _weapon_snapshot(1, "revision-weapon-1", &"forge_vanguard_sword", candidate_revision),
        },
        2: {
            "source": _equipment_source(2, 3.0),
            "weapon": _weapon_snapshot(2, "revision-weapon-2", &"forge_vanguard_sword", candidate_revision),
        },
    }, authority)
    TestAssertions.equal(accepted, 0, "%s revision fixture publishes two weapons" % label, failures)
    if accepted != 0:
        party.unbind_member_source_refresh_coordinator(coordinator, authority)
        party.free()
        return {}
    return {
        "party": party,
        "probe": probe,
        "coordinator": coordinator,
        "authority": authority,
    }

func _warm_party_caches(party: PartyManager) -> Dictionary:
    var result: Dictionary = {}
    for member: PartyMemberState in party.members:
        result[member.member_id] = {
            "base": party.stats_for(member.member_id),
            "action": party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags),
        }
    return result

func _assert_all_member_revision_state(
    party: PartyManager,
    revision_before: int,
    caches_before: Dictionary,
    events: Array[int],
    label: String,
    failures: Array[String],
) -> void:
    var expected_revision := revision_before + 1
    var expected_events: Array[int] = []
    for member: PartyMemberState in party.members:
        expected_events.append(member.member_id)
    TestAssertions.equal(party.stat_revision(), expected_revision, "%s advances the global revision once" % label, failures)
    TestAssertions.equal(events, expected_events, "%s signals every current member exactly once" % label, failures)
    for member: PartyMemberState in party.members:
        var base := party.stats_for(member.member_id)
        var action := party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags)
        TestAssertions.equal(base.revision, expected_revision, "%s member %d base uses the new member revision" % [label, member.member_id], failures)
        TestAssertions.equal(action.revision, expected_revision, "%s member %d action uses the new member revision" % [label, member.member_id], failures)
        if caches_before.has(member.member_id):
            var previous := caches_before[member.member_id] as Dictionary
            TestAssertions.truthy(not is_same(base, previous["base"]), "%s member %d base cache is invalidated" % [label, member.member_id], failures)
            TestAssertions.truthy(not is_same(action, previous["action"]), "%s member %d action cache is invalidated" % [label, member.member_id], failures)
        var weapon := party.active_weapon_snapshot(member.member_id)
        if member.member_id <= 2:
            TestAssertions.truthy(weapon != null, "%s member %d retains an active weapon" % [label, member.member_id], failures)
            if weapon != null:
                TestAssertions.equal(weapon.revision, expected_revision, "%s member %d weapon is restamped" % [label, member.member_id], failures)

func _commit_member_one_growth(fixture: Dictionary) -> bool:
    var party := fixture.get("party") as PartyManager
    if party == null:
        return false
    var equipment_source: StatModifierSource
    for source: StatModifierSource in party.member_by_id(1).modifier_sources:
        if source != null and source.source_type == &"equipment":
            equipment_source = source
            break
    var weapon := party.active_weapon_snapshot(1)
    if equipment_source == null or weapon == null:
        return false
    var restamped_weapon := ActiveWeaponDamageSnapshot.create(
        weapon.member_id,
        weapon.item_id,
        weapon.base_id,
        weapon.components,
        party.stat_revision() + 1,
    )
    return party.replace_member_source_with_equipment_atomically(
        1,
        _growth_source(1, &"member_revision_growth", 2.0),
        equipment_source,
        restamped_weapon,
        fixture.get("authority") as RefCounted,
    )

func _resolved_snapshot_document(snapshot: ResolvedStatSnapshot) -> String:
    if snapshot == null:
        return "null"
    var values: Dictionary = {}
    var breakdowns: Dictionary = {}
    for definition: StatDefinition in PartyManager.STAT_CATALOG.all():
        values[String(definition.id)] = snapshot.value(definition.id)
        breakdowns[String(definition.id)] = snapshot.breakdown(definition.id)
    var capabilities := PackedStringArray()
    for capability: StringName in snapshot.capabilities:
        capabilities.append(String(capability))
    capabilities.sort()
    return JSON.stringify({
        "revision": snapshot.revision,
        "capabilities": capabilities,
        "values": values,
        "breakdowns": breakdowns,
    })

func _method_argument_count(instance: Object, method_name: StringName) -> int:
    for method: Dictionary in instance.get_method_list():
        if StringName(method.get("name", "")) == method_name:
            return (method.get("args", []) as Array).size()
    return -1

func _bind_equipment_authority(party: PartyManager, coordinator: Callable) -> RefCounted:
    var probe := coordinator.get_object() as CoordinatorProbe
    if probe == null:
        return null
    probe.party = party
    return party.bind_member_source_refresh_coordinator(coordinator, Callable(probe, "validate"))

func _equipment_source(member_id: int, strength: float) -> StatModifierSource:
    var source_id := StringName("equipment_member_%d" % member_id)
    return StatModifierSource.create(source_id, &"equipment", "Equipment", member_id, [
        StatModifier.create(&"strength", StatModifier.Operation.FLAT, strength, StringName("equipment_strength_%d" % member_id), "Equipment"),
    ])


func _weapon_snapshot(member_id: int, item_id: String, base_id: StringName, revision: int) -> ActiveWeaponDamageSnapshot:
    return ActiveWeaponDamageSnapshot.create(
        member_id,
        item_id,
        base_id,
        [ItemBaseDamageComponent.create(&"physical", 4.0, 8.0)],
        revision,
    )


func _weapon_document(snapshot: ActiveWeaponDamageSnapshot) -> String:
    if snapshot == null:
        return "null"
    var components: Array[Dictionary] = []
    for component: ItemBaseDamageComponent in snapshot.components:
        components.append(component.to_dictionary())
    return JSON.stringify({
        "member_id": snapshot.member_id,
        "item_id": snapshot.item_id,
        "base_id": String(snapshot.base_id),
        "revision": snapshot.revision,
        "components": components,
    })

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

func _test_caster_party_upgrade_rejects_future_mage_atomically(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var definition := _task10t_party_upgrade(&"task10t_caster_overflow", [
        _task10t_effect(&"damage", StatModifier.Operation.INCREASED, 1.0e308, [&"caster"]),
        _task10t_effect(&"damage", StatModifier.Operation.INCREASED, 1.0e308, [&"caster"]),
    ])
    catalog.upgrades.append(definition)
    var party := PartyManager.new()
    party.configure_identity(8181, catalog.generic_name_pool)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.truthy(UpgradeApplicationService.apply(definition.id, catalog, party), "caster-only overflow upgrade is safe for current Fighter", failures)
    _assert_recruit_rejected_atomically(party, catalog.class_by_id(&"mage"), "future canonical Mage caster overflow", failures)
    party.free()

func _test_composition_trait_overflow_rejects_recruit_atomically(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var trait_definition := _task10t_trait(&"task10t_direct_overflow", 1.7e308)
    var class_definition := _task10t_trait_class(catalog, &"task10t_direct_class", trait_definition.id)
    class_definition.base_stat_overrides[&"attack_speed"] = 2.0
    var traits: Array[TraitDefinition] = [trait_definition]
    var party := PartyManager.new()
    party.initialize(class_definition, traits)
    _assert_recruit_rejected_atomically(party, class_definition, "composition-triggered trait overflow", failures)
    party.free()

func _test_later_existing_member_failure_rejects_recruit_atomically(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var trait_definition := _task10t_trait(&"task10t_later_overflow", 1.0e109)
    var special := _task10t_trait_class(catalog, &"task10t_later_class", trait_definition.id)
    var traits: Array[TraitDefinition] = [trait_definition]
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), traits)
    TestAssertions.truthy(party.recruit(special), "later-member fixture installs first trait member", failures)
    var source_id := &"task10t_later_growth"
    TestAssertions.truthy(party.add_member_source(2, StatModifierSource.create(source_id, &"character_growth", "Later Growth", 2, [
        StatModifier.create(&"attack_speed", StatModifier.Operation.MORE, 1.0e100, &"task10t_later_growth_a", "Later Growth A"),
        StatModifier.create(&"attack_speed", StatModifier.Operation.MORE, 1.0e100, &"task10t_later_growth_b", "Later Growth B"),
    ])), "later existing member holds an individually finite source", failures)
    _assert_recruit_rejected_atomically(party, special, "later existing-member prospective failure", failures)
    party.free()

func _test_finite_party_upgrade_reaches_future_recruit(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var fighter := catalog.class_by_id(&"fighter")
    var party := PartyManager.new()
    party.initialize(fighter, catalog.traits)
    TestAssertions.truthy(UpgradeApplicationService.apply(&"vanguard_wall", catalog, party), "finite Vanguard party upgrade applies before recruitment", failures)
    var revision_before := party.stat_revision()
    var leader_cache := party.stats_for(1)
    TestAssertions.truthy(party.recruit(fighter), "future Vanguard recruit passes prospective validation", failures)
    TestAssertions.equal(party.stat_revision(), revision_before + 1, "future-upgrade recruit advances one revision", failures)
    TestAssertions.truthy(not is_same(party.stats_for(1), leader_cache), "future-upgrade recruit invalidates the existing cache once", failures)
    TestAssertions.near(party.stats_for(2).value(&"armor"), fighter.armor + 3.0, 0.001, "future recruit inherits finite flat party effect", failures)
    TestAssertions.near(party.stats_for(2).value(&"max_health"), fighter.max_health * 1.10, 0.001, "future recruit inherits finite increased party effect", failures)
    party.free()

func _test_trait_tier_recruit_signal_order_and_single_invalidation(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var fighter := catalog.class_by_id(&"fighter")
    var party := PartyManager.new()
    party.initialize(fighter, catalog.traits)
    var revision_before := party.stat_revision()
    var events: Array[String] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append("stats:%d" % member_id))
    party.active_traits_changed.connect(func(_tiers: Dictionary) -> void: events.append("traits"))
    party.member_added.connect(func(member: PartyMemberState) -> void: events.append("member:%d" % member.member_id))
    TestAssertions.truthy(party.recruit(fighter), "legitimate trait-tier-changing recruit succeeds", failures)
    TestAssertions.equal(party.stat_revision(), revision_before + 1, "trait-tier recruit performs one shared invalidation", failures)
    TestAssertions.equal(events, ["stats:1", "stats:2", "traits", "member:2"], "trait-tier recruit preserves exact signal ordering", failures)
    TestAssertions.equal(party.active_tier(&"martial"), 2, "trait-tier recruit publishes Martial tier two", failures)
    TestAssertions.equal(party.active_tier(&"vanguard"), 2, "trait-tier recruit publishes Vanguard tier two", failures)
    party.free()

func _test_recruit_input_rejections_preserve_state(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var invalid_party := PartyManager.new()
    invalid_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    _assert_recruit_rejected_atomically(invalid_party, null, "null recruit definition", failures)
    invalid_party.free()

    var capacity_party := PartyManager.new()
    capacity_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    capacity_party.configure_capacity(PartyCapacityPolicy.new(1))
    _assert_recruit_rejected_atomically(capacity_party, catalog.class_by_id(&"ranger"), "capacity rejection", failures)
    capacity_party.free()

func _assert_recruit_rejected_atomically(
    party: PartyManager,
    definition: ClassDefinition,
    label: String,
    failures: Array[String],
) -> void:
    var members_before := _task10t_member_document(party)
    var class_ranks_before := _task10t_dictionary_document(party.class_ranks)
    var active_tiers_before := _task10t_dictionary_document(party.active_tiers)
    var upgrades_before := _task10t_party_upgrade_document(party)
    var definition_before := _task10t_class_document(definition)
    var revision_before := party.stat_revision()
    var capacity_before := party.capacity()
    var can_recruit_before := party.can_recruit()
    var base_before: Dictionary = {}
    var action_before: Dictionary = {}
    var actors: Dictionary = {}
    var health_before: Dictionary = {}
    var member_ids_before: Array[int] = []
    for member: PartyMemberState in party.members:
        member_ids_before.append(member.member_id)
        base_before[member.member_id] = party.stats_for(member.member_id)
        action_before[member.member_id] = party.stats_for_action(member.member_id, member.class_definition.primary_attack.action_tags)
        var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
        actor.configure(member)
        actor.configure_combat(party)
        var health := actor.get_node("HealthComponent") as HealthComponent
        actors[member.member_id] = actor
        health_before[member.member_id] = Vector2(health.current_health, health.max_health)
    var events: Array[String] = []
    party.stats_changed.connect(func(member_id: int) -> void: events.append("stats:%d" % member_id))
    party.active_traits_changed.connect(func(_tiers: Dictionary) -> void: events.append("traits"))
    party.member_added.connect(func(member: PartyMemberState) -> void: events.append("member:%d" % member.member_id))

    TestAssertions.truthy(not party.recruit(definition), "%s rejects before publication" % label, failures)
    TestAssertions.equal(_task10t_member_document(party), members_before, "%s preserves exact members, names, IDs, and sources" % label, failures)
    TestAssertions.equal(_task10t_dictionary_document(party.class_ranks), class_ranks_before, "%s preserves class ranks" % label, failures)
    TestAssertions.equal(_task10t_dictionary_document(party.active_tiers), active_tiers_before, "%s preserves active trait tiers" % label, failures)
    TestAssertions.equal(_task10t_party_upgrade_document(party), upgrades_before, "%s preserves party upgrade state" % label, failures)
    TestAssertions.equal(_task10t_class_document(definition), definition_before, "%s preserves caller class resource" % label, failures)
    TestAssertions.equal(party.stat_revision(), revision_before, "%s preserves revision" % label, failures)
    TestAssertions.equal(party.capacity(), capacity_before, "%s preserves configured capacity" % label, failures)
    TestAssertions.equal(party.can_recruit(), can_recruit_before, "%s preserves remaining-capacity result" % label, failures)
    for member_id: int in member_ids_before:
        var member := party.member_by_id(member_id)
        TestAssertions.truthy(is_same(party.stats_for(member_id), base_before[member_id]), "%s preserves member %d base cache identity" % [label, member_id], failures)
        TestAssertions.truthy(is_same(party.stats_for_action(member_id, member.class_definition.primary_attack.action_tags), action_before[member_id]), "%s preserves member %d action cache identity" % [label, member_id], failures)
        var health := (actors[member_id] as PartyActor).get_node("HealthComponent") as HealthComponent
        TestAssertions.equal(Vector2(health.current_health, health.max_health), health_before[member_id], "%s preserves member %d actor health" % [label, member_id], failures)
    TestAssertions.equal(events, [], "%s emits no recruit, trait, or stat signal" % label, failures)
    for actor_value: Variant in actors.values():
        (actor_value as PartyActor).free()

func _task10t_party_upgrade(id: StringName, effects: Array[UpgradeEffectDefinition]) -> UpgradeDefinition:
    var definition := UpgradeDefinition.new()
    definition.id = id
    definition.display_name = String(id).capitalize()
    definition.summary = "Task 10T fixture"
    definition.description = "Task 10T fixture"
    definition.scope = UpgradeDefinition.Scope.PARTY
    definition.max_rank = 1
    definition.effects = effects
    return definition

func _task10t_effect(
    stat_id: StringName,
    operation: int,
    value: float,
    required_capabilities: Array[StringName] = [],
) -> StatUpgradeEffect:
    var effect := StatUpgradeEffect.new()
    effect.stat_id = stat_id
    effect.operation = operation
    effect.value_per_rank = value
    effect.source_label = "Task 10T Fixture"
    effect.required_capability_tags = required_capabilities
    return effect

func _task10t_trait(id: StringName, tier_value: float) -> TraitDefinition:
    var definition := TraitDefinition.new()
    definition.id = id
    definition.display_name = String(id).capitalize()
    definition.stat_id = &"attack_speed"
    definition.tiers = {2: tier_value}
    return definition

func _task10t_trait_class(catalog: GameCatalog, id: StringName, trait_id: StringName) -> ClassDefinition:
    var definition := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
    definition.id = id
    definition.display_name = String(id).capitalize()
    definition.traits = [trait_id]
    definition.base_stat_overrides = definition.base_stat_overrides.duplicate(true)
    return definition

func _task10t_member_document(party: PartyManager) -> String:
    var rows: Array[Dictionary] = []
    for member: PartyMemberState in party.members:
        rows.append({
            "member_id": member.member_id,
            "character_name": member.character_name,
            "class_id": String(member.class_definition.id),
            "is_leader": member.is_leader,
            "capability_tags": member.capability_tags,
            "upgrade_ranks": _task10t_dictionary_document(member.upgrade_ranks),
            "sources": _member_source_documents(member),
        })
    return JSON.stringify(rows)

func _task10t_dictionary_document(dictionary: Dictionary) -> String:
    var keys: Array[String] = []
    for key_value: Variant in dictionary:
        keys.append(String(key_value))
    keys.sort()
    var rows: Array[Dictionary] = []
    for key: String in keys:
        rows.append({"key": key, "value": dictionary[StringName(key)]})
    return JSON.stringify(rows)

func _task10t_party_upgrade_document(party: PartyManager) -> String:
    var ranks := party.get("_party_upgrade_ranks") as Dictionary
    var definitions := party.get("_party_upgrade_definitions") as Dictionary
    var sources := party.get("_party_upgrade_sources") as Dictionary
    var ids: Array[String] = []
    for id_value: Variant in ranks:
        ids.append(String(id_value))
    ids.sort()
    var rows: Array[Dictionary] = []
    for id: String in ids:
        var definition := definitions[StringName(id)] as UpgradeDefinition
        rows.append({
            "id": id,
            "rank": int(ranks[StringName(id)]),
            "definition_instance": definition.get_instance_id(),
            "source": _modifier_source_document(sources[StringName(id)] as StatModifierSource),
        })
    return JSON.stringify(rows)

func _task10t_class_document(definition: ClassDefinition) -> String:
    if definition == null:
        return "<null>"
    return JSON.stringify({
        "id": String(definition.id),
        "display_name": definition.display_name,
        "traits": definition.traits,
        "capability_tags": definition.capability_tags,
        "base_stat_overrides": definition.base_stat_overrides,
        "max_health": definition.max_health,
        "armor": definition.armor,
        "move_speed": definition.move_speed,
        "class_rank_power_step": definition.class_rank_power_step,
        "primary_attack": definition.primary_attack.get_instance_id() if definition.primary_attack != null else 0,
        "support_action": definition.support_action.get_instance_id() if definition.support_action != null else 0,
    })

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
