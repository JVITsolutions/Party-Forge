extends RefCounted

const DEFINITION_SCRIPT_PATH := "res://scripts/presentation/humanoid_rig_definition.gd"
const CONTRACT_SCRIPT_PATH := "res://scripts/presentation/humanoid_rig_contract.gd"
const CANONICAL_RESOURCE_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const HUMANOID_SCENE_PATH := "res://scenes/characters/presentation/forge_humanoid_model.tscn"

const ROLES: Array[StringName] = [
	&"hips", &"spine", &"chest", &"neck", &"head",
	&"upper_arm_left", &"lower_arm_left", &"hand_left",
	&"upper_arm_right", &"lower_arm_right", &"hand_right",
	&"upper_leg_left", &"lower_leg_left", &"foot_left", &"toe_left",
	&"upper_leg_right", &"lower_leg_right", &"foot_right", &"toe_right",
]
const PARENTS: Array[StringName] = [
	&"", &"hips", &"spine", &"chest", &"neck",
	&"chest", &"upper_arm_left", &"lower_arm_left",
	&"chest", &"upper_arm_right", &"lower_arm_right",
	&"hips", &"upper_leg_left", &"lower_leg_left", &"foot_left",
	&"hips", &"upper_leg_right", &"lower_leg_right", &"foot_right",
]
const BONES: Array[StringName] = [
	&"Hips", &"Spine", &"Chest", &"Neck", &"Head",
	&"UpperArm.L", &"LowerArm.L", &"Hand.L",
	&"UpperArm.R", &"LowerArm.R", &"Hand.R",
	&"UpperLeg.L", &"LowerLeg.L", &"Foot.L", &"Toe.L",
	&"UpperLeg.R", &"LowerLeg.R", &"Foot.R", &"Toe.R",
]
const PIVOTS: Array[String] = [
	"HitPivot/BodyPivot/HipsPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
	"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	"HitPivot/BodyPivot/HipsPivot/LeftHipPivot",
	"HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot",
	"HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot",
	"HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot/LeftFootPivot",
	"HitPivot/BodyPivot/HipsPivot/RightHipPivot",
	"HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot",
	"HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot",
	"HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot/RightFootPivot",
]

var _definition_script: Script
var _contract: RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var scripts_exist := FileAccess.file_exists(DEFINITION_SCRIPT_PATH) and FileAccess.file_exists(CONTRACT_SCRIPT_PATH)
	TestAssertions.truthy(scripts_exist, "canonical humanoid rig definition and contract scripts exist", failures)
	if not scripts_exist:
		return failures
	_definition_script = load(DEFINITION_SCRIPT_PATH) as Script
	var contract_script := load(CONTRACT_SCRIPT_PATH) as Script
	TestAssertions.truthy(_definition_script != null and contract_script != null, "canonical humanoid rig scripts load", failures)
	if _definition_script == null or contract_script == null:
		return failures
	_contract = contract_script.new() as RefCounted
	_assert_definition_and_fixture_validation(failures)
	_assert_signatures_are_stable_and_independent(failures)
	_assert_quantized_rest_and_topology_changes(failures)
	_assert_invalid_role_bone_and_pivot_contracts(failures)
	_assert_named_skin_bind_contract(failures)
	_assert_canonical_resource_matches_current_pivots(failures)
	return failures

