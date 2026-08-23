extends RefCounted

const CANONICAL_RIG_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const CONTRACT_SCRIPT := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const SLOT_ID: StringName = &"body_armour"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_shared_fit_swap_commits(failures)
	_test_variant_fit_swap_commits(failures)
	_test_rigid_fit_regions_hide_and_restore(failures)
	_test_restored_descendant_body_region_drives_candidate_grounding(failures)
	_test_invisible_staged_equipment_ancestor_does_not_drive_grounding(failures)
	_test_rejection_preserves_state(&"fitted_scene", failures)
	_test_rejection_preserves_state(&"shared_skin", failures)
	_test_rejection_preserves_state(&"semantic_socket", failures)
	_test_rejection_preserves_state(&"body_region", failures)
	_test_rejection_preserves_state(&"rigid_body_region", failures)
	_test_rejection_preserves_state(&"grounding", failures)
	return failures

func _test_shared_fit_swap_commits(failures: Array[String]) -> void:
	var fixture := _fixture(_rigid_visual(&"shared", _rigid_scene(&"SharedFit"), _rigid_scene(&"SharedFit")))
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	var old_node := _equipped_node(model)
	TestAssertions.truthy(presentation.set_body_preset(&"feminine"), "public body API commits a shared-fit swap", failures)
	var new_node := _equipped_node(model)
	TestAssertions.equal(model._active_body_preset, &"feminine", "shared-fit swap commits the requested body", failures)
	TestAssertions.truthy(new_node != null and new_node != old_node, "shared-fit swap atomically replaces its equipment instance", failures)
	TestAssertions.truthy(_body_named(model, &"FeminineTorso").visible and not _body_named(model, &"MasculineTorso").visible, "shared-fit swap exposes only the requested body", failures)
	TestAssertions.near(model.ground_gap(), 0.0, 0.001, "shared-fit swap commits a grounded candidate", failures)
	presentation.free()

func _test_variant_fit_swap_commits(failures: Array[String]) -> void:
	var fixture := _fixture(_rigid_visual(&"variant", _rigid_scene(&"MasculineFit"), _rigid_scene(&"FeminineFit")))
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	TestAssertions.truthy(presentation.set_body_preset(&"feminine"), "public body API commits a variant-fit swap", failures)
	var installed := _equipped_node(model)
	TestAssertions.truthy(installed != null and installed.name == &"FeminineFit", "variant-fit swap installs only the target fit", failures)
	TestAssertions.equal(model._active_body_preset, &"feminine", "variant-fit swap commits the requested body", failures)
	TestAssertions.near(model.ground_gap(), 0.0, 0.001, "variant-fit swap commits a grounded candidate", failures)
	presentation.free()

func _test_rigid_fit_regions_hide_and_restore(failures: Array[String]) -> void:
	var visual := _rigid_visual(&"variant", _rigid_scene(&"MasculineFit"), _rigid_scene(&"FeminineFit"), [], [&"torso"])
	var fixture := _fixture(visual)
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	TestAssertions.truthy(presentation.set_body_preset(&"feminine"), "public body API commits a rigid fit with a valid hidden region", failures)
	TestAssertions.truthy(not _body_named(model, &"FeminineTorso").visible, "rigid fit hides its declared body region on commit", failures)
	TestAssertions.truthy(presentation.set_body_preset(&"masculine"), "public body API commits a rigid fit that omits the prior hidden region", failures)
	TestAssertions.truthy(_body_named(model, &"MasculineTorso").visible, "rigid fit restores a region omitted by the target fit", failures)
	TestAssertions.near(model.ground_gap(), 0.0, 0.001, "rigid region restoration keeps the committed candidate grounded", failures)
	presentation.free()

func _test_restored_descendant_body_region_drives_candidate_grounding(failures: Array[String]) -> void:
	var visual := _shared_skin_visual(_shared_skin_scene(false), _shared_skin_scene(false), [])
	var fixture := _nested_body_fixture(visual)
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	var target_region := _body_named(model, &"FeminineTorsoRegion")
	TestAssertions.truthy(not target_region.visible, "current fit hides the descendant region before the target swap", failures)
	TestAssertions.truthy(presentation.set_body_preset(&"feminine"), "public body API commits a fit that restores a descendant body region", failures)
	TestAssertions.truthy(target_region.visible, "target fit restores the descendant body region", failures)
	TestAssertions.near(model.ground_gap(), 0.0, 0.001, "restored descendant body geometry drives candidate grounding", failures)
	presentation.free()

