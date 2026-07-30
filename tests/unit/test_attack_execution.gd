extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/combat/attack_executor.gd",
    "res://scripts/combat/projectile.gd",
    "res://scripts/combat/timed_effect.gd",
    "res://scripts/combat/healing_selector.gd",
    "res://scripts/combat/combat_modifiers.gd",
    "res://scripts/combat/area_burst.gd",
    "res://scenes/combat/projectile.tscn",
    "res://scenes/combat/area_burst.tscn",
    "res://scenes/combat/heal_effect.tscn",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    var all_exist := true
    for path: String in REQUIRED_PATHS:
        var exists: bool = ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "Task 9 resource exists: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return failures

    _test_healing_selector(failures)
    _test_melee_execution(failures)
    _test_defender_resolution_order(failures)
    _test_automatic_melee_effective_range(failures)
    _test_projectile_contract(failures)
    _test_projectile_range_boundary(failures)
    _test_area_impact(failures)
    _test_multi_target_life_steal(failures)
    _test_cleric_healing(failures)
    _test_party_recovery(failures)
    _test_combat_modifiers(failures)
    _test_cleric_primary_fallback(failures)
    return failures

func _test_healing_selector(failures: Array[String]) -> void:
    var test_root := _new_test_root("HealingSelectorTest")
    var catalog := GameCatalog.load_defaults()
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    var moderately_injured := _create_actor(test_root, fighter, 1, Vector3(1.0, 0.0, 0.0))
    var most_injured := _create_actor(test_root, fighter, 1, Vector3(2.0, 0.0, 0.0))
    var downed := _create_actor(test_root, fighter, 1, Vector3(0.5, 0.0, 0.0))
    var dead := _create_actor(test_root, fighter, 1, Vector3(0.75, 0.0, 0.0), true)
    var out_of_range := _create_actor(test_root, fighter, 1, Vector3(20.0, 0.0, 0.0))
    var healthy := _create_actor(test_root, fighter, 1, Vector3(1.5, 0.0, 0.0))
    _set_health(moderately_injured, 100.0, 60.0)
    _set_health(most_injured, 200.0, 40.0)
    _set_health(downed, 100.0, 1.0, true, false)
    _set_health(dead, 100.0, 1.0, false, true)
    _set_health(out_of_range, 100.0, 1.0)
    _set_health(healthy, 100.0, 100.0)

    var candidates: Array[CombatTarget] = [
        moderately_injured.get_combat_target(),
        most_injured.get_combat_target(),
        downed.get_combat_target(),
        dead.get_combat_target(),
        out_of_range.get_combat_target(),
        healthy.get_combat_target(),
    ]
    var selector_script: Script = load("res://scripts/combat/healing_selector.gd") as Script
    TestAssertions.truthy(selector_script != null and selector_script.can_instantiate(), "healing selector parses", failures)
    if selector_script != null and selector_script.can_instantiate():
        var selector_instance: RefCounted = selector_script.new() as RefCounted
        var range_argument_name := StringName()
        for method: Dictionary in selector_instance.get_method_list():
            if method["name"] == &"most_injured":
                var arguments: Array = method["args"]
                if arguments.size() > 1:
                    range_argument_name = arguments[1]["name"]
                break
        TestAssertions.equal(range_argument_name, &"range", "healing selector range interface", failures)
        var selected: CombatTarget = selector_script.call("most_injured", candidates, 9.0, Vector3.ZERO) as CombatTarget
        TestAssertions.equal(selected.actor, most_injured, "healing selects greatest missing-health percentage", failures)
        _set_health(moderately_injured, 100.0, 100.0)
        _set_health(most_injured, 200.0, 200.0)
        selected = selector_script.call("most_injured", candidates, 9.0, Vector3.ZERO) as CombatTarget
        TestAssertions.equal(selected, null, "healing excludes full downed dead and out-of-range actors", failures)
    test_root.free()

