extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")

var slash_requests := 0

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_hosts_and_collision_contracts(failures)
	_test_fighter_profile_activation_and_ranger_fallback(failures)
	_test_primary_attack_keeps_executor_and_uses_slash(failures)
	_test_damage_downed_and_revival_feedback(failures)
	_test_fighter_palettes_remain_instance_local(failures)
	return failures

func _test_scene_hosts_and_collision_contracts(failures: Array[String]) -> void:
	var leader := LEADER_SCENE.instantiate() as PartyActor
	var companion := COMPANION_SCENE.instantiate() as PartyActor
	_assert_actor_host(leader, "leader", 0.45, 1.5, failures)
	_assert_actor_host(companion, "companion", 0.4, 1.4, failures)
	leader.free()
	companion.free()

func _test_fighter_profile_activation_and_ranger_fallback(failures: Array[String]) -> void:
	var root := _new_root("PartyActorProfileActivationTest")
	var fighter := _new_actor(root, LEADER_SCENE, _definition(&"fighter"), true)
	var fighter_presentation := fighter.get_node_or_null("Presentation") as CharacterPresentation
	var fighter_fallback := fighter.get_node_or_null("MeshInstance3D") as MeshInstance3D
	TestAssertions.truthy(fighter_presentation != null and fighter_presentation.active_profile != null, "fighter activates Forge Vanguard profile", failures)
	if fighter_presentation != null:
		TestAssertions.equal(fighter_presentation.active_profile.id if fighter_presentation.active_profile != null else &"", &"forge_vanguard", "fighter activates Forge Vanguard", failures)
	TestAssertions.truthy(fighter_fallback != null and not fighter_fallback.visible, "fighter hides capsule fallback", failures)

	var ranger := _new_actor(root, COMPANION_SCENE, _definition(&"ranger"), false)
	var ranger_presentation := ranger.get_node_or_null("Presentation") as CharacterPresentation
	var ranger_fallback := ranger.get_node_or_null("MeshInstance3D") as MeshInstance3D
	TestAssertions.truthy(ranger_presentation != null and ranger_presentation.active_profile == null, "ranger has no active visual profile", failures)
	TestAssertions.truthy(ranger_fallback != null and ranger_fallback.visible, "ranger keeps capsule fallback visible", failures)
	root.free()

func _test_primary_attack_keeps_executor_and_uses_slash(failures: Array[String]) -> void:
	var root := _new_root("PartyActorAttackPresentationTest")
	var catalog := GameCatalog.load_defaults()
	var definition := _definition(&"fighter")
	var party := PartyManager.new()
	party.initialize(definition, catalog.traits)
	party.configure_combat(CombatRng.new(501), catalog.damage_types)
	var fighter := LEADER_SCENE.instantiate() as PartyActor
	root.add_child(fighter)
	fighter.configure(party.members[0])
	fighter.configure_combat(party, root)
	var controller := fighter.get_node_or_null("AttackController") as AttackController
	var presentation := fighter.get_node_or_null("Presentation") as CharacterPresentation
	TestAssertions.truthy(controller != null and fighter.attack_executor != null and controller.attack_ready.is_connected(Callable(fighter.attack_executor, "execute")), "fighter attack controller still forwards attacks to executor", failures)
	if controller != null and presentation != null and presentation.active_model != null:
		var player := presentation.active_model.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player != null:
			player.animation_started.connect(_on_animation_started)
			slash_requests = 0
			controller.attack_ready.emit(definition.primary_attack, CombatTarget.new(fighter, fighter.position, fighter.team_id))
			TestAssertions.equal(slash_requests, 1, "fighter cleave requests attack slash once", failures)
			TestAssertions.equal(player.current_animation, &"attack_slash", "fighter cleave selects attack slash", failures)
			TestAssertions.truthy(player.current_animation != &"attack_combo", "fighter cleave does not request preview-only attack combo", failures)
			player.animation_started.disconnect(_on_animation_started)
	root.free()
	party.free()

