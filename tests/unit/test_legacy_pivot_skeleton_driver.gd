extends RefCounted

const DRIVER_PATH := "res://scripts/presentation/legacy_pivot_skeleton_driver.gd"
const MODEL_SCENE := preload("res://scenes/characters/presentation/forge_humanoid_model.tscn")
const RIG_DEFINITION := preload("res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres")
const TRANSFORM_TOLERANCE := 0.0001

func run() -> Array[String]:
	var failures: Array[String] = []
	var driver_script := load(DRIVER_PATH) as Script
	TestAssertions.truthy(driver_script != null, "legacy pivot skeleton driver script loads", failures)
	if driver_script == null:
		return failures
	_test_direct_parent_and_rest_identity(driver_script, failures)
	_test_animation_evaluation_drives_canonical_pose(driver_script, failures)
	_test_world_to_skeleton_conversion_and_root_pivot_propagation(driver_script, failures)
	_test_validation_failures_close_the_driver(driver_script, failures)
	_test_non_finite_runtime_pose_fails_closed(driver_script, failures)
	_test_both_body_meshes_observe_one_pose(driver_script, failures)
	_test_callback_contract_has_no_manual_blending(failures)
	return failures

func _test_direct_parent_and_rest_identity(driver_script: Script, failures: Array[String]) -> void:
	var fixture := _fixture(driver_script)
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	TestAssertions.equal(driver.get_parent(), skeleton, "driver is a direct Skeleton3D child", failures)
	TestAssertions.truthy(bool(driver.call(&"is_valid")), "canonical fixture validates", failures)
	TestAssertions.near(driver.influence, 1.0, 0.000001, "modifier influence is exactly one", failures)
	var rests_before := _bone_rests(skeleton)
	driver.call(&"_process_for_skeleton", skeleton)
	for bone_index: int in skeleton.get_bone_count():
		_assert_transform_near(skeleton.get_bone_pose(bone_index), Transform3D.IDENTITY, "rest pivot maps %s to identity pose delta" % skeleton.get_bone_name(bone_index), failures)
	_assert_rests_unchanged(skeleton, rests_before, "rest evaluation", failures)
	model.free()

func _test_animation_evaluation_drives_canonical_pose(driver_script: Script, failures: Array[String]) -> void:
	var fixture := _fixture(driver_script)
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var rests_before := _bone_rests(skeleton)
	player.play(&"walk")
	player.seek(0.2, true)
	player.advance(0.0)
	driver.call(&"_process_for_skeleton", skeleton)
	var expected := _expected_poses(fixture)
	for bone_name: StringName in [&"Hips", &"UpperLeg.L", &"LowerLeg.L", &"Foot.L", &"UpperLeg.R", &"LowerLeg.R", &"Foot.R"]:
		var bone_index := skeleton.find_bone(bone_name)
		_assert_transform_near(skeleton.get_bone_pose(bone_index), expected[bone_name] as Transform3D, "evaluated walk pivot drives %s" % bone_name, failures)
	TestAssertions.truthy(not _transforms_near(skeleton.get_bone_pose(skeleton.find_bone(&"UpperLeg.L")), Transform3D.IDENTITY), "evaluated pivot rotation produces a non-identity bone pose", failures)
	TestAssertions.truthy(not _transforms_near(skeleton.get_bone_pose(skeleton.find_bone(&"Hips")), Transform3D.IDENTITY), "evaluated pivot translation produces a non-identity root pose", failures)
	_assert_rests_unchanged(skeleton, rests_before, "animated evaluation", failures)
	model.free()

