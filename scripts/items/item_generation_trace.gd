class_name ItemGenerationTrace
extends RefCounted

var _stages: Array[Dictionary] = []
var stages: Array[Dictionary]:
	get:
		return _stages.duplicate(true)

func record(
	stage: StringName,
	eligible: Array[StringName],
	rejected: Dictionary,
	weights: Dictionary,
	selected: StringName,
	details: Dictionary = {}
) -> void:
	if _contains_nonfinite(rejected) or _contains_nonfinite(weights) or _contains_nonfinite(details):
		return
	var eligible_ids: Array[String] = []
	for id: StringName in eligible:
		eligible_ids.append(String(id))
	eligible_ids.sort()
	var record_data := {
		"stage": String(stage),
		"eligible": eligible_ids,
		"rejected": _canonical_dictionary(rejected),
		"weights": _canonical_dictionary(weights),
		"selected": String(selected),
	}
	if not details.is_empty():
		record_data["details"] = _canonical_dictionary(details)
	_stages.append(record_data)

func _canonical_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	var values_by_key: Dictionary = {}
	for source_key: Variant in source:
		var key := String(source_key)
		keys.append(key)
		values_by_key[key] = _json_copy(source[source_key])
	keys.sort()
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = values_by_key[key]
	return result

func _json_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var result: Array = []
			for entry: Variant in value:
				result.append(_json_copy(entry))
			return result
		TYPE_DICTIONARY:
			return _canonical_dictionary(value)
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
	return String(value)

func _contains_nonfinite(value: Variant) -> bool:
	match typeof(value):
		TYPE_FLOAT:
			return not is_finite(value)
		TYPE_ARRAY:
			for entry: Variant in value:
				if _contains_nonfinite(entry):
					return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if _contains_nonfinite(key) or _contains_nonfinite(value[key]):
					return true
	return false
