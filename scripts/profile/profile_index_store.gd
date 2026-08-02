class_name ProfileIndexStore
extends RefCounted

const FILE_NAME := "profile_index.json"

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
	return _documents.save_document(root.path_join(FILE_NAME), index.to_dictionary(), Callable(self, "_validate_document"))

func load_index(root: String = ProfileStore.DEFAULT_ROOT) -> ProfileIndexLoadResult:
	var result := ProfileIndexLoadResult.new()
	var loaded := _documents.load_document(root.path_join(FILE_NAME), Callable(self, "_validate_document"))
	result.missing = loaded.missing
	if loaded.missing:
		result.index = ProfileIndex.new()
		return result
	if not loaded.ok():
		result.error = loaded.error
		return result
	var index := ProfileIndex.new()
	index.schema_version = int(loaded.document["schema_version"])
	index.active_profile_id = str(loaded.document.get("active_profile_id", ""))
	for entry: Variant in loaded.document.get("entries", []):
		var item := (entry as Dictionary).duplicate(true)
		item["updated_at_unix"] = int(item["updated_at_unix"])
		index.entries.append(item)
	result.index = index
	return result

func _validate_document(document: Dictionary) -> String:
	var schema_value: Variant = document.get("schema_version")
	if not _is_json_int(schema_value) or int(schema_value) != ProfileIndex.SCHEMA_VERSION:
		return "PROFILE_INDEX_ERROR reason=unsupported schema"
	if typeof(document.get("active_profile_id", "")) != TYPE_STRING:
		return "PROFILE_INDEX_ERROR reason=active profile id must be a string"
	if not document.get("entries", []) is Array:
		return "PROFILE_INDEX_ERROR reason=entries must be an array"
	for entry: Variant in document.get("entries", []):
		if not entry is Dictionary:
			return "PROFILE_INDEX_ERROR reason=entry must be a dictionary"
		var item := entry as Dictionary
		if typeof(item.get("profile_id")) != TYPE_STRING or typeof(item.get("display_name")) != TYPE_STRING or not _is_json_int(item.get("updated_at_unix")):
			return "PROFILE_INDEX_ERROR reason=entry fields have invalid types"
	return ""

func _is_json_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= -ProfileCodec.JSON_SAFE_INTEGER_MAX and int(value) <= ProfileCodec.JSON_SAFE_INTEGER_MAX
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= -float(ProfileCodec.JSON_SAFE_INTEGER_MAX) and number <= float(ProfileCodec.JSON_SAFE_INTEGER_MAX)
