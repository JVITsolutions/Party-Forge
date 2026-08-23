extends SceneTree

const INVENTORY_SCRIPT := preload("res://tools/modular_equipment_backup_inventory.gd")
const ERROR_PREFIX := "PARTY_FORGE_MODULAR_BACKUP_ERROR"
const MANIFEST_NAME := "manifest.json"
const FAILURE_NAME := "backup.failure.json"
const PARTIAL_MANIFEST_NAME := "partial-manifest.json"
const MAX_FAILURE_MARKER_BYTES := 2048
const MAX_FAILURE_ERROR_CHARACTERS := 512
const REQUIRED_ARGUMENTS := ["source-root", "output", "source-commit", "source-branch"]
const ARGUMENT_FIELDS := {
	"source-root": "source_root",
	"output": "output",
	"source-commit": "source_commit",
	"source-branch": "source_branch",
}


class BackupService extends RefCounted:
	func build_backup(request: Dictionary, inventory_paths: PackedStringArray, source_status: String) -> Dictionary:
		var validation_error := _validate_request(request, inventory_paths)
		if not validation_error.is_empty():
			return _failed_result(validation_error)

		var source_root := _normalized_absolute(String(request.get("source_root", "")))
		var output := _normalized_absolute(String(request.get("output", "")))
		var source_metadata := {
			"root": source_root,
			"commit": String(request.get("source_commit", "")),
			"branch": String(request.get("source_branch", "")),
			"worktree_status": source_status,
		}
		var output_existed := DirAccess.dir_exists_absolute(output)
		if not output_existed:
			var create_error := DirAccess.make_dir_recursive_absolute(output)
			if create_error not in [OK, ERR_ALREADY_EXISTS]:
				return _failed_result("%s field=output reason=cannot create code=%d" % [ERROR_PREFIX, create_error])

		var sorted_paths := inventory_paths.duplicate()
		sorted_paths.sort()
		var completed_files: Array[Dictionary] = []
		var total_bytes := 0
		for relative_path: String in sorted_paths:
			var source_path := source_root.path_join(relative_path)
			var destination_path := output.path_join(relative_path)
			if not FileAccess.file_exists(source_path):
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=source file missing" % [ERROR_PREFIX, relative_path])
			if FileAccess.file_exists(destination_path) or DirAccess.dir_exists_absolute(destination_path):
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=destination already exists" % [ERROR_PREFIX, relative_path])
			var parent_error := DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
			if parent_error not in [OK, ERR_ALREADY_EXISTS]:
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=cannot create parent code=%d" % [ERROR_PREFIX, relative_path, parent_error])
			var source_file := FileAccess.open(source_path, FileAccess.READ)
			if source_file == null:
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=cannot read source" % [ERROR_PREFIX, relative_path])
			var source_bytes := source_file.get_buffer(source_file.get_length())
			source_file.close()
			var destination_file := FileAccess.open(destination_path, FileAccess.WRITE)
			if destination_file == null:
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=cannot create destination" % [ERROR_PREFIX, relative_path])
			destination_file.store_buffer(source_bytes)
			var write_error := destination_file.get_error()
			destination_file.close()
			if write_error != OK:
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=copy path=%s reason=write failed code=%d" % [ERROR_PREFIX, relative_path, write_error])
			if FileAccess.get_file_as_bytes(destination_path) != source_bytes:
				return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=verify path=%s reason=copied bytes differ" % [ERROR_PREFIX, relative_path])
			var row := {
				"path": relative_path,
				"size": source_bytes.size(),
				"sha256": FileAccess.get_sha256(destination_path),
			}
			completed_files.append(row)
			total_bytes += source_bytes.size()

		var manifest := {
			"schema_version": 1,
			"state": "complete",
			"source": source_metadata,
			"expected_file_count": sorted_paths.size(),
			"file_count": completed_files.size(),
			"total_bytes": total_bytes,
			"files": completed_files,
		}
		var manifest_error := _write_json_no_overwrite(output.path_join(MANIFEST_NAME), manifest)
		if not manifest_error.is_empty():
			return _preserve_failure(output, source_metadata, sorted_paths.size(), completed_files, "%s stage=manifest reason=%s" % [ERROR_PREFIX, manifest_error])
		return {
			"ok": true,
			"error": "",
			"manifest_path": output.path_join(MANIFEST_NAME),
			"file_count": completed_files.size(),
			"total_bytes": total_bytes,
		}


	func _validate_request(request: Dictionary, inventory_paths: PackedStringArray) -> String:
		var source_raw := String(request.get("source_root", ""))
		if source_raw.is_empty() or not source_raw.is_absolute_path():
			return "%s field=source_root reason=must be absolute" % ERROR_PREFIX
		var source_root := _normalized_absolute(source_raw)
		if not DirAccess.dir_exists_absolute(source_root):
			return "%s field=source_root reason=directory does not exist" % ERROR_PREFIX
		if not FileAccess.file_exists(source_root.path_join("project.godot")):
			return "%s field=source_root reason=project.godot must exist directly under source root" % ERROR_PREFIX

		var output_raw := String(request.get("output", ""))
		if output_raw.is_empty() or not output_raw.is_absolute_path():
			return "%s field=output reason=must be absolute" % ERROR_PREFIX
		var output := _normalized_absolute(output_raw)
		if _is_same_or_descendant(output, source_root):
			return "%s field=output reason=must be outside source root" % ERROR_PREFIX
		if DirAccess.dir_exists_absolute(output):
			if not DirAccess.get_files_at(output).is_empty() or not DirAccess.get_directories_at(output).is_empty():
				return "%s field=output reason=must be empty" % ERROR_PREFIX
		elif FileAccess.file_exists(output):
			return "%s field=output reason=must be an empty directory or absent" % ERROR_PREFIX

		var source_commit := String(request.get("source_commit", ""))
		var commit_expression := RegEx.new()
		if commit_expression.compile("^[0-9A-Fa-f]{40}$") != OK or commit_expression.search(source_commit) == null:
			return "%s field=source_commit reason=must be exactly 40 hexadecimal characters" % ERROR_PREFIX
		if String(request.get("source_branch", "")).is_empty():
			return "%s field=source_branch reason=must be non-empty" % ERROR_PREFIX

		if inventory_paths.is_empty():
			return "%s field=inventory reason=must be non-empty" % ERROR_PREFIX
		var seen := {}
		var sorted_paths := inventory_paths.duplicate()
		sorted_paths.sort()
		for relative_path: String in sorted_paths:
			if not _is_normalized_relative_path(relative_path):
				return "%s inventory path=%s reason=must be normalized and relative" % [ERROR_PREFIX, relative_path]
			if relative_path in [MANIFEST_NAME, FAILURE_NAME, PARTIAL_MANIFEST_NAME]:
				return "%s inventory path=%s reason=reserved builder output" % [ERROR_PREFIX, relative_path]
			if seen.has(relative_path):
				return "%s inventory path=%s reason=duplicate" % [ERROR_PREFIX, relative_path]
			seen[relative_path] = true
		return ""


	func _preserve_failure(output: String, source_metadata: Dictionary, expected_file_count: int, completed_files: Array[Dictionary], error: String) -> Dictionary:
		var owned_paths := PackedStringArray()
		for row: Dictionary in completed_files:
			owned_paths.append(String(row.get("path", "")))
		owned_paths.append(PARTIAL_MANIFEST_NAME)
		owned_paths.append(FAILURE_NAME)
		owned_paths.sort()
		var partial_manifest := {
			"schema_version": 1,
			"state": "failed",
			"source": source_metadata,
			"expected_file_count": expected_file_count,
			"completed_file_count": completed_files.size(),
			"files": completed_files,
			"owned_paths": owned_paths,
		}
		var partial_error := _write_json_no_overwrite(output.path_join(PARTIAL_MANIFEST_NAME), partial_manifest)
		var marker_error := _bounded(error, MAX_FAILURE_ERROR_CHARACTERS)
		if not partial_error.is_empty():
			marker_error = _bounded("%s; partial-manifest=%s" % [marker_error, partial_error], MAX_FAILURE_ERROR_CHARACTERS)
		var marker := {
			"schema_version": 1,
			"state": "failed",
			"error": marker_error,
			"partial_manifest": PARTIAL_MANIFEST_NAME,
			"completed_file_count": completed_files.size(),
		}
		var marker_text := JSON.stringify(marker, "\t", true)
		while marker_text.to_utf8_buffer().size() > MAX_FAILURE_MARKER_BYTES and not marker_error.is_empty():
			marker_error = marker_error.left(maxi(marker_error.length() / 2, 0))
			marker["error"] = marker_error
			marker_text = JSON.stringify(marker, "\t", true)
		_write_text_no_overwrite(output.path_join(FAILURE_NAME), marker_text)
		var result := _failed_result(error)
		result["failure_marker_path"] = output.path_join(FAILURE_NAME)
		result["partial_manifest_path"] = output.path_join(PARTIAL_MANIFEST_NAME)
		return result


	func _write_json_no_overwrite(path: String, document: Dictionary) -> String:
		return _write_text_no_overwrite(path, JSON.stringify(document, "\t", true))


	func _write_text_no_overwrite(path: String, text: String) -> String:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return "destination already exists path=%s" % path
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return "cannot open path=%s" % path
		file.store_string(text)
		var error := file.get_error()
		file.close()
		if error != OK:
			return "write failed code=%d path=%s" % [error, path]
		return ""


	func _is_normalized_relative_path(path: String) -> bool:
		if path.is_empty() or path.is_absolute_path() or path.begins_with("res://") or "\\" in path:
			return false
		var segments := path.split("/", true)
		return not segments.has("") and not segments.has(".") and not segments.has("..")


	func _normalized_absolute(path: String) -> String:
		return path.replace("\\", "/").simplify_path().trim_suffix("/")


	func _is_same_or_descendant(candidate: String, root: String) -> bool:
		var folded_candidate := candidate.to_lower()
		var folded_root := root.to_lower()
		return folded_candidate == folded_root or folded_candidate.begins_with(folded_root + "/")


	func _bounded(value: String, maximum_characters: int) -> String:
		return value if value.length() <= maximum_characters else value.left(maximum_characters)


	func _failed_result(error: String) -> Dictionary:
		return {"ok": false, "error": error}


