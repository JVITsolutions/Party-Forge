extends RefCounted

const FORMATION_PATH := "res://scripts/formation/formation_math.gd"
const COMPANION_SCENE_PATH := "res://scenes/characters/companion.tscn"
const SPAWNER_PATH := "res://scripts/party/party_actor_spawner.gd"

func run() -> Array[String]:
    var failures: Array[String] = []
    var required_paths: PackedStringArray = [FORMATION_PATH, COMPANION_SCENE_PATH, SPAWNER_PATH]
    var all_exist := true
    for path: String in required_paths:
        var exists: bool = ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "Task 8 resource exists: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return failures

    var formation_script: Script = load(FORMATION_PATH) as Script
    _test_tether_recovery(formation_script, failures)
    _test_role_distances(formation_script, failures)
    _test_separation(formation_script, failures)
    _test_companion_safety(failures)
    _test_party_actor_spawner(failures)
    return failures

func _test_tether_recovery(formation_script: Script, failures: Array[String]) -> void:
    var recovered := _desired_velocity(
        formation_script,
        ClassDefinition.Role.BACKLINE,
        Vector3(20.0, 7.0, 0.0),
        Vector3.ZERO,
        Vector3(10.0, -4.0, 0.0),
        6.5,
        10.0,
        Vector3(0.0, 50.0, 50.0),
        6.0
    )
    TestAssertions.truthy(recovered.dot(Vector3.LEFT) > 5.9, "beyond tether prioritizes leader recovery", failures)
    TestAssertions.near(recovered.y, 0.0, 0.001, "tether recovery flattens Y", failures)
    TestAssertions.near(recovered.length(), 6.0, 0.001, "tether recovery uses full speed", failures)

func _test_role_distances(formation_script: Script, failures: Array[String]) -> void:
    var fighter := _desired_velocity(
        formation_script, ClassDefinition.Role.FRONTLINE,
        Vector3(1.0, 3.0, 0.0), Vector3.ZERO, Vector3(10.0, -2.0, 0.0),
        2.0, 9.0, Vector3.ZERO, 6.0
    )
    TestAssertions.truthy(fighter.x > 5.9, "frontline advances between leader and threat", failures)
    TestAssertions.near(fighter.y, 0.0, 0.001, "frontline movement is planar", failures)

    var mage_retreat := _desired_velocity(
        formation_script, ClassDefinition.Role.BACKLINE,
        Vector3(8.0, 0.0, 0.0), Vector3.ZERO, Vector3(10.0, 0.0, 0.0),
        6.5, 12.0, Vector3.ZERO, 6.0
    )
    TestAssertions.truthy(mage_retreat.x < -5.9, "backline retreats inside preferred threat distance", failures)

    var threat := Vector3(20.0, 0.0, 0.0)
    var ranger_position := Vector3(15.0, 0.0, 0.0)
    var mage_position := Vector3(13.5, 0.0, 0.0)
    var cleric_position := Vector3(-4.0, 0.0, 0.0)
    var ranger_hold := _desired_velocity(
        formation_script, ClassDefinition.Role.MIDLINE,
        ranger_position, Vector3.ZERO, threat, 5.0, 30.0, Vector3.ZERO, 6.0
    )
    var mage_hold := _desired_velocity(
        formation_script, ClassDefinition.Role.BACKLINE,
        mage_position, Vector3.ZERO, threat, 6.5, 30.0, Vector3.ZERO, 6.0
    )
    var cleric_hold := _desired_velocity(
        formation_script, ClassDefinition.Role.SUPPORT,
        cleric_position, Vector3.ZERO, threat, 4.0, 30.0, Vector3.ZERO, 6.0
    )
    TestAssertions.equal(ranger_hold, Vector3.ZERO, "midline holds its class distance band", failures)
    TestAssertions.equal(mage_hold, Vector3.ZERO, "backline holds its class distance band", failures)
    TestAssertions.equal(cleric_hold, Vector3.ZERO, "support holds near leader", failures)
    TestAssertions.truthy(cleric_position.length() < mage_position.length(), "support stays closer to leader than backline", failures)
    TestAssertions.truthy(not is_equal_approx(ranger_position.x, mage_position.x), "midline and backline distance bands differ", failures)

