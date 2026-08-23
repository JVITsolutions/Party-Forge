class_name HumanoidRigContract
extends RefCounted

const RigDefinition := preload("res://scripts/presentation/humanoid_rig_definition.gd")
const CANONICAL_RIG_ID: StringName = &"pf_humanoid_v1"
const QUANTIZATION := 0.000001
const MIN_INVERTIBLE_DETERMINANT := 0.000000000001

const REQUIRED_ROLES: Array[StringName] = [
	&"hips", &"spine", &"chest", &"neck", &"head",
	&"upper_arm_left", &"lower_arm_left", &"hand_left",
	&"upper_arm_right", &"lower_arm_right", &"hand_right",
	&"upper_leg_left", &"lower_leg_left", &"foot_left", &"toe_left",
	&"upper_leg_right", &"lower_leg_right", &"foot_right", &"toe_right",
]
const REQUIRED_PARENT_BY_ROLE := {
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
const APPROVED_PIVOT_ALIAS_PARTNER := {
	&"spine": &"chest",
	&"chest": &"spine",
	&"neck": &"head",
	&"head": &"neck",
	&"foot_left": &"toe_left",
	&"toe_left": &"foot_left",
	&"foot_right": &"toe_right",
	&"toe_right": &"foot_right",
}

func validate_definition(definition: RigDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("humanoid rig definition is missing")
		return errors
	if definition.rig_id != CANONICAL_RIG_ID:
		errors.append("humanoid rig ID must be %s" % CANONICAL_RIG_ID)
	_validate_mapping_sizes(definition, errors)
	var seen_roles: Dictionary = {}
	var seen_bones: Dictionary = {}
	var roles_by_pivot_path: Dictionary = {}
	var safe_count := _safe_mapping_count(definition)
	for index: int in safe_count:
		var role: StringName = definition.roles[index]
		var bone_name: StringName = definition.bone_names[index]
		var parent_role: StringName = definition.parent_roles[index]
		var pivot_path: NodePath = definition.pivot_paths[index]
		var rest: Transform3D = definition.canonical_rests[index]
		if role not in REQUIRED_ROLES:
			errors.append("humanoid rig role %s is not required" % role)
		elif seen_roles.has(role):
			errors.append("humanoid rig has duplicate role %s" % role)
		else:
			seen_roles[role] = true
		if bone_name.is_empty():
			errors.append("humanoid rig role %s has an empty bone name" % role)
		elif seen_bones.has(bone_name):
			errors.append("humanoid rig has duplicate bone %s" % bone_name)
		else:
			seen_bones[bone_name] = true
		if role in REQUIRED_PARENT_BY_ROLE and parent_role != REQUIRED_PARENT_BY_ROLE[role]:
			errors.append("humanoid rig role %s parent role must be %s" % [role, REQUIRED_PARENT_BY_ROLE[role]])
		var pivot_path_is_safe := not pivot_path.is_empty() and not pivot_path.is_absolute()
		if not pivot_path_is_safe:
			errors.append("humanoid rig role %s pivot path must be a non-empty relative NodePath" % role)
		else:
			for segment_index: int in pivot_path.get_name_count():
				var segment := String(pivot_path.get_name(segment_index))
				if segment == "." or segment == "..":
					errors.append("humanoid rig role %s pivot path contains unsafe path segment %s" % [role, segment])
					pivot_path_is_safe = false
					break
		if pivot_path_is_safe:
			var pivot_key := String(pivot_path)
			if not roles_by_pivot_path.has(pivot_key):
				roles_by_pivot_path[pivot_key] = []
			var mapped_roles: Array = roles_by_pivot_path[pivot_key]
			mapped_roles.append(role)
		_validate_transform(rest, "humanoid rig role %s rest" % role, errors)
	for pivot_key: String in roles_by_pivot_path:
		var mapped_roles: Array = roles_by_pivot_path[pivot_key]
		if mapped_roles.size() <= 1:
			continue
		var approved_pair: bool = mapped_roles.size() == 2 and APPROVED_PIVOT_ALIAS_PARTNER.get(mapped_roles[0], &"") == mapped_roles[1]
		if not approved_pair:
			errors.append("humanoid rig pivot alias %s is not an approved exact role pair: %s" % [pivot_key, mapped_roles])
	for role: StringName in REQUIRED_ROLES:
		if not seen_roles.has(role):
			errors.append("humanoid rig is missing role %s" % role)
	var computed_topology := topology_signature(definition)
	if definition.topology_signature.is_empty():
		errors.append("humanoid rig topology signature is missing; expected %s" % computed_topology)
	elif definition.topology_signature != computed_topology:
		errors.append("humanoid rig topology signature mismatch; expected %s" % computed_topology)
	var computed_rest := canonical_rest_signature(definition)
	if definition.canonical_rest_signature.is_empty():
		errors.append("humanoid rig canonical rest signature is missing; expected %s" % computed_rest)
	elif definition.canonical_rest_signature != computed_rest:
		errors.append("humanoid rig canonical rest signature mismatch; expected %s" % computed_rest)
	return errors

func validate_rig(definition: RigDefinition, skeleton: Skeleton3D, pivot_root: Node) -> PackedStringArray:
	var errors := validate_definition(definition)
	if definition == null:
		return errors
	if skeleton == null:
		errors.append("humanoid rig Skeleton3D is missing")
		return errors
	if pivot_root == null:
		errors.append("humanoid rig pivot root is missing")
		return errors
	if skeleton.get_bone_count() != REQUIRED_ROLES.size():
		errors.append("humanoid rig bone count must be %d, got %d" % [REQUIRED_ROLES.size(), skeleton.get_bone_count()])
	for role: StringName in REQUIRED_ROLES:
		var mapping_index: int = definition.roles.find(role)
		if mapping_index < 0 or mapping_index >= _safe_mapping_count(definition):
			continue
		var bone_name: StringName = definition.bone_names[mapping_index]
		var matching_bones: Array[int] = _bone_indices_named(skeleton, bone_name)
		if matching_bones.size() != 1:
			errors.append("humanoid rig role %s bone %s must exist exactly once" % [role, bone_name])
			continue
		var bone_index: int = matching_bones[0]
		var parent_role: StringName = definition.parent_roles[mapping_index]
		var expected_parent_index := -1
		if not parent_role.is_empty():
			var parent_mapping_index: int = definition.roles.find(parent_role)
			if parent_mapping_index >= 0:
				var parent_matches: Array[int] = _bone_indices_named(skeleton, definition.bone_names[parent_mapping_index])
				if parent_matches.size() == 1:
					expected_parent_index = parent_matches[0]
		if skeleton.get_bone_parent(bone_index) != expected_parent_index:
			errors.append("humanoid rig role %s skeleton parent does not match parent role %s" % [role, parent_role])
		var actual_rest: Transform3D = skeleton.get_bone_rest(bone_index)
		_validate_transform(actual_rest, "humanoid rig bone %s rest" % bone_name, errors)
		if _serialize_transform(actual_rest) != _serialize_transform(definition.canonical_rests[mapping_index]):
			errors.append("humanoid rig bone %s rest does not match canonical rest" % bone_name)
		var pivot: Node = pivot_root.get_node_or_null(definition.pivot_paths[mapping_index])
		if not pivot is Node3D:
			errors.append("humanoid rig role %s pivot %s must exist exactly once as Node3D" % [role, definition.pivot_paths[mapping_index]])
	return errors

func validate_skin(definition: RigDefinition, skin: Skin) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("humanoid rig definition is missing")
		return errors
	if skin == null:
		errors.append("humanoid rig Skin is missing")
		return errors
	var seen_names: Dictionary = {}
	for bind_index: int in skin.get_bind_count():
		var bind_name: StringName = skin.get_bind_name(bind_index)
		if bind_name.is_empty():
			errors.append("humanoid rig Skin bind %d must be named; numeric-only and unnamed binds are invalid" % bind_index)
			continue
		if seen_names.has(bind_name):
			errors.append("humanoid rig Skin has duplicate bind name %s" % bind_name)
		else:
			seen_names[bind_name] = true
		if definition.bone_names.count(bind_name) != 1:
			errors.append("humanoid rig Skin bind %s must resolve to exactly one canonical bone" % bind_name)
		_validate_transform(skin.get_bind_pose(bind_index), "humanoid rig Skin bind %s pose" % bind_name, errors)
	for bone_name: StringName in definition.bone_names:
		if not seen_names.has(bone_name):
			errors.append("humanoid rig Skin is missing canonical bone %s" % bone_name)
	return errors

func topology_signature(definition: RigDefinition) -> String:
	return serialize_topology(definition).sha256_text()

func canonical_rest_signature(definition: RigDefinition) -> String:
	return serialize_canonical_rest(definition).sha256_text()

func skin_bind_signature(definition: RigDefinition, skin: Skin) -> String:
	return serialize_skin_binds(definition, skin).sha256_text()

func serialize_topology(definition: RigDefinition) -> String:
	var lines := PackedStringArray(["pf-humanoid-topology-v1"])
	if definition == null:
		return "\n".join(lines)
	lines.append(_field(String(definition.rig_id)))
	for role: StringName in REQUIRED_ROLES:
		var index: int = definition.roles.find(role)
		var bone_name := "" if index < 0 or index >= definition.bone_names.size() else String(definition.bone_names[index])
		var parent_role := "" if index < 0 or index >= definition.parent_roles.size() else String(definition.parent_roles[index])
		var pivot_path := "" if index < 0 or index >= definition.pivot_paths.size() else String(definition.pivot_paths[index])
		lines.append("|".join([_field(String(role)), _field(bone_name), _field(parent_role), _field(pivot_path)]))
	return "\n".join(lines)

func serialize_canonical_rest(definition: RigDefinition) -> String:
	var lines := PackedStringArray(["pf-humanoid-canonical-rest-v1"])
	if definition == null:
		return "\n".join(lines)
	lines.append(_field(String(definition.rig_id)))
	for role: StringName in REQUIRED_ROLES:
		var index: int = definition.roles.find(role)
		var serialized_rest := "missing"
		if index >= 0 and index < definition.canonical_rests.size():
			serialized_rest = _serialize_transform(definition.canonical_rests[index])
		lines.append("|".join([_field(String(role)), _field(serialized_rest)]))
	return "\n".join(lines)

func serialize_skin_binds(definition: RigDefinition, skin: Skin) -> String:
	var lines := PackedStringArray(["pf-humanoid-skin-binds-v1"])
	if definition == null or skin == null:
		return "\n".join(lines)
	lines.append(_field(String(definition.rig_id)))
	for bind_index: int in skin.get_bind_count():
		var bind_name: StringName = skin.get_bind_name(bind_index)
		var canonical_role := &""
		var bone_index: int = definition.bone_names.find(bind_name)
		if bone_index >= 0 and bone_index < definition.roles.size():
			canonical_role = definition.roles[bone_index]
		lines.append("|".join([
			str(bind_index),
			_field(String(bind_name)),
			_field(String(canonical_role)),
			_field(_serialize_transform(skin.get_bind_pose(bind_index))),
		]))
	return "\n".join(lines)

func _validate_mapping_sizes(definition: RigDefinition, errors: PackedStringArray) -> void:
	var expected := REQUIRED_ROLES.size()
	var sizes := {
		"roles": definition.roles.size(),
		"bone names": definition.bone_names.size(),
		"parent roles": definition.parent_roles.size(),
		"pivot paths": definition.pivot_paths.size(),
		"canonical rests": definition.canonical_rests.size(),
	}
	for label: String in sizes:
		if sizes[label] != expected:
			errors.append("humanoid rig %s count must be %d, got %d" % [label, expected, sizes[label]])

func _safe_mapping_count(definition: RigDefinition) -> int:
	return mini(definition.roles.size(), mini(definition.bone_names.size(), mini(definition.parent_roles.size(), mini(definition.pivot_paths.size(), definition.canonical_rests.size()))))

func _bone_indices_named(skeleton: Skeleton3D, bone_name: StringName) -> Array[int]:
	var matches: Array[int] = []
	for bone_index: int in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone_index) == bone_name:
			matches.append(bone_index)
	return matches

func _validate_transform(transform: Transform3D, label: String, errors: PackedStringArray) -> void:
	if not _transform_is_finite(transform):
		errors.append("%s must be finite" % label)
		return
	if absf(transform.basis.determinant()) <= MIN_INVERTIBLE_DETERMINANT:
		errors.append("%s must be invertible" % label)

func _transform_is_finite(transform: Transform3D) -> bool:
	return (
		_vector_is_finite(transform.basis.x)
		and _vector_is_finite(transform.basis.y)
		and _vector_is_finite(transform.basis.z)
		and _vector_is_finite(transform.origin)
	)

func _vector_is_finite(vector: Vector3) -> bool:
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)

func _serialize_transform(transform: Transform3D) -> String:
	return ",".join([
		_quantized(transform.basis.x.x), _quantized(transform.basis.x.y), _quantized(transform.basis.x.z),
		_quantized(transform.basis.y.x), _quantized(transform.basis.y.y), _quantized(transform.basis.y.z),
		_quantized(transform.basis.z.x), _quantized(transform.basis.z.y), _quantized(transform.basis.z.z),
		_quantized(transform.origin.x), _quantized(transform.origin.y), _quantized(transform.origin.z),
	])

func _quantized(value: float) -> String:
	var quantized := snappedf(value, QUANTIZATION)
	if absf(quantized) < QUANTIZATION * 0.5:
		quantized = 0.0
	return "%.6f" % quantized

func _field(value: String) -> String:
	return "%d:%s" % [value.length(), value]
