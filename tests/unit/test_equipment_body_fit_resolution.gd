extends RefCounted

const MASCULINE: StringName = &"masculine"
const FEMININE: StringName = &"feminine"
const SHARED: StringName = &"shared"

func run() -> Array[String]:
	var failures: Array[String] = []
	var visual := EquipmentVisualDefinition.new()
	TestAssertions.truthy(visual.has_method(&"presentation_scene_for"), "equipment visuals expose body-specific presentation resolution", failures)
	if not visual.has_method(&"presentation_scene_for"):
		return failures
	var descriptor := EquipmentBodyFitDescriptor.new()
	TestAssertions.truthy(descriptor is EquipmentBodyFitDescriptor, "typed equipment body fit descriptor loads", failures)
	_assert_legacy_fallback(failures)
	_assert_shared_fit(failures)
	_assert_variant_fit_requires_both_bodies(failures)
	_assert_zero_descriptor_variant_rejects(failures)
	_assert_shared_fit_descriptor_set_is_unambiguous(failures)
	_assert_shared_scene_roots_do_not_overlap(failures)
	_assert_shared_scene_alias_roots_do_not_overlap(failures)
	_assert_attachment_contracts(failures)
	_assert_unknown_values_reject_independently(failures)
	_assert_unknown_body_and_icon_only_behavior(failures)
	_assert_production_definitions_remain_valid(failures)
	return failures

func _assert_legacy_fallback(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"LegacyMesh"])
	var visual := _visual(scene)
	for body_id: StringName in [MASCULINE, FEMININE]:
		TestAssertions.equal(visual.presentation_scene_for(body_id), scene, "legacy %s resolves its presentation scene" % body_id, failures)
		var fit: Resource = visual.body_fit_for(body_id)
		TestAssertions.truthy(fit != null, "legacy %s resolves a fallback fit descriptor" % body_id, failures)
		if fit != null:
			TestAssertions.equal(fit.get(&"body_preset_id"), body_id, "legacy fallback records requested body ID", failures)
			TestAssertions.equal(fit.get(&"presentation_scene"), scene, "legacy fallback retains presentation scene", failures)
			TestAssertions.equal(fit.get(&"mesh_root_paths"), [NodePath(".")], "legacy fallback selects its scene root", failures)
	TestAssertions.truthy(visual.validate().is_empty(), "legacy visual remains valid without serialized descriptors", failures)

func _assert_shared_fit(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"SharedMesh"])
	var visual := _visual(scene)
	visual.fit_policy = SHARED
	visual.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")], [&"torso"])]
	for body_id: StringName in [MASCULINE, FEMININE]:
		var fit: Resource = visual.body_fit_for(body_id)
		TestAssertions.truthy(fit != null, "shared fit resolves for %s" % body_id, failures)
		TestAssertions.equal(visual.presentation_scene_for(body_id), scene, "shared fit chooses one scene for %s" % body_id, failures)
		TestAssertions.equal(visual.mesh_root_paths_for(body_id), [NodePath("SharedMesh")], "shared fit chooses explicit roots for %s" % body_id, failures)
	TestAssertions.equal(visual.validate(), PackedStringArray(), "shared descriptor with declared body regions validates", failures)

func _assert_variant_fit_requires_both_bodies(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"MasculineMesh", &"FeminineMesh"])
	var visual := _visual(scene)
	visual.fit_policy = &"variant"
	visual.body_fits = [_fit(MASCULINE, scene, [NodePath("MasculineMesh")])]
	TestAssertions.truthy(not visual.validate().is_empty(), "variant fit rejects missing feminine descriptor", failures)
	visual.body_fits = [
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
		_fit(FEMININE, scene, [NodePath("FeminineMesh")]),
	]
	TestAssertions.equal(visual.presentation_scene_for(MASCULINE), scene, "variant masculine resolves its scene", failures)
	TestAssertions.equal(visual.presentation_scene_for(FEMININE), scene, "variant feminine resolves its scene", failures)
	TestAssertions.equal(visual.validate(), PackedStringArray(), "variant fit validates with both body descriptors", failures)

