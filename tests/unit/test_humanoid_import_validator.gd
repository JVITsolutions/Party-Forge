extends RefCounted

const VALIDATOR_PATH := "res://tools/validate_humanoid_import.gd"
const RIG_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const CONTRACT_SCRIPT := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const DRIVER_SCRIPT := preload("res://scripts/presentation/legacy_pivot_skeleton_driver.gd")
const REGION_SCRIPT := preload("res://scripts/presentation/body_region_catalog.gd")
const BODY_PATHS := {
	&"masculine": "res://tests/fixtures/import/masculine.tscn",
	&"feminine": "res://tests/fixtures/import/feminine.tscn",
}
const SLOT_BONES := {
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

var _loaded_resources: Dictionary = {}
var _captured_lines: Array[String] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(FileAccess.file_exists(ProjectSettings.globalize_path(VALIDATOR_PATH)), "humanoid import validator implementation exists", failures)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(VALIDATOR_PATH)):
		return failures
	var script := load(VALIDATOR_PATH) as Script
	TestAssertions.truthy(script != null, "humanoid import validator script loads", failures)
	if script == null:
		return failures
	var entry_point: Object = script.new()
	TestAssertions.truthy(entry_point.has_method(&"new_service"), "validator exposes an independent read-only service", failures)
	TestAssertions.truthy(entry_point.has_method(&"run_cli"), "validator exposes its actual CLI control flow", failures)
	if not entry_point.has_method(&"new_service"):
		entry_point.free()
		return failures
	var service := entry_point.call(&"new_service") as RefCounted
	TestAssertions.truthy(service != null and service.has_method(&"validate_body_pair") and service.has_method(&"validate_shared_item_scene"), "validator service exposes body-pair and shared-item validation", failures)
	if service != null:
		_test_valid_body_pair(service, failures)
		_test_body_contract_failures(service, failures)
		_test_shared_item_contracts(service, failures)
		_test_cli_contract(entry_point, failures)
	_test_source_is_read_only(failures)
	entry_point.free()
	return failures


func _test_valid_body_pair(service: RefCounted, failures: Array[String]) -> void:
	var rig := load(RIG_PATH) as Resource
	var masculine := _body_scene(rig, &"masculine")
	var feminine := _body_scene(rig, &"feminine")
	var result := service.call(&"validate_body_pair", masculine, feminine, rig) as Dictionary
	TestAssertions.truthy(bool(result.get(&"ok", false)), "valid imported masculine and feminine bodies pass readiness validation", failures)
	TestAssertions.equal(result.get(&"errors", PackedStringArray()), PackedStringArray(), "valid body pair has no readiness errors", failures)
	var bodies := result.get(&"bodies", {}) as Dictionary
	for body_id: StringName in [&"masculine", &"feminine"]:
		var metrics := bodies.get(body_id, {}) as Dictionary
		TestAssertions.equal(metrics.get(&"region_count", -1), 17, "%s success reports exact body-region count" % body_id, failures)
		TestAssertions.equal(metrics.get(&"triangle_count", -1), 17, "%s success reports deterministic triangle count" % body_id, failures)
		TestAssertions.equal(metrics.get(&"material_count", -1), 1, "%s success reports shared material count" % body_id, failures)
		TestAssertions.equal(metrics.get(&"texture_count", -1), 1, "%s success reports unique texture count" % body_id, failures)
		TestAssertions.near(float(metrics.get(&"height", 0.0)), 1.7, 0.0001, "%s success reports visible height" % body_id, failures)
		TestAssertions.near(float(metrics.get(&"ground_y", -1.0)), 0.0, 0.0001, "%s success reports floor grounding" % body_id, failures)
	TestAssertions.equal(result.get(&"topology_signature", ""), rig.topology_signature, "success reports canonical topology signature", failures)
	TestAssertions.equal(result.get(&"canonical_rest_signature", ""), rig.canonical_rest_signature, "success reports canonical rest signature", failures)
	TestAssertions.equal(result.get(&"skin_bind_signature", ""), _skin_signature(rig), "success reports the shared exact Skin bind signature", failures)


