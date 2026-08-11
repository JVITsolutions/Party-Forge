class_name DeveloperLootLabPreferencesStore
extends RefCounted

const SCHEMA_VERSION := 1
const DOCUMENT_PATH := "user://developer_item_sandbox/loot_lab_preferences.json"
const BATCH_PRESETS: Array[int] = [0, 1, 100, 1000, 10000, 100000]
const NAME_ARRAY_FIELDS: Array[String] = [
	"permitted_rarity_ids",
	"party_archetype_tags",
	"unlock_tags",
	"required_base_tags",
	"excluded_base_tags",
	"required_affix_tags",
	"excluded_affix_tags",
]
const DOCUMENT_FIELDS: Array[String] = [
	"schema_version",
	"seed",
	"generation_sequence",
	"item_level",
	"source_id",
	"generation_domain",
	"difficulty_id",
	"heat",
	"charisma_value",
	"permitted_rarity_ids",
	"party_archetype_tags",
	"unlock_tags",
	"required_base_tags",
	"excluded_base_tags",
	"required_affix_tags",
	"excluded_affix_tags",
	"forced_base_id",
	"forced_rarity_id",
	"batch_preset",
	"custom_batch_count",
]

var _documents: AtomicJsonStore
var _document_path: String

func _init(documents: AtomicJsonStore = null, document_path := DOCUMENT_PATH) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()
	_document_path = document_path

func save(document: Dictionary) -> String:
	var json_error := ItemGenerationTrace.json_value_error(document, "document")
	if not json_error.is_empty():
		return _error("document", json_error)
	var canonical := _canonical_document(document)
	if canonical.is_empty():
		return validate(document)
	return _documents.save_document(_document_path, canonical, Callable(self, "validate"))

func load() -> JsonDocumentResult:
	return _documents.load_document(_document_path, Callable(self, "validate"))

func validate(document: Dictionary) -> String:
	var json_error := ItemGenerationTrace.json_value_error(document, "document")
	if not json_error.is_empty():
		return _error("document", json_error)
	var fields_error := ItemRegistry._exact_fields(document, DOCUMENT_FIELDS, "document")
	if not fields_error.is_empty():
		return _error("document", _reason_from_registry_error(fields_error))
	if not ItemInstanceCodec._is_json_int(document["schema_version"], SCHEMA_VERSION, SCHEMA_VERSION):
		return _error("schema_version", "must equal supported schema %d" % SCHEMA_VERSION)
	if not ItemInstanceCodec._is_json_int(document["seed"], -ItemInstanceCodec.JSON_SAFE_INTEGER_MAX, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return _error("seed", "must be a JSON-safe integer")
	if not ItemInstanceCodec._is_json_int(document["generation_sequence"], 0, ItemInstanceCodec.JSON_SAFE_INTEGER_MAX):
		return _error("generation_sequence", "must be a non-negative JSON-safe integer")
	if not ItemInstanceCodec._is_json_int(document["item_level"], ItemGenerationRequest.MIN_ITEM_LEVEL, ItemGenerationRequest.MAX_ITEM_LEVEL):
		return _error("item_level", "must be between %d and %d" % [ItemGenerationRequest.MIN_ITEM_LEVEL, ItemGenerationRequest.MAX_ITEM_LEVEL])
	for field: String in ["source_id", "generation_domain", "difficulty_id", "forced_base_id", "forced_rarity_id"]:
		if typeof(document[field]) != TYPE_STRING:
			return _error(field, "must be a string")
	for field: String in ["source_id", "generation_domain", "difficulty_id"]:
		if String(document[field]).is_empty():
			return _error(field, "must not be empty")
	for field: String in ["heat", "charisma_value"]:
		if typeof(document[field]) not in [TYPE_INT, TYPE_FLOAT]:
			return _error(field, "must be numeric")
		var value := float(document[field])
		if not is_finite(value) or value < 0.0:
			return _error(field, "must be finite and nonnegative")
	for field: String in NAME_ARRAY_FIELDS:
		var names_error := _validate_name_array(document[field], field)
		if not names_error.is_empty():
			return names_error
	if not ItemInstanceCodec._is_json_int(document["batch_preset"], 0, LootLabBatchSpec.MAX_ATTEMPTS):
		return _error("batch_preset", "must be a supported preset")
	if int(document["batch_preset"]) not in BATCH_PRESETS:
		return _error("batch_preset", "must be one of %s" % str(BATCH_PRESETS))
	if not ItemInstanceCodec._is_json_int(document["custom_batch_count"], 1, LootLabBatchSpec.MAX_ATTEMPTS):
		return _error("custom_batch_count", "must be between 1 and %d" % LootLabBatchSpec.MAX_ATTEMPTS)

	var request := _request_from_document(document)
	var request_error := request.validate(GameCatalog.ITEM_FOUNDATION_CATALOG)
	if not request_error.is_empty():
		return request_error
	return ""

func defaults() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed": 0,
		"generation_sequence": 0,
		"item_level": 1,
		"source_id": "developer",
		"generation_domain": "developer",
		"difficulty_id": "normal",
		"heat": 0.0,
		"charisma_value": 0.0,
		"permitted_rarity_ids": ["common"],
		"party_archetype_tags": [],
		"unlock_tags": [],
		"required_base_tags": [],
		"excluded_base_tags": [],
		"required_affix_tags": [],
		"excluded_affix_tags": [],
		"forced_base_id": "",
		"forced_rarity_id": "",
		"batch_preset": 1,
		"custom_batch_count": 1,
	}