func _test_melee_execution(failures: Array[String]) -> void:
    var test_root := _new_test_root("MeleeExecutionTest")
    var catalog := GameCatalog.load_defaults()
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(fighter, catalog.traits)
    var critical_training := StatModifierSource.create(&"critical_training", &"character", "Critical Training", party.members[0].member_id, [
        StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 0.50, &"critical_training", "Critical Training"),
    ])
    TestAssertions.truthy(party.add_member_source(party.members[0].member_id, critical_training), "melee crit source registers", failures)
    var combat_rng := CombatRng.new(101, [0.10])
    party.call("configure_combat", combat_rng, catalog.damage_types)
    var owner := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    var inside_one := _create_actor(test_root, fighter, 2, Vector3(0.8, 0.0, 0.0))
    var inside_two := _create_actor(test_root, fighter, 2, Vector3(-1.2, 0.0, 0.0))
    var outside := _create_actor(test_root, fighter, 2, Vector3(2.0, 0.0, 0.0))
    var friendly := _create_actor(test_root, fighter, 1, Vector3(0.5, 0.0, 0.0))
    for actor: PartyActor in [inside_one, inside_two, outside, friendly]:
        _set_health(actor, 100.0, 100.0)

    var executor_script: Script = load("res://scripts/combat/attack_executor.gd") as Script
    TestAssertions.truthy(executor_script != null and executor_script.can_instantiate(), "attack executor parses", failures)
    if executor_script != null and executor_script.can_instantiate():
        var executor: Node = executor_script.new() as Node
        test_root.add_child(executor)
        var combatants: Array[Node3D] = [owner, inside_one, inside_two, inside_one, outside, friendly]
        executor.call("configure", owner, party, test_root, combatants)
        executor.call("execute", fighter.primary_attack, inside_one.get_combat_target())
        TestAssertions.near(_health(inside_one).current_health, 73.0, 0.001, "shared crit hits first hostile once", failures)
        TestAssertions.near(_health(inside_two).current_health, 73.0, 0.001, "shared crit hits second hostile once", failures)
        TestAssertions.near(_health(outside).current_health, 100.0, 0.001, "melee excludes hostile outside cleave", failures)
        TestAssertions.near(_health(friendly).current_health, 100.0, 0.001, "melee excludes friendly", failures)
        TestAssertions.equal(combat_rng.draw_count, 1, "one prepared cleave packet shares one crit draw", failures)
    test_root.free()

func _test_defender_resolution_order(failures: Array[String]) -> void:
    var test_root := _new_test_root("DefenderResolutionOrderTest")
    var catalog := GameCatalog.load_defaults()
    var target_definition := _target_definition(&"defender")
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(target_definition)
    party.recruit(target_definition)
    for member_id: int in [party.members[1].member_id, party.members[2].member_id]:
        var defenses := StatModifierSource.create(StringName("defense_%d" % member_id), &"character", "Defense", member_id, [
            StatModifier.create(&"dodge_chance", StatModifier.Operation.FLAT, 0.50, &"test_dodge", "Test Dodge"),
            StatModifier.create(&"block_chance", StatModifier.Operation.FLAT, 0.50, &"test_block", "Test Block"),
        ])
        TestAssertions.truthy(party.add_member_source(member_id, defenses), "defender source registers for %d" % member_id, failures)
    var combat_rng := CombatRng.new(102, [0.10, 0.90, 0.10])
    party.call("configure_combat", combat_rng, catalog.damage_types)
    var owner := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    var first := _create_member_actor(test_root, party, party.members[1], 2, Vector3(0.8, 0.0, 0.0))
    var second := _create_member_actor(test_root, party, party.members[2], 2, Vector3(-0.8, 0.0, 0.0))
    _set_health(first, 100.0, 100.0)
    _set_health(second, 100.0, 100.0)
    var reversed_targets: Array[Node3D] = [second, first]
    owner.attack_executor.call("configure", owner, party, test_root, reversed_targets)
    owner.attack_executor.call("execute", catalog.class_by_id(&"fighter").primary_attack, first.get_combat_target())
    TestAssertions.near(_health(first).current_health, 100.0, 0.001, "lower combatant ID receives prescribed dodge first", failures)
    TestAssertions.near(_health(second).current_health, 91.0, 0.001, "higher combatant ID independently blocks after failed dodge", failures)
    TestAssertions.equal(combat_rng.draw_count, 3, "independent defender draws follow stable combatant order", failures)
    test_root.free()

