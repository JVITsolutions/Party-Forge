class_name AtomicJsonStore
extends RefCounted

var _promote_file: Callable

func _init(promote_file: Callable = Callable()) -> void:
	_promote_file = promote_file

func save_document(path: String, document: Dictionary, validator: Callable) -> String:
	if not validator.is_valid():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=validator is missing" % path
	var validation := str(validator.call(document))
	if not validation.is_empty():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=%s" % [path, validation]
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_parent := absolute_target.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_parent)
	if mkdir_error not in [OK, ERR_ALREADY_EXISTS]:
		return "JSON_STORE_SAVE_ERROR path=%s stage=mkdir code=%d" % [path, mkdir_error]
	var temporary := "%s.tmp" % path
	var backup := "%s.bak" % path
	var displaced_backup := "%s.previous" % backup
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "JSON_STORE_SAVE_ERROR path=%s stage=write code=%d" % [path, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(document, "\t", false))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_remove(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=write code=%d" % [path, write_error]
	var temporary_result := _load_one(temporary, validator)
	if not temporary_result.ok():
		_remove(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-temporary reason=%s" % [path, temporary_result.error]
	var had_previous := FileAccess.file_exists(path)
	var previous_was_valid := false
	var displaced_old_backup := false
	if had_previous:
		var previous := _load_one(path, validator)
		previous_was_valid = previous.ok()
		if previous_was_valid:
			if FileAccess.file_exists(displaced_backup):
				var remove_displaced_error := _remove(displaced_backup)
				if remove_displaced_error != OK:
					_remove(temporary)
					return "JSON_STORE_SAVE_ERROR path=%s stage=remove-stale-backup code=%d" % [path, remove_displaced_error]
			if FileAccess.file_exists(backup):
				var displace_error := _rename(backup, displaced_backup)
				if displace_error != OK:
					_remove(temporary)
					return "JSON_STORE_SAVE_ERROR path=%s stage=stage-old-backup code=%d" % [path, displace_error]
				displaced_old_backup = true
			var backup_error := _rename(path, backup)
			if backup_error != OK:
				var restore_displaced_error := _restore_displaced_backup(backup, displaced_backup, displaced_old_backup)
				_remove(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=backup code=%d restore_code=%d" % [path, backup_error, restore_displaced_error]
		else:
			var verified_backup := _load_one(backup, validator)
			if not verified_backup.ok():
				_remove(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=validate-existing primary=%s backup=%s" % [path, previous.error, verified_backup.error]
			var preserved_corrupt := _corrupt_artifact_path(path)
			var preserve_error := _rename(path, preserved_corrupt)
			if preserve_error != OK:
				_remove(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=preserve-corrupt code=%d" % [path, preserve_error]
			push_warning("JSON_STORE_CORRUPT_PRIMARY_PRESERVED path=%s artifact=%s" % [path, preserved_corrupt])
	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		var restore_after_promote := _restore_previous(path, backup, displaced_backup, had_previous, previous_was_valid, displaced_old_backup)
		_remove(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=promote code=%d restore_code=%d" % [path, promote_error, restore_after_promote]
	var promoted := _load_one(path, validator)
	if not promoted.ok():
		_remove(path)
		var restore_after_verify := _restore_previous(path, backup, displaced_backup, had_previous, previous_was_valid, displaced_old_backup)
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-promoted restore_code=%d reason=%s" % [path, restore_after_verify, promoted.error]
	if displaced_old_backup:
		var cleanup_error := _remove(displaced_backup)
		if cleanup_error != OK:
			return "JSON_STORE_SAVE_ERROR path=%s stage=remove-staged-backup code=%d" % [path, cleanup_error]
	return ""

func load_document(path: String, validator: Callable, recover_backup: bool = true) -> JsonDocumentResult:
	if not validator.is_valid():
		var invalid := JsonDocumentResult.new()
		invalid.error = "JSON_STORE_LOAD_ERROR path=%s reason=validator is missing" % path
		return invalid
	var primary := _load_one(path, validator)
	if primary.ok():
		return primary
	if not recover_backup:
		return primary
	var backup_path := "%s.bak" % path
	var backup := _load_one(backup_path, validator)
	if backup.ok():
		backup.recovered_from_backup = true
		return backup
	if primary.missing and backup.missing:
		return primary
	var failed := JsonDocumentResult.new()
	failed.error = "JSON_STORE_LOAD_ERROR path=%s primary=%s backup=%s" % [path, primary.error, backup.error]
	return failed

func _load_one(path: String, validator: Callable) -> JsonDocumentResult:
	var result := JsonDocumentResult.new()
	if not FileAccess.file_exists(path):
		result.missing = true
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = "open code=%d" % FileAccess.get_open_error()
		return result
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		result.error = "parse line=%d reason=%s" % [parser.get_error_line(), parser.get_error_message()]
		return result
	var document := (parser.data as Dictionary).duplicate(true)
	var validation := str(validator.call(document))
	if not validation.is_empty():
		result.error = "validate reason=%s" % validation
		return result
	result.document = document
	return result

func _restore_previous(path: String, backup: String, displaced_backup: String, had_previous: bool, previous_was_valid: bool, displaced_old_backup: bool) -> Error:
	if not had_previous:
		return OK
	if previous_was_valid:
		if FileAccess.file_exists(path):
			var remove_target_error := _remove(path)
			if remove_target_error != OK:
				return remove_target_error
		var restore_primary_error := _rename(backup, path)
		if restore_primary_error != OK:
			return restore_primary_error
		return _restore_displaced_backup(backup, displaced_backup, displaced_old_backup)
	var bytes := FileAccess.get_file_as_bytes(backup)
	if FileAccess.get_open_error() != OK:
		return FileAccess.get_open_error()
	var restored := FileAccess.open(path, FileAccess.WRITE)
	if restored == null:
		return FileAccess.get_open_error()
	restored.store_buffer(bytes)
	var restore_error := restored.get_error()
	restored.close()
	return restore_error

func _restore_displaced_backup(backup: String, displaced_backup: String, displaced_old_backup: bool) -> Error:
	if not displaced_old_backup:
		return OK
	return _rename(displaced_backup, backup)

func _corrupt_artifact_path(path: String) -> String:
	var base := "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
	var candidate := base
	var suffix := 1
	while FileAccess.file_exists(candidate):
		candidate = "%s-%d" % [base, suffix]
		suffix += 1
	return candidate

func _promote(temporary: String, target: String) -> Error:
	return _rename(temporary, target)

func _rename(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func _remove(path: String) -> Error:
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
