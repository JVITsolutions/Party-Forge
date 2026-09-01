extends RefCounted

const CONTRACT_PATH := "res://scripts/presentation/humanoid_rig_contract.gd"
const FIXTURE_PATH := "res://tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json"
const DEFINITION_PATH := "res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const EXPECTED := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}
const MAPPING_ID_BY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA_BY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const ROLE_TO_BONE := {
	&"hips": &"mixamorig_Hips",
	&"spine": &"mixamorig_Spine",
	&"chest": &"mixamorig_Spine2",
	&"neck": &"mixamorig_Neck",
	&"head": &"mixamorig_Head",
	&"upper_arm_left": &"mixamorig_LeftArm",
	&"lower_arm_left": &"mixamorig_LeftForeArm",
	&"hand_left": &"mixamorig_LeftHand",
	&"upper_arm_right": &"mixamorig_RightArm",
	&"lower_arm_right": &"mixamorig_RightForeArm",
	&"hand_right": &"mixamorig_RightHand",
	&"upper_leg_left": &"mixamorig_LeftUpLeg",
	&"lower_leg_left": &"mixamorig_LeftLeg",
	&"foot_left": &"mixamorig_LeftFoot",
	&"toe_left": &"mixamorig_LeftToeBase",
	&"upper_leg_right": &"mixamorig_RightUpLeg",
	&"lower_leg_right": &"mixamorig_RightLeg",
	&"foot_right": &"mixamorig_RightFoot",
	&"toe_right": &"mixamorig_RightToeBase",
}

var _contract: RefCounted
var _mapping_script: Script
var _definition: Resource

func run() -> Array[String]:
	var failures: Array[String] = []
	var contract_script := load(CONTRACT_PATH) as Script
	TestAssertions.truthy(contract_script != null, "production rest contract loads", failures)
	if contract_script == null:
		return failures
	_contract = contract_script.new() as RefCounted
	TestAssertions.truthy(_contract.has_method(&"serialize_production_rest"), "production rest serializer exists", failures)
	TestAssertions.truthy(_contract.has_method(&"production_rest_signature"), "production rest signature exists", failures)
	var mapping_exists := FileAccess.file_exists(MAPPING_PATH)
	var definition_exists := ResourceLoader.exists(DEFINITION_PATH)
	TestAssertions.truthy(mapping_exists, "production mapping script exists for public qualification", failures)
	TestAssertions.truthy(definition_exists, "canonical definition exists for public qualification", failures)
	if not mapping_exists or not definition_exists:
		return failures
	_mapping_script = load(MAPPING_PATH) as Script
	_definition = load(DEFINITION_PATH) as Resource
	TestAssertions.truthy(_mapping_script != null, "production mapping script loads for public qualification", failures)
	TestAssertions.truthy(_definition != null, "canonical definition loads for public qualification", failures)
	if _mapping_script == null or _definition == null:
		return failures
	var fixture := _fixture()
	TestAssertions.equal(int(fixture.get("schema_version", 0)), 1, "rest fixture schema is exact", failures)
	var candidates: Array = fixture.get("candidates", [])
	TestAssertions.equal(candidates.size(), 2, "rest fixture contains both body presets", failures)
	for candidate_value: Variant in candidates:
		var candidate := candidate_value as Dictionary
		var body_preset_id := StringName(candidate.get("body_preset_id", ""))
		var skeleton := _skeleton_for(candidate)
		TestAssertions.equal(skeleton.get_bone_count(), 52, "%s fixture reconstructs 52 bones" % body_preset_id, failures)
		skeleton.free()
	if not _contract.has_method(&"serialize_production_rest") or not _contract.has_method(&"production_rest_signature"):
		return failures
	for candidate_value: Variant in candidates:
		var candidate := candidate_value as Dictionary
		var body_preset_id := StringName(candidate.get("body_preset_id", ""))
		var skeleton := _skeleton_for(candidate)
		var expected_serialization := _expected_serialization(candidate)
		var actual_serialization := String(_contract.call(&"serialize_production_rest", skeleton))
		TestAssertions.equal(skeleton.get_bone_count(), 52, "%s fixture has 52 bones" % body_preset_id, failures)
		TestAssertions.equal(actual_serialization, expected_serialization, "%s rest serialization matches inspected bytes" % body_preset_id, failures)
		TestAssertions.truthy(not actual_serialization.begins_with("production"), "%s serialization has no header" % body_preset_id, failures)
		TestAssertions.truthy(not actual_serialization.ends_with("\n"), "%s serialization has no trailing newline" % body_preset_id, failures)
		TestAssertions.equal(
			_contract.call(&"production_rest_signature", skeleton),
			EXPECTED[body_preset_id],
			"%s rest signature matches approved inspection" % body_preset_id,
			failures
		)
		skeleton.free()
		_assert_public_candidate_validation(candidate, failures)
	TestAssertions.truthy(EXPECTED[&"masculine"] != EXPECTED[&"feminine"], "body presets retain distinct native rest identities", failures)
	return failures