func _test_automatic_melee_effective_range(failures: Array[String]) -> void:
    var test_root := _new_test_root("AutomaticMeleeRangeTest")
    var catalog := GameCatalog.load_defaults()
    var cleave_class := ClassDefinition.new()
    cleave_class.id = &"arcane_cleave_tester"
    cleave_class.display_name = "Arcane Cleave Tester"
    cleave_class.traits = [&"arcane"]
    cleave_class.primary_attack = catalog.class_by_id(&"fighter").primary_attack
    var party := PartyManager.new()
    party.initialize(cleave_class, catalog.traits)
    party.recruit(cleave_class)
    party.call("configure_combat", CombatRng.new(103), catalog.damage_types)

    var owner := _create_actor(test_root, cleave_class, 1, Vector3.ZERO, true)
    owner.configure(party.members[0])
    owner.configure_combat(party, test_root)
    var whiff_target := _create_actor(test_root, catalog.class_by_id(&"fighter"), 2, Vector3(2.0, 0.0, 0.0))
    var valid_target := _create_actor(test_root, catalog.class_by_id(&"fighter"), 2, Vector3(1.8, 0.0, 0.0))
    _set_health(whiff_target, 100.0, 100.0)
    _set_health(valid_target, 100.0, 100.0)
    var combatants: Array[Node3D] = [owner, whiff_target, valid_target]
    owner.attack_executor.call("configure", owner, party, test_root, combatants)
    var controller := owner.get_node("AttackController") as AttackController

    var outside_candidates: Array[CombatTarget] = [owner.get_combat_target(), whiff_target.get_combat_target()]
    owner.advance_combat(0.1, outside_candidates)
    TestAssertions.near(controller.cooldown_remaining, 0.0, 0.001, "melee target outside modified cleave does not consume cooldown", failures)
    TestAssertions.near(_health(whiff_target).current_health, 100.0, 0.001, "melee target outside modified cleave is not hit", failures)

    var inside_candidates: Array[CombatTarget] = [owner.get_combat_target(), whiff_target.get_combat_target(), valid_target.get_combat_target()]
    owner.advance_combat(0.1, inside_candidates)
    TestAssertions.truthy(controller.cooldown_remaining > 0.0, "melee target inside modified cleave consumes cooldown", failures)
    TestAssertions.near(_health(valid_target).current_health, 82.0, 0.001, "automatic melee hits once inside modified cleave", failures)
    TestAssertions.near(_health(whiff_target).current_health, 100.0, 0.001, "automatic melee excludes actor beyond modified cleave", failures)
    test_root.free()
    party.free()