func _assert_zero_descriptor_variant_rejects(failures: Array[String]) -> void:
	var visual := _visual(_scene_with_roots([&"LegacyMesh"]))
	visual.fit_policy = &"variant"
	TestAssertions.truthy(_contains(visual.validate(), "variant fit"), "variant fit rejects a legacy fallback with zero descriptors", failures)

func _assert_shared_fit_descriptor_set_is_unambiguous(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"SharedMesh", &"MasculineMesh", &"FeminineMesh"])
	var visual := _visual(scene)
	visual.fit_policy = SHARED
	visual.body_fits = [
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
		_fit(FEMININE, scene, [NodePath("FeminineMesh")]),
	]
	TestAssertions.truthy(_contains(visual.validate(), "shared fit"), "shared policy rejects masculine and feminine descriptor ambiguity", failures)
	visual.body_fits = [
		_fit(SHARED, scene, [NodePath("SharedMesh")]),
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
	]
	TestAssertions.truthy(_contains(visual.validate(), "shared fit"), "shared policy rejects a shared descriptor plus a body-specific descriptor", failures)

func _assert_shared_scene_roots_do_not_overlap(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"MasculineMesh", &"FeminineMesh"])
	var visual := _visual(scene)
	visual.fit_policy = &"variant"
	visual.body_fits = [
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
		_fit(FEMININE, scene, [NodePath("MasculineMesh")]),
	]
	TestAssertions.truthy(not visual.validate().is_empty(), "same-scene variant roots may not overlap", failures)
	visual.body_fits = [
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
		_fit(FEMININE, scene, [NodePath("FeminineMesh")]),
	]
	TestAssertions.equal(visual.validate(), PackedStringArray(), "same-scene variant roots validate when non-overlapping", failures)
	var missing_root := _fit(FEMININE, scene, [NodePath("MissingMesh")])
	visual.body_fits = [_fit(MASCULINE, scene, [NodePath("MasculineMesh")]), missing_root]
	TestAssertions.truthy(not visual.validate().is_empty(), "descriptor rejects an explicit root absent from its instantiated scene", failures)

func _assert_shared_scene_alias_roots_do_not_overlap(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"MasculineMesh", &"AliasStart"])
	var visual := _visual(scene)
	visual.fit_policy = &"variant"
	visual.body_fits = [
		_fit(MASCULINE, scene, [NodePath("MasculineMesh")]),
		_fit(FEMININE, scene, [NodePath("AliasStart/../MasculineMesh")]),
	]
	TestAssertions.truthy(_contains(visual.validate(), "roots overlap"), "resolved alias paths cannot select the same shared-scene root", failures)

func _assert_attachment_contracts(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"SharedMesh"])
	var rigid := _visual(scene)
	rigid.fit_policy = SHARED
	rigid.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")])]
	rigid.socket_id = &""
	TestAssertions.truthy(not rigid.validate().is_empty(), "rigid socket attachment rejects a missing semantic socket", failures)
	rigid.socket_id = &"RightHandSocket"
	TestAssertions.equal(rigid.validate(), PackedStringArray(), "rigid socket attachment validates with a semantic socket", failures)
	var skinned := _visual(scene)
	skinned.fit_policy = SHARED
	skinned.attachment_mode = &"shared_skin"
	skinned.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")])]
	TestAssertions.truthy(not skinned.validate().is_empty(), "shared skin rejects missing rig and signature metadata", failures)
	skinned.rig_id = &"pf_humanoid_v1"
	skinned.skeleton_topology_signature = "topology"
	skinned.canonical_rest_signature = "rest"
	skinned.skin_bind_signature = "binds"
	TestAssertions.equal(skinned.validate(), PackedStringArray(), "shared skin validates with rig, skeleton, rest, and bind signatures", failures)

