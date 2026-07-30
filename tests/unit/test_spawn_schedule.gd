extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/enemies/enemy_actor.gd",
    "res://scripts/enemies/swarmer.gd",
    "res://scripts/enemies/spitter.gd",
    "res://scripts/enemies/enemy_projectile.gd",
    "res://scripts/progression/experience_orb.gd",
    "res://scripts/game/spawn_schedule.gd",
    "res://scripts/game/spawn_director.gd",
    "res://scenes/enemies/swarmer.tscn",
    "res://scenes/enemies/spitter.tscn",
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
    _test_swarmer_targeting_and_contact_cooldown(failures)
    _test_spitter_spacing_and_projectile_cadence(failures)
    _test_experience_orb_collection(failures)
    _test_seeded_director_and_stop(failures)
    _test_director_pause(failures)
    _test_pickup_upgrade_reaches_existing_orbs(failures)
    return failures

func _test_schedule_boundaries(failures: Array[String]) -> void:
    var schedule: Script = load("res://scripts/game/spawn_schedule.gd") as Script
    _assert_band(schedule.call("sample", 0.0), 1.25, 100, 0, "zero", failures)
    _assert_band(schedule.call("sample", 59.999), 1.25, 100, 0, "before 60", failures)
    _assert_band(schedule.call("sample", 60.0), 0.9, 80, 20, "at 60", failures)
    _assert_band(schedule.call("sample", 149.999), 0.9, 80, 20, "before 150", failures)
    _assert_band(schedule.call("sample", 150.0), 0.65, 65, 35, "at 150", failures)
    _assert_band(schedule.call("sample", 239.999), 0.65, 65, 35, "before 240", failures)
    _assert_band(schedule.call("sample", 240.0), 0.45, 55, 45, "at 240", failures)
    _assert_band(schedule.call("sample", 299.999), 0.45, 55, 45, "before 300", failures)
    TestAssertions.equal(schedule.call("sample", -0.001), null, "negative time has no ordinary band", failures)
    TestAssertions.equal(schedule.call("sample", 300.0), null, "300 seconds has no ordinary band", failures)

func _test_enemy_reward_exactly_once(failures: Array[String]) -> void:
    var root := _new_root("EnemyRewardTest")
    var enemy: Node3D = (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(enemy)
    var rewards: Array = []
    enemy.connect("reward_dropped", func(value: int, drop_position: Vector3) -> void: rewards.append([value, drop_position]))
    var health := enemy.get_node("HealthComponent") as HealthComponent
    health.apply_damage(9999.0)
    health.apply_damage(9999.0)
    enemy.call("defeat")
    TestAssertions.equal(rewards.size(), 1, "enemy emits one reward after repeated lethal calls", failures)
    if rewards.size() == 1:
        TestAssertions.equal(int(rewards[0][0]), 2, "enemy reward uses definition experience", failures)
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

func _test_experience_orb_collection(failures: Array[String]) -> void:
    var root := _new_root("ExperienceOrbTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var experience := ExperienceSystem.new()
    root.add_child(experience)
    var orb_scene := load("res://scenes/progression/experience_orb.tscn") as PackedScene
    var orb: Node3D = orb_scene.instantiate() as Node3D
    root.add_child(orb)
    orb.position = Vector3(6.0, 0.0, 0.0)
    orb.call("configure", 7, leader, experience, 1.0)
    orb.call("advance_collection", 0.1)
    TestAssertions.near((orb.get("velocity") as Vector3).length(), 0.0, 0.001, "orb remains still outside pickup range", failures)
    orb.call("set_pickup_radius_multiplier", 2.0)
    orb.call("advance_collection", 0.1)
    TestAssertions.truthy(float(orb.get("velocity").x) < 0.0, "shared pickup modifier expands attraction radius", failures)
    orb.position = Vector3(0.5, 0.0, 0.0)
    orb.call("advance_collection", 0.01)
    TestAssertions.equal(experience.experience, 7, "orb adds its integer value on collection", failures)
    TestAssertions.truthy(orb.is_queued_for_deletion(), "collected orb frees itself", failures)
    root.free()

func _test_seeded_director_and_stop(failures: Array[String]) -> void:
    var root := _new_root("SpawnDirectorTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var experience := ExperienceSystem.new()
    root.add_child(experience)
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
    first.call("configure", 4242, leader, experience, markers, null, root, root, 1.0, CombatRng.new(4242), types)
    second.call("configure", 4242, leader, experience, markers, null, root, root, 1.0, CombatRng.new(4242), types)
    var first_ids: Array[StringName] = []
    var second_ids: Array[StringName] = []
    for index: int in range(40):
        first_ids.append(first.call("sample_enemy_id", 75.0))
        second_ids.append(second.call("sample_enemy_id", 75.0))
    TestAssertions.equal(first_ids, second_ids, "spawn selection is repeatable for a local seed", failures)
    TestAssertions.truthy(&"swarmer" in first_ids and &"spitter" in first_ids, "60-second band can produce both enemy types", failures)
    first.set("elapsed_seconds", 299.9)
    first.call("advance_time", 0.2)
    TestAssertions.near(float(first.get("elapsed_seconds")), 300.1, 0.001, "director clock can cross ordinary spawn stop", failures)
    TestAssertions.equal(first.call("active_band"), null, "director stops ordinary schedule at 300 seconds", failures)
    root.free()

func _test_director_pause(failures: Array[String]) -> void:
    var root := _new_root("SpawnDirectorPauseTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var experience := ExperienceSystem.new()
    root.add_child(experience)
    var markers: Array[Node3D] = []
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(director)
    director.call("configure", 7, leader, experience, markers, null, root, root, 1.0, CombatRng.new(7), GameCatalog.load_defaults().damage_types)
    var tree := Engine.get_main_loop() as SceneTree
    tree.paused = true
    director.call("advance_time", 10.0)
    tree.paused = false
    TestAssertions.near(float(director.get("elapsed_seconds")), 0.0, 0.001, "director elapsed clock pauses with level-up tree pause", failures)
    root.free()

func _test_pickup_upgrade_reaches_existing_orbs(failures: Array[String]) -> void:
    var root := _new_root("ExistingOrbPickupUpgradeTest")
    var leader := _party_actor(root, Vector3.ZERO)
    var experience := ExperienceSystem.new()
    root.add_child(experience)
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(director)
    var markers: Array[Node3D] = []
    director.call("configure", 9, leader, experience, markers, null, root, root, 1.0, CombatRng.new(9), GameCatalog.load_defaults().damage_types)
    var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(orb)
    orb.call("configure", 1, leader, experience, 1.0)
    director.call("set_pickup_radius_multiplier", 2.5)
    TestAssertions.near(float(orb.get("pickup_radius_multiplier")), 2.5, 0.001, "pickup upgrade propagates to existing XP orbs", failures)
    root.free()

func _assert_band(band: Variant, interval: float, swarmer: int, spitter: int, label: String, failures: Array[String]) -> void:
    TestAssertions.truthy(band != null, "%s returns a band" % label, failures)
    if band == null:
        return
    TestAssertions.near(float(band.get("interval")), interval, 0.001, "%s interval" % label, failures)
    TestAssertions.equal(int(band.get("swarmer_weight")), swarmer, "%s Swarmer weight" % label, failures)
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