func _assert_public_candidate_validation(candidate: Dictionary, failures: Array[String]) -> void:
	var preset := StringName(candidate.get("body_preset_id", ""))
	var skeleton := _skeleton_for(candidate)
	var skin := Skin.new()
	for bone_index: int in skeleton.get_bone_count():
		skin.add_bind(bone_index, skeleton.get_bone_global_rest(bone_index).affine_inverse())
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", MAPPING_ID_BY_PRESET[preset])
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"role_to_bone", ROLE_TO_BONE.duplicate(true))
	mapping.set(&"source_skeleton_sha256", SOURCE_SHA_BY_PRESET[preset])
	mapping.set(&"source_rest_signature", EXPECTED[preset])
	TestAssertions.equal(skeleton.get_bone_count(), 52, "%s public fixture retains 52 bones" % preset, failures)
	TestAssertions.equal(skin.get_bind_count(), 52, "%s public fixture creates 52 binds" % preset, failures)
	for bind_index: int in skin.get_bind_count():
		TestAssertions.equal(skin.get_bind_bone(bind_index), bind_index, "%s bind %d keeps exact numeric index" % [preset, bind_index], failures)
		TestAssertions.equal(skin.get_bind_name(bind_index), &"", "%s bind %d remains unnamed" % [preset, bind_index], failures)
	TestAssertions.equal(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), PackedStringArray(), "%s inspected candidate passes mapped validation" % preset, failures)
	var pivots := Node3D.new()
	TestAssertions.truthy(_contains(_contract.call(&"validate_rig", _definition, skeleton, pivots), "bone count must be 19, got 52"), "%s strict legacy rig validator still rejects superset" % preset, failures)
	TestAssertions.truthy(_contains(_contract.call(&"validate_skin", _definition, skin), "must be named; numeric-only and unnamed binds are invalid"), "%s strict legacy skin validator still rejects unnamed binds" % preset, failures)
	var incomplete_skin := Skin.new()
	for bone_index: int in 51:
		incomplete_skin.add_bind(bone_index, skeleton.get_bone_global_rest(bone_index).affine_inverse())
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, incomplete_skin), "mapped humanoid Skin is missing skeleton bone mixamorig_RightHandThumb3 at index 51"),
		"%s incomplete 51-bind fixture rejects the exact final bone" % preset,
		failures
	)
	pivots.free()
	skeleton.free()

func _fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _skeleton_for(candidate: Dictionary) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var bones: Array = candidate.get("bones", [])
	for bone_value: Variant in bones:
		var bone := bone_value as Dictionary
		skeleton.add_bone(StringName(bone.get("name", "")))
	for bone_value: Variant in bones:
		var bone := bone_value as Dictionary
		var index := int(bone.get("index", -1))
		skeleton.set_bone_parent(index, int(bone.get("parent_index", -1)))
		skeleton.set_bone_rest(index, _transform_from_signature(String(bone.get("local_rest_signature", ""))))
	return skeleton

func _transform_from_signature(signature: String) -> Transform3D:
	var fields := signature.split(",")
	assert(fields.size() == 12)
	var values := PackedFloat64Array()
	for field: String in fields:
		values.append(field.to_float())
	return Transform3D(
		Basis(
			Vector3(values[0], values[1], values[2]),
			Vector3(values[3], values[4], values[5]),
			Vector3(values[6], values[7], values[8])
		),
		Vector3(values[9], values[10], values[11])
	)

func _expected_serialization(candidate: Dictionary) -> String:
	var lines := PackedStringArray()
	for bone_value: Variant in candidate.get("bones", []):
		var bone := bone_value as Dictionary
		lines.append("%d|%s|%d|%s" % [
			int(bone.get("index", -1)),
			String(bone.get("name", "")),
			int(bone.get("parent_index", -1)),
			String(bone.get("local_rest_signature", "")),
		])
	return "\n".join(lines)

func _contains(errors: Variant, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false
