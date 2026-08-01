class_name ProfileStore
extends RefCounted

const DEFAULT_ROOT := "user://profiles"

var _documents: AtomicJsonStore

func _init(documents: AtomicJsonStore = null) -> void:
	_documents = documents if documents != null else AtomicJsonStore.new()

func profile_path(profile_id: String, root: String = DEFAULT_ROOT) -> String:
	return root.path_join("%s.json" % profile_id)

func save_profile(profile: ProfileState, root: String = DEFAULT_ROOT) -> String:
	var validation := ProfileCodec.validate_profile(profile)
	if not validation.is_empty():
		return validation
	return _documents.save_document(profile_path(profile.profile_id, root), profile.to_dictionary(), _validate_document)

func load_profile(profile_id: String, root: String = DEFAULT_ROOT) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var loaded := _documents.load_document(profile_path(profile_id, root), _validate_document)
	result.missing = loaded.missing
	result.recovered_from_backup = loaded.recovered_from_backup
	result.error = loaded.error
	if loaded.ok():
		var decoded := ProfileCodec.decode(JSON.stringify(loaded.document))
		result.profile = decoded.profile
		result.error = decoded.error
	return result

func profile_ids(root: String = DEFAULT_ROOT) -> PackedStringArray:
	var result := PackedStringArray()
	var directory := DirAccess.open(root)
	if directory == null:
		var open_error := DirAccess.get_open_error()
		if open_error not in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST]:
			push_error("PROFILE_STORE_LIST_ERROR root=%s code=%d" % [root, open_error])
		return result
	for name: String in directory.get_files():
		var profile_id := ""
		if name.ends_with(".json") and name != "profile_index.json":
			profile_id = name.trim_suffix(".json")
		elif name.ends_with(".json.bak") and name != "profile_index.json.bak":
			profile_id = name.trim_suffix(".json.bak")
		if not profile_id.is_empty() and profile_id not in result:
			result.append(profile_id)
	result.sort()
	return result

func _validate_document(document: Dictionary) -> String:
	var decoded := ProfileCodec.decode(JSON.stringify(document))
	if not decoded.error.is_empty():
		return decoded.error
	return ProfileCodec.validate_profile(decoded.profile)
