extends RefCounted

const REQUIRED_PATHS: PackedStringArray = [
    "res://scripts/enemies/boss_action_schedule.gd",
    "res://scripts/enemies/forge_guardian.gd",
    "res://scenes/enemies/forge_guardian.tscn",
    "res://scenes/effects/danger_ring.tscn",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    for path: String in REQUIRED_PATHS:
        TestAssertions.truthy(ResourceLoader.exists(path), "Task 11 resource exists: %s" % path, failures)
    if not failures.is_empty():
        return failures
    _test_action_schedule(failures)
    _test_charge_samples_then_executes(failures)
    _test_shockwave_telegraphs_before_damage(failures)
    _test_summon_requests_six_swarmers(failures)
    _test_boss_death_once_and_cancels_hit_areas(failures)
    return failures

func _test_action_schedule(failures: Array[String]) -> void:
    var schedule := (load("res://scripts/enemies/boss_action_schedule.gd") as Script).new() as RefCounted
    TestAssertions.equal(int(schedule.call("take_next")), 0, "schedule starts with CHARGE", failures)
    TestAssertions.near(float(schedule.get("remaining")), 2.0, 0.001, "charge recovery is 2.0", failures)
    TestAssertions.equal(int(schedule.call("take_next")), -1, "schedule blocks during charge recovery", failures)
    schedule.call("advance", 2.0)
    TestAssertions.equal(int(schedule.call("take_next")), 1, "schedule continues with SHOCKWAVE", failures)
    TestAssertions.near(float(schedule.get("remaining")), 2.5, 0.001, "shockwave recovery is 2.5", failures)
    schedule.call("advance", 2.5)
    TestAssertions.equal(int(schedule.call("take_next")), 2, "schedule continues with SUMMON", failures)
    TestAssertions.near(float(schedule.get("remaining")), 3.0, 0.001, "summon recovery is 3.0", failures)
    schedule.call("advance", 3.0)
    TestAssertions.equal(int(schedule.call("take_next")), 0, "schedule cycles to CHARGE", failures)

func _test_charge_samples_then_executes(failures: Array[String]) -> void:
    var root := _new_root("BossChargeTest")
    var leader := _party_actor(root, Vector3(6.0, 0.0, 0.0))
    var boss := _boss(root, leader)
    boss.position = Vector3.ZERO
    boss.call("advance_behavior", 0.0)
    TestAssertions.equal(int(boss.get("active_action")), 0, "boss begins CHARGE", failures)
    TestAssertions.near((boss.get("charge_target") as Vector3).x, 6.0, 0.001, "charge samples leader position", failures)
    leader.position = Vector3(-6.0, 0.0, 0.0)
    boss.call("advance_behavior", 0.79)
    TestAssertions.near(boss.position.x, 0.0, 0.001, "charge does not move during 0.8 second telegraph", failures)
    boss.call("advance_behavior", 0.01)
    boss.call("advance_behavior", 0.65)
    TestAssertions.truthy(boss.position.x > 0.0, "charge moves toward sampled position for 0.65 seconds", failures)
    root.free()

func _test_shockwave_telegraphs_before_damage(failures: Array[String]) -> void:
    var root := _new_root("BossShockwaveTest")
    var leader := _party_actor(root, Vector3(5.0, 0.0, 0.0))
    var health := leader.get_node("HealthComponent") as HealthComponent
    var boss := _boss(root, leader)
    boss.call("advance_behavior", 0.0)
    boss.call("advance_behavior", 1.45)
    boss.call("advance_behavior", 0.55)
    TestAssertions.equal(int(boss.get("active_action")), 1, "boss cycles to SHOCKWAVE", failures)
    var before := health.current_health
    boss.call("advance_behavior", 0.99)
    TestAssertions.near(health.current_health, before, 0.001, "shockwave does not damage during telegraph", failures)
    boss.call("advance_behavior", 0.01)
    TestAssertions.near(health.current_health, before - 22.0, 0.001, "shockwave damages within six meters after one second", failures)
    root.free()

func _test_summon_requests_six_swarmers(failures: Array[String]) -> void:
    var root := _new_root("BossSummonTest")
    var leader := _party_actor(root, Vector3(10.0, 0.0, 0.0))
    var experience := ExperienceSystem.new()
    root.add_child(experience)
    var marker := Marker3D.new()
    marker.position = Vector3(15.0, 0.0, 0.0)
    root.add_child(marker)
    var markers: Array[Node3D] = [marker]
    var director := (load("res://scripts/game/spawn_director.gd") as Script).new() as Node
    root.add_child(director)
    director.call("configure", 11, leader, experience, markers, null, root, root)
    var spawned_ids: Array[StringName] = []
    director.connect("enemy_spawned", func(enemy_id: StringName, _enemy: Node3D) -> void: spawned_ids.append(enemy_id))
    var boss := _boss(root, leader, director)
    boss.call("advance_behavior", 0.0)
    boss.call("advance_behavior", 1.45)
    boss.call("advance_behavior", 0.55)
    boss.call("advance_behavior", 1.0)
    boss.call("advance_behavior", 1.5)
    TestAssertions.equal(spawned_ids.size(), 6, "SUMMON requests exactly six enemies", failures)
    TestAssertions.truthy(spawned_ids.all(func(id: StringName) -> bool: return id == &"swarmer"), "SUMMON requests only Swarmers", failures)
    root.free()

func _test_boss_death_once_and_cancels_hit_areas(failures: Array[String]) -> void:
    var root := _new_root("BossDeathTest")
    var leader := _party_actor(root, Vector3(4.0, 0.0, 0.0))
    var health := leader.get_node("HealthComponent") as HealthComponent
    var boss := _boss(root, leader)
    boss.call("advance_behavior", 0.0)
    boss.call("advance_behavior", 1.45)
    boss.call("advance_behavior", 0.55)
    var pending: Array = boss.get("pending_hit_areas") as Array
    TestAssertions.equal(pending.size(), 1, "shockwave registers a pending hit area", failures)
    var danger_ring: Node = pending[0] as Node if not pending.is_empty() else null
    var defeated: Array[int] = [0]
    boss.connect("boss_defeated", func() -> void: defeated[0] += 1)
    var before := health.current_health
    boss.call("receive_damage", 99999.0)
    boss.call("receive_damage", 99999.0)
    boss.call("defeat")
    boss.call("advance_behavior", 2.0)
    TestAssertions.equal(defeated[0], 1, "boss death emits exactly once", failures)
    TestAssertions.equal((boss.get("pending_hit_areas") as Array).size(), 0, "boss death clears every pending hit area", failures)
    TestAssertions.truthy(danger_ring != null and danger_ring.is_queued_for_deletion(), "boss death disables pending danger ring", failures)
    TestAssertions.near(health.current_health, before, 0.001, "dead boss cannot apply pending shockwave damage", failures)
    root.free()

func _boss(parent: Node, leader: Node3D, director: Node = null) -> Node3D:
    var boss := (load("res://scenes/enemies/forge_guardian.tscn") as PackedScene).instantiate() as Node3D
    parent.add_child(boss)
    boss.call("configure_boss", leader, director, parent)
    return boss

func _party_actor(parent: Node, actor_position: Vector3) -> PartyActor:
    var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
    actor.position = actor_position
    parent.add_child(actor)
    actor.configure(PartyMemberState.new(actor.get_instance_id(), GameCatalog.load_defaults().class_by_id(&"fighter"), true))
    return actor

func _new_root(root_name: String) -> Node3D:
    var test_root := Node3D.new()
    test_root.name = root_name
    (Engine.get_main_loop() as SceneTree).root.add_child(test_root)
    return test_root
