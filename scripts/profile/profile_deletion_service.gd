class_name ProfileDeletionService
extends RefCounted

var _remove_file: Callable

func _init(remove_file: Callable = Callable()) -> void:
	_remove_file = remove_file if remove_file.is_valid() else func(path: String) -> Error:
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func delete_profile_artifacts(
	profile_id: String,
	discovered_profile_ids: PackedStringArray,
	root: String = ProfileStore.DEFAULT_ROOT,
) -> ProfileDeletionResult:
	var result := ProfileDeletionResult.new()
	var identity_error := _validate_identity(profile_id, discovered_profile_ids)
	if not identity_error.is_empty():
		result.error = identity_error
		return result
	var targets := _artifact_paths(profile_id, root)
	if targets.is_empty():
		result.error = "PROFILE_DELETE_ERROR profile=%s reason=confined artifact targets unavailable" % profile_id
		return result
	for path: String in targets:
		if not _is_confined_artifact_path(profile_id, root, path):
			result.error = "PROFILE_DELETE_ERROR profile=%s reason=confined artifact targets unavailable" % profile_id
			return result
	var snapshots: Dictionary = {}
	for path: String in targets:
		if not FileAccess.file_exists(path):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var read_error := FileAccess.get_open_error()
		if read_error != OK:
			result.error = "PROFILE_DELETE_ERROR profile=%s stage=snapshot path=%s code=%d" % [profile_id, path, read_error]
			return result
		snapshots[path] = bytes
	for path: String in targets:
		if not FileAccess.file_exists(path):
			continue
		if not _is_confined_artifact_path(profile_id, root, path):
			return _rollback_result(result, profile_id, "remove", path, "reason=target lost confinement", snapshots)
		var remove_error: Error = _remove_file.call(path) as Error
		if remove_error != OK and FileAccess.file_exists(path):
			return _rollback_result(result, profile_id, "remove", path, "code=%d" % remove_error, snapshots)
	for path: String in targets:
		if FileAccess.file_exists(path):
			return _rollback_result(result, profile_id, "verify", path, "reason=target remains after remove", snapshots)
	result.committed = true
	result.deleted_profile_id = profile_id
	return result

func _validate_identity(profile_id: String, discovered: PackedStringArray) -> String:
	if profile_id not in discovered:
		return "PROFILE_DELETE_ERROR profile=%s reason=undiscovered profile" % profile_id
	if ProfileCodec.validate_profile_id(profile_id).is_empty():
		return ""
	if profile_id.is_empty() or not profile_id.is_valid_filename() or profile_id in [".", ".."]:
		return "PROFILE_DELETE_ERROR profile=%s reason=unsafe discovered profile id" % profile_id
	if "/" in profile_id or "\\" in profile_id or ":" in profile_id:
		return "PROFILE_DELETE_ERROR profile=%s reason=unsafe discovered profile id" % profile_id
	return ""

func _artifact_paths(profile_id: String, root: String) -> Array[String]:
	if root.strip_edges().is_empty():
		return []
	var primary := ProfileStore.new().profile_path(profile_id, root)
	var root_absolute := ProjectSettings.globalize_path(root).simplify_path()
	var primary_absolute := ProjectSettings.globalize_path(primary).simplify_path()
	if root_absolute.is_empty() or primary_absolute.get_base_dir() != root_absolute:
		return []
	var result: Array[String] = [
		primary,
		"%s.bak" % primary,
		"%s.tmp" % primary,
		"%s.bak.previous" % primary,
		"%s.irreversible-primary.tmp" % primary,
		"%s.irreversible-backup.tmp" % primary,
	]
	for path: String in result:
		if not _is_confined_artifact_path(profile_id, root, path):
			return []
	if not DirAccess.dir_exists_absolute(root_absolute):
		if FileAccess.file_exists(root_absolute):
			return []
		result.sort()
		return result
	var directory := DirAccess.open(root_absolute)
	if directory == null:
		return []
	var list_error := directory.list_dir_begin()
	if list_error != OK:
		return []
	var basename := primary.get_file()
	var candidate_name := directory.get_next()
	while not candidate_name.is_empty():
		if directory.current_is_dir():
			candidate_name = directory.get_next()
			continue
		if not _is_dynamic_artifact_name(candidate_name, basename):
			candidate_name = directory.get_next()
			continue
		var candidate := root.path_join(candidate_name)
		if not _is_confined_artifact_path(profile_id, root, candidate):
			directory.list_dir_end()
			return []
		result.append(candidate)
		candidate_name = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result