func _test_body_contract_failures(service: RefCounted, failures: Array[String]) -> void:
	var rig := load(RIG_PATH) as Resource
	var valid := _body_scene(rig, &"masculine")
	_assert_body_error(service, null, rig, "request asset=masculine reason=scene is missing", "missing body scene", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_region": &"hair"}), rig, "body_regions asset=masculine reason=body region hair is missing", "missing exact region", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"duplicate_region": &"head"}), rig, "body_regions asset=masculine reason=body region head is duplicated", "duplicate exact region", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"unknown_region": true}), rig, "body_regions asset=masculine reason=body region node BodyRegion__generator_chunk has unknown region ID generator_chunk", "unknown generator region", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"wrong_skeleton_bone": true}), rig, "canonical_rig asset=masculine reason=humanoid rig role hips bone Hips must exist exactly once", "auto-rig topology", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"wrong_rest": true}), rig, "canonical_rig asset=masculine reason=humanoid rig bone Hips rest does not match canonical rest", "canonical rest", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_driver": true}), rig, "pivot_driver asset=masculine reason=requires exactly one LegacyPivotSkeletonDriver", "missing pivot driver", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"wrong_driver_root": true}), rig, "pivot_driver asset=masculine reason=pivot root must be the body scene root", "pivot-driver mapping", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"height": 1.5}), rig, "bounds asset=masculine reason=visible height 1.500000 is outside 1.600000..1.850000", "body height", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"ground_y": 0.01}), rig, "bounds asset=masculine reason=ground Y 0.010000 exceeds tolerance 0.001000", "grounding", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"nonfinite_transform": true}), rig, "transforms asset=masculine node=BodyRegion__head reason=transform is non-finite or non-invertible", "finite transforms", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_socket": &"off_hand"}), rig, "semantic_sockets asset=masculine reason=socket off_hand must exist exactly once", "semantic socket coverage", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"wrong_socket_bone": &"main_hand"}), rig, "semantic_sockets asset=masculine reason=socket main_hand must map to canonical bone Hand.R", "semantic socket bone mapping", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"triangle_count": 10001}), rig, "geometry asset=masculine reason=triangle count 10017 exceeds hard cap 10000", "triangle budget", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"material_count": 5}), rig, "body_regions asset=masculine reason=body regions use 5 source materials; maximum is 4", "material budget", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"texture_size": 2049}), rig, "materials asset=masculine reason=texture exceeds 2048px", "texture budget", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"texture_count": 5}), rig, "materials asset=masculine reason=material uses 5 textures; maximum is 4", "texture-map count budget", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_uv": true}), rig, "geometry asset=masculine node=BodyRegion__head surface=0 reason=UV0 is missing", "UV0 coverage", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_normals": true}), rig, "geometry asset=masculine node=BodyRegion__head surface=0 reason=normals are missing or malformed", "normal coverage", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"missing_tangents": true}), rig, "geometry asset=masculine node=BodyRegion__head surface=0 reason=tangents are missing or malformed", "tangent coverage", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"unweighted": true}), rig, "skinning asset=masculine node=BodyRegion__head vertex=0 reason=vertex is unweighted", "zero-weight vertices", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"unnormalized_weights": true}), rig, "skinning asset=masculine node=BodyRegion__head vertex=0 reason=weights total 0.499992 is not normalized", "normalized weights", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"eight_weights": true}), rig, "skinning asset=masculine node=BodyRegion__head vertex=0 reason=uses 8 influences; maximum is 4", "four-weight cap", failures)
	_assert_body_error(service, _body_scene(rig, &"masculine", {&"wrong_skin_bone": true}), rig, "skin asset=masculine node=BodyRegion__head reason=humanoid rig Skin bind AutoRigHips must resolve to exactly one canonical bone", "auto-rig Skin bone names", failures)

	var changed_skin := _body_scene(rig, &"feminine", {&"changed_skin_pose": true})
	var mismatch := service.call(&"validate_body_pair", valid, changed_skin, rig) as Dictionary
	_assert_error(mismatch, "PARTY_FORGE_HUMANOID_IMPORT_ERROR stage=signatures asset=bodies reason=masculine and feminine Skin bind signatures differ", "body pair exact bind signature", failures)