func _test_invisible_staged_equipment_ancestor_does_not_drive_grounding(failures: Array[String]) -> void:
	var fixture := _fixture(_rigid_invisible_ancestor_visual())
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	TestAssertions.truthy(presentation.set_body_preset(&"feminine"), "public body API commits equipment beneath an invisible staged ancestor", failures)
	TestAssertions.near(model.ground_gap(), 0.0, 0.001, "invisible staged equipment does not affect committed grounding", failures)
	TestAssertions.near(model.position.y, 0.0, 0.001, "candidate grounding uses only effectively visible post-commit geometry", failures)
	presentation.free()

func _test_rejection_preserves_state(invalid_case: StringName, failures: Array[String]) -> void:
	var visual: EquipmentVisualDefinition
	var invalid_grounding := invalid_case == &"grounding"
	match invalid_case:
		&"fitted_scene":
			visual = _rigid_visual(&"variant", _rigid_scene(&"MasculineFit"), _non_3d_scene())
		&"shared_skin":
			visual = _shared_skin_visual(_shared_skin_scene(false), _shared_skin_scene(true), [])
		&"semantic_socket":
			visual = _rigid_visual(&"variant", _rigid_scene(&"MasculineFit"), _rigid_scene(&"FeminineFit", &"MissingSocket"))
		&"body_region":
			visual = _shared_skin_visual(_shared_skin_scene(false), _shared_skin_scene(false), [&"unknown_region"])
		&"rigid_body_region":
			visual = _rigid_visual(&"variant", _rigid_scene(&"MasculineFit"), _rigid_scene(&"FeminineFit"), [], [&"unknown_region"])
		&"grounding":
			visual = _icon_only_visual()
	var fixture := _fixture(visual, invalid_grounding)
	var presentation := fixture.presentation as CharacterPresentation
	var model := fixture.model as ForgeHumanoidModel
	var before := _snapshot(presentation, model)
	var candidates_before := _candidate_count(model)
	var orphan_nodes_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	TestAssertions.truthy(not presentation.set_body_preset(&"feminine"), "%s rejection is reported by the public body API" % invalid_case, failures)
	var after := _snapshot(presentation, model)
	TestAssertions.equal(after, before, "%s rejection preserves body, equipment, materials, regions, palette, preset, transforms, and ground state" % invalid_case, failures)
	TestAssertions.equal(_candidate_count(model), candidates_before, "%s rejection leaves no additional staged candidate" % invalid_case, failures)
	TestAssertions.equal(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), orphan_nodes_before, "%s rejection leaves no orphan candidate nodes" % invalid_case, failures)
	presentation.free()

func _fixture(visual: EquipmentVisualDefinition, feminine_without_geometry: bool = false) -> Dictionary:
	var presentation := CharacterPresentation.new()
	presentation.name = &"Presentation"
	(Engine.get_main_loop() as SceneTree).root.add_child(presentation)
	var model := ForgeHumanoidModel.new()
	model.name = &"Model"
	presentation.add_child(model)
	presentation.active_model = model
	_add_rig_and_sockets(model)
	_add_body(model, &"MasculineTorso", &"masculine", true, false)
	_add_body(model, &"FeminineTorso", &"feminine", false, feminine_without_geometry)
	TestAssertions.truthy(model.set_body_preset(&"masculine"), "fixture activates masculine body", [])
	TestAssertions.truthy(presentation.set_palette(&"ember", Color("d66a42")), "fixture applies palette", [])
	if visual != null:
		TestAssertions.truthy(presentation.apply_equipment_visual(SLOT_ID, visual), "fixture equips initial masculine fit", [])
	TestAssertions.truthy(presentation.refresh_grounding(), "fixture starts grounded", [])
	model.transform = Transform3D(Basis.from_euler(Vector3(0.0, 0.17, 0.0)), Vector3(0.25, model.position.y, -0.4))
	return {&"presentation": presentation, &"model": model}

