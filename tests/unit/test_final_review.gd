extends RefCounted

const PARTY_STAT_IDS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]

var _profile_root := ""

func run() -> Array[String]:
    var failures: Array[String] = []
    _profile_root = "user://tests/final_review-profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
    ProfileTestSupport.remove_tree(_profile_root)
    print("FINAL_REVIEW_TEST resource")
    _test_resource_tunables_and_trait_validation(failures)
    _test_typed_party_delivery_source_contract(failures)
    print("FINAL_REVIEW_TEST party_stats")
    _test_party_stat_runtime_effects(failures)
    print("FINAL_REVIEW_TEST trait_upgrade")
    _test_trait_upgrade_runtime_effects(failures)
    print("FINAL_REVIEW_TEST vanguard")
    _test_vanguard_available_origin(failures)
    print("FINAL_REVIEW_TEST divine")
    _test_divine_healing_and_actual_revive(failures)
    print("FINAL_REVIEW_TEST enemy_health")
    _test_enemy_health_component_and_bars(failures)
    print("FINAL_REVIEW_TEST charge")
    _test_charge_telegraph_lifecycle(failures)
    print("FINAL_REVIEW_TEST unknown")
    _test_unknown_enemy_id(failures)
    print("FINAL_REVIEW_TEST sandbox")
    _test_sandbox_hostile_effect_cleanup(failures)
    print("FINAL_REVIEW_TEST done")
    ProfileTestSupport.remove_tree(_profile_root)
    return failures