func _test_projectile_contract(failures: Array[String]) -> void:
    var test_root := _new_test_root("ProjectileContractTest")
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
    party.call("configure_combat", CombatRng.new(104), catalog.damage_types)
    var owner := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    var target_actor := _create_actor(test_root, _target_definition(&"projectile_target"), 2, Vector3(5.0, 0.0, 0.0))
    var effects := Node3D.new()
    test_root.add_child(effects)
    var projectile_targets: Array[Node3D] = [target_actor]
    owner.attack_executor.call("configure", owner, party, effects, projectile_targets)
    owner.attack_executor.call("execute", catalog.class_by_id(&"ranger").primary_attack, target_actor.get_combat_target())
    var projectile := _first_child_of_type(effects, "PartyProjectile")
    TestAssertions.truthy(projectile != null, "ranger execution creates party projectile", failures)
    if projectile != null:
        TestAssertions.truthy(_has_property(projectile, &"packet"), "projectile stores prepared packet", failures)
        TestAssertions.truthy(not _has_property(projectile, &"damage"), "projectile carries no scalar damage", failures)
        var packet := projectile.get("packet") as DamagePacket
        TestAssertions.truthy(packet != null and packet.valid, "projectile packet is valid", failures)
        if packet != null and packet.valid:
            TestAssertions.equal(packet.source_id, &"party:1", "projectile packet preserves source identity", failures)
            TestAssertions.near(packet.components[0].post_crit, 11.0, 0.001, "projectile stores prepared damage", failures)
            var later_training := StatModifierSource.create(&"later_training", &"character", "Later Training", party.members[0].member_id, [
                StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 1.0, &"later_training", "Later Training"),
            ])
            TestAssertions.truthy(party.add_member_source(party.members[0].member_id, later_training), "post-fire source modifier registers", failures)
            TestAssertions.near(party.stats_for(party.members[0].member_id).value(&"damage"), 2.0, 0.001, "source stats change after firing", failures)
            TestAssertions.near(packet.components[0].post_crit, 11.0, 0.001, "projectile packet remains immutable after source change", failures)
        TestAssertions.near(float(projectile.get("speed")), 16.0, 0.001, "projectile carries resolved speed", failures)
        TestAssertions.near(float(projectile.get("maximum_range")), 11.0, 0.001, "projectile range is finite", failures)
        TestAssertions.truthy(is_finite(float(projectile.get("lifetime"))) and float(projectile.get("lifetime")) > 0.0, "projectile lifetime is finite", failures)
    test_root.free()

func _test_projectile_range_boundary(failures: Array[String]) -> void:
    var test_root := _new_test_root("ProjectileRangeBoundaryTest")
    var catalog := GameCatalog.load_defaults()
    var projectile_scene: PackedScene = load("res://scenes/combat/projectile.tscn") as PackedScene
    var packet := _packet(10.0, 1)
    var no_combatants: Array[Node3D] = []

    var limit_effects := Node3D.new()
    test_root.add_child(limit_effects)
    var at_limit := projectile_scene.instantiate() as Node3D
    limit_effects.add_child(at_limit)
    var limit_target := CombatTarget.new(null, Vector3(1.0, 0.0, 0.0), 2)
    at_limit.call("configure", packet, CombatRng.new(105), catalog.damage_types, 10.0, 1.0, 1.0, 1.0, limit_target, limit_effects, no_combatants)
    at_limit.call("_process", 0.1)
    TestAssertions.equal(_count_children_named(limit_effects, &"AreaBurst"), 1, "projectile impacts exactly at maximum range", failures)
    var spawned_burst := _first_child_of_type(limit_effects, "AreaBurst")
    TestAssertions.truthy(spawned_burst != null and spawned_burst.get("packet") == packet, "area burst receives projectile original packet", failures)

    var beyond_effects := Node3D.new()
    test_root.add_child(beyond_effects)
    var beyond_limit := projectile_scene.instantiate() as Node3D
    beyond_effects.add_child(beyond_limit)
    var beyond_target := CombatTarget.new(null, Vector3(1.01, 0.0, 0.0), 2)
    beyond_limit.call("configure", packet, CombatRng.new(106), catalog.damage_types, 10.0, 1.0, 1.0, 1.0, beyond_target, beyond_effects, no_combatants)
    beyond_limit.call("_process", 0.1)
    TestAssertions.equal(_count_children_named(beyond_effects, &"AreaBurst"), 0, "projectile cannot impact beyond maximum range", failures)
    TestAssertions.near(float(beyond_limit.get("distance_travelled")), 1.0, 0.001, "projectile accounts for full maximum travel", failures)
    test_root.free()