func _test_damage_downed_and_revival_feedback(failures: Array[String]) -> void:
	var root := _new_root("PartyActorFeedbackPresentationTest")
	var fighter := _new_actor(root, COMPANION_SCENE, _definition(&"fighter"), false)
	var health := fighter.get_node("HealthComponent") as HealthComponent
	var presentation := fighter.get_node_or_null("Presentation") as CharacterPresentation
	var model := presentation.active_model if presentation != null else null
	var primary_mesh := _first_primary_mesh(model)
	var original_color := (primary_mesh.material_override as StandardMaterial3D).albedo_color if primary_mesh != null else Color.TRANSPARENT
	health.apply_damage(1.0)
	TestAssertions.truthy(fighter.damage_flash_remaining > 0.0, "damage starts actor damage flash timer", failures)
	TestAssertions.near(float(model.get("_hit_weight")) if model != null else 0.0, 1.0, 0.001, "damage requests hit flinch feedback", failures)
	fighter.call("_advance_visual_feedback", 0.11)
	if primary_mesh != null:
		TestAssertions.equal((primary_mesh.material_override as StandardMaterial3D).albedo_color, original_color, "damage feedback restores red palette", failures)
	health.apply_damage(health.max_health)
	TestAssertions.truthy(bool(model.get("_is_downed")) if model != null else false, "downed signal forwards presentation state", failures)
	health.advance_time(health.revive_delay)
	TestAssertions.truthy(not bool(model.get("_is_downed")) if model != null else false, "revived signal clears presentation state", failures)
	root.free()

func _test_fighter_palettes_remain_instance_local(failures: Array[String]) -> void:
	var root := _new_root("PartyActorPaletteIsolationTest")
	var first_definition := _definition(&"fighter").duplicate() as ClassDefinition
	var second_definition := _definition(&"fighter").duplicate() as ClassDefinition
	first_definition.color = Color(0.8509804, 0.30980393, 0.30980393, 1.0)
	second_definition.color = Color(0.30980393, 0.47058824, 0.8509804, 1.0)
	var first := _new_actor(root, LEADER_SCENE, first_definition, true)
	var second := _new_actor(root, COMPANION_SCENE, second_definition, false)
	var first_presentation := first.get_node_or_null("Presentation") as CharacterPresentation
	var second_presentation := second.get_node_or_null("Presentation") as CharacterPresentation
	var first_mesh := _first_primary_mesh(first_presentation.active_model if first_presentation != null else null)
	var second_mesh := _first_primary_mesh(second_presentation.active_model if second_presentation != null else null)
	TestAssertions.truthy(first_mesh != null and second_mesh != null, "fighters expose independent primary palette meshes", failures)
	if first_mesh != null and second_mesh != null:
		TestAssertions.equal((first_mesh.material_override as StandardMaterial3D).albedo_color, first_definition.color, "first fighter keeps red palette", failures)
		TestAssertions.equal((second_mesh.material_override as StandardMaterial3D).albedo_color, second_definition.color, "second fighter keeps blue palette", failures)
		TestAssertions.truthy(first_mesh.material_override != second_mesh.material_override, "fighter palette materials are instance-local", failures)
	root.free()

func _assert_actor_host(actor: PartyActor, label: String, radius: float, height: float, failures: Array[String]) -> void:
	var fallback := actor.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation
	var shape := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	TestAssertions.truthy(fallback != null, "%s keeps direct capsule fallback mesh" % label, failures)
	TestAssertions.truthy(presentation != null, "%s owns CharacterPresentation child" % label, failures)
	TestAssertions.truthy(shape != null and shape.shape is CapsuleShape3D, "%s collision remains capsule", failures)
	if shape != null and shape.shape is CapsuleShape3D:
		var capsule := shape.shape as CapsuleShape3D
		TestAssertions.near(capsule.radius, radius, 0.001, "%s collision capsule radius" % label, failures)
		TestAssertions.near(capsule.height, height, 0.001, "%s collision capsule height" % label, failures)

func _new_actor(root: Node3D, scene: PackedScene, definition: ClassDefinition, is_leader: bool) -> PartyActor:
	var actor := scene.instantiate() as PartyActor
	root.add_child(actor)
	actor.configure(PartyMemberState.new(1, definition, is_leader))
	return actor

func _definition(id: StringName) -> ClassDefinition:
	return load("res://data/classes/%s.tres" % id) as ClassDefinition

func _first_primary_mesh(model: Node) -> MeshInstance3D:
	if model == null:
		return null
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		if StringName(node.get_meta(&"palette_region", &"")) == &"primary":
			return node as MeshInstance3D
	return null

func _new_root(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root

func _on_animation_started(animation_name: StringName) -> void:
	if animation_name == &"attack_slash":
		slash_requests += 1
