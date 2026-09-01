extends RefCounted

const DEFINITION_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const CONTRACT_SCRIPT_PATH := "res://scripts/presentation/humanoid_rig_contract.gd"
const MAPPING_SCRIPT_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const SHA_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const ROLES: Array[StringName] = [
	&"hips", &"spine", &"chest", &"neck", &"head",
	&"upper_arm_left", &"lower_arm_left", &"hand_left",
	&"upper_arm_right", &"lower_arm_right", &"hand_right",
	&"upper_leg_left", &"lower_leg_left", &"foot_left", &"toe_left",
	&"upper_leg_right", &"lower_leg_right", &"foot_right", &"toe_right",
]
const PARENT_BY_ROLE := {
	&"hips": &"",
	&"spine": &"hips",
	&"chest": &"spine",
	&"neck": &"chest",
	&"head": &"neck",
	&"upper_arm_left": &"chest",
	&"lower_arm_left": &"upper_arm_left",
	&"hand_left": &"lower_arm_left",
	&"upper_arm_right": &"chest",
	&"lower_arm_right": &"upper_arm_right",
	&"hand_right": &"lower_arm_right",
	&"upper_leg_left": &"hips",
	&"lower_leg_left": &"upper_leg_left",
	&"foot_left": &"lower_leg_left",
	&"toe_left": &"foot_left",
	&"upper_leg_right": &"hips",
	&"lower_leg_right": &"upper_leg_right",
	&"foot_right": &"lower_leg_right",
	&"toe_right": &"foot_right",
}

var _contract: RefCounted
var _mapping_script: Script
var _definition: Resource

func run() -> Array[String]:
	var failures: Array[String] = []
	var contract_script := load(CONTRACT_SCRIPT_PATH) as Script
	TestAssertions.truthy(contract_script != null, "humanoid rig contract loads", failures)
	TestAssertions.truthy(FileAccess.file_exists(MAPPING_SCRIPT_PATH), "production humanoid rig mapping contract exists", failures)
	if contract_script == null:
		return failures
	_contract = contract_script.new() as RefCounted
	TestAssertions.truthy(_contract.has_method(&"validate_mapped_rig"), "humanoid rig contract exposes mapped validation", failures)
	if not FileAccess.file_exists(MAPPING_SCRIPT_PATH) or not _contract.has_method(&"validate_mapped_rig"):
		return failures
	_mapping_script = load(MAPPING_SCRIPT_PATH) as Script
	_definition = load(DEFINITION_PATH) as Resource
	TestAssertions.truthy(_mapping_script != null and _definition != null, "mapping script and canonical semantic definition load", failures)
	if _mapping_script == null or _definition == null:
		return failures
	_assert_mapping_resource_contract(failures)
	_assert_superset_validation(failures)
	_assert_numeric_bind_resolution(failures)
	_assert_mapped_bone_and_hierarchy_failures(failures)
	_assert_rest_and_skin_failures(failures)
	_assert_source_rest_identity(failures)
	return failures

func _assert_mapping_resource_contract(failures: Array[String]) -> void:
	var valid := _mapping()
	TestAssertions.equal(valid.call(&"validate", _definition), PackedStringArray(), "complete semantic production mapping validates", failures)

	var missing_role := _mapping()
	var roles: Dictionary = missing_role.get(&"role_to_bone").duplicate(true)
	roles.erase(&"toe_right")
	missing_role.set(&"role_to_bone", roles)
	TestAssertions.truthy(_contains(missing_role.call(&"validate", _definition), "missing role toe_right"), "missing semantic role rejects", failures)

	var duplicate_target := _mapping()
	roles = duplicate_target.get(&"role_to_bone").duplicate(true)
	roles[&"toe_right"] = roles[&"toe_left"]
	duplicate_target.set(&"role_to_bone", roles)
	TestAssertions.truthy(_contains(duplicate_target.call(&"validate", _definition), "duplicate bone"), "duplicate target bone rejects", failures)

	var invalid_hash := _mapping()
	invalid_hash.set(&"source_skeleton_sha256", "ABC123")
	TestAssertions.truthy(_contains(invalid_hash.call(&"validate", _definition), "source skeleton hash"), "invalid source skeleton SHA-256 rejects", failures)

	var missing_rest_signature := _mapping()
	missing_rest_signature.set(&"source_rest_signature", "")
	TestAssertions.truthy(_contains(missing_rest_signature.call(&"validate", _definition), "source rest signature"), "missing source rest signature rejects", failures)