func _test_area_impact(failures: Array[String]) -> void:
    var test_root := _new_test_root("AreaImpactTest")
    var catalog := GameCatalog.load_defaults()
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    var inside_one := _create_actor(test_root, fighter, 2, Vector3(1.0, 0.0, 0.0))
    var inside_two := _create_actor(test_root, fighter, 2, Vector3(-2.0, 0.0, 0.0))
    var outside := _create_actor(test_root, fighter, 2, Vector3(3.0, 0.0, 0.0))
    var friendly := _create_actor(test_root, fighter, 1, Vector3(0.5, 0.0, 0.0))
    for actor: PartyActor in [inside_one, inside_two, outside, friendly]:
        _set_health(actor, 100.0, 100.0)

    var area_scene: PackedScene = load("res://scenes/combat/area_burst.tscn") as PackedScene
    TestAssertions.truthy(area_scene != null and area_scene.can_instantiate(), "area burst scene parses", failures)
    if area_scene != null and area_scene.can_instantiate():
        var burst := area_scene.instantiate() as Node3D
        test_root.add_child(burst)
        var combatants: Array[Node3D] = [inside_two, inside_one, inside_one, outside, friendly]
        burst.call("configure", _packet(10.0, 1), CombatRng.new(107), catalog.damage_types, 2.5, 0.25, combatants)
        TestAssertions.near(_health(inside_one).current_health, 90.0, 0.001, "area hits first in-radius hostile once", failures)
        TestAssertions.near(_health(inside_two).current_health, 90.0, 0.001, "area hits second in-radius hostile once", failures)
        TestAssertions.near(_health(outside).current_health, 100.0, 0.001, "area excludes outside hostile", failures)
        TestAssertions.near(_health(friendly).current_health, 100.0, 0.001, "area excludes friendly", failures)
    test_root.free()

func _test_multi_target_life_steal(failures: Array[String]) -> void:
    var test_root := _new_test_root("MultiTargetLifeStealTest")
    var catalog := GameCatalog.load_defaults()
    var target_definition := _target_definition(&"life_steal_target")
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(target_definition)
    party.recruit(target_definition)
    party.recruit(target_definition)
    var source_id := party.members[0].member_id
    var leech := StatModifierSource.create(&"full_leech", &"character", "Full Leech", source_id, [
        StatModifier.create(&"life_steal", StatModifier.Operation.FLAT, 1.0, &"full_leech", "Full Leech"),
    ])
    TestAssertions.truthy(party.add_member_source(source_id, leech), "life-steal source registers", failures)
    var dodge_id := party.members[1].member_id
    var dodge := StatModifierSource.create(&"dodge_target", &"character", "Dodge Target", dodge_id, [
        StatModifier.create(&"dodge_chance", StatModifier.Operation.FLAT, 0.50, &"dodge_target", "Dodge Target"),
    ])
    TestAssertions.truthy(party.add_member_source(dodge_id, dodge), "life-steal dodge source registers", failures)
    var block_id := party.members[2].member_id
    var full_block := StatModifierSource.create(&"block_target", &"character", "Block Target", block_id, [
        StatModifier.create(&"block_chance", StatModifier.Operation.FLAT, 0.50, &"block_target", "Block Target"),
        StatModifier.create(&"block_effectiveness", StatModifier.Operation.FLAT, 0.50, &"full_block", "Full Block"),
    ])
    TestAssertions.truthy(party.add_member_source(block_id, full_block), "life-steal block source registers", failures)
    var combat_rng := CombatRng.new(108, [0.10, 0.10])
    party.call("configure_combat", combat_rng, catalog.damage_types)
    var owner := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    var dodged := _create_member_actor(test_root, party, party.members[1], 2, Vector3(0.5, 0.0, 0.0))
    var blocked := _create_member_actor(test_root, party, party.members[2], 2, Vector3(0.8, 0.0, 0.0))
    var overkilled := _create_member_actor(test_root, party, party.members[3], 2, Vector3(1.0, 0.0, 0.0))
    _set_health(owner, 100.0, 50.0)
    _set_health(dodged, 100.0, 100.0)
    _set_health(blocked, 100.0, 100.0)
    _set_health(overkilled, 100.0, 10.0)
    var reversed_targets: Array[Node3D] = [overkilled, blocked, dodged]
    owner.attack_executor.call("configure", owner, party, test_root, reversed_targets)
    owner.attack_executor.call("execute", catalog.class_by_id(&"fighter").primary_attack, dodged.get_combat_target())
    TestAssertions.near(_health(dodged).current_health, 100.0, 0.001, "dodged target contributes no life steal", failures)
    TestAssertions.near(_health(blocked).current_health, 100.0, 0.001, "fully blocked target contributes no life steal", failures)
    TestAssertions.near(_health(overkilled).current_health, 0.0, 0.001, "remaining target loses only available health", failures)
    TestAssertions.near(_health(owner).current_health, 60.0, 0.001, "multi-target life steal sums actual health removed only", failures)
    TestAssertions.equal(combat_rng.draw_count, 2, "life-steal targets use prescribed defender draws", failures)
    test_root.free()