func _assert_definition_and_fixture_validation(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var skeleton := _skeleton_for(definition)
	var pivots := _pivot_fixture()
	TestAssertions.equal(definition.get(&"rig_id"), &"pf_humanoid_v1", "fixture uses stable pf_humanoid_v1 ID", failures)
	TestAssertions.equal(_contract.call(&"validate_definition", definition), PackedStringArray(), "complete unique semantic role definition validates", failures)
	TestAssertions.equal(_contract.call(&"validate_rig", definition, skeleton, pivots), PackedStringArray(), "programmatic skeleton and pivot fixture validate", failures)
	skeleton.free()
	pivots.free()

func _assert_signatures_are_stable_and_independent(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var topology := String(_contract.call(&"topology_signature", definition))
	var rest := String(_contract.call(&"canonical_rest_signature", definition))
	var skin := _named_skin_for(definition)
	var binds := String(_contract.call(&"skin_bind_signature", definition, skin))
	TestAssertions.equal(topology.length(), 64, "topology signature is SHA-256", failures)
	TestAssertions.equal(rest.length(), 64, "canonical rest signature is SHA-256", failures)
	TestAssertions.equal(binds.length(), 64, "Skin bind signature is SHA-256", failures)
	TestAssertions.truthy(topology != rest and topology != binds and rest != binds, "topology, rest, and Skin signatures are independent", failures)
	var reordered := _reordered_definition(definition)
	reordered.set(&"resource_name", "different_import_order")
	reordered.set_meta(&"resource_uid", "ignored")
	reordered.set_meta(&"timestamp", 999999)
	TestAssertions.equal(_contract.call(&"topology_signature", reordered), topology, "topology hash ignores resource identity, metadata, and mapping order", failures)
	TestAssertions.equal(_contract.call(&"canonical_rest_signature", reordered), rest, "rest hash ignores resource identity, metadata, and mapping order", failures)
	TestAssertions.equal(_contract.call(&"serialize_topology", definition).sha256_text(), topology, "topology signature hashes its UTF-8 serialization", failures)
	TestAssertions.equal(_contract.call(&"serialize_canonical_rest", definition).sha256_text(), rest, "rest signature hashes its UTF-8 serialization", failures)
	TestAssertions.equal(_contract.call(&"serialize_skin_binds", definition, skin).sha256_text(), binds, "Skin signature hashes its UTF-8 serialization", failures)

func _assert_quantized_rest_and_topology_changes(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var base_rest := String(_contract.call(&"canonical_rest_signature", definition))
	var below_quantum := definition.duplicate(true) as Resource
	_set_rest_origin_offset(below_quantum, &"head", Vector3(0.0000004, 0.0, 0.0))
	TestAssertions.equal(_contract.call(&"canonical_rest_signature", below_quantum), base_rest, "rest components are quantized to 1e-6 before hashing", failures)
	var changed_length := definition.duplicate(true) as Resource
	_set_rest_origin_offset(changed_length, &"lower_leg_left", Vector3(0.0, -0.01, 0.0))
	TestAssertions.truthy(String(_contract.call(&"canonical_rest_signature", changed_length)) != base_rest, "changed bone length changes canonical rest signature", failures)
	var changed_rotation := definition.duplicate(true) as Resource
	var rests: Array[Transform3D] = changed_rotation.get(&"canonical_rests")
	var head_index := _role_index(changed_rotation, &"head")
	rests[head_index].basis = Basis(Vector3.UP, 0.01) * rests[head_index].basis
	changed_rotation.set(&"canonical_rests", rests)
	TestAssertions.truthy(String(_contract.call(&"canonical_rest_signature", changed_rotation)) != base_rest, "changed rest rotation changes canonical rest signature", failures)
	var changed_parent := definition.duplicate(true) as Resource
	var parent_roles: Array[StringName] = changed_parent.get(&"parent_roles")
	parent_roles[_role_index(changed_parent, &"head")] = &"chest"
	changed_parent.set(&"parent_roles", parent_roles)
	TestAssertions.truthy(String(_contract.call(&"topology_signature", changed_parent)) != String(_contract.call(&"topology_signature", definition)), "changed parent changes topology signature", failures)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", changed_parent), "parent role"), "changed approved parent hierarchy rejects", failures)

func _assert_invalid_role_bone_and_pivot_contracts(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var missing_role := definition.duplicate(true) as Resource
	_remove_mapping_at(missing_role, ROLES.size() - 1)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", missing_role), "missing role"), "missing required role rejects", failures)
	var duplicate_role := definition.duplicate(true) as Resource
	var roles: Array[StringName] = duplicate_role.get(&"roles")
	roles[roles.size() - 1] = roles[roles.size() - 2]
	duplicate_role.set(&"roles", roles)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", duplicate_role), "duplicate role"), "duplicate semantic role rejects", failures)
	var duplicate_bone := definition.duplicate(true) as Resource
	var bone_names: Array[StringName] = duplicate_bone.get(&"bone_names")
	bone_names[bone_names.size() - 1] = bone_names[bone_names.size() - 2]
	duplicate_bone.set(&"bone_names", bone_names)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", duplicate_bone), "duplicate bone"), "two roles cannot map to one canonical bone", failures)
	var singular := definition.duplicate(true) as Resource
	var rests: Array[Transform3D] = singular.get(&"canonical_rests")
	rests[0].basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	singular.set(&"canonical_rests", rests)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", singular), "invertible"), "singular rest transform rejects", failures)
	var non_finite := definition.duplicate(true) as Resource
	rests = non_finite.get(&"canonical_rests")
	rests[0].origin.x = INF
	non_finite.set(&"canonical_rests", rests)
	TestAssertions.truthy(_contains(_contract.call(&"validate_definition", non_finite), "finite"), "non-finite rest transform rejects", failures)
	var skeleton := _skeleton_for(definition, ROLES.size() - 1)
	var pivots := _pivot_fixture()
	TestAssertions.truthy(_contains(_contract.call(&"validate_rig", definition, skeleton, pivots), "bone count"), "missing canonical bone rejects", failures)
	skeleton.free()
	skeleton = _skeleton_for(definition)
	var missing_pivot := pivots.get_node_or_null(NodePath(PIVOTS[PIVOTS.size() - 1]))
	if missing_pivot != null:
		missing_pivot.free()
	TestAssertions.truthy(_contains(_contract.call(&"validate_rig", definition, skeleton, pivots), "pivot"), "missing mapped pivot rejects", failures)
	skeleton.free()
	pivots.free()

func _assert_named_skin_bind_contract(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var skin := _named_skin_for(definition)
	TestAssertions.equal(_contract.call(&"validate_skin", definition, skin), PackedStringArray(), "ordered unique named Skin binds validate", failures)
	var signature := String(_contract.call(&"skin_bind_signature", definition, skin))
	var same_skin := _named_skin_for(definition)
	var pose := same_skin.get_bind_pose(0)
	pose.origin.x += 0.0000004
	same_skin.set_bind_pose(0, pose)
	TestAssertions.equal(_contract.call(&"skin_bind_signature", definition, same_skin), signature, "Skin bind poses are quantized to 1e-6", failures)
	var changed_pose := _named_skin_for(definition)
	pose = changed_pose.get_bind_pose(0)
	pose.origin.x += 0.01
	changed_pose.set_bind_pose(0, pose)
	TestAssertions.truthy(String(_contract.call(&"skin_bind_signature", definition, changed_pose)) != signature, "changed Skin bind pose changes signature", failures)
	var reordered := Skin.new()
	for index: int in range(BONES.size() - 1, -1, -1):
		reordered.add_named_bind(BONES[index], skin.get_bind_pose(index))
	TestAssertions.truthy(String(_contract.call(&"skin_bind_signature", definition, reordered)) != signature, "Skin bind order is serialized", failures)
	var numeric_only := Skin.new()
	numeric_only.add_bind(0, Transform3D.IDENTITY)
	TestAssertions.truthy(_contains(_contract.call(&"validate_skin", definition, numeric_only), "named"), "numeric-only unnamed Skin bind rejects", failures)
	var duplicate_name := _named_skin_for(definition)
	duplicate_name.set_bind_name(duplicate_name.get_bind_count() - 1, BONES[0])
	TestAssertions.truthy(_contains(_contract.call(&"validate_skin", definition, duplicate_name), "duplicate"), "duplicate Skin bind name rejects", failures)
	var unknown_name := _named_skin_for(definition)
	unknown_name.set_bind_name(0, &"UnknownBone")
	TestAssertions.truthy(_contains(_contract.call(&"validate_skin", definition, unknown_name), "canonical bone"), "Skin bind name must resolve to a canonical bone", failures)

func _assert_canonical_resource_matches_current_pivots(failures: Array[String]) -> void:
	var definition := load(CANONICAL_RESOURCE_PATH) as Resource
	TestAssertions.truthy(definition != null, "pf_humanoid_v1 resource loads", failures)
	if definition == null:
		return
	TestAssertions.equal(definition.get(&"rig_id"), &"pf_humanoid_v1", "canonical resource has stable rig ID", failures)
	TestAssertions.equal(_contract.call(&"validate_definition", definition), PackedStringArray(), "canonical resource signatures and hierarchy validate", failures)
	var scene := (load(HUMANOID_SCENE_PATH) as PackedScene).instantiate()
	var skeleton := _skeleton_for(definition)
	TestAssertions.equal(_contract.call(&"validate_rig", definition, skeleton, scene), PackedStringArray(), "canonical resource maps every bone to the current pivot hierarchy", failures)
	skeleton.free()
	scene.free()

func _fixture_definition() -> Resource:
	var definition := _definition_script.new() as Resource
	definition.set(&"rig_id", &"pf_humanoid_v1")
	var roles: Array[StringName] = []
	var bone_names: Array[StringName] = []
	var parent_roles: Array[StringName] = []
	var pivot_paths: Array[NodePath] = []
	var rests: Array[Transform3D] = []
	for index: int in ROLES.size():
		roles.append(ROLES[index])
		bone_names.append(BONES[index])
		parent_roles.append(PARENTS[index])
		pivot_paths.append(NodePath(PIVOTS[index]))
		rests.append(_fixture_rest(index))
	definition.set(&"roles", roles)
	definition.set(&"bone_names", bone_names)
	definition.set(&"parent_roles", parent_roles)
	definition.set(&"pivot_paths", pivot_paths)
	definition.set(&"canonical_rests", rests)
	definition.set(&"topology_signature", _contract.call(&"topology_signature", definition))
	definition.set(&"canonical_rest_signature", _contract.call(&"canonical_rest_signature", definition))
	return definition

func _fixture_rest(index: int) -> Transform3D:
	if index == 0:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.82, 0.0))
	var side := -1.0 if ROLES[index].ends_with("_left") else 1.0
	if ROLES[index].begins_with("upper_arm"):
		return Transform3D(Basis.IDENTITY, Vector3(0.34 * side, 0.13, 0.0))
	if ROLES[index].begins_with("lower_arm"):
		return Transform3D(Basis.IDENTITY, Vector3(0.08 * side, -0.28, 0.0))
	if ROLES[index].begins_with("hand"):
		return Transform3D(Basis.IDENTITY, Vector3(0.03 * side, -0.22, 0.0))
	if ROLES[index].begins_with("upper_leg"):
		return Transform3D(Basis.IDENTITY, Vector3(0.17 * side, -0.04, 0.0))
	if ROLES[index].begins_with("lower_leg"):
		return Transform3D(Basis.IDENTITY, Vector3(0.0, -0.38, 0.0))
	if ROLES[index].begins_with("foot"):
		return Transform3D(Basis.IDENTITY, Vector3(0.0, -0.36, 0.05))
	if ROLES[index].begins_with("toe"):
		return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.16))
	var central_origins := {
		&"spine": Vector3(0.0, 0.22, 0.0),
		&"chest": Vector3(0.0, 0.24, 0.0),
		&"neck": Vector3(0.0, 0.24, 0.0),
		&"head": Vector3(0.0, 0.12, 0.0),
	}
	return Transform3D(Basis.IDENTITY, central_origins[ROLES[index]])

func _skeleton_for(definition: Resource, count: int = -1) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var roles: Array[StringName] = definition.get(&"roles")
	var bone_names: Array[StringName] = definition.get(&"bone_names")
	var parent_roles: Array[StringName] = definition.get(&"parent_roles")
	var rests: Array[Transform3D] = definition.get(&"canonical_rests")
	var bone_count := roles.size() if count < 0 else count
	var role_to_bone: Dictionary = {}
	for index: int in bone_count:
		skeleton.add_bone(bone_names[index])
		role_to_bone[roles[index]] = index
	for index: int in bone_count:
		var parent_role: StringName = parent_roles[index]
		if not parent_role.is_empty() and role_to_bone.has(parent_role):
			skeleton.set_bone_parent(index, role_to_bone[parent_role])
		skeleton.set_bone_rest(index, rests[index])
	return skeleton

func _pivot_fixture() -> Node3D:
	var root := Node3D.new()
	root.name = &"Fixture"
	for pivot_path: String in PIVOTS:
		var current: Node = root
		for component: String in pivot_path.split("/"):
			var child := current.get_node_or_null(NodePath(component))
			if child == null:
				child = Node3D.new()
				child.name = component
				current.add_child(child)
			current = child
	return root

func _named_skin_for(definition: Resource) -> Skin:
	var skin := Skin.new()
	var bone_names: Array[StringName] = definition.get(&"bone_names")
	var rests: Array[Transform3D] = definition.get(&"canonical_rests")
	for index: int in bone_names.size():
		skin.add_named_bind(bone_names[index], rests[index].affine_inverse())
	return skin

func _reordered_definition(definition: Resource) -> Resource:
	var reordered := _definition_script.new() as Resource
	reordered.set(&"rig_id", definition.get(&"rig_id"))
	var roles: Array[StringName] = []
	var bone_names: Array[StringName] = []
	var parent_roles: Array[StringName] = []
	var pivot_paths: Array[NodePath] = []
	var rests: Array[Transform3D] = []
	for index: int in range(ROLES.size() - 1, -1, -1):
		roles.append(definition.get(&"roles")[index])
		bone_names.append(definition.get(&"bone_names")[index])
		parent_roles.append(definition.get(&"parent_roles")[index])
		pivot_paths.append(definition.get(&"pivot_paths")[index])
		rests.append(definition.get(&"canonical_rests")[index])
	reordered.set(&"roles", roles)
	reordered.set(&"bone_names", bone_names)
	reordered.set(&"parent_roles", parent_roles)
	reordered.set(&"pivot_paths", pivot_paths)
	reordered.set(&"canonical_rests", rests)
	reordered.set(&"topology_signature", definition.get(&"topology_signature"))
	reordered.set(&"canonical_rest_signature", definition.get(&"canonical_rest_signature"))
	return reordered

func _set_rest_origin_offset(definition: Resource, role: StringName, offset: Vector3) -> void:
	var rests: Array[Transform3D] = definition.get(&"canonical_rests")
	var index := _role_index(definition, role)
	rests[index].origin += offset
	definition.set(&"canonical_rests", rests)

func _remove_mapping_at(definition: Resource, index: int) -> void:
	for property_name: StringName in [&"roles", &"bone_names", &"parent_roles", &"pivot_paths", &"canonical_rests"]:
		var values: Array = definition.get(property_name)
		values.remove_at(index)
		definition.set(property_name, values)

func _role_index(definition: Resource, role: StringName) -> int:
	var roles: Array[StringName] = definition.get(&"roles")
	return roles.find(role)

func _contains(errors: Variant, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
