extends SceneTree

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const FIGHTER_DEFINITION := preload("res://data/classes/fighter.tres")
const RIGHT_HAND_PATH := NodePath("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket")
const LEFT_HAND_PATH := NodePath("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket")

func _initialize() -> void:
	var actor := LEADER_SCENE.instantiate() as PartyActor
	root.add_child(actor)
	actor.configure(PartyMemberState.new(1, FIGHTER_DEFINITION, true))
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation
	var model := presentation.active_model as ForgeHumanoidModel if presentation != null else null
	if presentation == null or model == null or not actor.has_method(&"update_presentation_locomotion"):
		_fail("configured real Fighter locomotion bridge is unavailable")
		return
	var actor_rotation := actor.rotation
	var directions: Array[Dictionary] = [
		{&"velocity": Vector3(0.0, 0.0, -3.0), &"yaw": 0.0},
		{&"velocity": Vector3(3.0, 0.0, 0.0), &"yaw": -PI / 2.0},
		{&"velocity": Vector3(0.0, 0.0, 3.0), &"yaw": PI},
		{&"velocity": Vector3(-3.0, 0.0, 0.0), &"yaw": PI / 2.0},
	]
	for entry: Dictionary in directions:
		actor.velocity = entry[&"velocity"] as Vector3
		actor.call(&"update_presentation_locomotion")
		if not _yaw_matches(presentation.rotation.y, float(entry[&"yaw"])) or model.active_action_id != &"walk" or actor.rotation != actor_rotation:
			_fail("cardinal direction did not rotate only the walking presentation")
			return
	actor.velocity = Vector3.ZERO
	actor.call(&"update_presentation_locomotion")
	if model.active_action_id != &"idle" or actor.rotation != actor_rotation:
		_fail("zero velocity did not restore idle without rotating actor root")
		return
	var target_actor := Node3D.new()
	target_actor.position = Vector3(5.0, 0.0, 0.0)
	root.add_child(target_actor)
	var target := CombatTarget.new(target_actor, target_actor.position, 2)
	presentation.play_attack(FIGHTER_DEFINITION.primary_attack, target)
	actor.velocity = Vector3(-2.0, 0.0, 0.0)
	actor.call(&"update_presentation_locomotion")
	if model.active_action_id != &"attack_slash" or not is_equal_approx(presentation.rotation.y, -PI / 2.0):
		_fail("attack target lock did not override movement")
		return
	model.call(&"_on_animation_finished", &"attack_slash")
	if model.active_action_id != &"walk" or not is_equal_approx(presentation.rotation.y, PI / 2.0):
		_fail("source model attack completion did not restore latest movement")
		return
	if not _equipment_is_independent(presentation, model):
		_fail("sword shield or arm equipment independence failed")
		return
	print("PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1")
	actor.free()
	target_actor.free()
	quit(0)

func _equipment_is_independent(presentation: CharacterPresentation, model: ForgeHumanoidModel) -> bool:
	var right_socket := model.get_node_or_null(RIGHT_HAND_PATH) as Node3D
	var left_socket := model.get_node_or_null(LEFT_HAND_PATH) as Node3D
	var sword_nodes: Array = model.equipped_nodes.get(&"main_hand", [])
	var shield_nodes: Array = model.equipped_nodes.get(&"off_hand", [])
	var arms := _arm_meshes(model)
	if right_socket == null or left_socket == null or sword_nodes.is_empty() or shield_nodes.is_empty() or arms.size() < 8:
		return false
	for node: Node3D in sword_nodes:
		if node.get_parent() != right_socket or _is_arm_descendant(node) or _shares_arm_mesh(node, arms):
			return false
	for node: Node3D in shield_nodes:
		if node.get_parent() != left_socket or _is_arm_descendant(node) or _shares_arm_mesh(node, arms):
			return false
	if not presentation.clear_equipment_visual(&"main_hand") or model.equipped_item_id(&"main_hand") != &"" or model.equipped_item_id(&"off_hand") != &"forge_vanguard_shield" or not _all_valid(arms):
		return false
	return presentation.clear_equipment_visual(&"off_hand") and model.equipped_item_id(&"off_hand") == &"" and _all_valid(arms)

func _arm_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var ancestry := _ancestor_names(mesh)
		if "upperarm" in ancestry or "forearm" in ancestry:
			result.append(mesh)
	return result

func _is_arm_descendant(node: Node) -> bool:
	var ancestry := _ancestor_names(node)
	return "upperarm" in ancestry or "forearm" in ancestry

func _shares_arm_mesh(attachment: Node3D, arms: Array[MeshInstance3D]) -> bool:
	for equipment_mesh: MeshInstance3D in attachment.find_children("*", "MeshInstance3D", true, false):
		for arm: MeshInstance3D in arms:
			if equipment_mesh == arm or equipment_mesh.mesh == arm.mesh:
				return true
	return false

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

func _fail(reason: String) -> void:
	push_error("PARTY_FORGE_LOCOMOTION_SMOKE_ERROR %s" % reason)
	quit(1)

func _yaw_matches(actual: float, expected: float) -> bool:
	return absf(angle_difference(actual, expected)) <= 0.001