func _is_confined_artifact_path(profile_id: String, root: String, candidate: String) -> bool:
	if root.strip_edges().is_empty() or candidate.is_empty():
		return false
	var primary := ProfileStore.new().profile_path(profile_id, root)
	var root_absolute := ProjectSettings.globalize_path(root).simplify_path()
	var candidate_absolute := ProjectSettings.globalize_path(candidate).simplify_path()
	if root_absolute.is_empty() or candidate_absolute.get_base_dir() != root_absolute:
		return false
	var basename := primary.get_file()
	var candidate_name := candidate_absolute.get_file()
	var fixed_names: Array[String] = [
		basename,
		"%s.bak" % basename,
		"%s.tmp" % basename,
		"%s.bak.previous" % basename,
		"%s.irreversible-primary.tmp" % basename,
		"%s.irreversible-backup.tmp" % basename,
	]
	return candidate_name in fixed_names or _is_dynamic_artifact_name(candidate_name, basename)

func _is_dynamic_artifact_name(candidate_name: String, basename: String) -> bool:
	for prefix: String in ["%s.corrupt-" % basename, "%s.bak.corrupt-" % basename]:
		if candidate_name.begins_with(prefix) and _digits_only(candidate_name.trim_prefix(prefix)):
			return true
	return false

func _digits_only(value: String) -> bool:
	if value.is_empty():
		return false
	for index: int in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint < 48 or codepoint > 57:
			return false
	return true

func _rollback_result(
	result: ProfileDeletionResult,
	profile_id: String,
	trigger_stage: String,
	trigger_path: String,
	trigger_detail: String,
	snapshots: Dictionary,
) -> ProfileDeletionResult:
	var restore_diagnostic := _restore_snapshots(snapshots)
	if restore_diagnostic.is_empty():
		result.error = "PROFILE_DELETE_ERROR profile=%s stage=%s path=%s %s restore_code=0" % [profile_id, trigger_stage, trigger_path, trigger_detail]
		return result
	result.cleanup_debt = true
	result.error = "PROFILE_DELETE_INDETERMINATE profile=%s committed=false cleanup_debt=true stage=rollback trigger_stage=%s trigger_path=%s %s restore=%s" % [profile_id, trigger_stage, trigger_path, trigger_detail, restore_diagnostic]
	return result

func _restore_snapshots(snapshots: Dictionary) -> String:
	var paths: Array[String] = []
	for snapshot_path: String in snapshots:
		paths.append(snapshot_path)
	paths.sort()
	var diagnostics: Array[String] = []
	for path: String in paths:
		var expected := snapshots[path] as PackedByteArray
		if _snapshot_matches(path, expected):
			continue
		var write_error := _write_snapshot(path, expected)
		if write_error != OK:
			diagnostics.append("path=%s write_code=%d" % [path, write_error])
	for path: String in paths:
		var expected := snapshots[path] as PackedByteArray
		if not FileAccess.file_exists(path):
			diagnostics.append("path=%s verify=missing" % path)
			continue
		var restored := FileAccess.get_file_as_bytes(path)
		var read_error := FileAccess.get_open_error()
		if read_error != OK:
			diagnostics.append("path=%s verify_read_code=%d" % [path, read_error])
		elif restored != expected:
			diagnostics.append("path=%s verify=byte-mismatch expected_size=%d actual_size=%d" % [path, expected.size(), restored.size()])
	return "; ".join(diagnostics)

func _snapshot_matches(path: String, expected: PackedByteArray) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var existing := FileAccess.get_file_as_bytes(path)
	return FileAccess.get_open_error() == OK and existing == expected

func _write_snapshot(path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var write_error := file.get_error()
	file.close()
	return write_error
