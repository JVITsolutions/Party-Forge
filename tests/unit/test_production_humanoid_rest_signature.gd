extends RefCounted

const CONTRACT_PATH := "res://scripts/presentation/humanoid_rig_contract.gd"
const FIXTURE_PATH := "res://tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json"
const EXPECTED := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}

var _contract: RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var contract_script := load(CONTRACT_PATH) as Script
	TestAssertions.truthy(contract_script != null, "production rest contract loads", failures)
	if contract_script == null:
		return failures
	_contract = contract_script.new() as RefCounted
	TestAssertions.truthy(_contract.has_method(&"serialize_production_rest"), "production rest serializer exists", failures)
	TestAssertions.truthy(_contract.has_method(&"production_rest_signature"), "production rest signature exists", failures)
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
	TestAssertions.truthy(EXPECTED[&"masculine"] != EXPECTED[&"feminine"], "body presets retain distinct native rest identities", failures)
	return failures

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
