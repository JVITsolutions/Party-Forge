class_name AtomicJsonStore
extends RefCounted

var _promote_file: Callable

func _init(promote_file: Callable = Callable()) -> void:
	_promote_file = promote_file

func save_document(
	path: String,
	document: Dictionary,
	validator: Callable,
	existing_generation_validator: Callable = Callable()
) -> String:
	if not validator.is_valid():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=validator is missing" % path
	var existing_validator := existing_generation_validator if existing_generation_validator.is_valid() else validator
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
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=write code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, write_error, cleanup_error]
	var temporary_result := _load_one(temporary, validator)
	if not temporary_result.ok():
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-temporary cleanup_stage=remove-temporary cleanup_code=%d reason=%s" % [path, cleanup_error, temporary_result.error]
	var had_previous := FileAccess.file_exists(path)
	var previous_was_valid := false
	var displaced_old_backup := false
	if had_previous:
		var previous := _load_one(path, existing_validator)
		previous_was_valid = previous.ok()
		if previous_was_valid:
			if FileAccess.file_exists(displaced_backup):
				var remove_displaced_error := _remove(displaced_backup)
				if remove_displaced_error != OK:
					var cleanup_error := _remove_if_exists(temporary)
					return "JSON_STORE_SAVE_ERROR path=%s stage=remove-stale-backup code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, remove_displaced_error, cleanup_error]
			if FileAccess.file_exists(backup):
				var displace_error := _rename(backup, displaced_backup)
				if displace_error != OK:
					var cleanup_error := _remove_if_exists(temporary)
					return "JSON_STORE_SAVE_ERROR path=%s stage=stage-old-backup code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, displace_error, cleanup_error]
				displaced_old_backup = true
			var backup_error := _rename(path, backup)
			if backup_error != OK:
				var restore_displaced_error := _restore_displaced_backup(backup, displaced_backup, displaced_old_backup)
				var cleanup_error := _remove_if_exists(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=backup code=%d restore_code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, backup_error, restore_displaced_error, cleanup_error]
		else:
			var verified_backup := _load_one(backup, existing_validator)
			if not verified_backup.ok():
				var cleanup_error := _remove_if_exists(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=validate-existing cleanup_stage=remove-temporary cleanup_code=%d primary=%s backup=%s" % [path, cleanup_error, previous.error, verified_backup.error]
			var preserved_corrupt := _corrupt_artifact_path(path)
			var preserve_error := _rename(path, preserved_corrupt)
			if preserve_error != OK:
				var cleanup_error := _remove_if_exists(temporary)
				return "JSON_STORE_SAVE_ERROR path=%s stage=preserve-corrupt code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, preserve_error, cleanup_error]
			push_warning("JSON_STORE_CORRUPT_PRIMARY_PRESERVED path=%s artifact=%s" % [path, preserved_corrupt])
	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		var restore_after_promote := _restore_previous(path, backup, displaced_backup, had_previous, previous_was_valid, displaced_old_backup)
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_SAVE_ERROR path=%s stage=promote code=%d restore_code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, promote_error, restore_after_promote, cleanup_error]
	var promoted := _load_one(path, validator)
	if promoted.ok() and _canonical_json(promoted.document) != _canonical_json(temporary_result.document):
		promoted.error = "promoted document differs from verified temporary"
	if not promoted.ok():
		var target_remove_error := _remove_if_exists(path)
		var restore_after_verify := _restore_previous(path, backup, displaced_backup, had_previous, previous_was_valid, displaced_old_backup)
		return "JSON_STORE_SAVE_ERROR path=%s stage=verify-promoted target_remove_code=%d restore_code=%d reason=%s" % [path, target_remove_error, restore_after_verify, promoted.error]
	if displaced_old_backup:
		var cleanup_error := _remove(displaced_backup)
		if cleanup_error != OK:
			push_warning("JSON_STORE_CLEANUP_DEBT path=%s artifact=%s code=%d committed=true" % [path, displaced_backup, cleanup_error])
	return ""

