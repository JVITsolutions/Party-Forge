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
	return _documents.save_document(profile_path(profile.profile_id, root), profile.to_dictionary(), _validate_current_document)

func save_profile_irreversible(profile: ProfileState, root: String = DEFAULT_ROOT) -> String:
	var validation := ProfileCodec.validate_profile(profile)
	if not validation.is_empty():
		return validation
	return _documents.save_irreversible_document(profile_path(profile.profile_id, root), profile.to_dictionary(), _validate_current_document)

func load_profile(profile_id: String, root: String = DEFAULT_ROOT) -> ProfileLoadResult:
	var result := ProfileLoadResult.new()
	var profile_id_error := ProfileCodec.validate_profile_id(profile_id)
	if not profile_id_error.is_empty():
		result.error = profile_id_error
		return result
	var path := profile_path(profile_id, root)
	var loaded := _documents.load_document(path, _validate_loadable_document)
	result.missing = loaded.missing
	result.recovered_from_backup = loaded.recovered_from_backup
	result.recovery_detail = loaded.recovery_detail
	result.error = loaded.error
	if not loaded.ok():
		return result
	var loaded_profile_id := String(loaded.document["profile_id"])
	if loaded_profile_id != profile_id:
		result.error = "PROFILE_LOAD_ERROR field=profile_id requested=%s loaded=%s reason=profile id mismatch" % [profile_id, loaded_profile_id]
		return result
	var decoded := ProfileCodec.decode_document(loaded.document)
	result.error = decoded.error
	result.source_schema_version = decoded.source_schema_version
	if not decoded.ok():
		return result
	if not decoded.migrated:
		result.profile = decoded.profile
		return result
	var candidate := decoded.profile.to_dictionary()
	var validation := ProfileCodec.validate_current_document(candidate)
	if not validation.is_empty():
		result.error = "PARTY_FORGE_PROFILE_MIGRATION_ERROR field=document reason=current candidate invalid: %s" % validation
		return result
	var promotion_error := _documents.save_document(path, candidate, _validate_current_document, _validate_loadable_document)
	if not promotion_error.is_empty():
		result.error = promotion_error
		return result
	result.profile = decoded.profile
	result.migrated = true
	result.source_schema_version = decoded.source_schema_version
	return result

func profile_ids(root: String = DEFAULT_ROOT) -> PackedStringArray:
	var result := PackedStringArray()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		return result
	var directory := DirAccess.open(root)
	if directory == null:
		push_error("PROFILE_STORE_LIST_ERROR root=%s code=%d" % [root, DirAccess.get_open_error()])
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

func _validate_current_document(document: Dictionary) -> String:
	return ProfileCodec.validate_current_document(document)

func _validate_loadable_document(document: Dictionary) -> String:
	return ProfileCodec.validate_loadable_document(document)
