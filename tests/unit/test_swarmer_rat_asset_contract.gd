extends RefCounted

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_sniff", &"scurry", &"pounce_bite", &"hit_react", &"death_curl",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_contract(failures)
	_test_presentation_and_defeat_contract(failures)
	return failures

func _test_scene_contract(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists("res://assets/models/enemies/swarmer_rat.glb"), "rat GLB exists", failures)
	var scene := load("res://scenes/enemies/swarmer.tscn") as PackedScene
	TestAssertions.truthy(scene != null, "swarmer scene loads", failures)
	if scene == null:
		return
	var enemy := scene.instantiate() as CharacterBody3D
	TestAssertions.truthy(enemy != null, "swarmer remains CharacterBody3D", failures)
	if enemy == null:
		return
	TestAssertions.truthy(enemy.is_in_group("hostile_actors"), "swarmer remains hostile actor", failures)
	TestAssertions.truthy(enemy.get_node_or_null("HealthComponent") is HealthComponent, "health component preserved", failures)
	var mesh := enemy.find_child("MeshInstance3D", true, false) as MeshInstance3D
	TestAssertions.truthy(mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() == 2, "two-surface skinned rat mesh exists", failures)
	var collision := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	TestAssertions.truthy(collision != null and collision.shape is CapsuleShape3D, "torso capsule replaces sphere", failures)
	var skeleton := enemy.find_child("Skeleton3D", true, false) as Skeleton3D
	TestAssertions.truthy(skeleton != null and skeleton.get_bone_count() == 28, "28-bone rat skeleton exists", failures)
	var animation_player := enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	TestAssertions.truthy(animation_player != null, "rat animation player exists", failures)
	if animation_player != null:
		var names := animation_player.get_animation_list()
		for animation_name: StringName in REQUIRED_ANIMATIONS:
			TestAssertions.truthy(names.has(animation_name), "animation %s imported" % animation_name, failures)
	var presentation := enemy.get_node_or_null("RatPresentation")
	TestAssertions.truthy(presentation != null and presentation.get_script() != null and presentation.get_script().resource_path == "res://scripts/enemies/swarmer_rat_presentation.gd", "rat presentation adapter exists", failures)
	var definition := enemy.get("definition") as EnemyDefinition
	TestAssertions.near(definition.max_health, 12.0, 0.001, "health unchanged", failures)
	TestAssertions.near(definition.move_speed, 4.8, 0.001, "speed unchanged", failures)
	TestAssertions.equal(definition.experience, 2, "experience unchanged", failures)
	var attack := definition.attack_by_id(&"swarmer_contact")
	TestAssertions.near(attack.cooldown, 0.8, 0.001, "cooldown unchanged", failures)
	TestAssertions.near(attack.range, 0.9, 0.001, "range unchanged", failures)
	TestAssertions.equal(attack.damage_components.size(), 1, "one damage component preserved", failures)
	if attack.damage_components.size() == 1:
		TestAssertions.equal(attack.damage_components[0].damage_type_id, &"physical", "physical damage type unchanged", failures)
		TestAssertions.near(attack.damage_components[0].base_amount, 8.0, 0.001, "damage unchanged", failures)
	enemy.free()

func _test_presentation_and_defeat_contract(failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var enemy := (load("res://scenes/enemies/swarmer.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(enemy)
	var presentation := enemy.get_node("RatPresentation")
	presentation.call("_ready")
	enemy.set("rat_presentation", presentation)
	enemy.call("configure", enemy.get("definition"))
	var player := enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	TestAssertions.equal(player.current_animation, &"idle_sniff", "rat begins in idle animation", failures)
	presentation.call("play_locomotion", true)
	TestAssertions.equal(player.current_animation, &"scurry", "moving rat selects scurry", failures)
	presentation.call("play_attack")
	TestAssertions.equal(player.current_animation, &"pounce_bite", "contact attack selects pounce bite", failures)
	presentation.call("_on_animation_finished", &"pounce_bite")
	var mesh := enemy.find_child("MeshInstance3D", true, false) as MeshInstance3D
	var primary_before := (mesh.get_active_material(0) as StandardMaterial3D).albedo_color
	var eyes_before := (mesh.get_active_material(1) as StandardMaterial3D).albedo_color
	var primary_uses_vertex_color := (mesh.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo
	var health := enemy.get_node("HealthComponent") as HealthComponent
	enemy.set("last_presentation_health", health.current_health)
	health.apply_damage(1.0)
	TestAssertions.equal((mesh.get_active_material(0) as StandardMaterial3D).albedo_color, Color.WHITE, "primary surface flashes white", failures)
	TestAssertions.equal((mesh.get_active_material(1) as StandardMaterial3D).albedo_color, Color.WHITE, "eye surface flashes white", failures)
	TestAssertions.truthy(not (mesh.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo, "flash overrides primary vertex colors", failures)
	enemy.call("_process", 0.11)
	TestAssertions.equal((mesh.get_active_material(0) as StandardMaterial3D).albedo_color, primary_before, "primary palette restores after flash", failures)
	TestAssertions.equal((mesh.get_active_material(1) as StandardMaterial3D).albedo_color, eyes_before, "eye palette restores after flash", failures)
	TestAssertions.equal((mesh.get_active_material(0) as StandardMaterial3D).vertex_color_use_as_albedo, primary_uses_vertex_color, "primary vertex-color palette restores after flash", failures)
	var rewards: Array[int] = []
	enemy.connect("reward_dropped", func(value: int, _position: Vector3) -> void: rewards.append(value))
	enemy.call("defeat")
	enemy.call("defeat")
	TestAssertions.equal(rewards, [2], "double defeat drops exactly one reward", failures)
	TestAssertions.truthy((enemy.get_node("CollisionShape3D") as CollisionShape3D).disabled, "death disables torso collision", failures)
	TestAssertions.equal(player.current_animation, &"death_curl", "death selects curl animation", failures)
	root.free()