func _test_resource_tunables_and_trait_validation(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    for definition: ClassDefinition in catalog.classes:
        for property_name: StringName in [&"class_rank_power_step", &"revive_delay", &"revive_health_fraction"]:
            TestAssertions.truthy(_has_property(definition, property_name), "%s exposes %s tuning" % [definition.id, property_name], failures)
        if _has_property(definition, &"class_rank_power_step"):
            TestAssertions.near(float(definition.get("class_rank_power_step")), 0.2, 0.001, "%s rank power step remains exact" % definition.id, failures)
        if _has_property(definition, &"revive_delay"):
            TestAssertions.near(float(definition.get("revive_delay")), 8.0, 0.001, "%s revive delay remains exact" % definition.id, failures)
        if _has_property(definition, &"revive_health_fraction"):
            TestAssertions.near(float(definition.get("revive_health_fraction")), 0.5, 0.001, "%s revive fraction remains exact" % definition.id, failures)

    var malformed := TraitDefinition.new()
    malformed.id = &"malformed"
    malformed.display_name = "Malformed"
    malformed.stat_id = &"unsupported_optional_effect"
    malformed.tiers = {2: 0.1}
    var reasons := malformed.validate()
    TestAssertions.truthy(reasons.has("trait malformed unsupported stat id unsupported_optional_effect"), "unsupported trait effect validation is grep-friendly", failures)
    var malformed_catalog := GameCatalog.new()
    malformed_catalog.traits.append(malformed)
    var catalog_errors := malformed_catalog.validate()
    TestAssertions.truthy(catalog_errors.has("PARTY_FORGE_RESOURCE_ERROR id=malformed reason=trait malformed unsupported stat id unsupported_optional_effect"), "catalog excludes malformed optional trait effect", failures)

func _test_typed_party_delivery_source_contract(failures: Array[String]) -> void:
    var executor_source := FileAccess.get_file_as_string("res://scripts/combat/attack_executor.gd")
    var projectile_source := FileAccess.get_file_as_string("res://scripts/combat/projectile.gd")
    var area_source := FileAccess.get_file_as_string("res://scripts/combat/area_burst.gd")
    var modifiers_source := FileAccess.get_file_as_string("res://scripts/combat/combat_modifiers.gd")
    var party_actor_source := FileAccess.get_file_as_string("res://scripts/characters/party_actor.gd")
    TestAssertions.truthy(not executor_source.contains("_legacy_damage_amount"), "typed executor removes temporary legacy damage bridge", failures)
    TestAssertions.truthy(executor_source.contains("DamageResolver.resolve"), "typed executor resolves packets", failures)
    TestAssertions.truthy(not projectile_source.contains("var damage :="), "party projectile stores packet instead of scalar damage", failures)
    TestAssertions.truthy(not area_source.contains("var damage :="), "area burst stores packet instead of scalar damage", failures)
    TestAssertions.truthy(not modifiers_source.contains("power_multiplier"), "combat movement facade carries no damaging power", failures)
    var recovery_index := party_actor_source.find("recovery_controller.advance(delta)")
    var attack_index := party_actor_source.find("advance_combat(delta, _collect_combat_targets())")
    TestAssertions.truthy(recovery_index >= 0 and attack_index > recovery_index, "party actor advances recovery before attacks", failures)

func _test_party_stat_runtime_effects(failures: Array[String]) -> void:
    var main := _started_main(&"fighter")
    var party := main.get_node("PartyManager") as PartyManager
    var leader := main.get("leader") as PartyActor
    var health := leader.get_node("HealthComponent") as HealthComponent
    var required_methods: PackedStringArray = ["upgrade_party_stat", "party_stat_rank", "party_stat_multiplier"]
    var has_all_methods := true
    for method_name: String in required_methods:
        TestAssertions.truthy(party.has_method(method_name), "PartyManager owns %s" % method_name, failures)
        has_all_methods = has_all_methods and party.has_method(method_name)
    if not has_all_methods:
        _free_main(main)
        return

    TestAssertions.truthy(party.call("upgrade_party_stat", &"max_health"), "max-health upgrade applies", failures)
    TestAssertions.near(float(party.call("party_stat_multiplier", &"max_health")), 1.05, 0.001, "max-health upgrade multiplier", failures)
    TestAssertions.near(health.max_health, 273.0, 0.001, "max-health upgrade immediately updates existing leader", failures)
    TestAssertions.near(health.current_health, 260.0, 0.001, "max-health upgrade grants no free healing", failures)

    TestAssertions.truthy(party.call("upgrade_party_stat", &"damage"), "damage upgrade applies", failures)
    TestAssertions.truthy(party.has_method("stats_for_action"), "damage upgrade exposes action-aware stats", failures)
    if party.has_method("stats_for_action"):
        var damage_tags: Array[StringName] = [&"melee", &"physical"]
        var damage_stats := party.call("stats_for_action", party.members[0].member_id, damage_tags) as ResolvedStatSnapshot
        TestAssertions.near(damage_stats.value(&"damage"), 1.05, 0.001, "damage upgrade changes resolver source stats", failures)

    TestAssertions.truthy(party.call("upgrade_party_stat", &"move_speed"), "move-speed upgrade applies", failures)
    TestAssertions.near(leader.move_speed, 6.39, 0.001, "resolved move-speed upgrade immediately updates existing leader", failures)

    TestAssertions.truthy(party.call("upgrade_party_stat", &"attack_speed"), "attack-speed upgrade applies", failures)
    var attack_modifiers := CombatModifiers.resolve(party.members[0], party)
    TestAssertions.near(float(attack_modifiers.get("cooldown_rate_multiplier")), 1.04, 0.001, "attack-speed upgrade changes cooldown rate", failures)
    TestAssertions.near(float(attack_modifiers.get("range_multiplier")), 1.0, 0.001, "context-free combat modifiers do not expose attack range", failures)
    TestAssertions.near(float(attack_modifiers.get("area_multiplier")), 1.0, 0.001, "context-free combat modifiers do not expose area size", failures)
    TestAssertions.near(float(attack_modifiers.get("projectile_multiplier")), 1.0, 0.001, "context-free combat modifiers do not expose projectile speed", failures)

    var effects := main.get_node("Effects") as Node3D
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
    effects.add_child(orb)
    orb.call("configure", 1, leader, main.get_node("ExperienceSystem"), 1.0)
    TestAssertions.truthy(party.call("upgrade_party_stat", &"pickup_radius"), "pickup-radius upgrade applies", failures)
    main.call("_sync_pickup_radius")
    TestAssertions.near(float(party.call("party_stat_multiplier", &"pickup_radius")), 1.2, 0.001, "pickup-radius upgrade multiplier", failures)
    TestAssertions.near(float(orb.get("pickup_radius_multiplier")), 1.2, 0.001, "pickup-radius upgrade immediately updates existing orb", failures)

    TestAssertions.truthy(party.recruit(main.get("catalog").class_by_id(&"ranger")), "future-member setup recruit succeeds", failures)
    var actors := main.get_node("Actors").get_children()
    var ranger := actors[actors.size() - 1] as PartyActor
    var ranger_health := ranger.get_node("HealthComponent") as HealthComponent
    TestAssertions.near(ranger.move_speed, 6.80, 0.001, "future recruit receives resolved move-speed upgrade", failures)
    TestAssertions.near(ranger_health.max_health, 95.0, 0.001, "future recruit receives resolved max-health upgrade", failures)

    for stat_id: StringName in PARTY_STAT_IDS:
        while int(party.call("party_stat_rank", stat_id)) < 20:
            party.call("upgrade_party_stat", stat_id)
        TestAssertions.truthy(not party.call("upgrade_party_stat", stat_id), "%s rank 20 remains capped" % stat_id, failures)
    TestAssertions.truthy(not main.call("_choice_is_valid", UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, &"damage", "Damage")), "capped PartyManager stat is invalid choice", failures)
    _free_main(main)