func _canonical_document(document: Dictionary) -> Dictionary:
	if not validate(document).is_empty():
		return {}
	var result := document.duplicate(true)
	for field: String in NAME_ARRAY_FIELDS:
		var names: Array[String] = []
		for value: Variant in result[field] as Array:
			names.append(String(value))
		names.sort()
		result[field] = names
	result["heat"] = float(result["heat"])
	result["charisma_value"] = float(result["charisma_value"])
	return result

func _request_from_document(document: Dictionary) -> ItemGenerationRequest:
	var permitted: Array[StringName] = _string_names(document["permitted_rarity_ids"] as Array)
	var request := ItemGenerationRequest.create(
		int(document["seed"]),
		int(document["generation_sequence"]),
		int(document["item_level"]),
		StringName(String(document["source_id"])),
		StringName(String(document["generation_domain"])),
		permitted
	)
	request.difficulty_id = StringName(String(document["difficulty_id"]))
	request.heat = float(document["heat"])
	request.charisma_value = float(document["charisma_value"])
	request.party_archetype_tags = _string_names(document["party_archetype_tags"] as Array)
	request.unlock_tags = _string_names(document["unlock_tags"] as Array)
	request.required_base_tags = _string_names(document["required_base_tags"] as Array)
	request.excluded_base_tags = _string_names(document["excluded_base_tags"] as Array)
	request.required_affix_tags = _string_names(document["required_affix_tags"] as Array)
	request.excluded_affix_tags = _string_names(document["excluded_affix_tags"] as Array)
	request.forced_base_id = StringName(String(document["forced_base_id"]))
	request.forced_rarity_id = StringName(String(document["forced_rarity_id"]))
	return request

func _validate_name_array(value: Variant, field: String) -> String:
	if not value is Array:
		return _error(field, "must be an array")
	var seen: Dictionary = {}
	for entry: Variant in value as Array:
		if typeof(entry) != TYPE_STRING or String(entry).is_empty():
			return _error(field, "values must be non-empty strings")
		if seen.has(String(entry)):
			return _error(field, "duplicate value %s" % String(entry))
		seen[String(entry)] = true
	return ""

func _string_names(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(String(value)))
	return result

func _reason_from_registry_error(error: String) -> String:
	var reason_index := error.find(" reason=")
	return error.substr(reason_index + 8) if reason_index >= 0 else error

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_LOOT_LAB_PREFERENCES_ERROR field=%s reason=%s" % [field, reason]