func save_irreversible_document(path: String, document: Dictionary, validator: Callable) -> String:
	if not validator.is_valid():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=validator is missing" % path
	var validation := str(validator.call(document))
	if not validation.is_empty():
		return "JSON_STORE_SAVE_ERROR path=%s stage=validate reason=%s" % [path, validation]
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if mkdir_error not in [OK, ERR_ALREADY_EXISTS]:
		return "JSON_STORE_SAVE_ERROR path=%s stage=mkdir code=%d" % [path, mkdir_error]

	var backup := "%s.bak" % path
	var primary_temporary := "%s.irreversible-primary.tmp" % path
	var backup_temporary := "%s.irreversible-backup.tmp" % path
	var previous_primary := "%s.irreversible-primary.previous" % path
	var previous_backup := "%s.irreversible-backup.previous" % path
	for stale_path: String in [primary_temporary, backup_temporary, previous_primary, previous_backup, "%s.previous" % backup]:
		if FileAccess.file_exists(stale_path):
			return "JSON_STORE_SAVE_ERROR path=%s stage=stale-artifact artifact=%s" % [path, stale_path]
	var document_text := JSON.stringify(document, "\t", false)
	var candidate_canonical := ""
	for temporary_path: String in [primary_temporary, backup_temporary]:
		var write_error := _write_text(temporary_path, document_text)
		if write_error != OK:
			var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
			return "JSON_STORE_SAVE_ERROR path=%s stage=write code=%d cleanup_code=%d" % [path, write_error, cleanup_error]
		var temporary_result := _load_one(temporary_path, validator)
		if not temporary_result.ok():
			var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
			return "JSON_STORE_SAVE_ERROR path=%s stage=verify-temporary cleanup_code=%d reason=%s" % [path, cleanup_error, temporary_result.error]
		var temporary_canonical := _canonical_json(temporary_result.document)
		if candidate_canonical.is_empty():
			candidate_canonical = temporary_canonical
		elif temporary_canonical != candidate_canonical:
			var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
			return "JSON_STORE_SAVE_ERROR path=%s stage=verify-temporary cleanup_code=%d reason=staged generations differ" % [path, cleanup_error]

	var had_primary := FileAccess.file_exists(path)
	var had_backup := FileAccess.file_exists(backup)
	if had_primary:
		var move_primary_error := _rename(path, previous_primary)
		if move_primary_error != OK:
			var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
			return "JSON_STORE_SAVE_ERROR path=%s stage=stage-primary code=%d cleanup_code=%d" % [path, move_primary_error, cleanup_error]
	if had_backup:
		var move_backup_error := _rename(backup, previous_backup)
		if move_backup_error != OK:
			var restore_error := _rename(previous_primary, path) if had_primary else OK
			var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
			return "JSON_STORE_SAVE_ERROR path=%s stage=stage-backup code=%d restore_code=%d cleanup_code=%d" % [path, move_backup_error, restore_error, cleanup_error]

	var promote_primary_error: Error = _promote_file.call(primary_temporary, path) if _promote_file.is_valid() else _promote(primary_temporary, path)
	if promote_primary_error != OK:
		var restore_error := _restore_irreversible_generations(path, backup, previous_primary, previous_backup, had_primary, had_backup)
		var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
		return "JSON_STORE_SAVE_ERROR path=%s stage=promote-primary code=%d restore_code=%d cleanup_code=%d" % [path, promote_primary_error, restore_error, cleanup_error]
	var promote_backup_error: Error = _promote_file.call(backup_temporary, backup) if _promote_file.is_valid() else _promote(backup_temporary, backup)
	if promote_backup_error != OK:
		var restore_error := _restore_irreversible_generations(path, backup, previous_primary, previous_backup, had_primary, had_backup)
		var cleanup_error := _cleanup_paths([primary_temporary, backup_temporary])
		return "JSON_STORE_SAVE_ERROR path=%s stage=promote-backup code=%d restore_code=%d cleanup_code=%d" % [path, promote_backup_error, restore_error, cleanup_error]

	for promoted_path: String in [path, backup]:
		var promoted := _load_one(promoted_path, validator)
		if not promoted.ok() or _canonical_json(promoted.document) != candidate_canonical:
			var restore_error := _restore_irreversible_generations(path, backup, previous_primary, previous_backup, had_primary, had_backup)
			return "JSON_STORE_SAVE_ERROR path=%s stage=verify-promoted restore_code=%d reason=%s" % [path, restore_error, promoted.error]

	var displaced_paths: Array[String] = [previous_primary, previous_backup]
	var cleanup_error := _cleanup_paths(displaced_paths)
	if cleanup_error != OK:
		var sanitize_error := _sanitize_remaining_artifacts(displaced_paths, document_text, validator, candidate_canonical)
		if sanitize_error != OK:
			return "JSON_STORE_SAVE_ERROR path=%s stage=cleanup-unsafe code=%d sanitize_code=%d committed=true" % [path, cleanup_error, sanitize_error]
		push_warning("JSON_STORE_CLEANUP_DEBT path=%s code=%d committed=true sanitized_generations=true" % [path, cleanup_error])
	return ""