func _assert_unknown_values_reject_independently(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"SharedMesh"])
	var unknown_fit := _visual(scene)
	unknown_fit.fit_policy = &"unknown_fit"
	unknown_fit.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")])]
	TestAssertions.truthy(_contains(unknown_fit.validate(), "fit policy"), "unknown fit policy rejects independently", failures)
	var unknown_attachment := _visual(scene)
	unknown_attachment.attachment_mode = &"unknown_attachment"
	unknown_attachment.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")])]
	TestAssertions.truthy(_contains(unknown_attachment.validate(), "attachment mode"), "unknown attachment mode rejects independently", failures)

func _assert_unknown_body_and_icon_only_behavior(failures: Array[String]) -> void:
	var scene := _scene_with_roots([&"SharedMesh"])
	var visual := _visual(scene)
	visual.body_fits = [_fit(SHARED, scene, [NodePath("SharedMesh")])]
	TestAssertions.equal(visual.presentation_scene_for(&"other"), null, "unknown body does not resolve a scene", failures)
	TestAssertions.equal(visual.body_fit_for(&"other"), null, "unknown body does not resolve a descriptor", failures)
	var icon_only := EquipmentVisualDefinition.new()
	icon_only.id = &"icon_only"
	icon_only.slot_id = &"amulet"
	icon_only.supported_slot_ids = [&"amulet"]
	icon_only.icon_master = GradientTexture2D.new()
	icon_only.icon_runtime = GradientTexture2D.new()
	icon_only.combat_visible = false
	icon_only.readability_channels = [&"icon"]
	TestAssertions.truthy(icon_only.validate().is_empty(), "icon-only non-combat visual remains valid without a scene", failures)
	TestAssertions.equal(icon_only.presentation_scene_for(MASCULINE), null, "icon-only visual has no fitted scene", failures)

func _assert_production_definitions_remain_valid(failures: Array[String]) -> void:
	var paths := _tres_paths("res://data/presentation/equipment")
	TestAssertions.truthy(not paths.is_empty(), "production visual definition resources are discovered", failures)
	for path: String in paths:
		var definition := load(path) as EquipmentVisualDefinition
		TestAssertions.truthy(definition != null and definition.validate().is_empty(), "%s production visual validates unchanged" % path, failures)

func _fit(body_id: StringName, scene: PackedScene, roots: Array[NodePath], hidden_regions: Array[StringName] = []) -> EquipmentBodyFitDescriptor:
	var descriptor := EquipmentBodyFitDescriptor.new()
	descriptor.body_preset_id = body_id
	descriptor.presentation_scene = scene
	descriptor.mesh_root_paths = roots
	descriptor.hide_body_regions = hidden_regions
	return descriptor

func _visual(scene: PackedScene) -> EquipmentVisualDefinition:
	var visual := EquipmentVisualDefinition.new()
	visual.id = &"fit_fixture"
	visual.slot_id = &"main_hand"
	visual.supported_slot_ids = [&"main_hand"]
	visual.presentation_scene = scene
	visual.icon_master = GradientTexture2D.new()
	visual.icon_runtime = GradientTexture2D.new()
	visual.socket_id = &"RightHandSocket"
	visual.readability_channels = [&"silhouette"]
	visual.attachment_role_id = &"wearable"
	return visual

func _scene_with_roots(root_names: Array[StringName]) -> PackedScene:
	var root := Node3D.new()
	root.name = &"Item"
	for root_name: StringName in root_names:
		var mesh_root := Node3D.new()
		mesh_root.name = root_name
		root.add_child(mesh_root)
		mesh_root.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene

func _tres_paths(directory_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir():
			paths.append_array(_tres_paths(directory_path.path_join(entry)))
		elif entry.ends_with(".tres"):
			paths.append(directory_path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths

func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
