class_name HumanoidRigMapping
extends Resource

@export var mapping_id: StringName
@export var canonical_rig_id: StringName = &"pf_humanoid_v1"
@export var role_to_bone: Dictionary = {}
@export var source_skeleton_sha256: String
@export var source_rest_signature: String

func validate(definition: HumanoidRigDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if mapping_id.is_empty():
		errors.append("humanoid rig mapping id is empty")
	if canonical_rig_id != HumanoidRigContract.CANONICAL_RIG_ID:
		errors.append("humanoid rig mapping canonical id is invalid")
	if definition == null:
		errors.append("humanoid rig mapping definition is missing")
		return errors
	var seen_bones: Dictionary = {}
	for role: StringName in HumanoidRigContract.REQUIRED_ROLES:
		if not role_to_bone.has(role):
			errors.append("humanoid rig mapping is missing role %s" % role)
			continue
		var bone_name := StringName(role_to_bone[role])
		if bone_name.is_empty() or seen_bones.has(bone_name):
			errors.append("humanoid rig mapping role %s has empty or duplicate bone %s" % [role, bone_name])
		seen_bones[bone_name] = true
	if not _is_sha256(source_skeleton_sha256):
		errors.append("humanoid rig mapping source skeleton hash is invalid")
	if source_rest_signature.is_empty():
		errors.append("humanoid rig mapping source rest signature is empty")
	return errors

func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
