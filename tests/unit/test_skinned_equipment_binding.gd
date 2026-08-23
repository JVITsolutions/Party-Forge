extends RefCounted

const BINDING_SCRIPT_PATH := "res://scripts/presentation/skinned_equipment_binding.gd"
const CANONICAL_RIG_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const CONTRACT_SCRIPT := preload("res://scripts/presentation/humanoid_rig_contract.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	var binding_script := load(BINDING_SCRIPT_PATH) as Script
	TestAssertions.truthy(binding_script != null, "shared-skinned equipment binding script exists", failures)
	if binding_script == null:
		return failures
	_test_stages_only_selected_skinned_meshes(binding_script, failures)
	_test_rejects_invalid_skinning_inputs(binding_script, failures)
	_test_duplicates_instance_skin_and_material_state(binding_script, failures)
	return failures

func _test_stages_only_selected_skinned_meshes(binding_script: Script, failures: Array[String]) -> void:
	var fixture := _actor_fixture()
	var scene := _shared_item_scene()
	var descriptor := _fit(&"feminine", scene, [NodePath("FeminineRoot")], [&"torso"])
	var definition := _shared_skin_visual(&"feminine_armour", scene, descriptor)
	var binding: RefCounted = binding_script.new()
	var result: Dictionary = binding.call(&"stage_candidate", fixture.model, fixture.skeleton, definition, descriptor)
	TestAssertions.truthy(bool(result.get(&"ok", false)), "valid shared-skinned item stages", failures)
	var candidate := result.get(&"root") as Node3D
	TestAssertions.truthy(candidate != null and candidate.get_parent() == fixture.model, "candidate stages beneath actor before commit", failures)
	if candidate != null:
		TestAssertions.truthy(not candidate.visible, "candidate remains hidden until atomic commit", failures)
		var meshes := candidate.find_children("*", "MeshInstance3D", true, false)
		TestAssertions.equal(meshes.size(), 1, "only selected fit MeshInstance3D content is staged", failures)
		var mesh := meshes[0] as MeshInstance3D if meshes.size() == 1 else null
		TestAssertions.truthy(mesh != null and mesh.name == &"FeminineMesh", "active feminine root stages its mesh", failures)
		TestAssertions.truthy(candidate.find_child("MasculineMesh", true, false) == null, "inactive masculine root is never staged", failures)
		TestAssertions.truthy(candidate.find_children("*", "Skeleton3D", true, false).is_empty(), "source duplicate Skeleton3D is not installed", failures)
		TestAssertions.truthy(candidate.find_children("*", "AnimationPlayer", true, false).is_empty(), "source AnimationPlayer content is not installed", failures)
		if mesh != null:
			TestAssertions.equal(mesh.skeleton, mesh.get_path_to(fixture.skeleton), "staged mesh targets actor canonical Skeleton3D", failures)
			var contract := CONTRACT_SCRIPT.new()
			TestAssertions.equal(contract.validate_skin(fixture.definition, mesh.skin), PackedStringArray(), "staged Skin has complete canonical named binds", failures)
			TestAssertions.equal(contract.skin_bind_signature(fixture.definition, mesh.skin), definition.skin_bind_signature, "staged Skin exact ordered-bind hash matches metadata", failures)
		candidate.free()
	fixture.model.free()

func _test_rejects_invalid_skinning_inputs(binding_script: Script, failures: Array[String]) -> void:
	for invalid_case: StringName in [&"missing_skin", &"unweighted", &"signature", &"unknown_bone", &"residual_rig"]:
		var fixture := _actor_fixture()
		var scene := _shared_item_scene(invalid_case)
		var descriptor := _fit(&"masculine", scene, [NodePath("MasculineRoot")])
		var definition := _shared_skin_visual(StringName("invalid_%s" % invalid_case), scene, descriptor)
		if invalid_case == &"signature":
			definition.skin_bind_signature = "wrong"
		elif invalid_case == &"unknown_bone":
			var source := scene.instantiate()
			var source_mesh := source.get_node("MasculineRoot/MasculineMesh") as MeshInstance3D
			definition.skin_bind_signature = CONTRACT_SCRIPT.new().skin_bind_signature(fixture.definition, source_mesh.skin)
			source.free()
		var binding: RefCounted = binding_script.new()
		var result: Dictionary = binding.call(&"stage_candidate", fixture.model, fixture.skeleton, definition, descriptor)
		TestAssertions.truthy(not bool(result.get(&"ok", false)), "%s aborts shared-skinned staging" % invalid_case, failures)
		TestAssertions.truthy(result.get(&"root") == null, "%s leaves no staged root" % invalid_case, failures)
		TestAssertions.equal(_candidate_count(fixture.model), 0, "%s leaves no residual candidate or rig" % invalid_case, failures)
		fixture.model.free()

func _test_duplicates_instance_skin_and_material_state(binding_script: Script, failures: Array[String]) -> void:
	var first_fixture := _actor_fixture()
	var second_fixture := _actor_fixture()
	var scene := _shared_item_scene()
	var descriptor := _fit(&"masculine", scene, [NodePath("MasculineRoot")])
	var definition := _shared_skin_visual(&"isolated_armour", scene, descriptor)
	var binding: RefCounted = binding_script.new()
	var first: Dictionary = binding.call(&"stage_candidate", first_fixture.model, first_fixture.skeleton, definition, descriptor)
	var second: Dictionary = binding.call(&"stage_candidate", second_fixture.model, second_fixture.skeleton, definition, descriptor)
	var first_mesh := _only_staged_mesh(first)
	var second_mesh := _only_staged_mesh(second)
	TestAssertions.truthy(first_mesh != null and second_mesh != null, "two valid candidates stage independently", failures)
	if first_mesh != null and second_mesh != null:
		TestAssertions.truthy(first_mesh.skin != second_mesh.skin, "each equipment instance owns a duplicate Skin", failures)
		TestAssertions.truthy(first_mesh.material_override != second_mesh.material_override, "each equipment instance owns a duplicate material override", failures)
		TestAssertions.truthy(first_mesh.mesh != second_mesh.mesh, "each equipment instance owns duplicate mesh material state", failures)
		TestAssertions.truthy(first_mesh.mesh.surface_get_material(0) != second_mesh.mesh.surface_get_material(0), "each equipment instance owns duplicate surface material state", failures)
	first_fixture.model.free()
	second_fixture.model.free()

func _actor_fixture() -> Dictionary:
	var definition := load(CANONICAL_RIG_PATH)
	var model := ForgeHumanoidModel.new()
	for pivot_path: NodePath in definition.pivot_paths:
		_ensure_path(model, pivot_path)
	var masculine := MeshInstance3D.new()
	masculine.name = &"MasculineTorso"
	masculine.set_meta(&"body_preset", &"masculine")
	masculine.set_meta(&"body_region", &"torso")
	masculine.visible = true
	model.add_child(masculine)
	var feminine := MeshInstance3D.new()
	feminine.name = &"FeminineTorso"
	feminine.set_meta(&"body_preset", &"feminine")
	feminine.set_meta(&"body_region", &"torso")
	feminine.visible = false
	model.add_child(feminine)
	var skeleton := Skeleton3D.new()
	skeleton.name = &"CanonicalSkeleton"
	var role_to_index: Dictionary = {}
	for index: int in definition.roles.size():
		skeleton.add_bone(definition.bone_names[index])
		role_to_index[definition.roles[index]] = index
	for index: int in definition.roles.size():
		var parent_role: StringName = definition.parent_roles[index]
		if not parent_role.is_empty():
			skeleton.set_bone_parent(index, role_to_index[parent_role])
		skeleton.set_bone_rest(index, definition.canonical_rests[index])
	model.add_child(skeleton)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	return {&"model": model, &"skeleton": skeleton, &"definition": definition}

func _shared_item_scene(invalid_case: StringName = &"") -> PackedScene:
	var root := Node3D.new()
	root.name = &"SharedItemSource"
	var source_skeleton := Skeleton3D.new()
	source_skeleton.name = &"SourceSkeleton"
	root.add_child(source_skeleton)
	source_skeleton.owner = root
	var player := AnimationPlayer.new()
	player.name = &"SourceAnimationPlayer"
	root.add_child(player)
	player.owner = root
	for fit: Dictionary in [
		{&"root": &"MasculineRoot", &"mesh": &"MasculineMesh"},
		{&"root": &"FeminineRoot", &"mesh": &"FeminineMesh"},
	]:
		var fit_root := Node3D.new()
		fit_root.name = fit.root
		root.add_child(fit_root)
		fit_root.owner = root
		var mesh := MeshInstance3D.new()
		mesh.name = fit.mesh
		mesh.mesh = _weighted_mesh(invalid_case == &"unweighted" and fit.root == &"MasculineRoot")
		mesh.skin = null if invalid_case == &"missing_skin" and fit.root == &"MasculineRoot" else _canonical_skin(invalid_case == &"unknown_bone" and fit.root == &"MasculineRoot")
		mesh.skeleton = NodePath("../../SourceSkeleton")
		mesh.material_override = StandardMaterial3D.new()
		fit_root.add_child(mesh)
		mesh.owner = root
		var fit_player := AnimationPlayer.new()
		fit_player.name = StringName("%sAnimation" % fit.root)
		fit_root.add_child(fit_player)
		fit_player.owner = root
		if invalid_case == &"residual_rig" and fit.root == &"MasculineRoot":
			var nested_skeleton := Skeleton3D.new()
			nested_skeleton.name = &"NestedDuplicateRig"
			fit_root.add_child(nested_skeleton)
			nested_skeleton.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _weighted_mesh(unweighted: bool) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
		0.0 if unweighted else 1.0, 0.0, 0.0, 0.0,
	])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	return mesh