func _test_world_to_skeleton_conversion_and_root_pivot_propagation(driver_script: Script, failures: Array[String]) -> void:
	var fixture := _fixture(driver_script, Transform3D(Basis.from_euler(Vector3(0.0, 0.45, 0.0)), Vector3(4.0, -1.0, 2.0)))
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	var hit := model.get_node("HitPivot") as Node3D
	var body := model.get_node("HitPivot/BodyPivot") as Node3D
	hit.transform = Transform3D(Basis.from_euler(Vector3(0.12, -0.18, 0.07)), Vector3(0.3, 0.15, -0.2)) * hit.transform
	body.transform = Transform3D(Basis.from_euler(Vector3(-0.08, 0.05, 0.11)), Vector3(-0.1, 0.2, 0.25)) * body.transform
	driver.call(&"_process_for_skeleton", skeleton)
	var expected := _expected_poses(fixture)
	var hips_index := skeleton.find_bone(&"Hips")
	_assert_transform_near(skeleton.get_bone_pose(hips_index), expected[&"Hips"] as Transform3D, "unmapped HitPivot and BodyPivot propagate through the hips pivot global", failures)
	TestAssertions.truthy(not _transforms_near(skeleton.get_bone_pose(hips_index), Transform3D.IDENTITY), "unmapped ancestor motion reaches the mapped root bone", failures)
	var left_hand_index := skeleton.find_bone(&"Hand.L")
	_assert_transform_near(skeleton.get_bone_pose(left_hand_index), expected[&"Hand.L"] as Transform3D, "pivot world transform is converted into skeleton space before child delta calculation", failures)
	model.free()

func _test_validation_failures_close_the_driver(driver_script: Script, failures: Array[String]) -> void:
	var missing_pivot := _fixture(driver_script, Transform3D.IDENTITY, &"missing_pivot")
	_assert_closed(missing_pivot, "missing pivot", failures)
	(missing_pivot[&"model"] as Node3D).free()
	var missing_bone := _fixture(driver_script, Transform3D.IDENTITY, &"missing_bone")
	_assert_closed(missing_bone, "missing bone", failures)
	(missing_bone[&"model"] as Node3D).free()
	var bad_signature := _fixture(driver_script, Transform3D.IDENTITY, &"signature_mismatch")
	_assert_closed(bad_signature, "signature mismatch", failures)
	(bad_signature[&"model"] as Node3D).free()
	var nested_driver := _fixture(driver_script, Transform3D.IDENTITY, &"nested_driver")
	_assert_closed(nested_driver, "driver without a direct Skeleton3D parent", failures)
	(nested_driver[&"model"] as Node3D).free()

func _test_non_finite_runtime_pose_fails_closed(driver_script: Script, failures: Array[String]) -> void:
	var fixture := _fixture(driver_script)
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	var hip := model.get_node("HitPivot/BodyPivot/HipsPivot") as Node3D
	hip.position += Vector3(0.2, 0.1, -0.1)
	driver.call(&"_process_for_skeleton", skeleton)
	TestAssertions.truthy(not _transforms_near(skeleton.get_bone_pose(skeleton.find_bone(&"Hips")), Transform3D.IDENTITY), "valid runtime motion is applied before fail-closed probe", failures)
	var rests_before := _bone_rests(skeleton)
	hip.transform = Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0))
	driver.call(&"_process_for_skeleton", skeleton)
	_assert_closed(fixture, "non-finite runtime pivot", failures)
	_assert_rests_unchanged(skeleton, rests_before, "non-finite rejection", failures)
	model.free()

func _test_both_body_meshes_observe_one_pose(driver_script: Script, failures: Array[String]) -> void:
	var fixture := _fixture(driver_script)
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	var bodies := fixture[&"body_meshes"] as Array[MeshInstance3D]
	(model.get_node("HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot") as Node3D).rotation = Vector3(0.31, -0.17, 0.22)
	driver.call(&"_process_for_skeleton", skeleton)
	TestAssertions.equal(bodies.size(), 2, "fixture contains both body meshes", failures)
	for body: MeshInstance3D in bodies:
		TestAssertions.equal(body.get_node(body.skeleton), skeleton, "%s resolves the canonical Skeleton3D" % body.name, failures)
		TestAssertions.equal(body.skin, bodies[0].skin, "%s uses the same canonical skin contract" % body.name, failures)
	var observed_first := _pose_snapshot(bodies[0].get_node(bodies[0].skeleton) as Skeleton3D)
	var observed_second := _pose_snapshot(bodies[1].get_node(bodies[1].skeleton) as Skeleton3D)
	TestAssertions.equal(observed_second, observed_first, "masculine and feminine body meshes observe identical skeleton poses", failures)
	model.free()