func _test_shared_item_contracts(service: RefCounted, failures: Array[String]) -> void:
	var rig := load(RIG_PATH) as Resource
	var expected_signature := _skin_signature(rig)
	var budgets := {&"max_triangles": 3500, &"max_materials": 4, &"max_texture_size": 2048}
	var valid := service.call(&"validate_shared_item_scene", _shared_item_scene(rig), rig, [NodePath("MasculineRoot")], expected_signature, budgets) as Dictionary
	TestAssertions.truthy(bool(valid.get(&"ok", false)), "valid shared-skinned active root passes separately", failures)
	TestAssertions.equal(valid.get(&"active_root_count", -1), 1, "shared-item success reports active-root count", failures)
	TestAssertions.equal(valid.get(&"mesh_count", -1), 1, "shared-item success reports only selected mesh count", failures)
	TestAssertions.equal(valid.get(&"skin_bind_signature", ""), expected_signature, "shared-item success reports exact bind signature", failures)

	_assert_shared_error(service, _shared_item_scene(rig), rig, [], expected_signature, budgets, "shared_item reason=active roots are empty", "active roots required", failures)
	_assert_shared_error(service, _shared_item_scene(rig), rig, [NodePath("MissingRoot")], expected_signature, budgets, "shared_item root=MissingRoot reason=active root is missing", "active root coverage", failures)
	_assert_shared_error(service, _shared_item_scene(rig), rig, [NodePath("MasculineRoot"), NodePath("MasculineRoot/Mesh")], expected_signature, budgets, "shared_item reason=active roots overlap", "active roots cannot overlap", failures)
	_assert_shared_error(service, _shared_item_scene(rig), rig, [NodePath("MasculineRoot")], "wrong", budgets, "shared_item node=Mesh reason=Skin bind signature mismatch", "exact bind signature", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"nested_skeleton": true}), rig, [NodePath("MasculineRoot")], expected_signature, budgets, "shared_item root=MasculineRoot reason=installed active root contains Skeleton3D", "installed duplicate skeleton", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"nested_player": true}), rig, [NodePath("MasculineRoot")], expected_signature, budgets, "shared_item root=MasculineRoot reason=installed active root contains AnimationPlayer", "installed duplicate animation player", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"wrong_skeleton_bone": true}), rig, [NodePath("MasculineRoot")], expected_signature, budgets, "shared_item node=Mesh reason=source skeleton does not match canonical rig", "auto-rig source skeleton", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"wrong_skin_bone": true}), rig, [NodePath("MasculineRoot")], expected_signature, budgets, "shared_item node=Mesh reason=humanoid rig Skin bind AutoRigHips must resolve to exactly one canonical bone", "auto-rig item Skin", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"unweighted": true}), rig, [NodePath("MasculineRoot")], expected_signature, budgets, "shared_item node=Mesh vertex=0 reason=vertex is unweighted", "shared-item weight contract", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"material_count": 5}), rig, [NodePath("MasculineRoot")], expected_signature, {&"max_triangles": 3500, &"max_materials": 3, &"max_texture_size": 1024}, "shared_item reason=material count 5 exceeds hard cap 3", "shared-item material budget", failures)
	_assert_shared_error(service, _shared_item_scene(rig, {&"texture_size": 1025}), rig, [NodePath("MasculineRoot")], expected_signature, {&"max_triangles": 3500, &"max_materials": 4, &"max_texture_size": 1024}, "shared_item reason=texture exceeds 1024px", "shared-item texture budget", failures)


