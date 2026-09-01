class_name HumanoidRigMappingCatalog
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
const MappingResolution := preload("res://scripts/presentation/humanoid_rig_mapping_resolution.gd")
const MappingLoader := preload("res://scripts/presentation/humanoid_rig_mapping_loader.gd")
const RigContract := preload("res://scripts/presentation/humanoid_rig_contract.gd")
const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const MAPPING_ID_BY_BODY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA256_BY_BODY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const REST_SIGNATURE_BY_BODY_PRESET := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}
const RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}

func resolve(body_preset_id: StringName, loader: MappingLoader = null) -> RefCounted:
	if body_preset_id not in BODY_PRESETS:
		return _single_failure(body_preset_id, "", &"unknown_body_preset", "humanoid rig mapping catalog body preset %s is unknown" % body_preset_id)
	var resource_path: String = RESOURCE_PATH_BY_BODY_PRESET[body_preset_id]
	var effective_loader := loader if loader != null else MappingLoader.new()
	if not effective_loader.exists_exact(resource_path):
		return _single_failure(body_preset_id, resource_path, &"missing_resource", "humanoid rig mapping catalog body preset %s resource %s does not exist" % [body_preset_id, resource_path])
	var value: Variant = effective_loader.load_exact(resource_path)
	if value == null:
		return _single_failure(body_preset_id, resource_path, &"resource_load_failed", "humanoid rig mapping catalog body preset %s resource %s could not be loaded" % [body_preset_id, resource_path])
	if not value is RigMapping:
		return _single_failure(body_preset_id, resource_path, &"wrong_resource_type", "humanoid rig mapping catalog body preset %s resource %s must be HumanoidRigMapping, got %s" % [body_preset_id, resource_path, _variant_type_name(value)])
	var mapping := value as RigMapping
	var categories: Array[StringName] = []
	var messages := PackedStringArray()
	_append_identity_errors(body_preset_id, mapping, categories, messages)
	if not categories.is_empty():
		return MappingResolution.failed(body_preset_id, resource_path, categories, messages)
	return MappingResolution.succeeded(body_preset_id, resource_path, mapping)

static func _single_failure(body_preset_id: StringName, resource_path: String, category: StringName, message: String) -> RefCounted:
	var categories: Array[StringName] = [category]
	return MappingResolution.failed(body_preset_id, resource_path, categories, PackedStringArray([message]))

static func _variant_type_name(value: Variant) -> String:
	return value.get_class() if value is Object else type_string(typeof(value))

static func _append_identity_errors(body_preset_id: StringName, mapping: RigMapping, categories: Array[StringName], messages: PackedStringArray) -> void:
	var expected_mapping_id: StringName = MAPPING_ID_BY_BODY_PRESET[body_preset_id]
	if mapping.mapping_id != expected_mapping_id:
		categories.append(&"wrong_mapping_id")
		messages.append("humanoid rig mapping catalog body preset %s mapping id must be %s, got %s" % [body_preset_id, expected_mapping_id, mapping.mapping_id])
	if mapping.canonical_rig_id != RigContract.CANONICAL_RIG_ID:
		categories.append(&"wrong_canonical_rig_id")
		messages.append("humanoid rig mapping catalog body preset %s canonical rig id must be %s, got %s" % [body_preset_id, RigContract.CANONICAL_RIG_ID, mapping.canonical_rig_id])
	var expected_source_hash: String = SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]
	if mapping.source_skeleton_sha256 != expected_source_hash:
		categories.append(&"wrong_source_hash")
		messages.append("humanoid rig mapping catalog body preset %s source skeleton hash must be %s, got %s" % [body_preset_id, expected_source_hash, mapping.source_skeleton_sha256])
	var expected_rest_signature: String = REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]
	if mapping.source_rest_signature != expected_rest_signature:
		categories.append(&"wrong_rest_signature")
		messages.append("humanoid rig mapping catalog body preset %s source rest signature must be %s, got %s" % [body_preset_id, expected_rest_signature, mapping.source_rest_signature])