func _test_trait_upgrade_runtime_effects(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"mage"), catalog.traits)
    party.recruit(catalog.class_by_id(&"mage"))
    for method_name: String in ["upgrade_trait", "trait_upgrade_rank", "effective_trait_value"]:
        TestAssertions.truthy(party.has_method(method_name), "PartyManager owns %s" % method_name, failures)
    if not party.has_method("upgrade_trait") or not party.has_method("effective_trait_value"):
        party.free()
        return
    var before := CombatModifiers.resolve_for_action(party.members[0], party, catalog.class_by_id(&"mage").primary_attack)
    TestAssertions.near(float(before.get("area_multiplier")), 1.18, 0.001, "base active Arcane effect", failures)
    TestAssertions.truthy(party.call("upgrade_trait", &"arcane"), "active Arcane upgrade applies", failures)
    TestAssertions.equal(int(party.call("trait_upgrade_rank", &"arcane")), 1, "trait upgrade rank centralized", failures)
    TestAssertions.near(float(party.call("effective_trait_value", &"arcane")), 0.225, 0.001, "trait upgrade scales selected active value", failures)
    var after := CombatModifiers.resolve_for_action(party.members[0], party, catalog.class_by_id(&"mage").primary_attack)
    TestAssertions.near(float(after.get("area_multiplier")), 1.23, 0.001, "trait selection changes resolved rounded area result", failures)
    TestAssertions.truthy(not party.call("upgrade_trait", &"divine"), "inactive trait cannot upgrade", failures)
    party.free()