func _nested_body_fixture(visual: EquipmentVisualDefinition) -> Dictionary:
	var presentation := CharacterPresentation.new()
	presentation.name = &"Presentation"
	(Engine.get_main_loop() as SceneTree).root.add_child(presentation)
	var model := ForgeHumanoidModel.new()
	model.name = &"Model"
	presentation.add_child(model)
	presentation.active_model = model
	_add_rig_and_sockets(model)
	_add_nested_body(model, &"MasculineBody", &"MasculineTorsoRegion", &"masculine", true, 1.0)
	_add_nested_body(model, &"FeminineBody", &"FeminineTorsoRegion", &"feminine", false, -1.0)
	TestAssertions.truthy(model.set_body_preset(&"masculine"), "nested fixture activates masculine body", [])
	TestAssertions.truthy(presentation.set_palette(&"ember", Color("d66a42")), "nested fixture applies palette", [])
	TestAssertions.truthy(presentation.apply_equipment_visual(SLOT_ID, visual), "nested fixture equips initial masculine fit", [])
	TestAssertions.truthy(presentation.refresh_grounding(), "nested fixture starts grounded", [])
	return {&"presentation": presentation, &"model": model}

func _add_rig_and_sockets(model: ForgeHumanoidModel) -> void:
	var rig := load(CANONICAL_RIG_PATH)
	for pivot_path: NodePath in rig.pivot_paths:
		_ensure_path(model, pivot_path)
	var skeleton := Skeleton3D.new()
	skeleton.name = &"CanonicalSkeleton"
	var role_to_index: Dictionary = {}
	for index: int in rig.roles.size():
		skeleton.add_bone(rig.bone_names[index])
		role_to_index[rig.roles[index]] = index
	for index: int in rig.roles.size():
		var parent_role: StringName = rig.parent_roles[index]
		if not parent_role.is_empty():
			skeleton.set_bone_parent(index, role_to_index[parent_role])
		skeleton.set_bone_rest(index, rig.canonical_rests[index])
	model.add_child(skeleton)
	var semantic_root := Node3D.new()
	semantic_root.name = &"SemanticSockets"
	model.add_child(semantic_root)
	var socket := BoneAttachment3D.new()
	socket.name = SLOT_ID
	socket.bone_name = &"Chest"
	socket.use_external_skeleton = true
	socket.external_skeleton = NodePath("../../CanonicalSkeleton")
	semantic_root.add_child(socket)

func _add_body(model: ForgeHumanoidModel, node_name: StringName, preset: StringName, visible: bool, without_geometry: bool) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.set_meta(&"body_preset", preset)
	mesh.set_meta(&"body_region", &"torso")
	mesh.set_meta(&"palette_region", &"primary")
	mesh.visible = visible
	mesh.position = Vector3(0.0, 0.85 if preset == &"masculine" else 1.05, 0.0)
	if not without_geometry:
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 1.7 if preset == &"masculine" else 2.1, 0.45)
		mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7a8195")
	mesh.material_override = material
	model.add_child(mesh)

func _add_nested_body(model: ForgeHumanoidModel, root_name: StringName, region_name: StringName, preset: StringName, visible: bool, region_y: float) -> void:
	var body_root := Node3D.new()
	body_root.name = root_name
	body_root.set_meta(&"body_preset", preset)
	body_root.visible = visible
	model.add_child(body_root)
	var mesh := MeshInstance3D.new()
	mesh.name = region_name
	mesh.set_meta(&"body_region", &"torso")
	mesh.set_meta(&"palette_region", &"primary")
	mesh.position.y = region_y
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 2.0, 0.45)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7a8195")
	mesh.material_override = material
	body_root.add_child(mesh)

func _rigid_visual(policy: StringName, masculine_scene: PackedScene, feminine_scene: PackedScene, masculine_hidden_regions: Array[StringName] = [], feminine_hidden_regions: Array[StringName] = []) -> EquipmentVisualDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = StringName("%s_armour" % policy)
	visual.slot_id = SLOT_ID
	visual.supported_slot_ids = [SLOT_ID]
	visual.fit_policy = policy
	visual.attachment_mode = &"rigid_socket"
	visual.socket_id = SLOT_ID
	visual.combat_visible = true
	if policy == &"shared":
		visual.body_fits = [_fit(&"shared", masculine_scene, [NodePath(".")], masculine_hidden_regions)]
	else:
		visual.body_fits = [
			_fit(&"masculine", masculine_scene, [NodePath(".")], masculine_hidden_regions),
			_fit(&"feminine", feminine_scene, [NodePath(".")], feminine_hidden_regions),
		]
	return visual

