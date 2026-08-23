extends SceneTree

const INVENTORY_SCRIPT := preload("res://tools/modular_equipment_backup_inventory.gd")
const ERROR_PREFIX := "PARTY_FORGE_MODULAR_BACKUP_ERROR"
const MANIFEST_NAME := "manifest.json"
const REQUIRED_SOURCE_FIELDS := ["root", "commit", "branch", "worktree_status", "toplevel"]


class ErrorText extends RefCounted:
	static func single_line(value: String) -> String:
		var result := ""
		for index: int in value.length():
			var codepoint := value.unicode_at(index)
			if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) or codepoint in [0x2028, 0x2029]:
				result += "%%%02X" % codepoint
			else:
				result += String.chr(codepoint)
		return result


class ReadOnlyFilesystem extends RefCounted:
	func read_file(path: String) -> Dictionary:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": "cannot open", "bytes": PackedByteArray(), "expected_length": -1, "bytes_read": 0, "position": 0, "read_error": ERR_CANT_OPEN, "sha256": ""}
		var expected_length := file.get_length()
		var bytes := file.get_buffer(expected_length)
		var position := file.get_position()
		var read_error := file.get_error()
		file.close()
		return {
			"error": "",
			"bytes": bytes,
			"expected_length": expected_length,
			"bytes_read": bytes.size(),
			"position": position,
			"read_error": read_error,
			"sha256": _sha256(bytes),
		}


	func list_files_recursive(root: String) -> Dictionary:
		var paths := PackedStringArray()
		var error := _list_directory(root, root, paths)
		paths.sort()
		return {"error": error, "paths": paths}


	func _list_directory(root: String, directory_path: String, paths: PackedStringArray) -> String:
		var directory := DirAccess.open(directory_path)
		if directory == null:
			return "cannot open directory path=%s" % directory_path
		var begin_error := directory.list_dir_begin()
		if begin_error != OK:
			return "cannot list directory code=%d path=%s" % [begin_error, directory_path]
		var names := PackedStringArray()
		var name := directory.get_next()
		while not name.is_empty():
			if name != "." and name != "..":
				names.append(name)
			name = directory.get_next()
		directory.list_dir_end()
		names.sort()
		for child_name: String in names:
			var child_path := directory_path.path_join(child_name)
			if DirAccess.dir_exists_absolute(child_path):
				var nested_error := _list_directory(root, child_path, paths)
				if not nested_error.is_empty():
					return nested_error
			else:
				paths.append(child_path.trim_prefix(root).trim_prefix("/").trim_prefix("\\").replace("\\", "/"))
		return ""


	func _sha256(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()


class BackupVerifier extends RefCounted:
	func verify_backup(backup_root: String, expected_paths: PackedStringArray, filesystem: RefCounted = null) -> Dictionary:
		var adapter := filesystem if filesystem != null else ReadOnlyFilesystem.new()
		var errors: Array[String] = []
		_validate_root(backup_root, errors)
		_validate_expected_paths(expected_paths, errors)
		if not errors.is_empty():
			return _result(errors)
		if not adapter.has_method(&"read_file") or not adapter.has_method(&"list_files_recursive"):
			errors.append("%s stage=request field=filesystem reason=read-only adapter required" % ERROR_PREFIX)
			return _result(errors)

		var manifest_path := backup_root.path_join(MANIFEST_NAME)
		var manifest_read := adapter.call(&"read_file", manifest_path) as Dictionary
		var manifest_error := _validate_read(manifest_read)
		if not manifest_error.is_empty():
			errors.append("%s stage=manifest reason=%s" % [ERROR_PREFIX, manifest_error])
			return _result(errors)
		var manifest_bytes := manifest_read.get("bytes", PackedByteArray()) as PackedByteArray
		var manifest_sha256 := String(manifest_read.get("sha256", ""))

		if not _is_valid_utf8(manifest_bytes):
			errors.append("%s stage=manifest reason=invalid UTF-8" % ERROR_PREFIX)
			return _result(errors, manifest_sha256)
		var json := JSON.new()
		if json.parse(manifest_bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
			errors.append("%s stage=manifest reason=malformed JSON" % ERROR_PREFIX)
			return _result(errors, manifest_sha256)
		var manifest := json.data as Dictionary
		_validate_manifest_header(manifest, expected_paths.size(), errors)

		var listing := adapter.call(&"list_files_recursive", backup_root) as Dictionary
		if not String(listing.get("error", "")).is_empty():
			errors.append("%s stage=files reason=%s" % [ERROR_PREFIX, listing["error"]])
			return _result(errors, manifest_sha256)
		var observed_paths := listing.get("paths", PackedStringArray()) as PackedStringArray
		observed_paths.erase(MANIFEST_NAME)
		var expected_set := _path_set(expected_paths)
		var observed_set := _path_set(observed_paths)
		for path: String in expected_paths:
			if not observed_set.has(path):
				errors.append("%s stage=files path=%s reason=missing" % [ERROR_PREFIX, path])
		for path: String in observed_paths:
			if not expected_set.has(path):
				errors.append("%s stage=files path=%s reason=unexpected" % [ERROR_PREFIX, path])

		var rows_value: Variant = manifest.get("files")
		var rows: Array = rows_value if rows_value is Array else []
		if not (rows_value is Array):
			errors.append("%s stage=manifest field=files reason=must be an array" % ERROR_PREFIX)
		var row_paths := {}
		var declared_total := 0
		var verified_files := 0
		var verified_bytes := 0
		for row_index: int in rows.size():
			var row_value: Variant = rows[row_index]
			if not (row_value is Dictionary):
				errors.append("%s stage=manifest row=%d reason=must be an object" % [ERROR_PREFIX, row_index])
				continue
			var row := row_value as Dictionary
			var path_value: Variant = row.get("path")
			var relative_path := String(path_value) if path_value is String else ""
			if not (path_value is String) or not _is_normalized_relative(relative_path):
				errors.append("%s stage=manifest path=%s reason=must be normalized and relative" % [ERROR_PREFIX, relative_path])
				continue
			if row_paths.has(relative_path):
				errors.append("%s stage=manifest path=%s reason=duplicate" % [ERROR_PREFIX, relative_path])
				continue
			row_paths[relative_path] = true
			if not expected_set.has(relative_path):
				errors.append("%s stage=manifest path=%s reason=unexpected" % [ERROR_PREFIX, relative_path])
			var size_value: Variant = row.get("size")
			var hash_value: Variant = row.get("sha256")
			if not _is_nonnegative_integer_number(size_value):
				errors.append("%s stage=manifest path=%s field=size reason=must be a nonnegative integer" % [ERROR_PREFIX, relative_path])
				continue
			if not (hash_value is String) or not _is_sha256(String(hash_value)):
				errors.append("%s stage=manifest path=%s field=sha256 reason=must be 64 lowercase hexadecimal characters" % [ERROR_PREFIX, relative_path])
				continue
			declared_total += int(size_value)
			if not observed_set.has(relative_path):
				continue
			var file_read := adapter.call(&"read_file", backup_root.path_join(relative_path)) as Dictionary
			var file_error := _validate_read(file_read)
			if not file_error.is_empty():
				errors.append("%s stage=content path=%s reason=%s" % [ERROR_PREFIX, relative_path, file_error])
				continue
			var actual_size := int(file_read.get("expected_length", -1))
			var actual_sha256 := String(file_read.get("sha256", ""))
			if actual_size != int(size_value):
				errors.append("%s stage=content path=%s reason=size expected=%d actual=%d" % [ERROR_PREFIX, relative_path, int(size_value), actual_size])
			if actual_sha256 != String(hash_value):
				errors.append("%s stage=content path=%s reason=sha256 mismatch" % [ERROR_PREFIX, relative_path])
			if actual_size == int(size_value) and actual_sha256 == String(hash_value):
				verified_files += 1
				verified_bytes += actual_size

		for path: String in expected_paths:
			if not row_paths.has(path):
				errors.append("%s stage=manifest path=%s reason=missing row" % [ERROR_PREFIX, path])
		_validate_manifest_totals(manifest, rows.size(), declared_total, errors)
		if errors.is_empty():
			return _result(errors, manifest_sha256, verified_files, verified_bytes)
		return _result(errors, manifest_sha256)


	func _validate_root(backup_root: String, errors: Array[String]) -> void:
		if not _is_local_drive_absolute(backup_root) or _is_unsafe_local_path(backup_root):
			errors.append("%s stage=request field=backup_root reason=must be an explicit local absolute path" % ERROR_PREFIX)
		elif not DirAccess.dir_exists_absolute(backup_root):
			errors.append("%s stage=request field=backup_root reason=directory does not exist" % ERROR_PREFIX)


	func _validate_expected_paths(expected_paths: PackedStringArray, errors: Array[String]) -> void:
		var seen := {}
		var sorted_paths := expected_paths.duplicate()
		sorted_paths.sort()
		for path: String in sorted_paths:
			if not _is_normalized_relative(path):
				errors.append("%s stage=inventory path=%s reason=must be normalized and relative" % [ERROR_PREFIX, path])
			if seen.has(path):
				errors.append("%s stage=inventory path=%s reason=duplicate" % [ERROR_PREFIX, path])
			seen[path] = true


	func _validate_manifest_header(manifest: Dictionary, expected_count: int, errors: Array[String]) -> void:
		if manifest.get("schema_version") != 1:
			errors.append("%s stage=manifest field=schema_version expected=1 actual=%s" % [ERROR_PREFIX, str(manifest.get("schema_version"))])
		if manifest.get("state") != "complete":
			errors.append("%s stage=manifest field=state expected=complete actual=%s" % [ERROR_PREFIX, str(manifest.get("state"))])
		var source_value: Variant = manifest.get("source")
		if not (source_value is Dictionary):
			errors.append("%s stage=manifest field=source reason=missing metadata" % ERROR_PREFIX)
		else:
			var source := source_value as Dictionary
			for field: String in REQUIRED_SOURCE_FIELDS:
				if not source.has(field) or not (source[field] is String) or (field != "worktree_status" and String(source[field]).is_empty()):
					errors.append("%s stage=manifest field=source.%s reason=missing metadata" % [ERROR_PREFIX, field])
			if source.has("commit") and (not (source["commit"] is String) or not _is_sha40(String(source["commit"]))):
				errors.append("%s stage=manifest field=source.commit reason=must be 40 hexadecimal characters" % ERROR_PREFIX)
			var root_valid := source.has("root") and source["root"] is String and _is_normalized_local_absolute(String(source["root"]))
			var toplevel_valid := source.has("toplevel") and source["toplevel"] is String and _is_normalized_local_absolute(String(source["toplevel"]))
			if source.has("root") and source["root"] is String and not root_valid:
				errors.append("%s stage=manifest field=source.root reason=must be a normalized local absolute path" % ERROR_PREFIX)
			if source.has("toplevel") and source["toplevel"] is String and not toplevel_valid:
				errors.append("%s stage=manifest field=source.toplevel reason=must be a normalized local absolute path" % ERROR_PREFIX)
			if root_valid and toplevel_valid and String(source["root"]).to_lower() != String(source["toplevel"]).to_lower():
				errors.append("%s stage=manifest field=source reason=root and toplevel must identify the same path" % ERROR_PREFIX)
		var expected_value: Variant = manifest.get("expected_file_count")
		if not _is_nonnegative_integer_number(expected_value) or int(expected_value) != expected_count:
			var actual := str(expected_value) if not _is_nonnegative_integer_number(expected_value) else str(int(expected_value))
			errors.append("%s stage=manifest field=expected_file_count expected=%d actual=%s" % [ERROR_PREFIX, expected_count, actual])


	func _validate_manifest_totals(manifest: Dictionary, actual_rows: int, declared_total: int, errors: Array[String]) -> void:
		var file_count_value: Variant = manifest.get("file_count")
		if not _is_nonnegative_integer_number(file_count_value) or int(file_count_value) != actual_rows:
			var actual_file_count := str(file_count_value) if not _is_nonnegative_integer_number(file_count_value) else str(int(file_count_value))
			errors.append("%s stage=manifest field=file_count expected=%d actual=%s" % [ERROR_PREFIX, actual_rows, actual_file_count])
		var total_value: Variant = manifest.get("total_bytes")
		if not _is_nonnegative_integer_number(total_value) or int(total_value) != declared_total:
			var actual_total := str(total_value) if not _is_nonnegative_integer_number(total_value) else str(int(total_value))
			errors.append("%s stage=manifest field=total_bytes expected=%d actual=%s" % [ERROR_PREFIX, declared_total, actual_total])


	func _validate_read(read_result: Dictionary) -> String:
		if not String(read_result.get("error", "")).is_empty():
			return String(read_result["error"])
		var expected_length := int(read_result.get("expected_length", -1))
		var bytes := read_result.get("bytes", PackedByteArray()) as PackedByteArray
		if expected_length < 0 or bytes.size() != expected_length or int(read_result.get("bytes_read", -1)) != expected_length or int(read_result.get("position", -1)) != expected_length:
			return "incomplete read"
		if int(read_result.get("read_error", ERR_FILE_CANT_READ)) not in [OK, ERR_FILE_EOF]:
			return "read status code=%d" % int(read_result.get("read_error", ERR_FILE_CANT_READ))
		var sha256 := String(read_result.get("sha256", ""))
		if not _is_sha256(sha256) or sha256 != _sha256(bytes):
			return "invalid SHA-256"
		return ""


	func _result(errors: Array[String], manifest_sha256: String = "", file_count: int = 0, total_bytes: int = 0) -> Dictionary:
		var single_line_errors: Array[String] = []
		for error: String in errors:
			single_line_errors.append(ErrorText.single_line(error))
		single_line_errors.sort()
		var unique_errors := PackedStringArray()
		for error: String in single_line_errors:
			if error not in unique_errors:
				unique_errors.append(error)
		return {
			"ok": unique_errors.is_empty(),
			"errors": unique_errors,
			"file_count": file_count,
			"total_bytes": total_bytes,
			"manifest_sha256": manifest_sha256,
		}


	func _path_set(paths: PackedStringArray) -> Dictionary:
		var result := {}
		for path: String in paths:
			result[path] = true
		return result


	func _is_normalized_relative(path: String) -> bool:
		if path.is_empty() or path.is_absolute_path() or path.begins_with("res://") or "\\" in path or _has_control_character(path):
			return false
		var segments := path.split("/", true)
		return not segments.has("") and not segments.has(".") and not segments.has("..") and path not in [MANIFEST_NAME, ".manifest.pending.json", "backup.failure.json", "partial-manifest.json"]


	func _is_unsafe_local_path(path: String) -> bool:
		var windows_path := path.replace("/", "\\")
		return windows_path.begins_with("\\\\") or windows_path.begins_with("\\??\\") or windows_path.begins_with("\\\\?\\") or windows_path.begins_with("\\\\.\\")


	func _is_normalized_local_absolute(path: String) -> bool:
		return _is_local_drive_absolute(path) and "\\" not in path and not _is_unsafe_local_path(path) and not _has_control_character(path) and path == path.simplify_path()


	func _is_local_drive_absolute(path: String) -> bool:
		if path.length() < 3 or path[1] != ":" or path[2] != "/":
			return false
		var drive_letter := path.unicode_at(0)
		return (drive_letter >= 65 and drive_letter <= 90) or (drive_letter >= 97 and drive_letter <= 122)


	func _has_control_character(value: String) -> bool:
		for index: int in value.length():
			var codepoint := value.unicode_at(index)
			if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
				return true
		return false


	func _is_valid_utf8(bytes: PackedByteArray) -> bool:
		var index := 0
		while index < bytes.size():
			var first := int(bytes[index])
			if first <= 0x7f:
				index += 1
				continue
			if first >= 0xc2 and first <= 0xdf:
				if index + 1 >= bytes.size() or not _is_continuation_byte(int(bytes[index + 1])):
					return false
				index += 2
				continue
			if first >= 0xe0 and first <= 0xef:
				if index + 2 >= bytes.size():
					return false
				var second := int(bytes[index + 1])
				if (first == 0xe0 and (second < 0xa0 or second > 0xbf)) or (first == 0xed and (second < 0x80 or second > 0x9f)) or (first not in [0xe0, 0xed] and not _is_continuation_byte(second)) or not _is_continuation_byte(int(bytes[index + 2])):
					return false
				index += 3
				continue
			if first >= 0xf0 and first <= 0xf4:
				if index + 3 >= bytes.size():
					return false
				var second := int(bytes[index + 1])
				if (first == 0xf0 and (second < 0x90 or second > 0xbf)) or (first == 0xf4 and (second < 0x80 or second > 0x8f)) or (first not in [0xf0, 0xf4] and not _is_continuation_byte(second)) or not _is_continuation_byte(int(bytes[index + 2])) or not _is_continuation_byte(int(bytes[index + 3])):
					return false
				index += 4
				continue
			return false
		return true


	func _is_continuation_byte(value: int) -> bool:
		return value >= 0x80 and value <= 0xbf


	func _is_sha40(value: String) -> bool:
		return value.length() == 40 and _is_hexadecimal(value)


	func _is_nonnegative_integer_number(value: Variant) -> bool:
		if typeof(value) == TYPE_INT:
			return int(value) >= 0
		if typeof(value) == TYPE_FLOAT:
			var number := float(value)
			return is_finite(number) and number >= 0.0 and floor(number) == number
		return false


	func _is_sha256(value: String) -> bool:
		return value.length() == 64 and value == value.to_lower() and _is_hexadecimal(value)


	func _is_hexadecimal(value: String) -> bool:
		for character: String in value:
			if character not in "0123456789abcdefABCDEF":
				return false
		return true


	func _sha256(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()


func _initialize() -> void:
	quit(run_cli(OS.get_cmdline_user_args(), INVENTORY_SCRIPT.new().expected_paths(), Callable(self, &"_print_line")))


func run_cli(arguments: PackedStringArray, expected_paths: PackedStringArray, output: Callable) -> int:
	var parsed := parse_named_args(arguments)
	var errors := parsed.get("errors", PackedStringArray()) as PackedStringArray
	if not errors.is_empty():
		_emit_lines(errors, output)
		return 1
	var result := BackupVerifier.new().verify_backup(String(parsed.get("backup_root", "")), expected_paths)
	if not bool(result.get("ok", false)):
		_emit_lines(result.get("errors", PackedStringArray()) as PackedStringArray, output)
		return 1
	output.call("PARTY_FORGE_MODULAR_BACKUP_OK files=%d bytes=%d manifest_sha256=%s" % [int(result.get("file_count", 0)), int(result.get("total_bytes", 0)), String(result.get("manifest_sha256", ""))])
	return 0


func parse_named_args(arguments: PackedStringArray) -> Dictionary:
	var backup_root := ""
	var errors := PackedStringArray()
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if not argument.begins_with("--backup-root"):
			errors.append("%s stage=request argument=%s reason=unknown" % [ERROR_PREFIX, argument])
			index += 1
			continue
		var value := ""
		if argument.begins_with("--backup-root="):
			value = argument.trim_prefix("--backup-root=")
		elif argument == "--backup-root" and index + 1 < arguments.size() and not arguments[index + 1].begins_with("--"):
			value = arguments[index + 1]
			index += 1
		else:
			errors.append("%s stage=request argument=--backup-root reason=value required" % ERROR_PREFIX)
		if not value.is_empty():
			if not backup_root.is_empty():
				errors.append("%s stage=request argument=--backup-root reason=duplicate" % ERROR_PREFIX)
			else:
				backup_root = value
		index += 1
	if backup_root.is_empty():
		errors.append("%s stage=request argument=--backup-root reason=required" % ERROR_PREFIX)
	var single_line_errors := PackedStringArray()
	for error: String in errors:
		single_line_errors.append(ErrorText.single_line(error))
	single_line_errors.sort()
	return {"backup_root": backup_root, "errors": single_line_errors}


func new_service() -> RefCounted:
	return BackupVerifier.new()


func new_read_only_filesystem() -> RefCounted:
	return ReadOnlyFilesystem.new()


func _emit_lines(errors: PackedStringArray, output: Callable) -> void:
	for error: String in errors:
		output.call(ErrorText.single_line(error))


func _print_line(line: String) -> void:
	print(ErrorText.single_line(line))
