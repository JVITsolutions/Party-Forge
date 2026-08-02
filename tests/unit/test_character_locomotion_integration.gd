extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const FIGHTER_DEFINITION := preload("res://data/classes/fighter.tres")
const RIGHT_HAND_PATH := NodePath("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket")
const LEFT_HAND_PATH := NodePath("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket")

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "CharacterLocomotionIntegrationTest"
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var actor := LEADER_SCENE.instantiate() as PartyActor
	root.add_child(actor)
	actor.configure(PartyMemberState.new(1, FIGHTER_DEFINITION, true))
	var presentation := actor.get_node("Presentation") as CharacterPresentation
	var model := presentation.active_model as ForgeHumanoidModel
	TestAssertions.truthy(actor.has_method(&"update_presentation_locomotion"), "real Fighter actor exposes locomotion bridge", failures)
	TestAssertions.truthy(model != null and presentation.active_profile.id == &"forge_vanguard", "integration uses the real Forge Vanguard Fighter model", failures)
	if model == null:
		root.free()
		return failures
	_test_cardinal_walk_idle(actor, presentation, model, failures)
	_test_attack_lock_and_downed_restore(root, actor, presentation, model, failures)
	_test_equipment_remains_independent(presentation, model, failures)
	root.free()
	return failures

func _test_cardinal_walk_idle(actor: PartyActor, presentation: CharacterPresentation, model: ForgeHumanoidModel, failures: Array[String]) -> void:
	var actor_rotation := actor.rotation
	var has_turn_api := _has_property(presentation, &"target_yaw") and presentation.has_method(&"advance_visual")
	TestAssertions.truthy(has_turn_api, "presentation exposes bounded visual turning", failures)
	if not has_turn_api:
		return
	var directions: Array[Dictionary] = [
		{&"velocity": Vector3(0.0, 0.0, -3.0), &"yaw": 0.0, &"label": "forward"},
		{&"velocity": Vector3(3.0, 0.0, 0.0), &"yaw": -PI / 2.0, &"label": "right"},
		{&"velocity": Vector3(0.0, 0.0, 3.0), &"yaw": PI, &"label": "back"},
		{&"velocity": Vector3(-3.0, 0.0, 0.0), &"yaw": PI / 2.0, &"label": "left"},
	]
	for entry: Dictionary in directions:
		actor.velocity = entry[&"velocity"] as Vector3
		_update_actor(actor)
		TestAssertions.truthy(_yaw_matches(float(presentation.get(&"target_yaw")), float(entry[&"yaw"])), "%s velocity sets the presentation target yaw" % entry[&"label"], failures)
		var before := presentation.rotation.y
		presentation.call(&"advance_visual", 0.05)
		TestAssertions.truthy(absf(angle_difference(presentation.rotation.y, before)) <= 0.501, "%s turn is bounded per frame" % entry[&"label"], failures)
		_advance_to_yaw(presentation, float(entry[&"yaw"]))
		TestAssertions.truthy(_yaw_matches(presentation.rotation.y, float(entry[&"yaw"])), "%s velocity converges the Fighter presentation" % entry[&"label"], failures)
		TestAssertions.equal(model.active_action_id, &"walk", "%s velocity selects real walk action" % entry[&"label"], failures)
		TestAssertions.equal(actor.rotation, actor_rotation, "%s velocity leaves actor and collision root rotation unchanged" % entry[&"label"], failures)
	actor.velocity = Vector3.ZERO
	_update_actor(actor)
	TestAssertions.equal(model.active_action_id, &"idle", "zero actual velocity restores real guard idle", failures)
	TestAssertions.near(presentation.rotation.y, PI / 2.0, 0.001, "zero velocity retains last movement facing", failures)
	TestAssertions.equal(actor.rotation, actor_rotation, "idle transition leaves actor root rotation unchanged", failures)
	_test_wraparound_turn(actor, presentation, failures)

func _test_attack_lock_and_downed_restore(root: Node3D, actor: PartyActor, presentation: CharacterPresentation, model: ForgeHumanoidModel, failures: Array[String]) -> void:
	actor.velocity = Vector3(0.0, 0.0, -2.0)
	_update_actor(actor)
	var target_actor := Node3D.new()
	target_actor.position = Vector3(5.0, 0.0, 0.0)
	root.add_child(target_actor)
	var target := CombatTarget.new(target_actor, target_actor.position, 2)
	presentation.play_attack(FIGHTER_DEFINITION.primary_attack, target)
	TestAssertions.equal(model.active_action_id, &"attack_slash", "real Fighter attack begins authored slash", failures)
	TestAssertions.near(float(presentation.get(&"target_yaw")), -PI / 2.0, 0.001, "attack locks target facing", failures)
	_advance_to_yaw(presentation, -PI / 2.0)
	TestAssertions.near(presentation.rotation.y, -PI / 2.0, 0.001, "combat turn converges to target", failures)
	actor.velocity = Vector3(-2.0, 0.0, 0.0)
	_update_actor(actor)
	TestAssertions.near(presentation.rotation.y, -PI / 2.0, 0.001, "movement cannot override attack target facing", failures)
	model.call(&"_on_animation_finished", &"attack_slash")
	TestAssertions.equal(model.active_action_id, &"walk", "source model attack completion restores latest walk", failures)
	_advance_to_yaw(presentation, PI / 2.0)
	TestAssertions.near(presentation.rotation.y, PI / 2.0, 0.001, "source model attack completion restores latest movement facing", failures)
	presentation.set_downed(true)
	actor.velocity = Vector3(0.0, 0.0, 2.0)
	_update_actor(actor)
	TestAssertions.equal(model.active_action_id, &"", "downed Fighter cannot enter walk", failures)
	presentation.set_downed(false)
	TestAssertions.equal(model.active_action_id, &"walk", "revived Fighter restores stored walk", failures)
	_advance_to_yaw(presentation, PI)
	TestAssertions.truthy(_yaw_matches(presentation.rotation.y, PI), "revived Fighter restores stored movement facing", failures)
	TestAssertions.equal(actor.rotation, Vector3.ZERO, "attack and downed state never rotate actor root", failures)