func _rigid_invisible_ancestor_visual() -> EquipmentVisualDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = &"invisible_ancestor_armour"
	visual.slot_id = SLOT_ID
	visual.supported_slot_ids = [SLOT_ID]
	visual.fit_policy = &"variant"
	visual.attachment_mode = &"rigid_socket"
	visual.socket_id = SLOT_ID
	visual.combat_visible = true
	visual.body_fits = [
		_fit(&"masculine", _rigid_invisible_ancestor_scene(), [NodePath("Attachment")]),
		_fit(&"feminine", _rigid_invisible_ancestor_scene(), [NodePath("Attachment")]),
	]
	return visual

func _shared_skin_visual(masculine_scene: PackedScene, feminine_scene: PackedScene, feminine_hidden_regions: Array[StringName]) -> EquipmentVisualDefinition:
	var rig := load(CANONICAL_RIG_PATH)
	var visual := EquipmentVisualDefinition.new()
	visual.id = &"shared_skin_armour"
	visual.slot_id = SLOT_ID
	visual.supported_slot_ids = [SLOT_ID]
	visual.fit_policy = &"variant"
	visual.attachment_mode = &"shared_skin"
	visual.combat_visible = true
	visual.body_fits = [
		_fit(&"masculine", masculine_scene, [NodePath("FitRoot")], [&"torso"]),
		_fit(&"feminine", feminine_scene, [NodePath("FitRoot")], feminine_hidden_regions),
	]
	visual.rig_id = rig.rig_id
	visual.skeleton_topology_signature = rig.topology_signature
	visual.canonical_rest_signature = rig.canonical_rest_signature
	visual.skin_bind_signature = CONTRACT_SCRIPT.new().skin_bind_signature(rig, _canonical_skin())
	return visual

func _icon_only_visual() -> EquipmentVisualDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = &"hidden_armour"
	visual.slot_id = SLOT_ID
	visual.supported_slot_ids = [SLOT_ID]
	visual.combat_visible = false
	return visual

func _fit(body: StringName, scene: PackedScene, paths: Array[NodePath], hidden_regions: Array[StringName] = []) -> EquipmentBodyFitDescriptor:
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = body
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = paths
	descriptor.hide_body_regions = hidden_regions
	return descriptor

func _rigid_scene(root_name: StringName, requested_socket: StringName = &"") -> PackedScene:
	var root := MeshInstance3D.new()
	root.name = root_name
	root.mesh = BoxMesh.new()
	root.position = Vector3(0.0, 0.15, 0.05)
	root.set_meta(&"palette_region", &"primary")
	if not requested_socket.is_empty():
		root.set_meta(&"equipment_socket_id", requested_socket)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40526f")
	root.material_override = material
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _rigid_invisible_ancestor_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = &"EquipmentRoot"
	var attachment := Node3D.new()
	attachment.name = &"Attachment"
	attachment.visible = false
	root.add_child(attachment)
	attachment.owner = root
	var mesh := MeshInstance3D.new()
	mesh.name = &"HiddenLowMesh"
	mesh.mesh = BoxMesh.new()
	mesh.position.y = -10.0
	mesh.set_meta(&"palette_region", &"primary")
	mesh.material_override = StandardMaterial3D.new()
	attachment.add_child(mesh)
	mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _non_3d_scene() -> PackedScene:
	var root := Node.new()
	root.name = &"InvalidRoot"
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _shared_skin_scene(missing_skin: bool) -> PackedScene:
	var root := Node3D.new()
	root.name = &"SkinSource"
	var source_skeleton := Skeleton3D.new()
	source_skeleton.name = &"SourceSkeleton"
	root.add_child(source_skeleton)
	source_skeleton.owner = root
	var fit_root := Node3D.new()
	fit_root.name = &"FitRoot"
	root.add_child(fit_root)
	fit_root.owner = root
	var mesh := MeshInstance3D.new()
	mesh.name = &"FittedMesh"
	mesh.mesh = _weighted_mesh()
	mesh.skin = null if missing_skin else _canonical_skin()
	mesh.skeleton = NodePath("../../SourceSkeleton")
	mesh.set_meta(&"palette_region", &"primary")
	mesh.material_override = StandardMaterial3D.new()
	fit_root.add_child(mesh)
	mesh.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _weighted_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	return mesh

