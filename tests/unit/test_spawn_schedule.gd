extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/enemies/enemy_actor.gd",
    "res://scripts/enemies/swarmer.gd",
    "res://scripts/enemies/spitter.gd",
    "res://scripts/enemies/boltcaster.gd",
    "res://scripts/enemies/enemy_projectile.gd",
    "res://scripts/progression/experience_orb.gd",
    "res://scripts/game/spawn_schedule.gd",
    "res://scripts/game/spawn_director.gd",
    "res://scenes/enemies/swarmer.tscn",
    "res://scenes/enemies/spitter.tscn",
    "res://scenes/enemies/boltcaster.tscn",
    "res://scenes/enemies/enemy_projectile.tscn",
    "res://scenes/progression/experience_orb.tscn",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    var all_exist := true
    for path: String in REQUIRED_PATHS:
        var exists := ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "Task 10 resource exists: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return failures

    _test_schedule_boundaries(failures)
    _test_enemy_reward_exactly_once(failures)
    _test_director_defeat_events_preserve_spawn_facts(failures)
    _test_swarmer_targeting_and_contact_cooldown(failures)
    _test_spitter_spacing_and_projectile_cadence(failures)
    _test_ranged_enemies_only_fire_in_resolved_range(failures)
    _test_boltcaster_telegraph_preserves_sampled_aim(failures)
    _test_linear_projectile_preserves_sampled_aim(failures)
    _test_homing_projectile_tracks_live_target(failures)
    _test_seeded_director_and_stop(failures)
    _test_deterministic_reward_packet_ids(failures)
    _test_density_adjusted_schedule(failures)
    _test_director_pause(failures)
    _test_pickup_upgrade_reaches_existing_orbs(failures)
    return failures

func _test_schedule_boundaries(failures: Array[String]) -> void:
    var schedule: Script = load("res://scripts/game/spawn_schedule.gd") as Script
    _assert_band(schedule.call("sample", 0.0), 0.56, 100, 0, 0, "zero", failures)
    _assert_band(schedule.call("sample", 59.999), 0.56, 100, 0, 0, "before 60", failures)
    _assert_band(schedule.call("sample", 60.0), 0.40, 75, 25, 0, "at 60", failures)
    _assert_band(schedule.call("sample", 149.999), 0.40, 75, 25, 0, "before 150", failures)
    _assert_band(schedule.call("sample", 150.0), 0.29, 60, 32, 8, "at 150", failures)
    _assert_band(schedule.call("sample", 239.999), 0.29, 60, 32, 8, "before 240", failures)
    _assert_band(schedule.call("sample", 240.0), 0.20, 50, 35, 15, "at 240", failures)
    _assert_band(schedule.call("sample", 299.999), 0.20, 50, 35, 15, "before 300", failures)
    TestAssertions.equal(schedule.call("sample", -0.001), null, "negative time has no ordinary band", failures)
    TestAssertions.equal(schedule.call("sample", 300.0), null, "300 seconds has no ordinary band", failures)