func _test_cleric_healing(failures: Array[String]) -> void:
    var test_root := _new_test_root("ClericTypedHealingTest")
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(catalog.class_by_id(&"cleric"), catalog.traits)
    party.recruit(catalog.class_by_id(&"ranger"))
    var source_id := party.members[0].member_id
    var healing := StatModifierSource.create(&"healing_training", &"character", "Healing Training", source_id, [
        StatModifier.create(&"healing_power", StatModifier.Operation.INCREASED, 0.38, &"healing_training", "Healing Training", [&"healing"]),
    ])
    TestAssertions.truthy(party.add_member_source(source_id, healing), "healing source registers", failures)
    var combat_rng := CombatRng.new(109, [0.01])
    party.call("configure_combat", combat_rng, catalog.damage_types)
    var cleric := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    var target := _create_member_actor(test_root, party, party.members[1], 1, Vector3(2.0, 0.0, 0.0))
    _set_health(target, 100.0, 40.0)
    var effects := Node3D.new()
    test_root.add_child(effects)
    var healing_targets: Array[Node3D] = [target]
    cleric.attack_executor.call("configure", cleric, party, effects, healing_targets)
    cleric.attack_executor.call("execute", catalog.class_by_id(&"cleric").support_action, target.get_combat_target())
    TestAssertions.near(_health(target).current_health, 40.0 + 18.0 * 1.38, 0.001, "cleric heal reads action-aware healing power", failures)
    TestAssertions.equal(combat_rng.draw_count, 0, "healing creates no damage packet or combat draw", failures)
    TestAssertions.equal(_count_children_named(effects, &"PartyProjectile"), 0, "healing creates no damage projectile", failures)
    test_root.free()

func _test_party_recovery(failures: Array[String]) -> void:
    var test_root := _new_test_root("PartyRecoveryIntegrationTest")
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var source_id := party.members[0].member_id
    var regeneration := StatModifierSource.create(&"regeneration", &"character", "Regeneration", source_id, [
        StatModifier.create(&"health_regeneration", StatModifier.Operation.FLAT, 10.0, &"regeneration", "Regeneration"),
    ])
    TestAssertions.truthy(party.add_member_source(source_id, regeneration), "regeneration source registers", failures)
    party.call("configure_combat", CombatRng.new(110), catalog.damage_types)
    var owner := _create_member_actor(test_root, party, party.members[0], 1, Vector3.ZERO)
    _set_health(owner, 100.0, 50.0)
    TestAssertions.near(party.stats_for(source_id).value(&"health_regeneration"), 10.0, 0.001, "party recovery reads resolved regeneration", failures)
    TestAssertions.truthy(owner.recovery_controller != null and owner.recovery_controller.health == _health(owner), "party recovery controller binds actor health", failures)
    if owner.recovery_controller != null:
        TestAssertions.near(float(owner.recovery_controller.regeneration_provider.call()), 10.0, 0.001, "party recovery provider reads current context-free stats", failures)
        owner.recovery_controller.advance(0.25)
    TestAssertions.near(_health(owner).current_health, 52.5, 0.001, "party recovery advances continuous regeneration", failures)
    TestAssertions.equal(_count_children_named(owner, &"RecoveryController"), 1, "party actor owns exactly one recovery controller", failures)
    test_root.free()

