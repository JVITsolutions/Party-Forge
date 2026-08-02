extends RefCounted

const EXPECTED_SLOTS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]
const FIGHTER_IDS: Array[StringName] = [
	&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves",
	&"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet",
	&"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt",
	&"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotCatalog.SLOT_IDS, EXPECTED_SLOTS, "PoE 1 sheet slot order", failures)
	var profile := load("res://data/presentation/profiles/forge_vanguard.tres") as CharacterVisualProfile
	TestAssertions.truthy(profile != null, "Fighter profile loads", failures)
	if profile == null:
		return failures
	TestAssertions.equal(profile.default_equipment.size(), 11, "Fighter default sheet has eleven items", failures)
	if profile.default_equipment.size() == 11:
		TestAssertions.equal(profile.default_equipment[9].item.id, &"forge_vanguard_sword", "sword remains default", failures)
		TestAssertions.equal(profile.default_equipment[10].item.id, &"forge_vanguard_shield", "shield remains default", failures)
	TestAssertions.equal(profile.available_equipment.size(), 12, "hammer remains an alternative", failures)
	for item_id: StringName in FIGHTER_IDS:
		var base_path := "res://data/equipment/bases/forge_vanguard/%s.tres" % item_id
		var visual_path := "res://data/presentation/equipment/forge_vanguard/%s.tres" % item_id
		var scene_path := "res://scenes/equipment/forge_vanguard/%s.tscn" % item_id
		TestAssertions.truthy(ResourceLoader.exists(base_path), "%s base exists" % item_id, failures)
		TestAssertions.truthy(ResourceLoader.exists(visual_path), "%s visual exists" % item_id, failures)
		TestAssertions.truthy(ResourceLoader.exists(scene_path), "%s independent scene exists" % item_id, failures)
	for item: EquipmentBaseDefinition in profile.available_equipment:
		TestAssertions.truthy(item != null and item.presentation != null and item.presentation.presentation_scene != null, "%s has independent scene" % (item.id if item != null else &"<null>"), failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_humanoid_model.tscn"), "shared humanoid exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_masculine.tscn"), "masculine base exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_feminine.tscn"), "feminine base exists", failures)
	_assert_fail_closed_nude_models(profile, failures)
	_assert_profile_starts_guard_idle(profile, failures)
	return failures

func _assert_profile_starts_guard_idle(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	var presentation := CharacterPresentation.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(presentation)
	TestAssertions.truthy(presentation.apply_profile(profile, Color("d94f4f")), "applying Fighter profile succeeds", failures)
	var player := presentation.active_model.get_node_or_null("AnimationPlayer") as AnimationPlayer if presentation.active_model != null else null
	TestAssertions.truthy(player != null and player.current_animation == &"idle" and player.is_playing(), "Fighter profile starts looping idle", failures)
	if player != null and player.has_animation(&"idle"):
		var idle := player.get_animation(&"idle")
		TestAssertions.equal(idle.loop_mode, Animation.LOOP_LINEAR, "Fighter idle loops", failures)
		var non_neutral := 0
		for pivot_path: String in [
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
			"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
		]:
			var track := idle.find_track(NodePath("%s:rotation" % pivot_path), Animation.TYPE_ROTATION_3D)
			TestAssertions.truthy(track >= 0, "guard idle contains %s rotation track" % pivot_path, failures)
			if track >= 0:
				var rotation := idle.rotation_track_interpolate(track, 0.0)
				if rotation.angle_to(Quaternion.IDENTITY) > 0.05:
					non_neutral += 1
		TestAssertions.equal(non_neutral, 4, "guard idle keeps both shoulder and elbow joints out of neutral A-pose", failures)
	presentation.free()

func _assert_fail_closed_nude_models(profile: CharacterVisualProfile, failures: Array[String]) -> void:
	for scene_path: String in [
		"res://scenes/characters/presentation/forge_humanoid_model.tscn",
		"res://scenes/characters/presentation/forge_base_masculine.tscn",
		"res://scenes/characters/presentation/forge_base_feminine.tscn",
	]:
		var scene := load(scene_path) as PackedScene
		var model := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(model != null, "%s instantiates for nude modularity check" % scene_path, failures)
		if model == null:
			continue
		for node: Node in model.find_children("*", "", true, false):
			TestAssertions.truthy(not node.has_meta(&"equipment_slot") and not node.has_meta(&"equipment_visual_id"), "%s has no embedded equipment metadata at %s" % [scene_path, node.name], failures)
			var node_name := String(node.name).to_lower()
			TestAssertions.truthy("sword" not in node_name and "shield" not in node_name and "hammer" not in node_name and "weapon" not in node_name, "%s has no baked weapon node at %s" % [scene_path, node.name], failures)
		model.free()
	var runtime_model := profile.presentation_scene.instantiate() as ForgeHumanoidModel
	TestAssertions.truthy(runtime_model != null, "shared humanoid instantiates for delayed equipment check", failures)
	if runtime_model == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(runtime_model)
	var right_socket := runtime_model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket") as Node3D
	var left_socket := runtime_model.get_node_or_null("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket") as Node3D
	var arm_meshes := _arm_meshes(runtime_model)
	TestAssertions.truthy(right_socket != null and left_socket != null, "shared humanoid exposes exact independent hand sockets", failures)
	TestAssertions.truthy(arm_meshes.size() >= 8, "shared humanoid retains both preset arm meshes", failures)
	if right_socket == null or left_socket == null or arm_meshes.size() < 8:
		runtime_model.free()
		return
	TestAssertions.equal(runtime_model.equipped_item_id(&"main_hand"), &"", "nude shared model begins without a sword", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"off_hand"), &"", "nude shared model begins without a shield", failures)
	var sword := _visual_by_id(profile, &"forge_vanguard_sword")
	var shield := _visual_by_id(profile, &"forge_vanguard_shield")
	TestAssertions.truthy(sword != null and shield != null, "independent sword and shield definitions exist", failures)
	if sword == null or shield == null:
		runtime_model.free()
		return
	var right_before := _children(right_socket)
	var left_before := _children(left_socket)
	TestAssertions.truthy(runtime_model.apply_equipment_visual(&"main_hand", sword), "independent sword scene equips through its exact socket", failures)
	var sword_nodes := _new_children(right_socket, right_before)
	TestAssertions.truthy(not sword_nodes.is_empty(), "sword creates independent right-hand attachment nodes", failures)
	TestAssertions.truthy(runtime_model.apply_equipment_visual(&"off_hand", shield), "independent shield scene equips through its exact socket", failures)
	var shield_nodes := _new_children(left_socket, left_before)
	TestAssertions.truthy(not shield_nodes.is_empty(), "shield creates independent left-hand attachment nodes", failures)
	_assert_independent_attachment(runtime_model, sword_nodes, arm_meshes, "sword", failures)
	_assert_independent_attachment(runtime_model, shield_nodes, arm_meshes, "shield", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"main_hand"), &"forge_vanguard_sword", "sword appears only after scene application", failures)
	TestAssertions.equal(runtime_model.equipped_item_id(&"off_hand"), &"forge_vanguard_shield", "shield appears only after scene application", failures)
	TestAssertions.truthy(runtime_model.set_body_preset(&"masculine") and _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes), "masculine body swap preserves independent equipment", failures)
	TestAssertions.truthy(runtime_model.set_body_preset(&"feminine") and _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes), "feminine body swap preserves independent equipment", failures)
	TestAssertions.truthy(runtime_model.clear_equipment_visual(&"main_hand"), "clearing main hand succeeds", failures)
	TestAssertions.truthy(not _nodes_alive(sword_nodes) and _nodes_alive(shield_nodes) and _meshes_alive(arm_meshes), "clearing sword leaves shield and both arms intact", failures)
	TestAssertions.truthy(runtime_model.clear_equipment_visual(&"off_hand"), "clearing off hand succeeds", failures)
	TestAssertions.truthy(not _nodes_alive(shield_nodes) and _meshes_alive(arm_meshes), "clearing shield leaves both arms intact", failures)
	runtime_model.free()

