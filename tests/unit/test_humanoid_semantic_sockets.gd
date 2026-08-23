extends RefCounted

const HUMANOID_SCENE_PATH := "res://scenes/characters/presentation/forge_humanoid_model.tscn"
const CANONICAL_RIG_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
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
	_assert_external_decoy_skeleton_fails_closed(failures)
	_assert_in_model_incomplete_and_wrong_rest_rigs_fail_closed(failures)
	_assert_recognized_direct_name_collisions_fail_closed(failures)
	_assert_single_right_hand_wrapper_request_fails_closed(failures)
	_assert_single_left_hand_wrapper_request_fails_closed(failures)
	_assert_untrusted_metadata_fallback_paths_fail_closed(failures)
	_assert_owned_metadata_fallback_paths_remain_supported(failures)
	_assert_wrong_type_semantic_root_is_stable_and_fails_closed(failures)
	return failures


func _assert_untrusted_metadata_fallback_paths_fail_closed(failures: Array[String]) -> void:
	for case: Dictionary in [
		{&"path": &"../../HealthBar3D", &"label": "ancestor escape"},
		{&"path": &"OwnedSocket:position", &"label": "NodePath subname"},
		{&"path": &"./OwnedSocket", &"label": "dot segment"},
		{&"path": &"OwnedContainer/../OwnedSocket", &"label": "parent segment"},
		{&"path": &"/root/SocketBoundaryActor/HealthBar3D", &"label": "absolute path"},
	]:
		var actor := Node3D.new()
		actor.name = &"SocketBoundaryActor"
		var presentation := Node3D.new()
		presentation.name = &"Presentation"
		actor.add_child(presentation)
		var model := ForgeHumanoidModel.new()
		model.name = &"Model"
		presentation.add_child(model)
		_add_body(model)
		var owned_socket := Node3D.new()
		owned_socket.name = &"OwnedSocket"
		model.add_child(owned_socket)
		var owned_container := Node3D.new()
		owned_container.name = &"OwnedContainer"
		model.add_child(owned_container)
		var external_target := Node3D.new()
		external_target.name = &"HealthBar3D"
		actor.add_child(external_target)
		_add_to_tree(actor)
		model.has_equipment_slot(&"main_hand")
		var before_tree := _node_tree_snapshot(actor)
		var visual := _visual(&"untrusted_metadata", &"main_hand", &"UnusedFallback", _metadata_attachment_scene(case[&"path"]))
		TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "%s metadata path fails closed" % case[&"label"], failures)
		TestAssertions.equal(model.equipped_nodes.get(&"main_hand", []), [], "%s installs no live equipment" % case[&"label"], failures)
		TestAssertions.equal(external_target.get_child_count(), 0, "%s cannot reparent below external HealthBar3D" % case[&"label"], failures)
		TestAssertions.equal(_node_tree_snapshot(actor), before_tree, "%s leaves the live actor tree unchanged" % case[&"label"], failures)
		actor.free()


func _assert_owned_metadata_fallback_paths_remain_supported(failures: Array[String]) -> void:
	for socket_path: StringName in [&"OwnedSocket", &"OwnedContainer/OwnedSocket"]:
		var model := ForgeHumanoidModel.new()
		_add_body(model)
		var target := _ensure_path(model, socket_path)
		_add_to_tree(model)
		var visual := _visual(&"owned_metadata_fallback", &"main_hand", &"UnusedFallback", _metadata_attachment_scene(socket_path))
		TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", visual), "owned normalized metadata path %s remains supported" % socket_path, failures)
		var installed: Array = model.equipped_nodes.get(&"main_hand", [])
		TestAssertions.equal(installed.size(), 1, "owned metadata path installs one attachment", failures)
		if installed.size() == 1:
			TestAssertions.equal((installed[0] as Node).get_parent(), target, "owned metadata path remains below the model", failures)
		model.free()


func _node_tree_snapshot(root: Node) -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_node_tree_paths(root, ".", paths)
	return paths


func _collect_node_tree_paths(node: Node, path: String, paths: PackedStringArray) -> void:
	paths.append(path)
	for child: Node in node.get_children():
		_collect_node_tree_paths(child, "%s/%s" % [path, child.name], paths)

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