func _test_cli_contract(entry_point: Object, failures: Array[String]) -> void:
	var rig := load(RIG_PATH) as Resource
	_loaded_resources = {
		BODY_PATHS[&"masculine"]: _body_scene(rig, &"masculine"),
		BODY_PATHS[&"feminine"]: _body_scene(rig, &"feminine"),
		RIG_PATH: rig,
	}
	var args := PackedStringArray([
		"--masculine-scene", BODY_PATHS[&"masculine"],
		"--feminine-scene", BODY_PATHS[&"feminine"],
		"--rig", RIG_PATH,
	])
	_captured_lines.clear()
	var exit_code := int(entry_point.call(&"run_cli", args, Callable(self, &"_load_resource"), Callable(self, &"_capture_line")))
	TestAssertions.equal(exit_code, 0, "valid explicit CLI paths exit zero", failures)
	TestAssertions.equal(_captured_lines.size(), 1, "CLI success prints one deterministic summary line", failures)
	if _captured_lines.size() == 1:
		var expected := "PARTY_FORGE_HUMANOID_IMPORT_OK masculine_regions=17 masculine_triangles=17 feminine_regions=17 feminine_triangles=17 topology_signature=%s canonical_rest_signature=%s skin_bind_signature=%s" % [rig.topology_signature, rig.canonical_rest_signature, _skin_signature(rig)]
		TestAssertions.equal(_captured_lines[0], expected, "CLI success prints body counts and shared signatures deterministically", failures)

	for invalid_case: Dictionary in [
		{&"label": "missing arguments", &"args": PackedStringArray(), &"error": "argument=--masculine-scene reason=required"},
		{&"label": "absolute path", &"args": _replace_arg(args, "--masculine-scene", "C:/imports/body.tscn"), &"error": "argument=--masculine-scene reason=must be a normalized res:// path"},
		{&"label": "user path", &"args": _replace_arg(args, "--feminine-scene", "user://body.tscn"), &"error": "argument=--feminine-scene reason=must be a normalized res:// path"},
		{&"label": "path traversal", &"args": _replace_arg(args, "--rig", "res://data/../pf_humanoid_v1.tres"), &"error": "argument=--rig reason=must be a normalized res:// path"},
		{&"label": "write attempt", &"args": PackedStringArray(["--write", "res://mutated.tscn"]), &"error": "argument=--write reason=unknown; validator is read-only"},
	]:
		_captured_lines.clear()
		var invalid_exit := int(entry_point.call(&"run_cli", invalid_case[&"args"], Callable(self, &"_load_resource"), Callable(self, &"_capture_line")))
		TestAssertions.equal(invalid_exit, 1, "%s CLI request exits nonzero" % invalid_case[&"label"], failures)
		_assert_line_contains(_captured_lines, String(invalid_case[&"error"]), "%s CLI rejection" % invalid_case[&"label"], failures)

	_loaded_resources.erase(BODY_PATHS[&"masculine"])
	_captured_lines.clear()
	var missing_exit := int(entry_point.call(&"run_cli", args, Callable(self, &"_load_resource"), Callable(self, &"_capture_line")))
	TestAssertions.equal(missing_exit, 1, "missing resource CLI request exits nonzero", failures)
	_assert_line_contains(_captured_lines, "resource asset=masculine path=%s reason=missing or unloadable PackedScene" % BODY_PATHS[&"masculine"], "missing resource rejection", failures)


func _test_source_is_read_only(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path(VALIDATOR_PATH))
	for forbidden: String in ["FileAccess.WRITE", "ResourceSaver", "store_string", "store_buffer", "DirAccess.make_dir", "ProjectSettings.set_setting", "change_import"]:
		TestAssertions.truthy(forbidden not in source, "validator source contains no write capability %s" % forbidden, failures)
	var dependencies := ResourceLoader.get_dependencies(VALIDATOR_PATH)
	TestAssertions.truthy("res://tools/build_shared_humanoid_scene.gd" not in dependencies, "validator does not invoke the scene builder", failures)


func _assert_body_error(service: RefCounted, masculine: PackedScene, rig: Resource, fragment: String, label: String, failures: Array[String]) -> void:
	var result := service.call(&"validate_body_pair", masculine, _body_scene(rig, &"feminine"), rig) as Dictionary
	_assert_error(result, "PARTY_FORGE_HUMANOID_IMPORT_ERROR stage=%s" % fragment, label, failures)