func _canonical_skin(unknown_bone: bool = false) -> Skin:
	var definition := load(CANONICAL_RIG_PATH)
	var skin := Skin.new()
	for index: int in definition.bone_names.size():
		var bone_name: StringName = &"UnknownBone" if unknown_bone and index == 0 else definition.bone_names[index]
		skin.add_named_bind(bone_name, definition.canonical_rests[index].affine_inverse())
	return skin

func _shared_skin_visual(id: StringName, scene: PackedScene, descriptor: EquipmentBodyFitDescriptor) -> EquipmentVisualDefinition:
	var definition_resource := load(CANONICAL_RIG_PATH)
	var visual := EquipmentVisualDefinition.new()
	visual.id = id
	visual.slot_id = &"body_armour"
	visual.supported_slot_ids = [&"body_armour"]
	visual.presentation_scene = scene
	visual.fit_policy = &"variant"
	visual.attachment_mode = &"shared_skin"
	visual.body_fits = [descriptor, _fit(&"feminine" if descriptor.body_preset_id == &"masculine" else &"masculine", scene, [NodePath("FeminineRoot") if descriptor.body_preset_id == &"masculine" else NodePath("MasculineRoot")])]
	visual.rig_id = definition_resource.rig_id
	visual.skeleton_topology_signature = definition_resource.topology_signature
	visual.canonical_rest_signature = definition_resource.canonical_rest_signature
	visual.skin_bind_signature = CONTRACT_SCRIPT.new().skin_bind_signature(definition_resource, _canonical_skin())
	visual.combat_visible = true
	return visual

func _fit(body: StringName, scene: PackedScene, roots: Array[NodePath], hidden: Array[StringName] = []) -> EquipmentBodyFitDescriptor:
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = body
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = roots
	descriptor.hide_body_regions = hidden
	return descriptor

func _ensure_path(root: Node, path: NodePath) -> void:
	var cursor := root
	for component: String in String(path).split("/"):
		var child := cursor.get_node_or_null(NodePath(component))
		if child == null:
			child = Node3D.new()
			child.name = component
			cursor.add_child(child)
		cursor = child

func _candidate_count(model: Node) -> int:
	var count := 0
	for child: Node in model.get_children():
		if bool(child.get_meta(&"shared_skin_candidate", false)):
			count += 1
	return count

func _only_staged_mesh(result: Dictionary) -> MeshInstance3D:
	var root := result.get(&"root") as Node3D
	if root == null:
		return null
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	return meshes[0] as MeshInstance3D if meshes.size() == 1 else null
