extends RefCounted

const HUMANOID_SCENE_PATH := "res://scenes/characters/presentation/forge_humanoid_model.tscn"
const SLOT_IDS: Array[StringName] = [
	&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet",
	&"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand",
]
const EXPECTED_BONES := {
	&"helmet": &"Head",
	&"body_armour": &"Chest",
	&"legs": &"Hips",
	&"gloves": &"Hand.R",
	&"boots": &"Foot.R",
	&"amulet": &"Neck",
	&"ring_left": &"Hand.L",
	&"ring_right": &"Hand.R",
	&"belt": &"Hips",
	&"main_hand": &"Hand.R",
	&"off_hand": &"Hand.L",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	_assert_owned_root_exposes_all_slots(failures)
	_assert_rig_socket_precedes_legacy_fallback(failures)
	_assert_legacy_paths_remain_fallbacks(failures)
	_assert_held_action_and_projectile_anchors_remain_discoverable(failures)
	_assert_wrong_bone_fails_closed(failures)
	_assert_missing_mapping_never_searches_imported_names(failures)
	return failures

func _assert_owned_root_exposes_all_slots(failures: Array[String]) -> void:
	var model := (load(HUMANOID_SCENE_PATH) as PackedScene).instantiate() as ForgeHumanoidModel
	_add_to_tree(model)
	model.has_equipment_slot(&"helmet")
	var root := model.get_node_or_null("SemanticSockets")
	TestAssertions.truthy(root != null and root.get_parent() == model, "humanoid owns a direct SemanticSockets root", failures)
	for slot_id: StringName in SLOT_IDS:
		var socket := root.get_node_or_null(NodePath(String(slot_id))) if root != null else null
		TestAssertions.truthy(socket != null and socket.get_parent() == root, "SemanticSockets exposes exact %s identity" % slot_id, failures)
		TestAssertions.truthy(model.has_equipment_slot(slot_id), "current humanoid resolves %s through semantic or legacy socket" % slot_id, failures)
	model.free()

func _assert_rig_socket_precedes_legacy_fallback(failures: Array[String]) -> void:
	var fixture := _rig_fixture()
	var model := fixture[&"model"] as ForgeHumanoidModel
	var semantic := fixture[&"sockets"][&"main_hand"] as BoneAttachment3D
	var legacy := _ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_to_tree(model)
	var visual := _visual(&"rig_priority", &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(false))
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "rig-backed main-hand equipment stages", failures)
	var installed: Array = model.equipped_nodes.get(&"main_hand", [])
	TestAssertions.equal(installed.size(), 1, "rig-backed equipment installs one root", failures)
	if installed.size() == 1:
		TestAssertions.equal((installed[0] as Node).get_parent(), semantic, "rig-backed semantic socket takes precedence over legacy path", failures)
		TestAssertions.truthy((installed[0] as Node).get_parent() != legacy, "rig priority never stages under legacy fallback", failures)
	model.free()

func _assert_legacy_paths_remain_fallbacks(failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	var legacy := _ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_body(model)
	_add_to_tree(model)
	var visual := _visual(&"legacy_fallback", &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(false))
	TestAssertions.truthy(model.has_equipment_slot(&"main_hand"), "legacy SLOT_SOCKET_PATHS main hand remains available", failures)
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "legacy path equipment still stages", failures)
	var installed: Array = model.equipped_nodes.get(&"main_hand", [])
	if installed.size() == 1:
		TestAssertions.equal((installed[0] as Node).get_parent(), legacy, "legacy fallback retains current rigid attachment behavior", failures)
	model.free()

func _assert_held_action_and_projectile_anchors_remain_discoverable(failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	_ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_body(model)
	_add_to_tree(model)
	var visual := _visual(&"anchored_weapon", &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(true))
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "anchored held item equips through resolver", failures)
	var names := model.equipped_anchor_names(&"main_hand")
	for anchor_name: StringName in [&"ReadabilityAnchor", &"ActionOriginSocket", &"ProjectileLaunchSocket"]:
		TestAssertions.truthy(anchor_name in names, "%s remains discoverable" % anchor_name, failures)
		var anchor := model.equipped_nodes[&"main_hand"][0].find_child(String(anchor_name), true, false) as Node3D
		var expected: Transform3D = model.call(&"_transform_without_tree", anchor)
		TestAssertions.equal(model.socket_global_transform(anchor_name), expected, "%s transform query resolves equipped anchor" % anchor_name, failures)
	model.free()