func _assert_superset_validation(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	var skin := _skin_for(skeleton)
	TestAssertions.equal(skeleton.get_bone_count(), 22, "synthetic production fixture has nineteen mapped and three presentation bones", failures)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin),
		PackedStringArray(),
		"semantic mapping accepts a finite named-bind superset skeleton",
		failures
	)
	var legacy_pivots := Node3D.new()
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_rig", _definition, skeleton, legacy_pivots), "bone count must be 19, got 22"),
		"legacy exact validator remains strict for the same superset skeleton",
		failures
	)
	legacy_pivots.free()
	skeleton.free()

func _assert_numeric_bind_resolution(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	var duplicate_name_snapshot: Array[StringName] = [&"PresentationRoot", &"DuplicateName", &"DuplicateName"]
	var has_name_list_helper := _contract.has_method(&"_matching_name_indices")
	TestAssertions.truthy(has_name_list_helper, "mapped-production duplicate-name resolver exists", failures)
	if has_name_list_helper:
		TestAssertions.equal(
			_contract.call(&"_matching_name_indices", duplicate_name_snapshot, &"DuplicateName"),
			PackedInt32Array([1, 2]),
			"mapped-production duplicate-name resolver returns every matching index deterministically",
			failures
		)

	var numeric_only := _skin_for(skeleton, &"", false)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, numeric_only),
		PackedStringArray(),
		"complete unique numeric-only Skin binds validate",
		failures
	)

	var named_numeric := _skin_for(skeleton)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, named_numeric),
		PackedStringArray(),
		"present names that agree with numeric indices validate",
		failures
	)

	var negative := _skin_for(skeleton, &"", false)
	negative.set_bind_bone(0, -1)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, negative), "bind 0 bone index -1 is out of range"),
		"negative numeric bind rejects",
		failures
	)

	var out_of_range := _skin_for(skeleton, &"", false)
	out_of_range.set_bind_bone(0, skeleton.get_bone_count())
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, out_of_range), "bind 0 bone index %d is out of range" % skeleton.get_bone_count()),
		"out-of-range numeric bind rejects",
		failures
	)

	var duplicate := _skin_for(skeleton, &"", false)
	var final_bind := duplicate.get_bind_count() - 1
	duplicate.set_bind_bone(final_bind, 0)
	var duplicate_errors: PackedStringArray = _contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, duplicate)
	TestAssertions.truthy(_contains(duplicate_errors, "bind %d duplicates skeleton bone 0" % final_bind), "duplicate numeric coverage rejects", failures)
	TestAssertions.truthy(_contains(duplicate_errors, "missing skeleton bone WeaponSocketDriver"), "duplicate coverage also reports the uncovered bone", failures)

	var incomplete := _skin_for(skeleton, &"WeaponSocketDriver", false)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, incomplete), "missing skeleton bone WeaponSocketDriver"),
		"incomplete full-skeleton coverage rejects",
		failures
	)

	var missing_name := _skin_for(skeleton)
	missing_name.set_bind_name(0, &"MissingProductionBone")
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, missing_name), "bind 0 name MissingProductionBone must resolve exactly once"),
		"present bind name with no skeleton match rejects",
		failures
	)

	var name_conflict := _skin_for(skeleton)
	name_conflict.set_bind_name(0, skeleton.get_bone_name(1))
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, name_conflict), "bind 0 name %s resolves to bone 1 but numeric index is 0" % skeleton.get_bone_name(1)),
		"present name/index conflict rejects",
		failures
	)

	var singular_bind := _skin_for(skeleton, &"", false)
	singular_bind.set_bind_pose(0, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, singular_bind), "bind 0 pose must be invertible"),
		"singular numeric bind pose rejects",
		failures
	)

	var non_finite_bind := _skin_for(skeleton, &"", false)
	var invalid_pose := non_finite_bind.get_bind_pose(0)
	invalid_pose.origin.x = INF
	non_finite_bind.set_bind_pose(0, invalid_pose)
	non_finite_bind.set_bind_bone(0, -1)
	var ordered_errors: PackedStringArray = _contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, non_finite_bind)
	TestAssertions.equal(ordered_errors[0], "mapped humanoid Skin bind 0 pose must be finite", "bind-pose errors lead slot-local resolution errors", failures)
	TestAssertions.equal(ordered_errors[1], "mapped humanoid Skin bind 0 bone index -1 is out of range", "numeric range error follows pose error deterministically", failures)

	skeleton.free()