func _assert_shared_error(service: RefCounted, scene: PackedScene, rig: Resource, roots: Array, signature: String, budgets: Dictionary, fragment: String, label: String, failures: Array[String]) -> void:
	var result := service.call(&"validate_shared_item_scene", scene, rig, roots, signature, budgets) as Dictionary
	_assert_error(result, "PARTY_FORGE_HUMANOID_IMPORT_ERROR stage=%s" % fragment, label, failures)


func _assert_error(result: Dictionary, expected: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not bool(result.get(&"ok", true)), "%s rejects" % label, failures)
	var errors := result.get(&"errors", PackedStringArray()) as PackedStringArray
	TestAssertions.truthy(expected in errors, "%s reports exact error `%s`; actual=%s" % [label, expected, errors], failures)


func _assert_line_contains(lines: Array[String], fragment: String, label: String, failures: Array[String]) -> void:
	for line: String in lines:
		if fragment in line:
			return
	failures.append("%s reports `%s`; actual=%s" % [label, fragment, lines])


func _body_scene(rig: Resource, body_id: StringName, options: Dictionary = {}) -> PackedScene:
	var root := Node3D.new()
	root.name = StringName("%sImportedBody" % String(body_id).capitalize())
	for pivot_path: NodePath in rig.pivot_paths:
		_ensure_owned_path(root, pivot_path)
	var skeleton := _canonical_skeleton(rig, bool(options.get(&"wrong_skeleton_bone", false)), bool(options.get(&"wrong_rest", false)))
	skeleton.name = &"CanonicalSkeleton"
	root.add_child(skeleton)
	skeleton.owner = root
	if not bool(options.get(&"missing_driver", false)):
		var driver := DRIVER_SCRIPT.new() as Node
		driver.name = &"LegacyPivotSkeletonDriver"
		skeleton.add_child(driver)
		driver.owner = root
		driver.call(&"configure", rig, skeleton if bool(options.get(&"wrong_driver_root", false)) else root)
	_add_semantic_sockets(root, skeleton, rig, options)

	var material_count := int(options.get(&"material_count", 1))
	var materials: Array[StandardMaterial3D] = []
	for index: int in material_count:
		var material := StandardMaterial3D.new()
		var texture_size := int(options.get(&"texture_size", 4))
		_populate_material_textures(material, texture_size, int(options.get(&"texture_count", 1)))
		materials.append(material)
	var height := float(options.get(&"height", 1.7))
	var ground_y := float(options.get(&"ground_y", 0.0))
	var region_index := 0
	for region_id: StringName in REGION_SCRIPT.REGION_IDS:
		if options.get(&"missing_region", &"") == region_id:
			continue
		var region := _region_node(rig, region_id, region_index, height, ground_y, materials[region_index % materials.size()], options)
		root.add_child(region)
		region.owner = root
		region_index += 1
	if options.has(&"duplicate_region"):
		var duplicate_id := options[&"duplicate_region"] as StringName
		var duplicate := _region_node(rig, duplicate_id, 0, height, ground_y, materials[0], options)
		var duplicate_container := Node3D.new()
		duplicate_container.name = &"DuplicateRegionContainer"
		root.add_child(duplicate_container)
		duplicate_container.owner = root
		duplicate_container.add_child(duplicate)
		duplicate.owner = root
	if bool(options.get(&"unknown_region", false)):
		var unknown := _region_node(rig, &"generator_chunk", 0, height, ground_y, materials[0], options)
		root.add_child(unknown)
		unknown.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _populate_material_textures(material: StandardMaterial3D, texture_size: int, texture_count: int) -> void:
	var textures: Array[Texture2D] = []
	for index: int in texture_count:
		textures.append(ImageTexture.create_from_image(Image.create_empty(texture_size, 1, false, Image.FORMAT_RGBA8)))
	if texture_count > 0: material.albedo_texture = textures[0]
	if texture_count > 1: material.metallic_texture = textures[1]
	if texture_count > 2: material.roughness_texture = textures[2]
	if texture_count > 3:
		material.emission_enabled = true
		material.emission_texture = textures[3]
	if texture_count > 4:
		material.normal_enabled = true
		material.normal_texture = textures[4]


