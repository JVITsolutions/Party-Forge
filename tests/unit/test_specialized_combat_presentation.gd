extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const LAUNCH_SOCKET := &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket/ProjectileLaunchSocket"
const PROJECTILES := {
	&"ranger_shot": ["res://scenes/combat/presentation/projectiles/ranger_arrow.tscn", Vector3.ONE],
	&"marksman_heavy_shot": ["res://scenes/combat/presentation/projectiles/marksman_heavy_arrow.tscn", Vector3(1.45, 1.45, 1.45)],
	&"mage_burst": ["res://scenes/combat/presentation/projectiles/mage_fire_orb.tscn", Vector3.ONE],
	&"frost_shard": ["res://scenes/combat/presentation/projectiles/frost_shard.tscn", Vector3.ONE],
	&"cleric_bolt": ["res://scenes/combat/presentation/projectiles/cleric_lightning_bolt.tscn", Vector3.ONE],
	&"warlock_bolt": ["res://scenes/combat/presentation/projectiles/warlock_chaos_bolt.tscn", Vector3.ONE],
}
const EFFECTS := [
	"res://scenes/combat/presentation/effects/fire_impact.tscn",
	"res://scenes/combat/presentation/effects/frost_impact.tscn",
	"res://scenes/combat/presentation/effects/lightning_impact.tscn",
	"res://scenes/combat/presentation/effects/healing_blessing.tscn",
	"res://scenes/combat/presentation/effects/chaos_impact.tscn",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var all_exist := true
	for attack_id: StringName in PROJECTILES:
		var path := String(PROJECTILES[attack_id][0])
		var exists := ResourceLoader.exists(path)
		TestAssertions.truthy(exists, "%s specialized projectile exists" % attack_id, failures)
		all_exist = all_exist and exists
		var scene := load(path) as PackedScene if exists else null
		var node := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(node != null and node.has_method(&"configure"), "%s projectile obeys runtime API" % attack_id, failures)
		if node != null:
			node.free()
	for path: String in EFFECTS:
		var exists := ResourceLoader.exists(path)
		TestAssertions.truthy(exists, "%s effect exists" % path.get_file(), failures)
		all_exist = all_exist and exists
		var scene := load(path) as PackedScene if exists else null
		var node := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(node != null and node.has_method(&"configure"), "%s effect obeys runtime API" % path.get_file(), failures)
		if node != null:
			node.free()
	if not all_exist:
		return failures
	_test_specialized_launch_and_scale(failures)
	_test_invalid_specialized_scene_falls_back(failures)
	_test_impact_presentation_forwarding(failures)
	_test_healing_presentation_override(failures)
	_test_effect_lifecycle_and_material_isolation(failures)
	return failures

func _test_specialized_launch_and_scale(failures: Array[String]) -> void:
	for attack_id: StringName in [&"ranger_shot", &"marksman_heavy_shot"]:
		var fixture := _executor_fixture(attack_id)
		var executor := fixture[&"executor"] as AttackExecutor
		var owner := fixture[&"owner"] as PartyActor
		var target := fixture[&"target"] as PartyActor
		var root := fixture[&"root"] as Node3D
		var presentation := _presentation(attack_id, String(PROJECTILES[attack_id][0]), PROJECTILES[attack_id][1] as Vector3)
		var socket := (owner.get_node("Presentation") as CharacterPresentation).active_model.get_node(String(LAUNCH_SOCKET)) as Node3D
		socket.position += Vector3(0.67, 0.23, -0.19)
		var expected_transform := _transform_without_tree(socket)
		executor.execute(load("res://data/attacks/%s.tres" % attack_id) as AttackDefinition, target.get_combat_target(), presentation)
		var projectile := _first_projectile(root)
		TestAssertions.truthy(projectile != null, "%s spawns specialized projectile" % attack_id, failures)
		if projectile != null:
			TestAssertions.equal(projectile.name, StringName(_scene_name(attack_id)), "%s uses specialized scene root" % attack_id, failures)
			TestAssertions.equal(_transform_without_tree(projectile).origin, expected_transform.origin, "%s launches from declared socket" % attack_id, failures)
			TestAssertions.equal(projectile.scale, PROJECTILES[attack_id][1], "%s applies authored visual scale" % attack_id, failures)
		root.free()

func _test_invalid_specialized_scene_falls_back(failures: Array[String]) -> void:
	var fixture := _executor_fixture(&"ranger_shot")
	var executor := fixture[&"executor"] as AttackExecutor
	var target := fixture[&"target"] as PartyActor
	var root := fixture[&"root"] as Node3D
	var invalid_root := Node.new()
	var invalid_scene := PackedScene.new()
	TestAssertions.equal(invalid_scene.pack(invalid_root), OK, "invalid projectile fixture packs", failures)
	invalid_root.free()
	var presentation := _presentation(&"ranger_shot", "", Vector3.ONE)
	presentation.projectile_scene = invalid_scene
	var messages: Array[String] = []
	TestAssertions.truthy(executor.has_signal(&"projectile_presentation_error"), "executor exposes specialized fallback diagnostic", failures)
	if executor.has_signal(&"projectile_presentation_error"):
		executor.connect(&"projectile_presentation_error", func(message: String) -> void: messages.append(message))
	executor.execute(load("res://data/attacks/ranger_shot.tres") as AttackDefinition, target.get_combat_target(), presentation)
	var projectile := _first_projectile(root)
	TestAssertions.truthy(projectile != null and projectile.name == &"Projectile", "invalid specialized scene uses generic projectile", failures)
	TestAssertions.truthy(messages.size() == 1 and messages[0].begins_with("PARTY_FORGE_PROJECTILE_PRESENTATION_ERROR attack=ranger_shot"), "invalid specialized scene emits stable fallback diagnostic", failures)
	root.free()

func _test_impact_presentation_forwarding(failures: Array[String]) -> void:
	var fixture := _executor_fixture(&"mage_burst")
	var executor := fixture[&"executor"] as AttackExecutor
	var target := fixture[&"target"] as PartyActor
	var root := fixture[&"root"] as Node3D
	var presentation := _presentation(&"mage_burst", String(PROJECTILES[&"mage_burst"][0]), Vector3.ONE)
	presentation.impact_scene = load("res://scenes/combat/presentation/effects/fire_impact.tscn") as PackedScene
	presentation.impact_color = Color("ff6b35")
	executor.execute(load("res://data/attacks/mage_burst.tres") as AttackDefinition, target.get_combat_target(), presentation)
	var projectile := _first_projectile(root)
	TestAssertions.truthy(projectile != null, "area projectile exists for impact forwarding", failures)
	if projectile != null:
		TestAssertions.equal(projectile.get("impact_scene"), presentation.impact_scene, "projectile stores typed impact scene", failures)
		TestAssertions.equal(projectile.get("impact_color"), presentation.impact_color, "projectile stores typed impact color", failures)
		projectile.call("_impact")
		var effect := root.get_node_or_null("FireImpact")
		TestAssertions.truthy(effect != null, "projectile impact spawns typed presentation effect", failures)
	root.free()

func _test_healing_presentation_override(failures: Array[String]) -> void:
	var fixture := _executor_fixture(&"cleric_heal")
	var executor := fixture[&"executor"] as AttackExecutor
	var target := fixture[&"target"] as PartyActor
	var root := fixture[&"root"] as Node3D
	target.team_id = 1
	var health := target.get_node("HealthComponent") as HealthComponent
	health.current_health = 50.0
	var presentation := _presentation(&"cleric_heal", "", Vector3.ONE)
	presentation.impact_scene = load("res://scenes/combat/presentation/effects/healing_blessing.tscn") as PackedScene
	presentation.impact_color = Color("ffe891")
	executor.execute(load("res://data/attacks/cleric_heal.tres") as AttackDefinition, target.get_combat_target(), presentation)
	TestAssertions.truthy(root.get_node_or_null("HealingBlessing") != null, "heal uses specialized blessing effect", failures)
	TestAssertions.truthy(health.current_health > 50.0, "specialized heal presentation preserves healing math", failures)
	root.free()

func _test_effect_lifecycle_and_material_isolation(failures: Array[String]) -> void:
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var scene := load("res://scenes/combat/presentation/effects/fire_impact.tscn") as PackedScene
	var first := scene.instantiate() as PresentationEffect
	var second := scene.instantiate() as PresentationEffect
	root.add_child(first)
	root.add_child(second)
	first.configure(Color.RED, 0.1)
	second.configure(Color.BLUE, 0.1)
	var first_material := (first.get_node("EffectMesh") as MeshInstance3D).material_override as StandardMaterial3D
	var second_material := (second.get_node("EffectMesh") as MeshInstance3D).material_override as StandardMaterial3D
	TestAssertions.truthy(first_material != second_material, "effect instances duplicate their materials", failures)
	TestAssertions.equal(first.scale, Vector3.ONE * 0.35, "effect starts at authored minimum scale", failures)
	first.call("_process", 0.05)
	TestAssertions.truthy(first.scale.x > 0.35 and first.scale.x < 1.0, "effect expands over authored duration", failures)
	TestAssertions.truthy(first_material.albedo_color.a < 1.0, "effect fades material alpha", failures)
	first.call("_process", 0.05)
	TestAssertions.truthy(first.is_queued_for_deletion(), "effect frees itself at authored duration", failures)
	root.free()

func _executor_fixture(attack_id: StringName) -> Dictionary:
	var root := Node3D.new()
	root.name = "SpecializedPresentation%sTest" % attack_id
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	root.add_child(party)
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.configure_combat(CombatRng.new(700), catalog.damage_types)
	var owner := LEADER_SCENE.instantiate() as PartyActor
	root.add_child(owner)
	owner.configure(party.members[0])
	owner.configure_combat(party, root)
	var target := COMPANION_SCENE.instantiate() as PartyActor
	target.team_id = 2
	target.position = Vector3(4.0, 0.0, 0.0)
	root.add_child(target)
	target.configure(PartyMemberState.new(90, catalog.class_by_id(&"fighter"), false))
	var target_health := target.get_node("HealthComponent") as HealthComponent
	target_health.configure(100.0, false, 8.0, 0.5)
	var combatants: Array[Node3D] = [target]
	owner.attack_executor.configure(owner, party, root, combatants)
	return {&"root": root, &"owner": owner, &"target": target, &"executor": owner.attack_executor}

func _presentation(attack_id: StringName, scene_path: String, visual_scale: Vector3) -> AttackPresentationDefinition:
	var value := AttackPresentationDefinition.new()
	value.id = StringName("%s_visual" % attack_id)
	value.attack_id = attack_id
	value.action_id = &"attack_slash"
	value.required_event_name = &"release"
	value.launch_socket_id = LAUNCH_SOCKET
	value.projectile_scene = load(scene_path) as PackedScene if not scene_path.is_empty() else null
	value.projectile_scale = visual_scale
	return value

func _first_projectile(root: Node) -> PartyProjectile:
	for child: Node in root.get_children():
		if child is PartyProjectile:
			return child as PartyProjectile
	return null

func _scene_name(attack_id: StringName) -> String:
	match attack_id:
		&"ranger_shot": return "RangerArrow"
		&"marksman_heavy_shot": return "MarksmanHeavyArrow"
	return ""

func _transform_without_tree(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result
