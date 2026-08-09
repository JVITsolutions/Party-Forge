class_name ItemGenerationTrace
extends RefCounted

var _stages: Array[Dictionary] = []
var stages: Array[Dictionary]:
	get:
		return _stages.duplicate(true)

func record(stage: StringName, eligible: Array[StringName], rejected: Dictionary, weights: Dictionary, selected: StringName) -> void:
	var eligible_ids: Array[String] = []
	for id: StringName in eligible:
		eligible_ids.append(String(id))
	eligible_ids.sort()
	_stages.append({
		"stage": String(stage),
		"eligible": eligible_ids,
		"rejected": _canonical_dictionary(rejected),
		"weights": _canonical_dictionary(weights),
		"selected": String(selected),
	})

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