func _assert_mapped_bone_and_hierarchy_failures(failures: Array[String]) -> void:
	var missing_bone_mapping := _mapping()
	var roles: Dictionary = missing_bone_mapping.get(&"role_to_bone").duplicate(true)
	roles[&"head"] = &"SyntheticMissingHead"
	missing_bone_mapping.set(&"role_to_bone", roles)
	var skeleton := _superset_skeleton(_mapping())
	_bind_mapping_to_skeleton(missing_bone_mapping, skeleton)
	var skin := _skin_for(skeleton)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, missing_bone_mapping, skeleton, skin), "must exist exactly once"),
		"missing mapped skeleton bone rejects",
		failures
	)
	skeleton.free()

	var mapping := _mapping()
	skeleton = _superset_skeleton(mapping)
	var child_index := skeleton.find_bone(_bone_for(mapping, &"upper_arm_left"))
	var wrong_parent_index := skeleton.find_bone(_bone_for(mapping, &"upper_leg_left"))
	skeleton.set_bone_parent(child_index, wrong_parent_index)
	_bind_mapping_to_skeleton(mapping, skeleton)
	skin = _skin_for(skeleton)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "does not descend from parent role chest"),
		"mapped child outside its required ancestor branch rejects",
		failures
	)
	skeleton.free()

func _assert_rest_and_skin_failures(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	var head_index := skeleton.find_bone(_bone_for(mapping, &"head"))
	var invalid_rest := skeleton.get_bone_rest(head_index)
	invalid_rest.origin.x = INF
	skeleton.set_bone_rest(head_index, invalid_rest)
	_bind_mapping_to_skeleton(mapping, skeleton)
	var skin := _skin_for(skeleton)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "rest must be finite"),
		"non-finite mapped rest rejects",
		failures
	)
	skeleton.free()

	skeleton = _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	skin = _skin_for(skeleton, _bone_for(mapping, &"hand_right"))
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "missing bone %s" % _bone_for(mapping, &"hand_right")),
		"missing mapped Skin bind rejects",
		failures
	)

	skin = _skin_for(skeleton)
	var bind_index := _bind_index(skin, _bone_for(mapping, &"head"))
	var invalid_bind := skin.get_bind_pose(bind_index)
	invalid_bind.origin.y = INF
	skin.set_bind_pose(bind_index, invalid_bind)
	TestAssertions.truthy(
		_contains(
			_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin),
			"mapped humanoid Skin bind %d pose must be finite" % bind_index
		),
		"non-finite named Skin bind rejects",
		failures
	)
	skeleton.free()

	skeleton = _superset_skeleton(mapping)
	skin = _skin_for(skeleton, &"", false)
	var singular_rest_index := skeleton.find_bone(_bone_for(mapping, &"head"))
	skeleton.set_bone_rest(
		singular_rest_index,
		Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	)
	_bind_mapping_to_skeleton(mapping, skeleton)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "mapped humanoid bone %s rest must be invertible" % _bone_for(mapping, &"head")),
		"singular mapped rest rejects",
		failures
	)
	skeleton.free()

	skeleton = _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	skin = _skin_for(skeleton, _bone_for(mapping, &"hand_right"), false)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "mapped humanoid Skin is missing bone %s" % _bone_for(mapping, &"hand_right")),
		"complete skeleton coverage includes every semantic mapped bone",
		failures
	)
	skeleton.free()