func _test_combat_modifiers(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var modifier_script: Script = load("res://scripts/combat/combat_modifiers.gd") as Script
    TestAssertions.truthy(modifier_script != null and modifier_script.can_instantiate(), "combat modifier helper parses", failures)
    if modifier_script == null or not modifier_script.can_instantiate():
        return

    var fighter_party := PartyManager.new()
    fighter_party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    fighter_party.recruit(catalog.class_by_id(&"fighter"))
    fighter_party.rank_up(&"fighter")
    var fighter_modifiers: RefCounted = modifier_script.call("resolve", fighter_party.members[0], fighter_party) as RefCounted
    TestAssertions.truthy(not _has_property(fighter_modifiers, &"power_multiplier"), "combat movement facade carries no damage multiplier", failures)
    TestAssertions.near(float(fighter_modifiers.get("cooldown_rate_multiplier")), 1.15, 0.001, "active Martial tier scales attack rate", failures)
    var personal := StatModifierSource.create(&"fighter_personal_damage", &"character", "Personal Training", fighter_party.members[0].member_id, [
        StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"fighter_personal_damage", "Personal Training"),
    ])
    TestAssertions.truthy(fighter_party.add_member_source(fighter_party.members[0].member_id, personal), "combat test member source added", failures)
    var personalized: RefCounted = modifier_script.call("resolve", fighter_party.members[0], fighter_party) as RefCounted
    var resolved := fighter_party.stats_for(fighter_party.members[0].member_id)
    TestAssertions.near(resolved.value(&"damage"), 1.45, 0.001, "resolved stats retain member-owned damage for DamageResolver", failures)
    TestAssertions.near(float(personalized.get("cooldown_rate_multiplier")), resolved.value(&"attack_speed"), 0.001, "combat rate equals resolved attack speed", failures)
    fighter_party.free()

    var mage_party := PartyManager.new()
    mage_party.initialize(catalog.class_by_id(&"mage"), catalog.traits)
    mage_party.recruit(catalog.class_by_id(&"mage"))
    var mage_modifiers: RefCounted = modifier_script.call("resolve", mage_party.members[0], mage_party) as RefCounted
    TestAssertions.near(float(mage_modifiers.get("area_multiplier")), 1.18, 0.001, "active Arcane tier scales area", failures)
    TestAssertions.near(float(mage_modifiers.get("projectile_multiplier")), 1.15, 0.001, "active Ranged tier scales projectile", failures)
    TestAssertions.near(float(mage_modifiers.get("cooldown_rate_multiplier")), 1.14, 0.001, "active Caster tier resolves rounded attack rate", failures)
    mage_party.free()