func replace_document(path: String, document: Dictionary, validator: Callable) -> String:
	if not validator.is_valid():
		return "JSON_STORE_REPLACE_ERROR path=%s stage=validate reason=validator is missing" % path
	var validation := str(validator.call(document))
	if not validation.is_empty():
		return "JSON_STORE_REPLACE_ERROR path=%s stage=validate reason=%s" % [path, validation]
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	if mkdir_error not in [OK, ERR_ALREADY_EXISTS]:
		return "JSON_STORE_REPLACE_ERROR path=%s stage=mkdir code=%d" % [path, mkdir_error]
	var temporary := "%s.tmp" % path
	var backup := "%s.bak" % path
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "JSON_STORE_REPLACE_ERROR path=%s stage=write code=%d" % [path, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(document, "\t", false))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_REPLACE_ERROR path=%s stage=write code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, write_error, cleanup_error]
	var temporary_result := _load_one(temporary, validator)
	if not temporary_result.ok():
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_REPLACE_ERROR path=%s stage=verify-temporary cleanup_stage=remove-temporary cleanup_code=%d reason=%s" % [path, cleanup_error, temporary_result.error]

	var had_primary := FileAccess.file_exists(path)
	var had_backup := FileAccess.file_exists(backup)
	var primary_quarantine := _corrupt_artifact_path(path) if had_primary else ""
	var backup_quarantine := _corrupt_artifact_path(backup) if had_backup else ""
	if had_primary:
		var quarantine_primary_error := _rename(path, primary_quarantine)
		if quarantine_primary_error != OK:
			var cleanup_error := _remove_if_exists(temporary)
			return "JSON_STORE_REPLACE_ERROR path=%s stage=quarantine-primary code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, quarantine_primary_error, cleanup_error]
	if had_backup:
		var quarantine_backup_error := _rename(backup, backup_quarantine)
		if quarantine_backup_error != OK:
			var restore_primary_error := _rename(primary_quarantine, path) if had_primary else OK
			var cleanup_error := _remove_if_exists(temporary)
			return "JSON_STORE_REPLACE_ERROR path=%s stage=quarantine-backup code=%d restore_code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, quarantine_backup_error, restore_primary_error, cleanup_error]

	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		var restore_error := _restore_replaced_generations(path, backup, primary_quarantine, backup_quarantine, had_primary, had_backup)
		var cleanup_error := _remove_if_exists(temporary)
		return "JSON_STORE_REPLACE_ERROR path=%s stage=promote code=%d restore_code=%d cleanup_stage=remove-temporary cleanup_code=%d" % [path, promote_error, restore_error, cleanup_error]
	var promoted := _load_one(path, validator)
	if promoted.ok() and _canonical_json(promoted.document) != _canonical_json(temporary_result.document):
		promoted.error = "promoted document differs from verified temporary"
	if not promoted.ok():
		var restore_error := _restore_replaced_generations(path, backup, primary_quarantine, backup_quarantine, had_primary, had_backup)
		return "JSON_STORE_REPLACE_ERROR path=%s stage=verify-promoted restore_code=%d reason=%s" % [path, restore_error, promoted.error]
	return ""

func _canonical_json(document: Dictionary) -> String:
	return JSON.stringify(_canonicalize(document))

func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key: Variant in source:
			keys.append(key as String)
		keys.sort()
		var result: Dictionary = {}
		for key: String in keys:
			result[key] = _canonicalize(source[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value as Array:
			result.append(_canonicalize(item))
		return result
	return value

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
		backup.recovery_detail = primary.error if not primary.error.is_empty() else "primary is missing"
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

func _restore_replaced_generations(
	path: String,
	backup: String,
	primary_quarantine: String,
	backup_quarantine: String,
	had_primary: bool,
	had_backup: bool
) -> Error:
	var first_error := _remove_if_exists(path)
	if had_primary:
		var primary_error := _rename(primary_quarantine, path)
		if first_error == OK and primary_error != OK:
			first_error = primary_error
	if had_backup:
		var backup_error := _rename(backup_quarantine, backup)
		if first_error == OK and backup_error != OK:
			first_error = backup_error
	return first_error

func _restore_irreversible_generations(
	path: String,
	backup: String,
	previous_primary: String,
	previous_backup: String,
	had_primary: bool,
	had_backup: bool,
) -> Error:
	var first_error := _remove_if_exists(path)
	var remove_backup_error := _remove_if_exists(backup)
	if first_error == OK and remove_backup_error != OK:
		first_error = remove_backup_error
	if had_primary:
		var primary_error := _rename(previous_primary, path)
		if first_error == OK and primary_error != OK:
			first_error = primary_error
	if had_backup:
		var backup_error := _rename(previous_backup, backup)
		if first_error == OK and backup_error != OK:
			first_error = backup_error
	return first_error

func _write_text(path: String, contents: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(contents)
	var error := file.get_error()
	file.close()
	return error

func _cleanup_paths(paths: Array[String]) -> Error:
	var first_error := OK
	for path: String in paths:
		var cleanup_error := _remove_if_exists(path)
		if first_error == OK and cleanup_error != OK:
			first_error = cleanup_error
	return first_error

func _sanitize_remaining_artifacts(paths: Array[String], contents: String, validator: Callable, expected_canonical: String) -> Error:
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue
		var write_error := _write_text(path, contents)
		if write_error != OK:
			return write_error
		var sanitized := _load_one(path, validator)
		if not sanitized.ok() or _canonical_json(sanitized.document) != expected_canonical:
			return ERR_FILE_CORRUPT
	return OK

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

func _remove_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return _remove(path)