func _test_enemy_reward_exactly_once(failures: Array[String]) -> void:
    var root := _new_root("EnemyRewardTest")
    var enemy: Node3D = (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(enemy)
    var rewards: Array = []
    var defeats: Array = []
    enemy.connect("reward_dropped", func(value: int, drop_position: Vector3) -> void: rewards.append([value, drop_position]))
    TestAssertions.truthy(enemy.has_signal("enemy_defeated"), "enemy exposes one typed defeat signal beside the XP reward", failures)
    if enemy.has_signal("enemy_defeated"):
        enemy.connect("enemy_defeated", func(definition: EnemyDefinition, drop_position: Vector3) -> void: defeats.append([definition, drop_position]))
    var health := enemy.get_node("HealthComponent") as HealthComponent
    health.apply_damage(9999.0)
    health.apply_damage(9999.0)
    enemy.call("defeat")
    TestAssertions.equal(rewards.size(), 1, "enemy emits one reward after repeated lethal calls", failures)
    TestAssertions.equal(defeats.size(), 1, "enemy emits one typed defeat after repeated lethal calls", failures)
    if rewards.size() == 1:
        TestAssertions.equal(int(rewards[0][0]), 2, "enemy reward uses definition experience", failures)
    if defeats.size() == 1:
        TestAssertions.equal((defeats[0][0] as EnemyDefinition).id, &"swarmer", "typed defeat preserves the enemy definition", failures)
        TestAssertions.equal(defeats[0][1], rewards[0][1], "typed defeat and XP reward use the same drop position", failures)
    root.free()

func _test_director_defeat_events_preserve_spawn_facts(failures: Array[String]) -> void:
    var root := _new_root("EnemyDefeatSequenceTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var marker := Marker3D.new()
    marker.position = Vector3(3.0, 0.0, 2.0)
    root.add_child(marker)
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as SpawnDirector
    root.add_child(director)
    var markers: Array[Node3D] = [marker]
    director.configure(4242, leader, null, markers, null, root, root, 1.0, CombatRng.new(4242), GameCatalog.load_defaults().damage_types)
    var events: Array[EnemyDefeatEvent] = []
    TestAssertions.truthy(director.has_signal("enemy_defeated"), "director exposes typed defeat events", failures)
    if director.has_signal("enemy_defeated"):
        director.connect("enemy_defeated", func(event: EnemyDefeatEvent) -> void: events.append(event))

    director.elapsed_seconds = 12.5
    var first := director.spawn_enemy(&"swarmer") as EnemyActor
    director.elapsed_seconds = 24.25
    var second := director.spawn_enemy(&"spitter") as EnemyActor
    TestAssertions.truthy(first != null and second != null, "director spawns both defeat fixtures", failures)
    if first == null or second == null:
        root.free()
        return
    director.elapsed_seconds = 33.0
    second.defeat()
    director.elapsed_seconds = 34.5
    first.defeat()

    TestAssertions.equal(events.size(), 2, "two kills produce two typed director events", failures)
    if events.size() == 2:
        TestAssertions.equal([events[0].defeat_sequence, events[1].defeat_sequence], [1, 2], "defeat sequence increases in kill order", failures)
        TestAssertions.equal([events[0].enemy_sequence, events[1].enemy_sequence], [2, 1], "events retain immutable original spawn sequence", failures)
        TestAssertions.equal([events[0].enemy_id, events[1].enemy_id], [&"spitter", &"swarmer"], "kill order does not replace spawned enemy identity", failures)
        TestAssertions.equal([events[0].source_category, events[1].source_category], [&"ordinary_specialist", &"ordinary_melee"], "source category comes from enemy data", failures)
        TestAssertions.near(events[0].encounter_seconds, 33.0, 0.001, "first kill captures director elapsed time", failures)
        TestAssertions.near(events[1].encounter_seconds, 34.5, 0.001, "second kill captures its own director elapsed time", failures)
        TestAssertions.equal(events[0].run_seed, 4242, "typed event preserves configured run seed", failures)
    root.free()

func _test_swarmer_targeting_and_contact_cooldown(failures: Array[String]) -> void:
    var root := _new_root("SwarmerBehaviorTest")
    var swarmer: Node3D = (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(swarmer)
    swarmer.call("configure_combat", 1, CombatRng.new(101), GameCatalog.load_defaults().damage_types)
    swarmer.position = Vector3.ZERO
    var downed := _party_actor(root, Vector3(0.25, 0.0, 0.0))
    var living := _party_actor(root, Vector3(2.0, 0.0, 0.0))
    var downed_health := downed.get_node("HealthComponent") as HealthComponent
    downed_health.is_downed = true
    var living_health := living.get_node("HealthComponent") as HealthComponent
    var before := living_health.current_health
    var initial_candidates: Array[Node3D] = [downed, living]
    swarmer.call("advance_behavior", 0.1, initial_candidates)
    TestAssertions.truthy(float(swarmer.get("velocity").x) > 0.0, "swarmer chases nearest living party actor", failures)
    living.position = Vector3(0.5, 0.0, 0.0)
    var contact_candidates: Array[Node3D] = [living]
    swarmer.call("advance_behavior", 0.1, contact_candidates)
    var after_first := living_health.current_health
    swarmer.call("advance_behavior", 0.1, contact_candidates)
    TestAssertions.near(after_first, before - 8.0, 0.001, "swarmer applies contact damage", failures)
    TestAssertions.near(living_health.current_health, after_first, 0.001, "contact cooldown is per target", failures)
    root.free()

func _test_spitter_spacing_and_projectile_cadence(failures: Array[String]) -> void:
    var root := _new_root("SpitterBehaviorTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var spitter: Node3D = (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(spitter)
    spitter.call("configure_combat", 1, CombatRng.new(102), GameCatalog.load_defaults().damage_types)
    spitter.call("configure_target", leader, root)
    spitter.position = Vector3(4.0, 0.0, 0.0)
    spitter.call("advance_behavior", 0.1)
    TestAssertions.truthy(float(spitter.get("velocity").x) > 0.0, "spitter retreats inside five meters", failures)
    spitter.position = Vector3(8.0, 0.0, 0.0)
    spitter.call("advance_behavior", 0.1)
    TestAssertions.near((spitter.get("velocity") as Vector3).length(), 0.0, 0.001, "spitter holds at eight meters", failures)
    var before := _count_named(root, &"EnemyProjectile")
    spitter.call("advance_behavior", 2.2)
    TestAssertions.equal(_count_named(root, &"EnemyProjectile"), before + 1, "spitter fires at 2.2 second cadence", failures)
    root.free()

func _test_ranged_enemies_only_fire_in_resolved_range(failures: Array[String]) -> void:
    var root := _new_root("RangedEnemyRangeTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var spitter: Node3D = (load("res://scenes/enemies/spitter.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(spitter)
    spitter.call("configure_combat", 1, CombatRng.new(105), GameCatalog.load_defaults().damage_types)
    spitter.call("configure_target", leader, root)
    spitter.position = Vector3(19.0, 0.0, 0.0)
    spitter.set("fire_cooldown", 0.0)
    spitter.call("advance_behavior", 0.1)
    TestAssertions.equal(_count_named(root, &"EnemyProjectile"), 0, "Spitter does not fire outside resolved attack range", failures)
    TestAssertions.truthy((spitter.get("velocity") as Vector3).x < 0.0, "Spitter advances while outside attack range", failures)

    var boltcaster: Node3D = (load("res://scenes/enemies/boltcaster.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(boltcaster)
    boltcaster.call("configure_combat", 2, CombatRng.new(106), GameCatalog.load_defaults().damage_types)
    boltcaster.call("configure_target", leader, root)
    boltcaster.position = Vector3(17.0, 0.0, 0.0)
    boltcaster.set("fire_cooldown", 0.0)
    boltcaster.call("advance_behavior", 0.1)
    TestAssertions.near(float(boltcaster.get("tell_remaining")), 0.0, 0.001, "Boltcaster does not tell outside resolved attack range", failures)
    TestAssertions.truthy((boltcaster.get("velocity") as Vector3).x < 0.0, "Boltcaster advances while outside attack range", failures)
    root.free()

func _test_boltcaster_telegraph_preserves_sampled_aim(failures: Array[String]) -> void:
    var root := _new_root("BoltcasterBehaviorTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var boltcaster: Node3D = (load("res://scenes/enemies/boltcaster.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(boltcaster)
    boltcaster.call("configure_combat", 1, CombatRng.new(107), GameCatalog.load_defaults().damage_types)
    boltcaster.call("configure_target", leader, root)
    boltcaster.position = Vector3(9.0, 0.0, 0.0)
    boltcaster.set("fire_cooldown", 0.0)
    boltcaster.call("advance_behavior", 0.0)
    TestAssertions.near(float(boltcaster.get("tell_remaining")), 0.35, 0.001, "Boltcaster begins its configured tell in range", failures)
    TestAssertions.equal(boltcaster.get("sampled_aim_position"), Vector3.ZERO, "Boltcaster samples aim when tell begins", failures)
    leader.position = Vector3(0.0, 0.0, 9.0)
    boltcaster.call("advance_behavior", 0.35)
    var projectile := root.get_node_or_null("EnemyProjectile") as Node3D
    TestAssertions.truthy(projectile != null, "Boltcaster fires when tell ends", failures)
    if projectile != null:
        var direction := projectile.get("direction") as Vector3
        TestAssertions.near(direction.x, -1.0, 0.001, "Boltcaster projectile aims at sampled position", failures)
        TestAssertions.near(direction.z, 0.0, 0.001, "Boltcaster projectile ignores leader movement during tell", failures)
    root.free()

func _test_linear_projectile_preserves_sampled_aim(failures: Array[String]) -> void:
    var root := _new_root("LinearEnemyProjectileTest")
    var target := _party_actor(root, Vector3(10.0, 0.0, 0.0))
    var projectile := (load("res://scenes/enemies/enemy_projectile.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(projectile)
    projectile.position = Vector3.ZERO
    TestAssertions.truthy(_method_accepts(projectile, &"configure", 7), "enemy projectile accepts data-driven configuration", failures)
    if not _method_accepts(projectile, &"configure", 7):
        root.free()
        return
    var attack := AttackDefinition.new()
    attack.projectile_speed = 10.0
    attack.range = 6.0
    attack.area_radius = 1.25
    var profile := EnemyProjectileProfile.new()
    profile.movement = EnemyProjectileProfile.Movement.LINEAR
    profile.color = Color(1.0, 0.08, 0.05, 1.0)
    profile.hit_radius = 0.2
    profile.max_lifetime = 10.0
    projectile.call("configure", target, null, CombatRng.new(103), GameCatalog.load_defaults().damage_types, attack, profile, target.position)
    target.position = Vector3(0.0, 0.0, 10.0)
    projectile.call("advance_projectile", 0.5)
    TestAssertions.equal(projectile.get("movement"), EnemyProjectileProfile.Movement.LINEAR, "linear projectile exposes configured movement", failures)
    TestAssertions.near(float(projectile.get("speed")), 10.0, 0.001, "linear projectile uses attack speed", failures)
    TestAssertions.near(float(projectile.get("maximum_range")), 6.0, 0.001, "linear projectile uses attack range", failures)
    TestAssertions.near(float(projectile.get("area_radius")), 1.25, 0.001, "linear projectile uses attack area radius", failures)
    TestAssertions.near((projectile.get("direction") as Vector3).z, 0.0, 0.001, "linear projectile preserves sampled aim after target moves", failures)
    TestAssertions.near(projectile.position.x, 5.0, 0.001, "linear projectile advances at configured speed", failures)
    var material := (projectile.get_node("MeshInstance3D") as MeshInstance3D).get_active_material(0) as StandardMaterial3D
    TestAssertions.equal(material.albedo_color if material != null else Color.TRANSPARENT, profile.color, "linear projectile uses profile color", failures)
    projectile.call("advance_projectile", 0.5)
    TestAssertions.near(float(projectile.get("distance_travelled")), 6.0, 0.001, "linear projectile stops at attack range", failures)
    TestAssertions.truthy(projectile.is_queued_for_deletion(), "linear projectile expires at attack range", failures)
    root.free()

func _test_homing_projectile_tracks_live_target(failures: Array[String]) -> void:
    var root := _new_root("HomingEnemyProjectileTest")
    var target := _party_actor(root, Vector3(10.0, 0.0, 0.0))
    var projectile := (load("res://scenes/enemies/enemy_projectile.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(projectile)
    projectile.position = Vector3.ZERO
    var attack := AttackDefinition.new()
    attack.projectile_speed = 10.0
    attack.range = 6.0
    var profile := EnemyProjectileProfile.new()
    profile.movement = EnemyProjectileProfile.Movement.HOMING
    profile.color = Color(0.75, 0.15, 1.0, 1.0)
    profile.hit_radius = 0.2
    profile.max_lifetime = 10.0
    projectile.call("configure", target, null, CombatRng.new(104), GameCatalog.load_defaults().damage_types, attack, profile, target.position)
    target.position = Vector3(0.0, 0.0, 10.0)
    projectile.call("advance_projectile", 0.5)
    TestAssertions.equal(projectile.get("movement"), EnemyProjectileProfile.Movement.HOMING, "homing projectile exposes configured movement", failures)
    TestAssertions.truthy((projectile.get("direction") as Vector3).z > 0.0, "homing projectile follows live target after it moves", failures)
    var material := (projectile.get_node("MeshInstance3D") as MeshInstance3D).get_active_material(0) as StandardMaterial3D
    TestAssertions.equal(material.albedo_color if material != null else Color.TRANSPARENT, profile.color, "homing projectile uses profile color", failures)
    projectile.call("advance_projectile", 0.5)
    TestAssertions.near(float(projectile.get("distance_travelled")), 6.0, 0.001, "homing projectile stops at attack range", failures)
    TestAssertions.truthy(projectile.is_queued_for_deletion(), "homing projectile expires at attack range", failures)
    root.free()

func _test_seeded_director_and_stop(failures: Array[String]) -> void:
    var root := _new_root("SpawnDirectorTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var distributor := RewardDistributionService.new()
    var markers: Array[Node3D] = []
    for position: Vector3 in [Vector3(-17.0, 0.0, -12.0), Vector3(17.0, 0.0, 12.0)]:
        var marker := Marker3D.new()
        marker.position = position
        root.add_child(marker)
        markers.append(marker)
    var director_script := load("res://scripts/game/spawn_director.gd") as Script
    var first: Node = director_script.new() as Node
    var second: Node = director_script.new() as Node
    root.add_child(first)
    root.add_child(second)
    var types := GameCatalog.load_defaults().damage_types
    first.call("configure", 4242, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(4242), types)
    second.call("configure", 4242, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(4242), types)
    var first_ids: Array[StringName] = []
    var second_ids: Array[StringName] = []
    for index: int in range(2000):
        first_ids.append(first.call("sample_enemy_id", 150.0))
        second_ids.append(second.call("sample_enemy_id", 150.0))
    TestAssertions.equal(first_ids, second_ids, "spawn selection is repeatable for a local seed", failures)
    TestAssertions.truthy(&"swarmer" in first_ids and &"boltcaster" in first_ids and &"spitter" in first_ids, "150-second band can produce all three enemy types", failures)
    var swarmer_ratio := float(first_ids.count(&"swarmer")) / float(first_ids.size())
    var boltcaster_ratio := float(first_ids.count(&"boltcaster")) / float(first_ids.size())
    var spitter_ratio := float(first_ids.count(&"spitter")) / float(first_ids.size())
    TestAssertions.near(swarmer_ratio, 0.60, 0.04, "seeded samples follow the Swarmer weight", failures)
    TestAssertions.near(boltcaster_ratio, 0.32, 0.04, "seeded samples follow the Boltcaster weight", failures)
    TestAssertions.near(spitter_ratio, 0.08, 0.025, "seeded samples follow the Spitter weight", failures)
    var invalid_band := SpawnSchedule.SpawnBand.new(1.0, 0, 0, 0)
    TestAssertions.equal(first.call("_sample_enemy_id_from_band", invalid_band), &"", "non-positive total weight selects no enemy", failures)
    first.set("elapsed_seconds", 299.9)
    first.call("advance_time", 0.2)
    TestAssertions.near(float(first.get("elapsed_seconds")), 300.1, 0.001, "director clock can cross ordinary spawn stop", failures)
    TestAssertions.equal(first.call("active_band"), null, "director stops ordinary schedule at 300 seconds", failures)
    root.free()

func _test_deterministic_reward_packet_ids(failures: Array[String]) -> void:
    var root := _new_root("RewardPacketSequenceTest")
    var first_effects := Node3D.new()
    var second_effects := Node3D.new()
    root.add_child(first_effects)
    root.add_child(second_effects)
    var first_leader := _party_actor(root, Vector3.ZERO)
    var second_leader := _party_actor(root, Vector3(3.0, 0.0, 0.0))
    var distributor := RewardDistributionService.new()
    var first := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    var second := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(first)
    root.add_child(second)
    var markers: Array[Node3D] = []
    var types := GameCatalog.load_defaults().damage_types
    first.call("configure", 1337, first_leader, distributor, markers, null, root, first_effects, 1.0, CombatRng.new(1337), types)
    second.call("configure", 1337, first_leader, distributor, markers, null, root, second_effects, 1.0, CombatRng.new(1337), types)
    first.call("_on_reward_dropped", 2, Vector3.ONE)
    first.call("_on_reward_dropped", 3, Vector3(2.0, 0.0, 0.0))
    second.call("_on_reward_dropped", 2, Vector3.ONE)
    second.call("_on_reward_dropped", 3, Vector3(2.0, 0.0, 0.0))
    var first_orbs := _experience_orbs(first_effects)
    var second_orbs := _experience_orbs(second_effects)
    TestAssertions.equal(_packet_ids(first_orbs), [&"xp_1337_1", &"xp_1337_2"], "sequential drops use distinct deterministic IDs", failures)
    TestAssertions.equal(_packet_ids(second_orbs), _packet_ids(first_orbs), "fresh same-seed director reproduces packet sequence", failures)
    TestAssertions.truthy(first_orbs.all(func(orb: Node3D) -> bool: return orb.get("leader") == first_leader), "spawned orbs target the current active leader", failures)

    first.call("configure", 1337, second_leader, distributor, markers, null, root, first_effects, 1.0, CombatRng.new(1337), types)
    first.call("_on_reward_dropped", 5, Vector3(3.0, 0.0, 0.0))
    var reset_orb := _experience_orbs(first_effects)[-1]
    TestAssertions.equal(reset_orb.get("packet_id"), &"xp_1337_1", "reconfiguration resets reward sequence", failures)
    TestAssertions.truthy(reset_orb.get("leader") == second_leader, "reconfiguration targets the new active leader", failures)
    root.free()

func _test_director_pause(failures: Array[String]) -> void:
    var root := _new_root("SpawnDirectorPauseTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var distributor := RewardDistributionService.new()
    var markers: Array[Node3D] = []
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(director)
    director.call("configure", 7, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(7), GameCatalog.load_defaults().damage_types)
    var tree := Engine.get_main_loop() as SceneTree
    tree.paused = true
    director.call("advance_time", 10.0)
    tree.paused = false
    TestAssertions.near(float(director.get("elapsed_seconds")), 0.0, 0.001, "director elapsed clock pauses with level-up tree pause", failures)
    root.free()

func _test_density_adjusted_schedule(failures: Array[String]) -> void:
    var root := _new_root("SpawnDensityTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var distributor := RewardDistributionService.new()
    var markers: Array[Node3D] = []
    for position: Vector3 in [Vector3(-17.0, 0.0, -12.0), Vector3(17.0, 0.0, 12.0)]:
        var marker := Marker3D.new()
        marker.position = position
        root.add_child(marker)
        markers.append(marker)
    var director_script := load("res://scripts/game/spawn_director.gd") as Script
    var types := GameCatalog.load_defaults().damage_types
    var signature_probe := director_script.new() as Node
    var configure_arguments: Array = []
    for method: Dictionary in director_script.get_script_method_list():
        if method.get("name", "") == "configure":
            configure_arguments = method.get("args", []) as Array
            break
    var supports_density := configure_arguments.size() == 12 \
        and StringName((configure_arguments[10] as Dictionary).get("name", "")) == &"density_percent" \
        and _method_accepts(signature_probe, &"configure", 11)
    var supports_service := configure_arguments.size() == 12 \
        and StringName((configure_arguments[11] as Dictionary).get("name", "")) == &"resolution_service" \
        and _method_accepts(signature_probe, &"configure", 12)
    signature_probe.free()
    TestAssertions.truthy(supports_density, "spawn director accepts a final density argument", failures)
    TestAssertions.truthy(supports_service, "spawn director accepts an optional combat service after density", failures)
    if not supports_density or not supports_service:
        root.free()
        return

    var zero: Node = director_script.new() as Node
    root.add_child(zero)
    zero.call("configure", 10, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(10), types, 0)
    TestAssertions.equal(zero.call("advance_time", 10.0), 0, "zero density disables scheduled normal spawns", failures)
    TestAssertions.near(float(zero.get("elapsed_seconds")), 10.0, 0.001, "zero density still advances schedule time", failures)
    TestAssertions.truthy(zero.call("spawn_enemy", &"swarmer") != null, "zero density preserves direct enemy spawning", failures)

    var normal: Node = director_script.new() as Node
    root.add_child(normal)
    normal.call("configure", 11, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(11), types, 100)
    TestAssertions.equal(normal.call("advance_time", 1.26), 3, "100 percent preserves retuned baseline schedule including initial spawn", failures)

    var extreme: Node = director_script.new() as Node
    root.add_child(extreme)
    extreme.call("configure", 12, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(12), types, 1000)
    TestAssertions.equal(extreme.call("advance_time", 30.0), director_script.get("MAX_SCHEDULED_SPAWNS_PER_UPDATE"), "1000 percent is bounded per update", failures)
    TestAssertions.truthy(float(extreme.get("spawn_cooldown")) > 0.0, "overflow debt resets to one effective interval", failures)
    TestAssertions.near(float(extreme.get("elapsed_seconds")), 30.0, 0.001, "overflow handling advances the remaining clock", failures)
    root.free()

func _test_pickup_upgrade_reaches_existing_orbs(failures: Array[String]) -> void:
    var root := _new_root("ExistingOrbPickupUpgradeTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var distributor := RewardDistributionService.new()
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(director)
    var markers: Array[Node3D] = []
    director.call("configure", 9, leader, distributor, markers, null, root, root, 1.0, CombatRng.new(9), GameCatalog.load_defaults().damage_types)
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(orb)
    orb.call("configure", 1, &"xp_9_1", leader, distributor, 1.0)
    director.call("set_pickup_radius_multiplier", 2.5)
    TestAssertions.near(float(orb.get("pickup_radius_multiplier")), 2.5, 0.001, "pickup upgrade propagates to existing XP orbs", failures)
    root.free()

func _assert_band(band: Variant, interval: float, swarmer: int, boltcaster: int, spitter: int, label: String, failures: Array[String]) -> void:
    TestAssertions.truthy(band != null, "%s returns a band" % label, failures)
    if band == null:
        return
    TestAssertions.near(float(band.get("interval")), interval, 0.001, "%s interval" % label, failures)
    TestAssertions.equal(int(band.get("swarmer_weight")), swarmer, "%s Swarmer weight" % label, failures)
    TestAssertions.equal(int(band.get("boltcaster_weight")), boltcaster, "%s Boltcaster weight" % label, failures)
    TestAssertions.equal(int(band.get("spitter_weight")), spitter, "%s Spitter weight" % label, failures)

func _new_root(root_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = root_name
    (Engine.get_main_loop() as SceneTree).root.add_child(root)
    return root

func _party_actor(parent: Node, actor_position: Vector3) -> PartyActor:
    var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
    actor.position = actor_position
    parent.add_child(actor)
    var definition := GameCatalog.load_defaults().class_by_id(&"fighter")
    actor.configure(PartyMemberState.new(actor.get_instance_id(), definition, true))
    return actor

func _count_named(parent: Node, node_name: StringName) -> int:
    var count := 0
    for child: Node in parent.get_children():
        if child.name == node_name:
            count += 1
    return count

func _experience_orbs(parent: Node) -> Array[Node3D]:
    var result: Array[Node3D] = []
    for child: Node in parent.get_children():
        if child is ExperienceOrb:
            result.append(child as Node3D)
    return result

func _packet_ids(orbs: Array[Node3D]) -> Array[StringName]:
    var result: Array[StringName] = []
    for orb: Node3D in orbs:
        result.append(orb.get("packet_id") as StringName)
    return result

func _method_accepts(object: Object, method_name: StringName, argument_count: int) -> bool:
    for row: Dictionary in object.get_method_list():
        if StringName(row.get("name", "")) == method_name:
            var total_arguments := (row.get("args", []) as Array).size()
            var default_arguments := (row.get("default_args", []) as Array).size()
            return argument_count >= total_arguments - default_arguments and argument_count <= total_arguments
    return false