func _assert_external_decoy_skeleton_fails_closed(failures: Array[String]) -> void:
	var container := Node3D.new()
	container.name = &"ExternalDecoyFixture"
	var model := ForgeHumanoidModel.new()
	model.name = &"Model"
	_add_body(model)
	container.add_child(model)
	var decoy := Skeleton3D.new()
	decoy.name = &"DecoySkeleton"
	decoy.add_bone(&"Hand.R")
	container.add_child(decoy)
	var semantic_root := Node3D.new()
	semantic_root.name = &"SemanticSockets"
	model.add_child(semantic_root)
	var socket := BoneAttachment3D.new()
	socket.name = &"main_hand"
	socket.bone_name = &"Hand.R"
	socket.use_external_skeleton = true
	socket.external_skeleton = NodePath("../../../DecoySkeleton")
	semantic_root.add_child(socket)
	var legacy := _ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_to_tree(container)
	var visual := _visual(&"external_decoy", &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(false))
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "external one-bone decoy cannot authorize a semantic socket", failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "external decoy cannot stage rigid equipment", failures)
	TestAssertions.equal(socket.get_child_count(), 0, "external decoy socket receives no equipment", failures)
	TestAssertions.equal(legacy.get_child_count(), 0, "external decoy rejection cannot fall through to legacy path", failures)
	container.free()

func _assert_in_model_incomplete_and_wrong_rest_rigs_fail_closed(failures: Array[String]) -> void:
	var incomplete := Skeleton3D.new()
	incomplete.name = &"CanonicalSkeleton"
	incomplete.add_bone(&"Hand.R")
	var incomplete_fixture := _rig_fixture({}, incomplete)
	_assert_invalid_rig_fixture(incomplete_fixture, &"incomplete_rig", "in-model incomplete rig", failures)
	var wrong_rest := _canonical_skeleton()
	var hand_index := wrong_rest.find_bone(&"Hand.R")
	var changed_rest := wrong_rest.get_bone_rest(hand_index)
	changed_rest.origin.x += 0.125
	wrong_rest.set_bone_rest(hand_index, changed_rest)
	var wrong_rest_fixture := _rig_fixture({}, wrong_rest)
	_assert_invalid_rig_fixture(wrong_rest_fixture, &"wrong_rest_rig", "in-model wrong-rest rig", failures)

func _assert_invalid_rig_fixture(fixture: Dictionary, visual_id: StringName, label: String, failures: Array[String]) -> void:
	var model := fixture[&"model"] as ForgeHumanoidModel
	var socket := fixture[&"sockets"][&"main_hand"] as BoneAttachment3D
	var legacy := _ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	_add_to_tree(model)
	var visual := _visual(visual_id, &"main_hand", StringName(ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"]), _anchor_scene(false))
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "%s cannot authorize semantic slot" % label, failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "%s cannot stage rigid equipment" % label, failures)
	TestAssertions.equal(socket.get_child_count(), 0, "%s socket receives no equipment" % label, failures)
	TestAssertions.equal(legacy.get_child_count(), 0, "%s cannot fall through to legacy path" % label, failures)
	model.free()

func _assert_recognized_direct_name_collisions_fail_closed(failures: Array[String]) -> void:
	for description: Dictionary in [
		{&"id": &"main_hand", &"name": &"main_hand", &"label": "slot ID"},
		{&"id": &"RightHandSocket", &"name": &"RightHandSocket", &"label": "legacy leaf"},
	]:
		var model := ForgeHumanoidModel.new()
		_add_body(model)
		var collision := Node3D.new()
		collision.name = description[&"name"]
		model.add_child(collision)
		_add_to_tree(model)
		var visual := _visual(&"recognized_collision", &"main_hand", description[&"id"], _anchor_scene(false))
		TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "recognized %s collision cannot satisfy missing authorized target" % description[&"label"], failures)
		TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", visual), "recognized %s collision cannot stage equipment" % description[&"label"], failures)
		TestAssertions.equal(collision.get_child_count(), 0, "recognized %s collision remains unused" % description[&"label"], failures)
		model.free()