func _test_callback_contract_has_no_manual_blending(failures: Array[String]) -> void:
	var source := FileAccess.get_file_as_string(DRIVER_PATH)
	TestAssertions.truthy(source.contains("func _process_modification_with_delta(delta"), "driver overrides Godot 4.7 delta callback", failures)
	TestAssertions.truthy(source.contains("get_skeleton()"), "driver obtains its target through get_skeleton()", failures)
	for forbidden: String in ["interpolate_with", "slerp(", "lerp("]:
		TestAssertions.truthy(not source.contains(forbidden), "driver performs no manual %s blending" % forbidden, failures)

func _fixture(driver_script: Script, skeleton_transform: Transform3D = Transform3D.IDENTITY, invalid_case: StringName = &"") -> Dictionary:
	var definition := RIG_DEFINITION.duplicate(true) as Resource
	if invalid_case == &"signature_mismatch":
		definition.topology_signature = "mismatch"
	var model := MODEL_SCENE.instantiate() as ForgeHumanoidModel
	model.name = "LegacyPivotBridgeFixture"
	var skeleton := Skeleton3D.new()
	skeleton.name = "CanonicalSkeleton"
	skeleton.transform = skeleton_transform
	model.add_child(skeleton)
	_build_skeleton(skeleton, definition, invalid_case == &"missing_bone")
	var body_meshes := _add_body_meshes(skeleton, definition)
	if invalid_case == &"missing_pivot":
		(model.get_node("HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket") as Node3D).free()
	var driver := driver_script.new() as SkeletonModifier3D
	driver.name = "LegacyPivotSkeletonDriver"
	driver.call(&"configure", definition, model)
	if invalid_case == &"nested_driver":
		var spacer := Node3D.new()
		spacer.name = "InvalidSpacer"
		skeleton.add_child(spacer)
		spacer.add_child(driver)
	else:
		skeleton.add_child(driver)
	driver.call(&"_skeleton_changed", null, skeleton)
	var pivot_rests: Dictionary = {}
	if bool(driver.call(&"is_valid")):
		for pivot_path: NodePath in definition.pivot_paths:
			var pivot := model.get_node(pivot_path) as Node3D
			pivot_rests[String(pivot_path)] = _transform_without_tree(skeleton).affine_inverse() * _transform_without_tree(pivot)
	return {
		&"model": model,
		&"skeleton": skeleton,
		&"driver": driver,
		&"definition": definition,
		&"pivot_rests": pivot_rests,
		&"body_meshes": body_meshes,
	}

func _build_skeleton(skeleton: Skeleton3D, definition: Resource, omit_last_bone: bool) -> void:
	var count: int = definition.roles.size() - (1 if omit_last_bone else 0)
	for index: int in count:
		skeleton.add_bone(definition.bone_names[index])
		var parent_role: StringName = definition.parent_roles[index]
		skeleton.set_bone_parent(index, definition.roles.find(parent_role) if not parent_role.is_empty() else -1)
		skeleton.set_bone_rest(index, definition.canonical_rests[index])

func _add_body_meshes(skeleton: Skeleton3D, definition: Resource) -> Array[MeshInstance3D]:
	var skin := Skin.new()
	for index: int in skeleton.get_bone_count():
		skin.add_named_bind(definition.bone_names[index], Transform3D.IDENTITY)
	var bodies: Array[MeshInstance3D] = []
	for body_name: StringName in [&"MasculineBodyMesh", &"FeminineBodyMesh"]:
		var body := MeshInstance3D.new()
		body.name = body_name
		body.mesh = BoxMesh.new()
		body.skin = skin
		body.skeleton = NodePath("..")
		skeleton.add_child(body)
		bodies.append(body)
	return bodies

