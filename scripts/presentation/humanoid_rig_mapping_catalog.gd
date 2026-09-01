class_name HumanoidRigMappingCatalog
extends RefCounted

const RigMapping := preload("res://scripts/presentation/humanoid_rig_mapping.gd")
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

var _mapping_by_body_preset: Dictionary

func _init(mapping_by_body_preset: Dictionary = {}) -> void:
	_mapping_by_body_preset = mapping_by_body_preset.duplicate()

func resolve(body_preset_id: StringName) -> RigMapping:
	var value: Variant = _mapping_by_body_preset.get(body_preset_id)
	if not value is RigMapping:
		return null
	var mapping := value as RigMapping
	if not _identity_errors(body_preset_id, mapping).is_empty():
		return null
	return mapping

func _identity_errors(
		body_preset_id: StringName,
		mapping: RigMapping
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if body_preset_id not in BODY_PRESETS:
		errors.append("humanoid rig mapping catalog body preset %s is invalid" % body_preset_id)
		return errors
	if mapping == null:
		errors.append("humanoid rig mapping catalog body preset %s mapping is missing" % body_preset_id)
		return errors
	if mapping.mapping_id != MAPPING_ID_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s mapping id must be %s"
			% [body_preset_id, MAPPING_ID_BY_BODY_PRESET[body_preset_id]]
		)
	if mapping.canonical_rig_id != HumanoidRigContract.CANONICAL_RIG_ID:
		errors.append(
			"humanoid rig mapping catalog body preset %s canonical rig id must be %s"
			% [body_preset_id, HumanoidRigContract.CANONICAL_RIG_ID]
		)
	if mapping.source_skeleton_sha256 != SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s source skeleton hash must be %s"
			% [body_preset_id, SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]]
		)
	if mapping.source_rest_signature != REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s source rest signature must be %s"
			% [body_preset_id, REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]]
		)
	return errors
