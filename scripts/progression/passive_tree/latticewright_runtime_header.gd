class_name LatticewrightRuntimeHeader
extends RefCounted

const FORMAT := "latticewright-progression"
const ROOT_KEYS: Array[String] = [
	"archetype",
	"assets",
	"content",
	"extensions",
	"format",
	"formatVersion",
	"graphPortals",
	"graphs",
	"name",
	"projectId",
	"schemas",
	"vocabulary",
]
const SIGNED_64_MIN_AS_FLOAT := -9223372036854775808.0
const SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT := 9223372036854775808.0

var format_version := 0
var project_id: StringName = &""
var error := ""

func ok() -> bool:
	return error.is_empty()

static func validate(document: Dictionary) -> LatticewrightRuntimeHeader:
	var header := LatticewrightRuntimeHeader.new()
	var actual_keys: Array[String] = []
	for key: Variant in document.keys():
		if not key is String:
			header.error = _error("root", "key must be a string")
			return header
		actual_keys.append(key as String)
	actual_keys.sort()
	if actual_keys != ROOT_KEYS:
		for required: String in ROOT_KEYS:
			if not actual_keys.has(required):
				header.error = _error(required, "required root key is missing")
				return header
		for actual: String in actual_keys:
			if not ROOT_KEYS.has(actual):
				header.error = _error(actual, "unexpected root key")
				return header

	if document.get("format") != FORMAT:
		header.error = _error("format", "must equal %s" % FORMAT)
		return header
	var version: Variant = _exact_positive_integer(document.get("formatVersion"))
	if version == null:
		header.error = _error("formatVersion", "must be a positive exact integer version")
		return header
	header.format_version = version as int
	var project_id_value: Variant = document.get("projectId")
	if not project_id_value is String or String(project_id_value).strip_edges().is_empty():
		header.error = _error("projectId", "must be a non-empty string")
		return header
	header.project_id = StringName(project_id_value as String)
	if not document.get("name") is String or String(document.get("name")).strip_edges().is_empty():
		header.error = _error("name", "must be a non-empty string")
		return header
	if not document.get("archetype") is String or String(document.get("archetype")).strip_edges().is_empty():
		header.error = _error("archetype", "must be a non-empty string")
		return header
	for key: String in ["vocabulary", "schemas", "extensions"]:
		if not document.get(key) is Dictionary:
			header.error = _error(key, "must be a JSON object")
			return header
	for key: String in ["content", "graphs", "graphPortals", "assets"]:
		if not document.get(key) is Array:
			header.error = _error(key, "must be a JSON array")
			return header
	return header

static func _exact_positive_integer(value: Variant) -> Variant:
	if value is int:
		return value if (value as int) > 0 else null
	if not value is float:
		return null
	var number := value as float
	if not is_finite(number) or number < SIGNED_64_MIN_AS_FLOAT or number >= SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT:
		return null
	if number != floor(number) or number <= 0.0:
		return null
	return int(number)

static func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_PASSIVE_TREE_HEADER_ERROR field=%s reason=%s" % [field, reason]