func _test_separation(formation_script: Script, failures: Array[String]) -> void:
    var separated_hold := _desired_velocity(
        formation_script, ClassDefinition.Role.MIDLINE,
        Vector3(15.0, 8.0, 0.0), Vector3.ZERO, Vector3(20.0, -8.0, 0.0),
        5.0, 30.0, Vector3(0.0, 100.0, 1.0), 6.0
    )
    TestAssertions.truthy(separated_hold.z > 5.9, "separation changes zero desired vector", failures)
    TestAssertions.near(separated_hold.y, 0.0, 0.001, "separation flattens Y", failures)

    var capped := _desired_velocity(
        formation_script, ClassDefinition.Role.MIDLINE,
        Vector3(14.0, 0.0, 0.0), Vector3.ZERO, Vector3(20.0, 0.0, 0.0),
        5.0, 30.0, Vector3(0.0, 0.0, 100.0), 6.0
    )
    TestAssertions.truthy(capped.x > 3.0, "separation contribution is capped", failures)
    TestAssertions.near(capped.length(), 6.0, 0.001, "separated movement respects speed", failures)

func _test_companion_safety(failures: Array[String]) -> void:
    var companion_scene: PackedScene = load(COMPANION_SCENE_PATH) as PackedScene
    TestAssertions.truthy(companion_scene != null and companion_scene.can_instantiate(), "companion scene parses", failures)
    if companion_scene == null or not companion_scene.can_instantiate():
        return
    var companion: PartyActor = companion_scene.instantiate() as PartyActor
    TestAssertions.truthy(companion != null and companion.get_script() != null, "companion script attaches", failures)
    if companion == null or companion.get_script() == null:
        if companion != null:
            companion.free()
        return
    companion.call("_physics_process", 1.0 / 60.0)
    TestAssertions.equal(companion.velocity, Vector3.ZERO, "unassigned companion remains stationary", failures)
    TestAssertions.truthy(companion.is_in_group("party_actors"), "companion belongs to party actor group", failures)
    companion.free()

func _test_party_actor_spawner(failures: Array[String]) -> void:
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    var actor_container := Node3D.new()
    var leader_scene: PackedScene = load("res://scenes/characters/leader.tscn") as PackedScene
    var leader: PartyActor = leader_scene.instantiate() as PartyActor
    actor_container.add_child(leader)

    var spawner_script: Script = load(SPAWNER_PATH) as Script
    TestAssertions.truthy(spawner_script != null and spawner_script.can_instantiate(), "party actor spawner parses", failures)
    if spawner_script == null or not spawner_script.can_instantiate():
        actor_container.free()
        party.free()
        return
    var spawner: Node = spawner_script.new() as Node
    spawner.call("initialize", party, actor_container, leader)
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    party.recruit(catalog.class_by_id(&"ranger"))
    party.recruit(catalog.class_by_id(&"mage"))
    party.recruit(catalog.class_by_id(&"cleric"))
    party.member_added.emit(PartyMemberState.new(5, catalog.class_by_id(&"fighter"), false))
    party.member_added.emit(PartyMemberState.new(6, catalog.class_by_id(&"mage"), false))

    TestAssertions.equal(actor_container.get_child_count(), 6, "spawner accepts arbitrary companion collection", failures)
    for index: int in range(1, actor_container.get_child_count()):
        var companion: PartyActor = actor_container.get_child(index) as PartyActor
        TestAssertions.truthy(companion != null, "spawned child %d is party actor" % index, failures)
        if companion == null:
            continue
        TestAssertions.truthy(companion.member_state != null and not companion.member_state.is_leader, "spawned child %d is companion record" % index, failures)
        TestAssertions.equal(companion.get("leader"), leader, "spawned child %d follows leader" % index, failures)
        TestAssertions.truthy(companion.position.length() <= 0.751, "spawned child %d uses small initial offset" % index, failures)

    spawner.free()
    actor_container.free()
    party.free()

func _desired_velocity(formation_script: Script, role: ClassDefinition.Role, actor_position: Vector3, leader_position: Vector3, threat_position: Vector3, preferred_distance: float, tether_distance: float, separation: Vector3, speed: float) -> Vector3:
    var result: Vector3 = formation_script.call("desired_velocity", role, actor_position, leader_position, threat_position, preferred_distance, tether_distance, separation, speed)
    return result