func _visual_by_id(profile: CharacterVisualProfile, item_id: StringName) -> EquipmentVisualDefinition:
	var item := profile.available_equipment.filter(func(candidate: EquipmentBaseDefinition) -> bool: return candidate != null and candidate.id == item_id)
	return item[0].presentation as EquipmentVisualDefinition if not item.is_empty() else null

func _children(node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node in node.get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result

func _new_children(node: Node, before: Array[Node3D]) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child: Node3D in _children(node):
		if child not in before:
			result.append(child)
	return result

func _arm_meshes(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var ancestry := _ancestor_names(mesh)
		if "upperarm" in ancestry or "forearm" in ancestry:
			result.append(mesh)
	return result

func _ancestor_names(node: Node) -> String:
	var names := ""
	var cursor: Node = node
	while cursor != null:
		names += String(cursor.name).to_lower()
		cursor = cursor.get_parent()
	return names

func _assert_independent_attachment(model: Node3D, attachments: Array[Node3D], arms: Array[MeshInstance3D], label: String, failures: Array[String]) -> void:
	var body_nodes: Array[Node3D] = []
	for node: Node in model.find_children("*", "Node3D", true, false):
		if node.has_meta(&"body_preset") or "upperarm" in String(node.name).to_lower() or "forearm" in String(node.name).to_lower():
			body_nodes.append(node as Node3D)
	for attachment: Node3D in attachments:
		for body_node: Node3D in body_nodes:
			TestAssertions.truthy(not _is_descendant(attachment, body_node), "%s attachment is not owned by a body or arm node" % label, failures)
		for mesh: MeshInstance3D in attachment.find_children("*", "MeshInstance3D", true, false):
			for arm: MeshInstance3D in arms:
				TestAssertions.truthy(mesh != arm and mesh.mesh != arm.mesh, "%s mesh is independent from arm mesh geometry" % label, failures)

func _is_descendant(node: Node, ancestor: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor == ancestor:
			return true
		cursor = cursor.get_parent()
	return false

func _nodes_alive(nodes: Array[Node3D]) -> bool:
	for node: Node3D in nodes:
		if not is_instance_valid(node):
			return false
	return true

func _meshes_alive(meshes: Array[MeshInstance3D]) -> bool:
	for mesh: MeshInstance3D in meshes:
		if not is_instance_valid(mesh):
			return false
	return true