func _initialize() -> void:
	var parsed := parse_named_args(OS.get_cmdline_user_args())
	var parse_errors := parsed.get("errors", PackedStringArray()) as PackedStringArray
	if not parse_errors.is_empty():
		_fail(parse_errors[0])
		return
	var request := parsed.get("request", {}) as Dictionary
	var source_root := String(request.get("source_root", ""))
	var inventory := INVENTORY_SCRIPT.new().build(source_root) as Dictionary
	var inventory_errors := inventory.get("errors", PackedStringArray()) as PackedStringArray
	if not inventory_errors.is_empty():
		_fail(inventory_errors[0])
		return
	var git_output: Array = []
	var git_exit := OS.execute("git", ["-C", source_root, "status", "--porcelain=v1", "--untracked-files=all"], git_output, true)
	if git_exit != 0:
		_fail("%s field=source_root reason=git status failed code=%d" % [ERROR_PREFIX, git_exit])
		return
	var result := BackupService.new().build_backup(request, inventory.get("paths", PackedStringArray()) as PackedStringArray, "".join(git_output))
	if not bool(result.get("ok", false)):
		_fail(String(result.get("error", "%s reason=unknown" % ERROR_PREFIX)))
		return
	print("PARTY_FORGE_MODULAR_BACKUP_OK files=%d bytes=%d manifest=%s" % [int(result.get("file_count", 0)), int(result.get("total_bytes", 0)), String(result.get("manifest_path", ""))])
	quit(0)