func _expected_poses(fixture: Dictionary) -> Dictionary:
	var model := fixture[&"model"] as Node3D
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var definition := fixture[&"definition"] as Resource
	var pivot_rests := fixture[&"pivot_rests"] as Dictionary
	var canonical_globals: Dictionary = {}
	var desired_globals: Dictionary = {}
	var poses: Dictionary = {}
	for index: int in definition.roles.size():
		var role: StringName = definition.roles[index]
		var parent_role: StringName = definition.parent_roles[index]
		var parent_rest := Transform3D.IDENTITY if parent_role.is_empty() else canonical_globals[parent_role] as Transform3D
		var canonical_global: Transform3D = parent_rest * definition.canonical_rests[index]
		canonical_globals[role] = canonical_global
		var pivot := model.get_node(definition.pivot_paths[index]) as Node3D
		var current_pivot := _transform_without_tree(skeleton).affine_inverse() * _transform_without_tree(pivot)
		var pivot_delta := current_pivot * (pivot_rests[String(definition.pivot_paths[index])] as Transform3D).affine_inverse()
		var desired_global: Transform3D = pivot_delta * canonical_global
		desired_globals[role] = desired_global
		var desired_parent := Transform3D.IDENTITY if parent_role.is_empty() else desired_globals[parent_role] as Transform3D
		var desired_local: Transform3D = desired_parent.affine_inverse() * desired_global
		poses[definition.bone_names[index]] = definition.canonical_rests[index].affine_inverse() * desired_local
	return poses

func _assert_closed(fixture: Dictionary, label: String, failures: Array[String]) -> void:
	var skeleton := fixture[&"skeleton"] as Skeleton3D
	var driver := fixture[&"driver"] as SkeletonModifier3D
	TestAssertions.truthy(not bool(driver.call(&"is_valid")), "%s fails closed" % label, failures)
	for bone_index: int in skeleton.get_bone_count():
		_assert_transform_near(skeleton.get_bone_pose(bone_index), Transform3D.IDENTITY, "%s leaves %s at identity pose delta" % [label, skeleton.get_bone_name(bone_index)], failures)

func _bone_rests(skeleton: Skeleton3D) -> Array[Transform3D]:
	var rests: Array[Transform3D] = []
	for bone_index: int in skeleton.get_bone_count():
		rests.append(skeleton.get_bone_rest(bone_index))
	return rests

func _assert_rests_unchanged(skeleton: Skeleton3D, before: Array[Transform3D], label: String, failures: Array[String]) -> void:
	for bone_index: int in skeleton.get_bone_count():
		_assert_transform_near(skeleton.get_bone_rest(bone_index), before[bone_index], "%s never edits %s rest" % [label, skeleton.get_bone_name(bone_index)], failures)

func _pose_snapshot(skeleton: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for bone_index: int in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(bone_index))
	return poses

func _assert_transform_near(actual: Transform3D, expected: Transform3D, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(_transforms_near(actual, expected), "%s (actual=%s expected=%s)" % [label, actual, expected], failures)

func _transforms_near(actual: Transform3D, expected: Transform3D) -> bool:
	return (
		actual.origin.distance_to(expected.origin) <= TRANSFORM_TOLERANCE
		and actual.basis.x.distance_to(expected.basis.x) <= TRANSFORM_TOLERANCE
		and actual.basis.y.distance_to(expected.basis.y) <= TRANSFORM_TOLERANCE
		and actual.basis.z.distance_to(expected.basis.z) <= TRANSFORM_TOLERANCE
	)

func _transform_without_tree(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result