func _test_vanguard_available_origin(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    var root := _new_root("VanguardReviewTest")
    root.add_child(party)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(catalog.class_by_id(&"fighter"))
    party.recruit(catalog.class_by_id(&"ranger"))
    party.call("configure_combat", CombatRng.new(201), catalog.damage_types)
    TestAssertions.truthy(party.has_method("incoming_damage_multiplier"), "PartyManager owns nearby Vanguard query", failures)
    if not party.has_method("incoming_damage_multiplier"):
        root.free()
        return
    var vanguard := _actor_for_member(root, party, party.members[1], Vector3.ZERO)
    var ally := _actor_for_member(root, party, party.members[2], Vector3(3.0, 0.0, 0.0))
    var ally_health := ally.get_node("HealthComponent") as HealthComponent
    TestAssertions.near(float(party.call("incoming_damage_multiplier", ally)), 0.88, 0.001, "near available Vanguard protects ally", failures)
    TestAssertions.truthy(ally.has_method("get_combat_adapter"), "party actor exposes combat adapter", failures)
    if ally.has_method("get_combat_adapter"):
        var physical_tags: Array[StringName] = [&"physical"]
        var adapter := ally.call("get_combat_adapter", physical_tags) as CombatantAdapter
        TestAssertions.equal(adapter.combatant_id, &"party:3", "party adapter uses stable member identity", failures)
        TestAssertions.near(adapter.incoming_damage_multiplier(null), 0.88, 0.001, "Vanguard multiplier exists on combat adapter", failures)
    var swarmer := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as EnemyActor
    swarmer.configure(swarmer.definition)
    swarmer.configure_combat(&"vanguard_audit", party.combat_rng, catalog.damage_types)
    var contact_packet := swarmer.prepare_attack(&"swarmer_contact")
    var contact_result := swarmer.resolve_attack(contact_packet, ally.get_combat_adapter(contact_packet.action_tags))
    TestAssertions.truthy(contact_result.valid, "authored contact attack resolves through typed combat", failures)
    TestAssertions.near(contact_result.incoming_multiplier, 0.88, 0.001, "typed damage applies nearby Vanguard", failures)
    TestAssertions.near(ally_health.current_health, 90.0 - 8.0 * 100.0 / 101.0 * 0.88, 0.001, "typed contact applies armor and Vanguard in resolver order", failures)
    swarmer.free()
    ally.position = Vector3(7.0, 0.0, 0.0)
    TestAssertions.near(float(party.call("incoming_damage_multiplier", ally)), 1.0, 0.001, "far Vanguard gives no protection", failures)
    ally.position = Vector3(3.0, 0.0, 0.0)
    var vanguard_health := vanguard.get_node("HealthComponent") as HealthComponent
    vanguard_health.apply_damage(9999.0)
    TestAssertions.equal(party.trait_count(&"vanguard"), 2, "downed Vanguard still counts toward active trait", failures)
    TestAssertions.near(float(party.call("incoming_damage_multiplier", ally)), 1.0, 0.001, "downed Vanguard cannot originate protection", failures)
    root.free()

func _test_divine_healing_and_actual_revive(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    var root := _new_root("DivineReviewTest")
    root.add_child(party)
    party.initialize(catalog.class_by_id(&"cleric"), catalog.traits)
    party.recruit(catalog.class_by_id(&"cleric"))
    party.recruit(catalog.class_by_id(&"ranger"))
    party.call("configure_combat", CombatRng.new(202), catalog.damage_types)
    TestAssertions.truthy(party.has_method("upgrade_trait"), "Divine upgrade uses centralized PartyManager ownership", failures)
    if not party.has_method("upgrade_trait"):
        root.free()
        return
    var cleric := _actor_for_member(root, party, party.members[0], Vector3.ZERO)
    var ranger := _actor_for_member(root, party, party.members[2], Vector3(2.0, 0.0, 0.0))
    var ranger_health := ranger.get_node("HealthComponent") as HealthComponent
    ranger_health.current_health = 40.0
    var executor := cleric.get_node("AttackExecutor") as Node
    var heal := catalog.class_by_id(&"cleric").support_action
    var combatants: Array[Node3D] = [cleric, ranger]
    executor.call("configure", cleric, party, root, combatants)
    executor.call("execute", heal, ranger.get_combat_target())
    TestAssertions.near(ranger_health.current_health, 40.0 + 18.0 * 1.33, 0.001, "active Divine and Support add into resolved healing", failures)
    party.call("upgrade_trait", &"divine")
    ranger_health.current_health = 40.0
    executor.call("execute", heal, ranger.get_combat_target())
    TestAssertions.near(ranger_health.current_health, 40.0 + 18.0 * 1.38, 0.001, "Divine upgrade further strengthens resolved healing", failures)

    ranger_health.current_health = ranger_health.max_health
    ranger_health.apply_damage(9999.0)
    TestAssertions.truthy(ranger_health.is_downed, "companion naturally enters downed lifecycle", failures)
    TestAssertions.near(ranger_health.revive_remaining, 6.2, 0.001, "upgraded Divine shortens configured revive delay", failures)
    ranger_health.advance_time(6.19)
    TestAssertions.truthy(ranger_health.is_downed, "companion remains downed before Divine-adjusted delay", failures)
    ranger_health.advance_time(0.01)
    TestAssertions.truthy(not ranger_health.is_downed, "companion revives at Divine-adjusted delay", failures)
    TestAssertions.near(ranger_health.current_health, ranger_health.max_health * 0.5, 0.001, "resource revive fraction controls actual revive health", failures)
    root.free()

func _test_enemy_health_component_and_bars(failures: Array[String]) -> void:
    for scene_path: String in ["res://scenes/enemies/swarmer.tscn", "res://scenes/enemies/spitter.tscn", "res://scenes/enemies/forge_guardian.tscn"]:
        var enemy := (load(scene_path) as PackedScene).instantiate() as Node3D
        var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
        TestAssertions.truthy(health != null, "%s scene owns HealthComponent" % scene_path, failures)
        if health != null:
            enemy.call("configure", enemy.get("definition"))
            var before := health.current_health
            health.apply_damage(1.0)
            TestAssertions.near(health.current_health, before - 1.0, 0.001, "%s shares HealthComponent state" % scene_path, failures)
            TestAssertions.near(float(enemy.get("current_health")), health.current_health, 0.001, "%s public health mirrors component" % scene_path, failures)
        enemy.free()

    var root := _new_root("EnemyRewardReviewTest")
    var swarmer := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(swarmer)
    var rewards: Array[int] = []
    swarmer.connect("reward_dropped", func(value: int, _position: Vector3) -> void: rewards.append(value))
    var swarmer_health := swarmer.get_node("HealthComponent") as HealthComponent
    swarmer_health.apply_damage(9999.0)
    swarmer_health.apply_damage(9999.0)
    swarmer.call("defeat")
    TestAssertions.equal(rewards.size(), 1, "shared enemy death drops reward exactly once", failures)

    var main := _started_main(&"fighter")
    var regular := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    main.get_node("Enemies").add_child(regular)
    main.call("_on_enemy_spawned", &"swarmer", regular)
    var regular_bar := regular.get_node_or_null("HealthBar3D") as Node3D
    TestAssertions.truthy(regular_bar != null, "regular enemy receives shared health bar", failures)
    if regular_bar != null:
        var before_text := (regular_bar.get_node("Label3D") as Label3D).text
        (regular.get_node("HealthComponent") as HealthComponent).apply_damage(6.0)
        TestAssertions.truthy((regular_bar.get_node("Label3D") as Label3D).text != before_text, "regular enemy bar updates from shared health flow", failures)
    main.call("_spawn_boss")
    var boss := main.get("boss") as Node3D
    TestAssertions.equal(boss.get("combatant_id"), &"enemy:boss", "boss receives stable combat id", failures)
    var boss_bar := boss.get_node_or_null("HealthBar3D") as Node3D
    TestAssertions.truthy(boss_bar != null, "boss receives shared billboard health bar", failures)
    if boss_bar != null:
        var boss_before := (boss_bar.get_node("Label3D") as Label3D).text
        (boss.get_node("HealthComponent") as HealthComponent).apply_damage(750.0)
        TestAssertions.truthy((boss_bar.get_node("Label3D") as Label3D).text != boss_before, "boss bar updates from shared health flow", failures)
    _free_main(main)
    root.free()

func _test_charge_telegraph_lifecycle(failures: Array[String]) -> void:
    var path := "res://scenes/effects/charge_telegraph.tscn"
    TestAssertions.truthy(ResourceLoader.exists(path), "camera-readable charge telegraph scene exists", failures)
    if not ResourceLoader.exists(path):
        return
    var root := _new_root("ChargeTelegraphReviewTest")
    var leader := _standalone_leader(root, Vector3(7.0, 0.0, 2.0))
    var effects := Node3D.new()
    root.add_child(effects)
    var boss := (load("res://scenes/enemies/forge_guardian.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(boss)
    boss.call("configure_combat", &"boss", CombatRng.new(1337), GameCatalog.load_defaults().damage_types)
    boss.call("configure_boss", leader, null, effects)
    boss.call("advance_behavior", 0.0)
    var pending: Array = boss.get("pending_charge_telegraphs") as Array
    TestAssertions.equal(pending.size(), 1, "charge creates one visible telegraph", failures)
    var marker := pending[0] as Node3D if not pending.is_empty() else null
    if marker != null:
        TestAssertions.equal(marker.position, Vector3(7.0, 0.0, 2.0), "charge marker samples leader position", failures)
        leader.position = Vector3(-4.0, 0.0, -3.0)
        boss.call("advance_behavior", 0.79)
        TestAssertions.truthy(not marker.is_queued_for_deletion(), "charge marker remains for first 0.79 seconds", failures)
        TestAssertions.equal(marker.position, Vector3(7.0, 0.0, 2.0), "charge marker sample is immutable", failures)
        boss.call("advance_behavior", 0.01)
        TestAssertions.truthy(marker.is_queued_for_deletion(), "charge marker clears at full 0.8-second telegraph", failures)
    boss.call("defeat")
    TestAssertions.equal((boss.get("pending_charge_telegraphs") as Array).size(), 0, "boss death cancels charge markers", failures)
    root.free()

func _test_unknown_enemy_id(failures: Array[String]) -> void:
    var root := _new_root("UnknownEnemyReviewTest")
    var marker := Marker3D.new()
    marker.position = Vector3(2.0, 0.0, 0.0)
    root.add_child(marker)
    var director := SpawnDirector.new()
    root.add_child(director)
    var markers: Array[Node3D] = [marker]
    director.configure(1, null, null, markers, null, root, root, 1.0, CombatRng.new(1), GameCatalog.load_defaults().damage_types)
    var before := root.get_child_count()
    var result := director.spawn_enemy(&"bogus")
    TestAssertions.equal(result, null, "unknown enemy id returns null", failures)
    TestAssertions.equal(root.get_child_count(), before, "unknown enemy id never falls through to Spitter", failures)
    TestAssertions.truthy(director.has_method("format_unknown_enemy_id"), "unknown enemy diagnostic formatter exists", failures)
    if director.has_method("format_unknown_enemy_id"):
        TestAssertions.equal(director.call("format_unknown_enemy_id", &"bogus"), "PARTY_FORGE_UNKNOWN_ENEMY_ID id=bogus", "unknown enemy diagnostic is grep-friendly", failures)
    root.free()

func _test_sandbox_hostile_effect_cleanup(failures: Array[String]) -> void:
    var sandbox := (load("res://scenes/dev/combat_sandbox.tscn") as PackedScene).instantiate()
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(sandbox)
    sandbox.call("_ready")
    var effects := sandbox.get_node("Effects") as Node3D
    var friendly := Node3D.new()
    friendly.name = "FriendlyEffect"
    effects.add_child(friendly)
    var hostile_projectile := (load("res://scenes/enemies/enemy_projectile.tscn") as PackedScene).instantiate() as Node3D
    effects.add_child(hostile_projectile)
    var danger := (load("res://scenes/effects/danger_ring.tscn") as PackedScene).instantiate() as Node3D
    effects.add_child(danger)
    var charge_path := "res://scenes/effects/charge_telegraph.tscn"
    var charge: Node3D
    if ResourceLoader.exists(charge_path):
        charge = (load(charge_path) as PackedScene).instantiate() as Node3D
        effects.add_child(charge)
    sandbox.call("spawn_enemy", &"swarmer")
    sandbox.call("clear_hostiles")
    TestAssertions.truthy(friendly != null and not friendly.is_queued_for_deletion(), "sandbox cleanup preserves friendly effects", failures)
    TestAssertions.truthy(hostile_projectile.is_in_group("hostile_transient_effects") and hostile_projectile.is_queued_for_deletion(), "sandbox cleanup clears hostile projectile by explicit group", failures)
    TestAssertions.truthy(danger.is_in_group("hostile_transient_effects") and danger.is_queued_for_deletion(), "sandbox cleanup clears danger effect by explicit group", failures)
    if charge != null:
        TestAssertions.truthy(charge.is_in_group("hostile_transient_effects") and charge.is_queued_for_deletion(), "sandbox cleanup clears charge effect by explicit group", failures)
    sandbox.free()
    tree.paused = false

func _started_main(class_id: StringName) -> Node:
    (Engine.get_main_loop() as SceneTree).paused = false
    var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate()
    main.set("profile_root", _profile_root)
    (Engine.get_main_loop() as SceneTree).root.add_child(main)
    main.call("_ready")
    var manager := main.get("profile_manager") as ProfileManager
    if manager.active_profile() == null:
        manager.create_profile("Test Profile")
    (main.get_node("SettingsScreen") as SettingsScreen).close()
    main.call("select_leader_class", class_id)
    return main

func _free_main(main: Node) -> void:
    (Engine.get_main_loop() as SceneTree).paused = false
    main.free()

func _new_root(root_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = root_name
    (Engine.get_main_loop() as SceneTree).root.add_child(root)
    return root

func _actor_for_member(parent: Node, party: PartyManager, member: PartyMemberState, actor_position: Vector3) -> PartyActor:
    var scene_path := "res://scenes/characters/leader.tscn" if member.is_leader else "res://scenes/characters/companion.tscn"
    var actor := (load(scene_path) as PackedScene).instantiate() as PartyActor
    parent.add_child(actor)
    actor.position = actor_position
    actor.configure(member)
    actor.configure_combat(party)
    return actor

func _standalone_leader(parent: Node, actor_position: Vector3) -> PartyActor:
    var catalog := GameCatalog.load_defaults()
    var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
    parent.add_child(actor)
    actor.position = actor_position
    actor.configure(PartyMemberState.new(1, catalog.class_by_id(&"fighter"), true))
    return actor

func _has_property(object: Object, property_name: StringName) -> bool:
    for property: Dictionary in object.get_property_list():
        if property["name"] == property_name:
            return true
    return false