func parse_named_args(arguments: PackedStringArray) -> Dictionary:
	var request := {}
	var errors := PackedStringArray()
	var index := 0
	while index < arguments.size():
		var argument := arguments[index]
		if not argument.begins_with("--"):
			errors.append("%s argument=%s reason=expected named argument" % [ERROR_PREFIX, argument])
			index += 1
			continue
		var name := argument.trim_prefix("--")
		var value := ""
		var equals_index := name.find("=")
		if equals_index >= 0:
			value = name.substr(equals_index + 1)
			name = name.left(equals_index)
		elif index + 1 < arguments.size() and not arguments[index + 1].begins_with("--"):
			value = arguments[index + 1]
			index += 1
		if not ARGUMENT_FIELDS.has(name):
			errors.append("%s argument=--%s reason=unknown" % [ERROR_PREFIX, name])
		elif request.has(ARGUMENT_FIELDS[name]):
			errors.append("%s argument=--%s reason=duplicate" % [ERROR_PREFIX, name])
		elif value.is_empty():
			errors.append("%s argument=--%s reason=value required" % [ERROR_PREFIX, name])
		else:
			request[ARGUMENT_FIELDS[name]] = value
		index += 1
	for name: String in REQUIRED_ARGUMENTS:
		var field := String(ARGUMENT_FIELDS[name])
		if not request.has(field):
			errors.append("%s argument=--%s reason=required" % [ERROR_PREFIX, name])
	return {"request": request, "errors": errors}


func new_service() -> RefCounted:
	return BackupService.new()


func _fail(error: String) -> void:
	push_error(error)
	quit(1)