func _assert_single_right_hand_wrapper_request_fails_closed(failures: Array[String]) -> void:
	_assert_single_hand_wrapper_request_fails_closed(&"main_hand", &"RightHandSocket", &"LeftHandSocket", "right", failures)

func _assert_single_left_hand_wrapper_request_fails_closed(failures: Array[String]) -> void:
	_assert_single_hand_wrapper_request_fails_closed(&"off_hand", &"LeftHandSocket", &"RightHandSocket", "left", failures)

func _assert_single_hand_wrapper_request_fails_closed(slot_id: StringName, requested_socket_id: StringName, unrelated_socket_id: StringName, label: String, failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	_add_body(model)
	var requested_socket := Node3D.new()
	requested_socket.name = requested_socket_id
	model.add_child(requested_socket)
	var unrelated_socket := Node3D.new()
	unrelated_socket.name = unrelated_socket_id
	model.add_child(unrelated_socket)
	_add_to_tree(model)
	var visual := _visual(&"single_hand_wrapper", slot_id, requested_socket_id, _metadata_attachment_scene(requested_socket_id))
	TestAssertions.truthy(not model.apply_equipment_visual(slot_id, visual), "single %s legacy hand-wrapper request fails closed despite unrelated opposite sibling" % label, failures)
	TestAssertions.equal(requested_socket.get_child_count(), 0, "single %s request installs nothing under its direct-name collision" % label, failures)
	TestAssertions.equal(unrelated_socket.get_child_count(), 0, "single %s request leaves unrelated opposite sibling untouched" % label, failures)
	model.free()

func _assert_wrong_type_semantic_root_is_stable_and_fails_closed(failures: Array[String]) -> void:
	var model := ForgeHumanoidModel.new()
	_add_body(model)
	_ensure_path(model, ForgeHumanoidModel.SLOT_SOCKET_PATHS[&"main_hand"])
	var wrong_type := Node.new()
	wrong_type.name = &"SemanticSockets"
	model.add_child(wrong_type)
	_add_to_tree(model)
	var child_count_before := model.get_child_count()
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "wrong-type owned root fails closed", failures)
	TestAssertions.truthy(not model.has_equipment_slot(&"main_hand"), "wrong-type owned root remains fail-closed on repeat", failures)
	TestAssertions.equal(model.get_child_count(), child_count_before, "wrong-type root resolution creates no duplicate children", failures)
	var semantic_name_count := 0
	for child: Node in model.get_children():
		if child.name == &"SemanticSockets" or String(child.name).begins_with("@Node3D@"):
			semantic_name_count += 1
	TestAssertions.equal(semantic_name_count, 1, "wrong-type root resolution creates no renamed SemanticSockets root", failures)
	model.free()

func _rig_fixture(overrides: Dictionary = {}, skeleton_override: Skeleton3D = null) -> Dictionary:
	var model := ForgeHumanoidModel.new()
	_add_body(model)
	var definition := load(CANONICAL_RIG_PATH) as Resource
	for pivot_path: NodePath in definition.pivot_paths:
		_ensure_path(model, pivot_path)
	var skeleton := skeleton_override if skeleton_override != null else _canonical_skeleton()
	skeleton.name = &"CanonicalSkeleton"
	model.add_child(skeleton)
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

func _canonical_skeleton() -> Skeleton3D:
	var definition := load(CANONICAL_RIG_PATH) as Resource
	var skeleton := Skeleton3D.new()
	var bone_index_by_role: Dictionary = {}
	for index: int in definition.roles.size():
		skeleton.add_bone(definition.bone_names[index])
		bone_index_by_role[definition.roles[index]] = index
	for index: int in definition.roles.size():
		var parent_role: StringName = definition.parent_roles[index]
		if not parent_role.is_empty():
			skeleton.set_bone_parent(index, bone_index_by_role[parent_role])
		skeleton.set_bone_rest(index, definition.canonical_rests[index])
	return skeleton

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

func _metadata_attachment_scene(socket_id: StringName) -> PackedScene:
	var root := Node3D.new()
	root.name = &"AttachmentRoot"
	var attachment := Node3D.new()
	attachment.name = &"Attachment"
	attachment.set_meta(&"equipment_socket_id", socket_id)
	root.add_child(attachment)
	attachment.owner = root
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
