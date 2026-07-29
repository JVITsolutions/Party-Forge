extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    TestAssertions.equal(LeaderMovement.velocity(Vector2.ZERO, 6.0), Vector3.ZERO, "zero input is stationary", failures)
    TestAssertions.equal(LeaderMovement.velocity(Vector2(1.0, 0.0), 6.0), Vector3(6.0, 0.0, 0.0), "horizontal input is planar", failures)
    var diagonal: Vector3 = LeaderMovement.velocity(Vector2(1.0, 1.0), 6.0)
    TestAssertions.truthy(diagonal.length() <= 6.0001, "diagonal never exceeds speed", failures)
    TestAssertions.near(diagonal.length(), 6.0, 0.001, "diagonal preserves full speed", failures)
    _test_party_actor_interface(failures)
    _test_scene_contracts(failures)
    return failures

func _test_party_actor_interface(failures: Array[String]) -> void:
    var actor_scene: PackedScene = load("res://scenes/characters/leader.tscn") as PackedScene
    var actor: PartyActor = actor_scene.instantiate() as PartyActor
    var configure_argument_name := StringName()
    for method: Dictionary in actor.get_method_list():
        if method["name"] == &"configure":
            var arguments: Array = method["args"]
            if not arguments.is_empty():
                configure_argument_name = arguments[0]["name"]
            break
    TestAssertions.equal(configure_argument_name, &"member_state", "configure member_state interface", failures)

    var definition: ClassDefinition = load("res://data/classes/fighter.tres") as ClassDefinition
    var member := PartyMemberState.new(1, definition, true)
    actor.configure(member)
    TestAssertions.equal(actor.member_state, member, "actor stores member state", failures)
    TestAssertions.near(actor.move_speed, definition.move_speed, 0.001, "actor uses class move speed", failures)
    var health: HealthComponent = actor.get_node("HealthComponent") as HealthComponent
    TestAssertions.near(health.max_health, definition.max_health, 0.001, "actor configures class health", failures)
    TestAssertions.near(actor.receive_damage(10.0), 4.0, 0.001, "actor forwards damage", failures)
    actor.free()

func _test_scene_contracts(failures: Array[String]) -> void:
    var scene_paths: PackedStringArray = [
        "res://scenes/arena/arena.tscn",
        "res://scenes/characters/leader.tscn",
        "res://scenes/camera/leader_camera.tscn",
    ]
    var all_exist := true
    for path: String in scene_paths:
        var exists: bool = ResourceLoader.exists(path)
        TestAssertions.truthy(exists, "scene exists: %s" % path, failures)
        all_exist = all_exist and exists
    if not all_exist:
        return

    var arena_scene: PackedScene = load(scene_paths[0]) as PackedScene
    var arena: Node3D = arena_scene.instantiate() as Node3D
    var floor_body: StaticBody3D = arena.get_node("Floor") as StaticBody3D
    var floor_mesh: MeshInstance3D = arena.get_node("Floor/MeshInstance3D") as MeshInstance3D
    var floor_collision: CollisionShape3D = arena.get_node("Floor/CollisionShape3D") as CollisionShape3D
    TestAssertions.equal((floor_mesh.mesh as BoxMesh).size, Vector3(40.0, 0.5, 30.0), "arena floor mesh size", failures)
    TestAssertions.equal((floor_collision.shape as BoxShape3D).size, Vector3(40.0, 0.5, 30.0), "arena floor collision size", failures)
    TestAssertions.equal(floor_body.collision_layer, 1, "floor collision layer", failures)
    TestAssertions.equal(floor_body.collision_mask, 2, "floor blocks actor layer only", failures)
    for boundary_name: String in ["BoundaryNorth", "BoundarySouth", "BoundaryWest", "BoundaryEast"]:
        var boundary: StaticBody3D = arena.get_node(boundary_name) as StaticBody3D
        TestAssertions.equal(boundary.collision_layer, 1, "%s collision layer" % boundary_name, failures)
        TestAssertions.equal(boundary.collision_mask, 2, "%s blocks actor layer only" % boundary_name, failures)
    TestAssertions.equal((arena.get_node("PlayerSpawn") as Marker3D).position, Vector3(0.0, 0.75, 0.0), "player spawn position", failures)
    var expected_spawns: Array[Vector3] = [
        Vector3(-17.0, 0.75, -12.0), Vector3(17.0, 0.75, -12.0),
        Vector3(-17.0, 0.75, 12.0), Vector3(17.0, 0.75, 12.0),
    ]
    for index: int in expected_spawns.size():
        var marker: Marker3D = arena.get_node("EnemySpawnMarker%d" % (index + 1)) as Marker3D
        TestAssertions.equal(marker.position, expected_spawns[index], "enemy spawn marker %d" % (index + 1), failures)
        TestAssertions.truthy(marker.is_in_group("enemy_spawn_markers"), "enemy marker group %d" % (index + 1), failures)
    arena.free()

    var leader_scene: PackedScene = load(scene_paths[1]) as PackedScene
    var leader: CharacterBody3D = leader_scene.instantiate() as CharacterBody3D
    TestAssertions.truthy(leader.is_in_group("party_actors"), "leader party actor group", failures)
    TestAssertions.equal(leader.collision_layer, 2, "leader actor collision layer", failures)
    TestAssertions.equal(leader.collision_mask, 1, "leader collides with environment", failures)
    TestAssertions.truthy(leader.get_node("HealthComponent") is HealthComponent, "leader owns health component", failures)
    TestAssertions.truthy(leader.get_node("CollisionShape3D") is CollisionShape3D, "leader owns collision shape", failures)
    TestAssertions.truthy(leader.get_node("MeshInstance3D") is MeshInstance3D, "leader owns colored mesh", failures)
    TestAssertions.truthy(leader.get_node("AttackController") is AttackController, "leader owns attack controller", failures)
    TestAssertions.equal(leader.get("member_state"), null, "leader starts before member configuration", failures)
    var initial_target: CombatTarget = leader.call("get_combat_target") as CombatTarget
    TestAssertions.truthy(initial_target != null and initial_target.is_available, "unconfigured leader exposes safe target", failures)
    leader.free()

    var camera_scene: PackedScene = load(scene_paths[2]) as PackedScene
    var camera_rig: Node3D = camera_scene.instantiate() as Node3D
    var camera: Camera3D = camera_rig.get_node("Camera3D") as Camera3D
    TestAssertions.equal(camera.position, Vector3(0.0, 18.0, 14.0), "camera fixed offset", failures)
    TestAssertions.near(camera.rotation_degrees.x, -55.0, 0.001, "camera high angle", failures)
    TestAssertions.near(camera.fov, 52.0, 0.001, "camera perspective fov", failures)
    camera_rig.free()

    var main_scene: PackedScene = load("res://scenes/game/main.tscn") as PackedScene
    var main: Node = main_scene.instantiate()
    var main_leader: Node3D = main.get_node("Leader") as Node3D
    var main_camera: Node3D = main.get_node("LeaderCamera") as Node3D
    main_camera.call("_resolve_target")
    TestAssertions.truthy(main.get_node_or_null("Arena") != null, "main instances arena", failures)
    TestAssertions.truthy(main_leader != null, "main instances leader", failures)
    TestAssertions.truthy(main_camera != null, "main instances camera", failures)
    TestAssertions.equal(main_leader.position, Vector3(0.0, 0.75, 0.0), "main leader uses player spawn", failures)
    TestAssertions.equal(main_camera.get("target"), main_leader, "camera targets leader", failures)
    main.free()