func _region_node(rig: Resource, region_id: StringName, region_index: int, height: float, ground_y: float, material: StandardMaterial3D, options: Dictionary) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = StringName("BodyRegion__%s" % region_id)
	var local_options := options if region_id == &"head" else {}
	mesh_instance.mesh = _weighted_mesh(height, ground_y, material, local_options)
	mesh_instance.skin = _canonical_skin(rig, bool(local_options.get(&"wrong_skin_bone", false)), bool(options.get(&"changed_skin_pose", false)))
	mesh_instance.skeleton = NodePath("../CanonicalSkeleton")
	if bool(local_options.get(&"nonfinite_transform", false)):
		mesh_instance.transform = Transform3D(Basis(Vector3(INF, 0.0, 0.0), Vector3.UP, Vector3.BACK), Vector3.ZERO)
	return mesh_instance


func _shared_item_scene(rig: Resource, options: Dictionary = {}) -> PackedScene:
	var root := Node3D.new()
	root.name = &"SharedItemSource"
	var source_skeleton := _canonical_skeleton(rig, bool(options.get(&"wrong_skeleton_bone", false)), false)
	source_skeleton.name = &"SourceSkeleton"
	root.add_child(source_skeleton)
	source_skeleton.owner = root
	var source_player := AnimationPlayer.new()
	source_player.name = &"SourceAnimationPlayer"
	root.add_child(source_player)
	source_player.owner = root
	for fit_name: StringName in [&"MasculineRoot", &"FeminineRoot"]:
		var fit_root := Node3D.new()
		fit_root.name = fit_name
		root.add_child(fit_root)
		fit_root.owner = root
		var material_count := int(options.get(&"material_count", 1)) if fit_name == &"MasculineRoot" else 1
		for surface_index: int in material_count:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = &"Mesh" if surface_index == 0 else StringName("Mesh%d" % surface_index)
			var material := StandardMaterial3D.new()
			var texture_size := int(options.get(&"texture_size", 4)) if fit_name == &"MasculineRoot" else 4
			material.albedo_texture = ImageTexture.create_from_image(Image.create_empty(texture_size, 1, false, Image.FORMAT_RGBA8))
			var mesh_options := options if fit_name == &"MasculineRoot" else {}
			mesh_instance.mesh = _weighted_mesh(0.4, 0.0, material, mesh_options)
			mesh_instance.skin = _canonical_skin(rig, bool(mesh_options.get(&"wrong_skin_bone", false)))
			mesh_instance.skeleton = NodePath("../../SourceSkeleton")
			fit_root.add_child(mesh_instance)
			mesh_instance.owner = root
		if fit_name == &"MasculineRoot" and bool(options.get(&"nested_skeleton", false)):
			var nested_skeleton := Skeleton3D.new()
			nested_skeleton.name = &"DuplicateSkeleton"
			fit_root.add_child(nested_skeleton)
			nested_skeleton.owner = root
		if fit_name == &"MasculineRoot" and bool(options.get(&"nested_player", false)):
			var nested_player := AnimationPlayer.new()
			nested_player.name = &"DuplicateAnimationPlayer"
			fit_root.add_child(nested_player)
			nested_player.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _weighted_mesh(height: float, ground_y: float, material: StandardMaterial3D, options: Dictionary) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.1, ground_y, 0.0), Vector3(0.1, ground_y, 0.0), Vector3(0.0, ground_y + height, 0.0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var triangle_count := int(options.get(&"triangle_count", 1))
	if triangle_count > 1:
		var indices := PackedInt32Array()
		indices.resize(triangle_count * 3)
		for index: int in triangle_count:
			indices[index * 3] = 0
			indices[index * 3 + 1] = 1
			indices[index * 3 + 2] = 2
		arrays[Mesh.ARRAY_INDEX] = indices
	if not bool(options.get(&"missing_normals", false)) and not bool(options.get(&"missing_tangents", false)):
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	if not bool(options.get(&"missing_tangents", false)):
		arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0])
	if not bool(options.get(&"missing_uv", false)) and not bool(options.get(&"missing_tangents", false)):
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	var influences := 8 if bool(options.get(&"eight_weights", false)) else 4
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(3 * influences)
	weights.resize(3 * influences)
	for vertex_index: int in 3:
		for influence_index: int in influences:
			var array_index := vertex_index * influences + influence_index
			bones[array_index] = mini(influence_index, 18)
			if bool(options.get(&"unweighted", false)):
				weights[array_index] = 0.0
			elif bool(options.get(&"eight_weights", false)):
				weights[array_index] = 0.125
			elif bool(options.get(&"unnormalized_weights", false)):
				weights[array_index] = 0.5 if influence_index == 0 else 0.0
			else:
				weights[array_index] = 1.0 if influence_index == 0 else 0.0
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influences == 8 else 0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	mesh.surface_set_material(0, material)
	return mesh