func _assert_wrong_bone_fails_closed(failures: Array[String]) -> void:
	var fixture := _rig_fixture({&"main_hand": &"Hand.L"})
	var model := fixture[&"model"] as ForgeHumanoidModel
	var wrong := fixture[&"sockets"][&"main_hand"] as BoneAttachment3D
	var legacy := _ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_to_tree(model)
	var visual := _visual(&"wrong_bone", &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(false))
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "wrong canonical bone invalidates semantic slot", failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "wrong canonical bone aborts rigid staging", failures)
	TestAssertions.equal(wrong.get_child_count(), 0, "wrong bone receives no equipment", failures)
	TestAssertions.equal(legacy.get_child_count(), 0, "invalid rig mapping cannot silently redirect to legacy socket", failures)
	model.free()

func _assert_missing_mapping_never_searches_imported_names(failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	_add_body(model)
	var semantic_root := Node3D.new()
	semantic_root.name = &"SemanticSockets"
	model.add_child(semantic_root)
	var imported := Node3D.new()
	imported.name = &"ImportedGLB"
	model.add_child(imported)
	var imported_bone := Node3D.new()
	imported_bone.name = &"Hand.R"
	imported.add_child(imported_bone)
	var tempting_socket := Node3D.new()
	tempting_socket.name = &"main_hand"
	imported_bone.add_child(tempting_socket)
	_add_to_tree(model)
	var visual := _visual(&"missing_mapping", &"main_hand", &"main_hand", _anchor_scene(false))
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "missing owned semantic identity fails closed", failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "missing mapping cannot stage through imported node names", failures)
	TestAssertions.equal(tempting_socket.get_child_count(), 0, "imported same-name node never becomes an equipment contract", failures)
	model.free()

func _rig_fixture(overrides: Dictionary = {}) -> Dictionary:
	var model := ForgeHumanoidModel.new()
	_add_body(model)
	var skeleton := Skeleton3D.new()
	skeleton.name = &"CanonicalSkeleton"
	model.add_child(skeleton)
	var unique_bones: Array[StringName] = []
	for bone_name: StringName in EXPECTED_BONES.values():
		if bone_name not in unique_bones:
			unique_bones.append(bone_name)
	for bone_name: StringName in unique_bones:
		skeleton.add_bone(bone_name)
	var semantic_root := Node3D.new()
	semantic_root.name = &"SemanticSockets"
	model.add_child(semantic_root)
	var sockets: Dictionary = {}
	for slot_id: StringName in SLOT_IDS:
		var socket := BoneAttachment3D.new()
		socket.name = slot_id
		socket.bone_name = overrides.get(slot_id, EXPECTED_BONES[slot_id])
		socket.use_external_skeleton = true
		socket.external_skeleton = NodePath("../../CanonicalSkeleton")
		semantic_root.add_child(socket)
		sockets[slot_id] = socket
	return {&"model": model, &"skeleton": skeleton, &"sockets": sockets}

func _add_body(model: ForgeHumanoidModel) -> void:
	var body := Node3D.new()
	body.name = &"Body"
	body.set_meta(&"body_preset", &"masculine")
	model.add_child(body)

func _ensure_path(root: Node, path_value: Variant) -> Node3D:
	var cursor := root
	for component: String in String(path_value).split("/"):
		var child := cursor.get_node_or_null(NodePath(component))
		if child == null:
			child = Node3D.new()
			child.name = component
			cursor.add_child(child)
		cursor = child
	return cursor as Node3D

func _anchor_scene(with_anchors: bool) -> PackedScene:
	var root := Node3D.new()
	root.name = &"Attachment"
	if with_anchors:
		for description: Dictionary in [
			{&"name": &"ReadabilityAnchor", &"position": Vector3(0.1, 0.2, 0.3)},
			{&"name": &"ActionOriginSocket", &"position": Vector3(0.2, 0.3, 0.4)},
			{&"name": &"ProjectileLaunchSocket", &"position": Vector3(0.3, 0.4, 0.5)},
		]:
			var anchor := Node3D.new()
			anchor.name = description[&"name"]
			anchor.position = description[&"position"]
			root.add_child(anchor)
			anchor.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _visual(id: StringName, slot_id: StringName, socket_id: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = id
	visual.slot_id = slot_id
	visual.supported_slot_ids = [slot_id]
	visual.socket_id = socket_id
	visual.presentation_scene = scene
	visual.combat_visible = true
	visual.body_preset_ids = [&"masculine", &"feminine"]
	return visual

func _add_to_tree(model: Node3D) -> void:
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