func _canonical_skin() -> Skin:
	var rig := load(CANONICAL_RIG_PATH)
	var skin := Skin.new()
	for index: int in rig.bone_names.size():
		skin.add_named_bind(rig.bone_names[index], rig.canonical_rests[index].affine_inverse())
	return skin

func _snapshot(presentation: CharacterPresentation, model: ForgeHumanoidModel) -> Dictionary:
	var bodies: Array[Dictionary] = []
	for preset: StringName in [&"masculine", &"feminine"]:
		for body: Node3D in model.body_nodes.get(preset, []):
			bodies.append(_node_state(body, model))
	var equipment: Array[Dictionary] = []
	for slot: StringName in model.equipped_nodes:
		for node: Node3D in model.equipped_nodes[slot]:
			equipment.append(_node_state(node, model))
	var material_cache: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.base_materials:
		var material := model.base_materials[mesh] as StandardMaterial3D
		material_cache.append({&"mesh": mesh.get_instance_id(), &"material": material.get_instance_id(), &"color": material.albedo_color})
	material_cache.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.mesh) < int(right.mesh))
	return {
		&"active_preset": model._active_body_preset,
		&"active_palette": presentation.active_palette_id,
		&"primary_color": model._primary_color,
		&"model_transform": model.transform,
		&"ground_position": model.position.y,
		&"ground_gap": model.ground_gap(),
		&"visible_bounds": model.visual_bounds(),
		&"bodies": bodies,
		&"equipment": equipment,
		&"definitions": _definition_state(model),
		&"material_cache": material_cache,
		&"region_visibility": _region_state(model),
	}

func _node_state(root: Node3D, model: ForgeHumanoidModel) -> Dictionary:
	var meshes: Array[Dictionary] = []
	for mesh: MeshInstance3D in _meshes_including_root(root):
		var material := mesh.material_override as StandardMaterial3D
		meshes.append({
			&"id": mesh.get_instance_id(),
			&"visible": mesh.visible,
			&"transform": mesh.transform,
			&"material": material.get_instance_id() if material != null else 0,
			&"color": material.albedo_color if material != null else Color.TRANSPARENT,
			&"skin": mesh.skin.get_instance_id() if mesh.skin != null else 0,
		})
	return {
		&"id": root.get_instance_id(),
		&"parent": root.get_parent().get_instance_id() if root.get_parent() != null else 0,
		&"path": String(model.get_path_to(root)),
		&"visible": root.visible,
		&"transform": root.transform,
		&"meshes": meshes,
	}

func _definition_state(model: ForgeHumanoidModel) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: StringName in model.equipped_definitions:
		var definition := model.equipped_definitions[slot] as EquipmentVisualDefinition
		result.append({&"slot": slot, &"id": definition.get_instance_id() if definition != null else 0})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.slot) < String(right.slot))
	return result

func _region_state(model: ForgeHumanoidModel) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for region: StringName in model.body_region_nodes:
		for node: Node3D in model.body_region_nodes[region]:
			result.append({&"region": region, &"id": node.get_instance_id(), &"visible": node.visible})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.id) < int(right.id))
	return result

func _meshes_including_root(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	return meshes

func _body_named(model: ForgeHumanoidModel, body_name: StringName) -> Node3D:
	return model.find_child(String(body_name), true, false) as Node3D

func _equipped_node(model: ForgeHumanoidModel) -> Node3D:
	var nodes: Array = model.equipped_nodes.get(SLOT_ID, [])
	return nodes[0] as Node3D if nodes.size() == 1 else null

func _candidate_count(model: ForgeHumanoidModel) -> int:
	var count := 0
	for child: Node in model.get_children():
		if bool(child.get_meta(&"shared_skin_candidate", false)) or bool(child.get_meta(&"body_fit_candidate", false)):
			count += 1
	return count

func _ensure_path(root: Node, path: NodePath) -> Node3D:
	var cursor := root
	for component: String in String(path).split("/"):
		var child := cursor.get_node_or_null(NodePath(component))
		if child == null:
			child = Node3D.new()
			child.name = component
			cursor.add_child(child)
		cursor = child
	return cursor as Node3D