func _assert_source_rest_identity(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	var skin := _skin_for(skeleton, &"", false)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin),
		PackedStringArray(),
		"matching mapped source rest signature validates",
		failures
	)
	mapping.set(&"source_rest_signature", SHA_A)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "source rest signature mismatch"),
		"wrong body-specific rest identity rejects",
		failures
	)
	skeleton.free()

func _mapping() -> Resource:
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", &"synthetic_superset_v1")
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	var role_to_bone: Dictionary = {}
	for role: StringName in ROLES:
		role_to_bone[role] = StringName("SyntheticBone__%s" % role)
	mapping.set(&"role_to_bone", role_to_bone)
	mapping.set(&"source_skeleton_sha256", SHA_A)
	mapping.set(&"source_rest_signature", SHA_A)
	return mapping

func _bind_mapping_to_skeleton(mapping: Resource, skeleton: Skeleton3D) -> void:
	mapping.set(&"source_rest_signature", String(_contract.call(&"production_rest_signature", skeleton)))

func _superset_skeleton(mapping: Resource) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.add_bone(&"PresentationRoot")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)
	var role_to_index: Dictionary = {}
	var shoulder_driver_index := -1
	for role: StringName in ROLES:
		if role == &"upper_arm_left":
			shoulder_driver_index = skeleton.get_bone_count()
			skeleton.add_bone(&"ShoulderDriver")
			skeleton.set_bone_rest(shoulder_driver_index, Transform3D.IDENTITY)
		var index := skeleton.get_bone_count()
		skeleton.add_bone(_bone_for(mapping, role))
		skeleton.set_bone_rest(index, Transform3D.IDENTITY)
		role_to_index[role] = index
	for role: StringName in ROLES:
		var index: int = role_to_index[role]
		var parent_role: StringName = PARENT_BY_ROLE[role]
		if role == &"hips":
			skeleton.set_bone_parent(index, 0)
		elif role == &"upper_arm_left":
			skeleton.set_bone_parent(index, shoulder_driver_index)
		else:
			skeleton.set_bone_parent(index, role_to_index[parent_role])
	skeleton.set_bone_parent(shoulder_driver_index, role_to_index[&"chest"])
	var weapon_driver_index := skeleton.get_bone_count()
	skeleton.add_bone(&"WeaponSocketDriver")
	skeleton.set_bone_parent(weapon_driver_index, role_to_index[&"hand_right"])
	skeleton.set_bone_rest(weapon_driver_index, Transform3D.IDENTITY)
	return skeleton

func _skin_for(
		skeleton: Skeleton3D,
		omitted_bone: StringName = &"",
		include_names: bool = true
	) -> Skin:
	var skin := Skin.new()
	for bone_index: int in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		if bone_name == omitted_bone:
			continue
		skin.add_bind(bone_index, skeleton.get_bone_rest(bone_index).affine_inverse())
		if include_names:
			skin.set_bind_name(skin.get_bind_count() - 1, bone_name)
	return skin

func _bind_index(skin: Skin, bone_name: StringName) -> int:
	for bind_index: int in skin.get_bind_count():
		if skin.get_bind_name(bind_index) == bone_name:
			return bind_index
	return -1

func _bone_for(mapping: Resource, role: StringName) -> StringName:
	var role_to_bone: Dictionary = mapping.get(&"role_to_bone")
	return StringName(role_to_bone[role])

func _contains(errors: Variant, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
