class_name LegacyPivotSkeletonDriver
extends SkeletonModifier3D

const RigDefinition := preload("res://scripts/presentation/humanoid_rig_definition.gd")
const RigContract := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const MIN_INVERTIBLE_DETERMINANT := 0.000000000001

@export var rig_definition: RigDefinition
@export var pivot_root: Node3D

var _is_valid := false
var _setup_attempted := false
var _entries: Array[Dictionary] = []

func _ready() -> void:
	influence = 1.0

func configure(definition: RigDefinition, source_root: Node3D) -> void:
	rig_definition = definition
	pivot_root = source_root
	_setup_attempted = false
	_is_valid = false

func is_valid() -> bool:
	return _is_valid

func _process_modification_with_delta(delta: float) -> void:
	_process_for_skeleton(get_skeleton())

func _skeleton_changed(_old_skeleton: Skeleton3D, new_skeleton: Skeleton3D) -> void:
	_setup_attempted = false
	_is_valid = false
	if new_skeleton != null:
		_capture_validated_setup(new_skeleton)

func _process_for_skeleton(skeleton: Skeleton3D) -> void:
	if not _setup_attempted:
		_capture_validated_setup(skeleton)
	if not _is_valid:
		return
	var skeleton_world := _node_world_transform(skeleton)
	if skeleton == null or get_parent() != skeleton or not _transform_is_usable(skeleton_world):
		_fail_closed(skeleton)
		return
	var desired_globals: Dictionary = {}
	var pending_poses: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		var pivot := entry[&"pivot"] as Node3D
		var bone_index := int(entry[&"bone_index"])
		if not is_instance_valid(pivot) or bone_index < 0 or bone_index >= skeleton.get_bone_count():
			_fail_closed(skeleton)
			return
		var current_pivot := skeleton_world.affine_inverse() * _node_world_transform(pivot)
		if not _transform_is_usable(current_pivot):
			_fail_closed(skeleton)
			return
		var pivot_delta := current_pivot * (entry[&"pivot_rest"] as Transform3D).affine_inverse()
		var desired_global := pivot_delta * (entry[&"canonical_global_rest"] as Transform3D)
		var parent_role := entry[&"parent_role"] as StringName
		var desired_parent := Transform3D.IDENTITY if parent_role.is_empty() else desired_globals.get(parent_role, Transform3D.IDENTITY) as Transform3D
		var desired_local := desired_parent.affine_inverse() * desired_global
		var pose := (entry[&"canonical_local_rest"] as Transform3D).affine_inverse() * desired_local
		if not _transform_is_usable(desired_global) or not _transform_is_usable(desired_local) or not _transform_is_usable(pose):
			_fail_closed(skeleton)
			return
		desired_globals[entry[&"role"]] = desired_global
		pending_poses.append({&"bone_index": bone_index, &"pose": pose})
	for pending: Dictionary in pending_poses:
		skeleton.set_bone_pose(int(pending[&"bone_index"]), pending[&"pose"] as Transform3D)

func _capture_validated_setup(skeleton: Skeleton3D) -> void:
	_setup_attempted = true
	_is_valid = false
	_entries.clear()
	influence = 1.0
	if skeleton == null or get_parent() != skeleton or rig_definition == null or pivot_root == null:
		_fail_closed(skeleton)
		return
	var skeleton_world := _node_world_transform(skeleton)
	if not _transform_is_usable(skeleton_world):
		_fail_closed(skeleton)
		return
	var contract := RigContract.new()
	if not contract.validate_rig(rig_definition, skeleton, pivot_root).is_empty():
		_fail_closed(skeleton)
		return
	var canonical_globals: Dictionary = {}
	for role: StringName in RigContract.REQUIRED_ROLES:
		var mapping_index: int = rig_definition.roles.find(role)
		var parent_role: StringName = rig_definition.parent_roles[mapping_index]
		var canonical_local: Transform3D = rig_definition.canonical_rests[mapping_index]
		var canonical_parent := Transform3D.IDENTITY if parent_role.is_empty() else canonical_globals[parent_role] as Transform3D
		var canonical_global := canonical_parent * canonical_local
		var pivot := pivot_root.get_node_or_null(rig_definition.pivot_paths[mapping_index]) as Node3D
		var pivot_rest := skeleton_world.affine_inverse() * _node_world_transform(pivot)
		if not _transform_is_usable(pivot_rest) or not _transform_is_usable(canonical_global):
			_fail_closed(skeleton)
			return
		canonical_globals[role] = canonical_global
		_entries.append({
			&"role": role,
			&"parent_role": parent_role,
			&"bone_index": skeleton.find_bone(rig_definition.bone_names[mapping_index]),
			&"pivot": pivot,
			&"pivot_rest": pivot_rest,
			&"canonical_local_rest": canonical_local,
			&"canonical_global_rest": canonical_global,
		})
	_is_valid = true
	active = true

func _fail_closed(skeleton: Skeleton3D) -> void:
	_is_valid = false
	active = false
	if skeleton == null:
		return
	for entry: Dictionary in _entries:
		var bone_index := int(entry.get(&"bone_index", -1))
		if bone_index >= 0 and bone_index < skeleton.get_bone_count():
			skeleton.set_bone_pose(bone_index, Transform3D.IDENTITY)

func _transform_is_usable(value: Transform3D) -> bool:
	return (
		value.origin.is_finite()
		and value.basis.x.is_finite()
		and value.basis.y.is_finite()
		and value.basis.z.is_finite()
		and absf(value.basis.determinant()) > MIN_INVERTIBLE_DETERMINANT
	)

func _node_world_transform(node: Node3D) -> Transform3D:
	if node.is_inside_tree():
		return node.global_transform
	var result := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null:
		if cursor is Node3D:
			result = (cursor as Node3D).transform * result
		cursor = cursor.get_parent()
	return result