func _canonical_skeleton(rig: Resource, wrong_bone: bool, wrong_rest: bool) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var role_indices: Dictionary = {}
	for index: int in rig.roles.size():
		var bone_name: StringName = &"AutoRigHips" if wrong_bone and index == 0 else rig.bone_names[index]
		skeleton.add_bone(bone_name)
		role_indices[rig.roles[index]] = index
	for index: int in rig.roles.size():
		var parent_role: StringName = rig.parent_roles[index]
		if not parent_role.is_empty():
			skeleton.set_bone_parent(index, int(role_indices[parent_role]))
		var rest: Transform3D = rig.canonical_rests[index]
		if wrong_rest and index == 0:
			rest.origin.x += 0.05
		skeleton.set_bone_rest(index, rest)
	return skeleton


func _canonical_skin(rig: Resource, wrong_bone: bool = false, changed_pose: bool = false) -> Skin:
	var skin := Skin.new()
	for index: int in rig.bone_names.size():
		var bone_name: StringName = &"AutoRigHips" if wrong_bone and index == 0 else rig.bone_names[index]
		var pose: Transform3D = rig.canonical_rests[index].affine_inverse()
		if changed_pose and index == 0:
			pose.origin.x += 0.01
		skin.add_named_bind(bone_name, pose)
	return skin


func _skin_signature(rig: Resource) -> String:
	return CONTRACT_SCRIPT.new().skin_bind_signature(rig, _canonical_skin(rig))


func _add_semantic_sockets(root: Node3D, skeleton: Skeleton3D, rig: Resource, options: Dictionary) -> void:
	var semantic_root := Node3D.new()
	semantic_root.name = &"SemanticSockets"
	root.add_child(semantic_root)
	semantic_root.owner = root
	var missing_socket := options.get(&"missing_socket", &"") as StringName
	var wrong_socket := options.get(&"wrong_socket_bone", &"") as StringName
	for slot_id: StringName in SLOT_BONES:
		if slot_id == missing_socket:
			continue
		var socket := BoneAttachment3D.new()
		socket.name = slot_id
		socket.bone_name = &"Hand.L" if slot_id == wrong_socket else SLOT_BONES[slot_id]
		socket.use_external_skeleton = true
		socket.external_skeleton = NodePath("../../CanonicalSkeleton")
		semantic_root.add_child(socket)
		socket.owner = root


func _ensure_owned_path(root: Node3D, path: NodePath) -> Node3D:
	var cursor: Node = root
	for component: String in String(path).split("/"):
		var child := cursor.get_node_or_null(NodePath(component))
		if child == null:
			child = Node3D.new()
			child.name = component
			cursor.add_child(child)
			child.owner = root
		cursor = child
	return cursor as Node3D


func _replace_arg(arguments: PackedStringArray, name: String, value: String) -> PackedStringArray:
	var result := arguments.duplicate()
	var index := result.find(name)
	if index >= 0 and index + 1 < result.size():
		result[index + 1] = value
	return result


func _load_resource(path: String) -> Resource:
	return _loaded_resources.get(path) as Resource


func _capture_line(line: String) -> void:
	_captured_lines.append(line)