func _test_cleric_primary_fallback(failures: Array[String]) -> void:
    var test_root := _new_test_root("ClericFallbackTest")
    var catalog := GameCatalog.load_defaults()
    var cleric_definition: ClassDefinition = catalog.class_by_id(&"cleric")
    var fighter: ClassDefinition = catalog.class_by_id(&"fighter")
    var party := PartyManager.new()
    test_root.add_child(party)
    party.initialize(cleric_definition, catalog.traits)
    party.call("configure_combat", CombatRng.new(111), catalog.damage_types)
    var cleric := _create_actor(test_root, cleric_definition, 1, Vector3.ZERO, true)
    cleric.configure(party.members[0])
    cleric.call("configure_combat", party, test_root)
    var hostile := _create_actor(test_root, fighter, 2, Vector3(4.0, 0.0, 0.0))
    _set_health(cleric, 100.0, 100.0)
    _set_health(hostile, 100.0, 100.0)

    var candidates: Array[CombatTarget] = [null, cleric.get_combat_target(), hostile.get_combat_target()]
    cleric.call("advance_combat", 0.1, candidates)
    var primary: AttackController = cleric.get_node("AttackController") as AttackController
    var support: AttackController = cleric.get_node_or_null("SupportController") as AttackController
    TestAssertions.truthy(primary.cooldown_remaining > 0.0, "Cleric primary remains active without heal target", failures)
    TestAssertions.truthy(support != null and is_zero_approx(support.cooldown_remaining), "Cleric support waits without injured ally", failures)
    test_root.free()

func _new_test_root(name_value: String) -> Node3D:
    var test_root := Node3D.new()
    test_root.name = name_value
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(test_root)
    return test_root

func _create_actor(parent: Node, definition: ClassDefinition, team: int, actor_position: Vector3, is_leader: bool = false) -> PartyActor:
    var actor_scene: PackedScene = load("res://scenes/characters/leader.tscn") as PackedScene
    var actor: PartyActor = actor_scene.instantiate() as PartyActor
    actor.team_id = team
    actor.position = actor_position
    actor.configure(PartyMemberState.new(actor.get_instance_id(), definition, is_leader))
    parent.add_child(actor)
    return actor

func _create_member_actor(parent: Node, party: PartyManager, member: PartyMemberState, team: int, actor_position: Vector3) -> PartyActor:
    var scene_path := "res://scenes/characters/leader.tscn" if member.is_leader else "res://scenes/characters/companion.tscn"
    var actor := (load(scene_path) as PackedScene).instantiate() as PartyActor
    actor.team_id = team
    actor.position = actor_position
    actor.configure(member)
    parent.add_child(actor)
    actor.configure_combat(party, parent)
    return actor

func _target_definition(id: StringName) -> ClassDefinition:
    var definition := ClassDefinition.new()
    definition.id = id
    definition.display_name = String(id)
    definition.max_health = 100.0
    definition.armor = 0.0
    definition.move_speed = 1.0
    return definition

func _packet(amount: float, source_team: int) -> DamagePacket:
    var source := CombatantAdapter.new(null, &"party:test", source_team)
    var components: Array[PreparedDamageComponent] = [PreparedDamageComponent.new(&"physical", amount, amount, amount, amount)]
    return DamagePacket.create(source, &"test_projectile", [&"physical", &"projectile"], false, false, -1.0, 1.0, 0.0, components)

func _set_health(actor: PartyActor, maximum: float, current: float, downed: bool = false, dead: bool = false) -> void:
    var health := _health(actor)
    health.configure(maximum, dead, 8.0, 0.5)
    health.current_health = current
    health.is_downed = downed
    health.is_dead = dead

func _health(actor: PartyActor) -> HealthComponent:
    return actor.get_node("HealthComponent") as HealthComponent

func _count_children_named(parent: Node, child_name: StringName) -> int:
    var count := 0
    for child: Node in parent.get_children():
        if child.name == child_name:
            count += 1
    return count

func _first_child_of_type(parent: Node, type_name: String) -> Node:
    for child: Node in parent.get_children():
        if child.get_class() == type_name or child.is_class(type_name):
            return child
        var child_script := child.get_script() as Script
        if child_script != null and String(child_script.get_global_name()) == type_name:
            return child
    return null

func _has_property(object: Object, property_name: StringName) -> bool:
    for property: Dictionary in object.get_property_list():
        if property["name"] == property_name:
            return true
    return false
