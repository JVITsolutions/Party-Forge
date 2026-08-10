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
) -> bool:
	if not json_value_error(rejected).is_empty() or not json_value_error(weights, "value", false).is_empty() or not json_value_error(details).is_empty():
		return false
	var eligible_ids: Array[String] = []
	for id: StringName in eligible:
		eligible_ids.append(String(id))
	eligible_ids.sort()
	var record_data := {
		"stage": String(stage),
		"eligible": eligible_ids,
		"rejected": canonical_json_copy(rejected),
		"weights": _trace_weight_copy(weights),
		"selected": String(selected),
	}
	if not details.is_empty():
		record_data["details"] = canonical_json_copy(details)
	_stages.append(record_data)
	return true

static func canonical_json_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value as StringName)
		TYPE_FLOAT:
			var number := float(value)
			if number == floor(number):
				return int(number)
			return number
		TYPE_ARRAY:
			var copied: Array = []
			for entry: Variant in value as Array:
				copied.append(canonical_json_copy(entry))
			return copied
		TYPE_DICTIONARY:
			return _canonical_dictionary(value as Dictionary)
		_:
			return value

static func json_value_error(value: Variant, path: String = "value", enforce_integral_float_safety: bool = true) -> String:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			return ""
		TYPE_INT:
			if int(value) < -ItemInstanceCodec.JSON_SAFE_INTEGER_MAX or int(value) > ItemInstanceCodec.JSON_SAFE_INTEGER_MAX:
				return "%s is outside the JSON-safe integer range" % path
			return ""
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number):
				return "%s must be finite" % path
			if enforce_integral_float_safety and number == floor(number) and absf(number) > float(ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
				return "%s is outside the JSON-safe integer range" % path
			return ""
		TYPE_ARRAY:
			var entries := value as Array
			for index: int in entries.size():
				var entry_error := json_value_error(entries[index], "%s[%d]" % [path, index], enforce_integral_float_safety)
				if not entry_error.is_empty():
					return entry_error
			return ""
		TYPE_DICTIONARY:
			var source := value as Dictionary
			var normalized_keys: Dictionary = {}
			for key: Variant in source:
				if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
					return "%s has a non-string key" % path
				var normalized_key := String(key)
				if normalized_keys.has(normalized_key):
					return "%s has duplicate key %s after canonicalization" % [path, normalized_key]
				normalized_keys[normalized_key] = true
				var entry_error := json_value_error(source[key], "%s.%s" % [path, normalized_key], enforce_integral_float_safety)
				if not entry_error.is_empty():
					return entry_error
			return ""
	return "%s has unsupported type %s" % [path, type_string(typeof(value))]

static func _canonical_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array[String] = []
	var values_by_key: Dictionary = {}
	for source_key: Variant in source:
		var key := String(source_key)
		keys.append(key)
		values_by_key[key] = canonical_json_copy(source[source_key])
	keys.sort()
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = values_by_key[key]
	return result

static func _trace_weight_copy(value: Variant) -> Variant:
	# Selection weights are diagnostic numeric evidence, not persisted provenance.
	# Preserve their authored float representation, including huge finite overflow fixtures.
	match typeof(value):
		TYPE_FLOAT:
			return value
		TYPE_STRING_NAME:
			return String(value as StringName)
		TYPE_ARRAY:
			var copied: Array = []
			for entry: Variant in value as Array:
				copied.append(_trace_weight_copy(entry))
			return copied
		TYPE_DICTIONARY:
			var source := value as Dictionary
			var keys: Array[String] = []
			var values_by_key: Dictionary = {}
			for source_key: Variant in source:
				var key := String(source_key)
				keys.append(key)
				values_by_key[key] = _trace_weight_copy(source[source_key])
			keys.sort()
			var copied: Dictionary = {}
			for key: String in keys:
				copied[key] = values_by_key[key]
			return copied
		_:
			return value