func _test_equipment_remains_independent(presentation: CharacterPresentation, model: ForgeHumanoidModel, failures: Array[String]) -> void:
	var right_socket := model.get_node_or_null(RIGHT_HAND_PATH) as Node3D
	var left_socket := model.get_node_or_null(LEFT_HAND_PATH) as Node3D
	var sword_nodes: Array = model.equipped_nodes.get(&"main_hand", [])
	var shield_nodes: Array = model.equipped_nodes.get(&"off_hand", [])
	var arm_meshes := _arm_meshes(model)
	TestAssertions.truthy(right_socket != null and left_socket != null, "real Fighter exposes exact hand sockets", failures)
	TestAssertions.truthy(not sword_nodes.is_empty() and not shield_nodes.is_empty(), "real Fighter equips separate sword and shield nodes", failures)
	for node: Node3D in sword_nodes:
		TestAssertions.equal(node.get_parent(), right_socket, "sword attachment is directly socketed to right hand", failures)
		_assert_not_arm_geometry(node, arm_meshes, "sword", failures)
	for node: Node3D in shield_nodes:
		TestAssertions.equal(node.get_parent(), left_socket, "shield attachment is directly socketed to left hand", failures)
		_assert_not_arm_geometry(node, arm_meshes, "shield", failures)
	TestAssertions.truthy(presentation.clear_equipment_visual(&"main_hand"), "real Fighter clears sword independently", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"", "sword slot is empty after clear", failures)
	TestAssertions.equal(model.equipped_item_id(&"off_hand"), &"forge_vanguard_shield", "clearing sword preserves shield", failures)
	TestAssertions.truthy(_all_valid(arm_meshes), "clearing sword preserves all arm meshes", failures)
	TestAssertions.truthy(presentation.clear_equipment_visual(&"off_hand"), "real Fighter clears shield independently", failures)
	TestAssertions.equal(model.equipped_item_id(&"off_hand"), &"", "shield slot is empty after clear", failures)
	TestAssertions.truthy(_all_valid(arm_meshes), "clearing shield preserves all arm meshes", failures)

func _update_actor(actor: PartyActor) -> void:
	if actor.has_method(&"update_presentation_locomotion"):
		actor.call(&"update_presentation_locomotion")

func _test_wraparound_turn(actor: PartyActor, presentation: CharacterPresentation, failures: Array[String]) -> void:
	presentation.rotation.y = PI - 0.05
	var desired_yaw := -PI + 0.05
	actor.velocity = Vector3(-sin(desired_yaw), 0.0, -cos(desired_yaw))
	_update_actor(actor)
	var before := presentation.rotation.y
	presentation.call(&"advance_visual", 0.01)
	TestAssertions.truthy(absf(angle_difference(presentation.rotation.y, before)) <= 0.101, "wraparound turn uses the bounded short arc", failures)
	_advance_to_yaw(presentation, desired_yaw)
	TestAssertions.truthy(_yaw_matches(presentation.rotation.y, desired_yaw), "wraparound turn converges across PI", failures)

func _advance_to_yaw(presentation: CharacterPresentation, expected: float) -> void:
	for _step: int in 120:
		presentation.call(&"advance_visual", 0.016)
		if _yaw_matches(presentation.rotation.y, expected):
			return

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get(&"name", &"")) == property_name:
			return true
	return false

func _arm_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var ancestry := _ancestor_names(mesh)
		if "upperarm" in ancestry or "forearm" in ancestry:
			result.append(mesh)
	return result

func _assert_not_arm_geometry(attachment: Node3D, arms: Array[MeshInstance3D], label: String, failures: Array[String]) -> void:
	var ancestry := _ancestor_names(attachment)
	TestAssertions.truthy("upperarm" not in ancestry and "forearm" not in ancestry, "%s is not a descendant of arm geometry" % label, failures)
	for equipment_mesh: MeshInstance3D in attachment.find_children("*", "MeshInstance3D", true, false):
		for arm: MeshInstance3D in arms:
			TestAssertions.truthy(equipment_mesh != arm and equipment_mesh.mesh != arm.mesh, "%s mesh resource is distinct from arm mesh" % label, failures)

func _ancestor_names(node: Node) -> String:
	var result := ""
	var cursor := node
	while cursor != null:
		result += String(cursor.name).to_lower()
		cursor = cursor.get_parent()
	return result

func _all_valid(nodes: Array[MeshInstance3D]) -> bool:
	for node: MeshInstance3D in nodes:
		if not is_instance_valid(node):
			return false
	return true

func _yaw_matches(actual: float, expected: float) -> bool:
	return absf(angle_difference(actual, expected)) <= 0.001
