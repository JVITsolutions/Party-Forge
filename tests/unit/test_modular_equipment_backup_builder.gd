extends RefCounted

const BUILDER_PATH := "res://tools/build_modular_equipment_backup.gd"
const MANIFEST_NAME := "manifest.json"
const FAILURE_NAME := "backup.failure.json"
const PARTIAL_MANIFEST_NAME := "partial-manifest.json"
const PENDING_MANIFEST_NAME := ".manifest.pending.json"
const COMMIT := "0123456789abcdef0123456789abcdef01234567"
const BRANCH := "feat/test-backup"
const STATUS := " M assets/item.bin\n?? notes/untracked.txt\n"

var _test_root := ""
var _source_root := ""
var _outside_file := ""
var _created_files: Array[String] = []
var _created_directories: Array[String] = []


class FixtureFilesystem extends RefCounted:
	var read_overrides := {}
	var create_modes := {}
	var publish_error := ""
	var ensure_failure_path := ""
	var requires_configuration := false
	var configured_output_root := ""
	var copy_calls := 0
	var created_files: Array[String] = []
	var created_directories: Array[String] = []


	func probe_path(path: String, require_exists: bool) -> Dictionary:
		var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/")
		if require_exists and not FileAccess.file_exists(normalized) and not DirAccess.dir_exists_absolute(normalized):
			return {"error": "physical path does not exist: %s" % normalized, "path": ""}
		return {"error": "", "path": normalized}


	func directory_state(path: String) -> Dictionary:
		if FileAccess.file_exists(path):
			return {"error": "path is a file", "exists": false, "empty": false}
		if not DirAccess.dir_exists_absolute(path):
			return {"error": "", "exists": false, "empty": true}
		return {
			"error": "",
			"exists": true,
			"empty": DirAccess.get_files_at(path).is_empty() and DirAccess.get_directories_at(path).is_empty(),
		}


	func configure_output_root(path: String) -> Dictionary:
		configured_output_root = path
		return {"error": ""}


	func ensure_directory(path: String) -> Dictionary:
		if requires_configuration and configured_output_root.is_empty():
			return {"error": "output containment root was not configured", "created_paths": []}
		var missing: Array[String] = []
		var cursor := path.replace("\\", "/").simplify_path().trim_suffix("/")
		while not cursor.is_empty() and not DirAccess.dir_exists_absolute(cursor):
			if FileAccess.file_exists(cursor):
				return {"error": "directory component is a file: %s" % cursor, "created_paths": missing}
			missing.append(cursor)
			var parent := cursor.get_base_dir()
			if parent == cursor:
				break
			cursor = parent
		missing.reverse()
		for directory: String in missing:
			var error := DirAccess.make_dir_absolute(directory)
			if error not in [OK, ERR_ALREADY_EXISTS]:
				return {"error": "directory create failed code=%d path=%s" % [error, directory], "created_paths": created_directories.duplicate()}
			if error == OK:
				created_directories.append(directory)
		if path == ensure_failure_path:
			return {"error": "injected failure after directory creation", "created_paths": missing}
		return {"error": "", "created_paths": missing}


	func read_file(path: String) -> Dictionary:
		if read_overrides.has(path):
			return (read_overrides[path] as Dictionary).duplicate(true)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": "cannot open", "bytes": PackedByteArray(), "expected_length": -1, "bytes_read": 0, "read_error": ERR_CANT_OPEN, "sha256": ""}
		var expected_length := file.get_length()
		var bytes := file.get_buffer(expected_length)
		var position := file.get_position()
		var read_error := file.get_error()
		file.close()
		return {"error": "", "bytes": bytes, "expected_length": expected_length, "bytes_read": bytes.size(), "position": position, "read_error": read_error, "sha256": _hash(bytes)}


	func create_file_exclusive(path: String, bytes: PackedByteArray) -> Dictionary:
		var mode := String(create_modes.get(path, ""))
		if mode == "fail":
			return {"error": "exclusive create injected failure", "created": false}
		if mode == "collision":
			var collision := FileAccess.open(path, FileAccess.WRITE)
			if collision != null:
				collision.store_string("collision-sentinel")
				collision.close()
				created_files.append(path)
			return {"error": "exclusive create collision", "created": false}
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return {"error": "exclusive create collision", "created": false}
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return {"error": "exclusive create cannot open", "created": false}
		created_files.append(path)
		if mode == "partial":
			file.store_buffer(bytes.slice(0, maxi(bytes.size() / 2, 1)))
			file.close()
			return {"error": "exclusive create partial write", "created": true}
		file.store_buffer(bytes)
		var error := file.get_error()
		file.close()
		return {"error": "" if error == OK else "exclusive create write failed code=%d" % error, "created": true}


	func copy_file_verified(source_path: String, destination_path: String) -> Dictionary:
		copy_calls += 1
		var source := read_file(source_path)
		if not String(source.get("error", "")).is_empty():
			return {"error": String(source["error"]), "created": false}
		var bytes := source.get("bytes", PackedByteArray()) as PackedByteArray
		var created := create_file_exclusive(destination_path, bytes)
		if not String(created.get("error", "")).is_empty():
			return {"error": String(created["error"]), "created": bool(created.get("created", false))}
		var destination := read_file(destination_path)
		return {"error": String(destination.get("error", "")), "created": true, "source": source, "destination": destination, "equal": bytes == (destination.get("bytes", PackedByteArray()) as PackedByteArray)}


	func publish_no_replace(pending_path: String, final_path: String) -> Dictionary:
		if not publish_error.is_empty():
			return {"error": publish_error, "published": false}
		if FileAccess.file_exists(final_path) or DirAccess.dir_exists_absolute(final_path):
			return {"error": "collision", "published": false}
		var error := DirAccess.rename_absolute(pending_path, final_path)
		if error != OK:
			return {"error": "publish failed code=%d" % error, "published": false}
		created_files.append(final_path)
		return {"error": "", "published": true}


	func _hash(bytes: PackedByteArray) -> String:
		var hashing := HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(bytes)
		return hashing.finish().hex_encode()


func run() -> Array[String]:
	var failures: Array[String] = []
	if not FileAccess.file_exists(ProjectSettings.globalize_path(BUILDER_PATH)):
		failures.append("backup builder implementation exists: expected %s" % BUILDER_PATH)
		return failures

	var builder_script := load(BUILDER_PATH) as Script
	TestAssertions.truthy(builder_script != null, "backup builder implementation loads", failures)
	if builder_script == null:
		return failures
	var entry_point: Object = builder_script.new()
	TestAssertions.truthy(entry_point != null, "backup builder entry point instantiates", failures)
	if entry_point == null:
		return failures
	TestAssertions.truthy(entry_point.has_method(&"parse_named_args"), "entry point exposes named CLI parsing", failures)
	TestAssertions.truthy(entry_point.has_method(&"new_service"), "entry point exposes a separately testable service", failures)
	TestAssertions.truthy(entry_point.has_method(&"new_local_filesystem"), "entry point exposes the trusted local filesystem adapter", failures)
	TestAssertions.truthy(entry_point.has_method(&"validate_local_request_paths"), "entry point validates local path forms before any filesystem or Git probe", failures)
	if not entry_point.has_method(&"parse_named_args") or not entry_point.has_method(&"new_service") or not entry_point.has_method(&"new_local_filesystem"):
		entry_point.free()
		return failures

	_prepare_fixture(failures)
	var service := entry_point.call(&"new_service") as RefCounted
	TestAssertions.truthy(service != null, "pure backup service is available without a subprocess", failures)
	var has_review_api := service != null and service.has_method(&"build_backup_with_filesystem")
	TestAssertions.truthy(has_review_api, "backup service accepts an injected local filesystem", failures)
	TestAssertions.truthy(entry_point.has_method(&"validate_git_metadata"), "entry point validates caller Git metadata against an actual probe", failures)
	if not has_review_api or not entry_point.has_method(&"validate_git_metadata"):
		_cleanup_fixture(failures)
		entry_point.free()
		return failures
	if service != null:
		_test_local_filesystem_transaction(entry_point, service, failures)
		_test_named_argument_parsing(entry_point, failures)
		_test_git_metadata_validation(entry_point, failures)
		_test_local_path_form_rejections(service, failures)
		_test_git_toplevel_configuration(service, failures)
		_test_request_rejections(service, failures)
		_test_adversarial_path_configuration(service, failures)
		_test_successful_byte_exact_backup(service, failures)
		_test_failure_preservation(service, failures)
		_test_output_creation_failure_preserves_ownership(service, failures)
		_test_partial_write_ownership_and_preservation_reporting(service, failures)
		_test_read_integrity_failures(service, failures)
		_test_no_overwrite_and_publish_failures(service, failures)
		_test_inventory_escape_rejection(service, failures)
	_cleanup_fixture(failures)
	entry_point.free()
	return failures


func _test_local_filesystem_transaction(entry_point: Object, service: RefCounted, failures: Array[String]) -> void:
	var local := entry_point.call(&"new_local_filesystem") as RefCounted
	TestAssertions.truthy(local != null, "trusted local adapter instantiates", failures)
	if local == null:
		return
	TestAssertions.truthy(not local.has_method(&"encoded_invocation") and not local.has_method(&"configure_supervision"), "trusted local adapter has no PowerShell or hostile-process machinery", failures)
	var output := _test_root.path_join("local-adapter-attempt")
	var result := service.call(&"build_backup_with_filesystem", _request(output), PackedStringArray(["assets/item.bin"]), _metadata(), local) as Dictionary
	for path: String in [output.path_join("assets/item.bin"), output.path_join(MANIFEST_NAME), output.path_join(PENDING_MANIFEST_NAME), output.path_join(FAILURE_NAME), output.path_join(PARTIAL_MANIFEST_NAME)]:
		if FileAccess.file_exists(path):
			_created_files.append(path)
	for directory: String in [output, output.path_join("assets")]:
		if DirAccess.dir_exists_absolute(directory):
			_created_directories.append(directory)
	TestAssertions.truthy(bool(result.get("ok", false)), "trusted local adapter completes a tiny deterministic backup transaction", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(output.path_join("assets/item.bin")), FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin")), "trusted local adapter preserves copied bytes", failures)
	TestAssertions.truthy(FileAccess.file_exists(output.path_join(MANIFEST_NAME)) and not FileAccess.file_exists(output.path_join(PENDING_MANIFEST_NAME)), "trusted local adapter publishes manifest last", failures)


func _test_local_path_form_rejections(service: RefCounted, failures: Array[String]) -> void:
	for unsafe_source: String in ["//server/share/project", "\\\\?\\C:\\party-forge", "\\\\.\\C:\\party-forge"]:
		var request := _request(_test_root.path_join("unsafe-source-%d" % unsafe_source.hash()), unsafe_source)
		var metadata := _metadata()
		metadata["toplevel"] = unsafe_source
		var result := service.call(&"build_backup_with_filesystem", request, PackedStringArray(["assets/item.bin"]), metadata, FixtureFilesystem.new()) as Dictionary
		TestAssertions.truthy(not bool(result.get("ok", false)) and "source_root reason=must be a local absolute path" in String(result.get("error", "")), "UNC/device source form fails closed: %s" % unsafe_source, failures)
	for unsafe_output: String in ["//server/share/backup", "\\\\?\\C:\\backup", "\\\\.\\C:\\backup"]:
		var result := _build(service, _request(unsafe_output), PackedStringArray(["assets/item.bin"]), FixtureFilesystem.new())
		TestAssertions.truthy(not bool(result.get("ok", false)) and "output reason=must be a local absolute path" in String(result.get("error", "")), "UNC/device output form fails closed: %s" % unsafe_output, failures)


func _test_git_toplevel_configuration(service: RefCounted, failures: Array[String]) -> void:
	var matching := _build(service, _request(_test_root.path_join("toplevel-matching")), PackedStringArray(["assets/item.bin"]), FixtureFilesystem.new())
	TestAssertions.truthy(bool(matching.get("ok", false)), "matching normalized source and actual Git top-level are accepted", failures)
	var mismatch_metadata := _metadata()
	mismatch_metadata["toplevel"] = _test_root
	var mismatch_output := _test_root.path_join("toplevel-mismatch")
	var mismatch := service.call(&"build_backup_with_filesystem", _request(mismatch_output), PackedStringArray(["assets/item.bin"]), mismatch_metadata, FixtureFilesystem.new()) as Dictionary
	TestAssertions.truthy(not bool(mismatch.get("ok", false)) and "actual Git top-level must equal source root" in String(mismatch.get("error", "")), "Git top-level mismatch is rejected before output creation", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(mismatch_output), "Git top-level mismatch creates no output", failures)


func _prepare_fixture(failures: Array[String]) -> void:
	var nonce := "%d-%d" % [Time.get_ticks_usec(), randi()]
	_test_root = OS.get_user_data_dir().path_join("modular-equipment-backup-builder-tests").path_join(nonce).replace("\\", "/")
	_source_root = _test_root.path_join("source")
	_outside_file = _test_root.path_join("outside.dat")
	_make_directory(_source_root.path_join("assets"), failures)
	_make_directory(_source_root.path_join("config"), failures)
	_write_bytes(_source_root.path_join("project.godot"), "[application]\nconfig/name=\"Party Forge\"\n".to_utf8_buffer(), failures)
	_write_bytes(_source_root.path_join("assets/item.bin"), PackedByteArray([0, 255, 13, 10, 65, 0, 66]), failures)
	_write_bytes(_source_root.path_join("config/info.txt"), "tiny explicit inventory\n".to_utf8_buffer(), failures)
	_write_bytes(_source_root.path_join("assets/not-in-inventory.bin"), PackedByteArray([88, 84, 82, 65]), failures)
	_write_bytes(_outside_file, PackedByteArray([79, 85, 84, 83, 73, 68, 69]), failures)


func _test_named_argument_parsing(entry_point: Object, failures: Array[String]) -> void:
	var parsed := entry_point.call(&"parse_named_args", PackedStringArray([
		"--source-root", _source_root,
		"--output=%s" % _test_root.path_join("cli-output"),
		"--source-commit", COMMIT,
		"--source-branch=%s" % BRANCH,
	])) as Dictionary
	TestAssertions.equal(parsed.get("errors", PackedStringArray()), PackedStringArray(), "all four named CLI arguments parse without positional coupling", failures)
	var request := parsed.get("request", {}) as Dictionary
	TestAssertions.equal(request.get("source_root", ""), _source_root, "CLI parser preserves explicit source root", failures)
	TestAssertions.equal(request.get("output", ""), _test_root.path_join("cli-output"), "CLI parser preserves explicit output", failures)
	TestAssertions.equal(request.get("source_commit", ""), COMMIT, "CLI parser preserves explicit source commit", failures)
	TestAssertions.equal(request.get("source_branch", ""), BRANCH, "CLI parser preserves explicit source branch", failures)
	var missing := entry_point.call(&"parse_named_args", PackedStringArray(["--source-root", _source_root])) as Dictionary
	TestAssertions.truthy((missing.get("errors", PackedStringArray()) as PackedStringArray).size() == 3, "CLI parser requires every named argument", failures)
	if entry_point.has_method(&"validate_local_request_paths"):
		var unsafe_request := _request(_test_root.path_join("cli-unsafe"), "\\\\?\\C:\\party-forge")
		TestAssertions.truthy("source_root reason=must be a local absolute path" in String(entry_point.call(&"validate_local_request_paths", unsafe_request)), "CLI rejects device paths before filesystem and Git probes", failures)


func _test_git_metadata_validation(entry_point: Object, failures: Array[String]) -> void:
	TestAssertions.equal(entry_point.call(&"validate_git_metadata", _request(_test_root.path_join("git-ok")), _metadata()), "", "matching probed Git metadata is accepted", failures)
	var wrong_head := _metadata()
	wrong_head["commit"] = "fedcba9876543210fedcba9876543210fedcba98"
	TestAssertions.truthy("source_commit reason=does not match actual Git HEAD" in String(entry_point.call(&"validate_git_metadata", _request(_test_root.path_join("git-head")), wrong_head)), "caller commit mismatch is rejected", failures)
	var wrong_branch := _metadata()
	wrong_branch["branch"] = "feat/other"
	TestAssertions.truthy("source_branch reason=does not match actual Git branch" in String(entry_point.call(&"validate_git_metadata", _request(_test_root.path_join("git-branch")), wrong_branch)), "caller branch mismatch is rejected", failures)
	var missing_toplevel := _metadata()
	missing_toplevel.erase("toplevel")
	TestAssertions.truthy("Git top-level" in String(entry_point.call(&"validate_git_metadata", _request(_test_root.path_join("git-toplevel")), missing_toplevel)), "actual Git top-level is required", failures)
	var wrong_toplevel := _metadata()
	wrong_toplevel["toplevel"] = _test_root
	TestAssertions.truthy("actual Git top-level must equal source root" in String(entry_point.call(&"validate_git_metadata", _request(_test_root.path_join("git-wrong-toplevel")), wrong_toplevel)), "CLI Git validation rejects a mismatched actual top-level before inventory or output", failures)


func _test_request_rejections(service: RefCounted, failures: Array[String]) -> void:
	var relative_request := _request("relative/output")
	var relative_result := _build(service, relative_request, _inventory())
	TestAssertions.truthy(not bool(relative_result.get("ok", false)) and "output reason=must be absolute" in String(relative_result.get("error", "")), "relative output is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(_test_root.path_join("relative/output")), "relative-output rejection creates no target", failures)

	var inside_output := _source_root.path_join("backup")
	var inside_result := _build(service, _request(inside_output), _inventory())
	TestAssertions.truthy(not bool(inside_result.get("ok", false)) and "output reason=must be outside source root" in String(inside_result.get("error", "")), "output inside the Godot project is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(inside_output), "inside-project rejection never writes to the source", failures)

	var nonempty_output := _test_root.path_join("existing-nonempty")
	_make_directory(nonempty_output, failures)
	var sentinel := nonempty_output.path_join("keep.txt")
	_write_bytes(sentinel, "keep".to_utf8_buffer(), failures)
	var nonempty_result := _build(service, _request(nonempty_output), _inventory())
	TestAssertions.truthy(not bool(nonempty_result.get("ok", false)) and "output reason=must be empty" in String(nonempty_result.get("error", "")), "existing non-empty target is rejected", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(sentinel), "keep", "non-empty target rejection preserves existing bytes", failures)

	var bad_commit_output := _test_root.path_join("bad-commit")
	var bad_commit_request := _request(bad_commit_output)
	bad_commit_request["source_commit"] = "abc123"
	var bad_commit_result := _build(service, bad_commit_request, _inventory())
	TestAssertions.truthy(not bool(bad_commit_result.get("ok", false)) and "source_commit reason=must be exactly 40 hexadecimal characters" in String(bad_commit_result.get("error", "")), "malformed source commit is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(bad_commit_output), "commit rejection creates no target", failures)

	var nested_project_root := _test_root.path_join("not-project-root")
	_make_directory(nested_project_root.path_join("nested"), failures)
	_write_bytes(nested_project_root.path_join("nested/project.godot"), "[application]\n".to_utf8_buffer(), failures)
	var wrong_root_result := _build(service, _request(_test_root.path_join("wrong-root-output"), nested_project_root), _inventory())
	TestAssertions.truthy(not bool(wrong_root_result.get("ok", false)) and "source_root reason=project.godot must exist directly under source root" in String(wrong_root_result.get("error", "")), "source must be the exact Party Forge project root", failures)


func _test_adversarial_path_configuration(service: RefCounted, failures: Array[String]) -> void:
	var relative_path := "assets/odd & $name [x];.bin"
	var source_path := _source_root.path_join(relative_path)
	_write_bytes(source_path, PackedByteArray([77, 69, 84, 65]), failures)
	var output := _test_root.path_join("external weird & $root [x];").path_join("attempt")
	var filesystem := FixtureFilesystem.new()
	filesystem.requires_configuration = true
	var result := _build(service, _request(output), PackedStringArray([relative_path]), filesystem)
	TestAssertions.truthy(bool(result.get("ok", false)), "adversarial metacharacter paths remain structured adapter arguments", failures)
	TestAssertions.equal(filesystem.configured_output_root, output, "service configures the exact output containment root before mutation", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(output.path_join(relative_path)), PackedByteArray([77, 69, 84, 65]), "adversarial path copies exact bytes", failures)


func _test_successful_byte_exact_backup(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("external").path_join("parents-created").path_join("attempt-a")
	var before_project := FileAccess.get_file_as_bytes(_source_root.path_join("project.godot"))
	var before_item := FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin"))
	var filesystem := FixtureFilesystem.new()
	var result := _build(service, _request(output), _inventory(), filesystem)
	TestAssertions.truthy(bool(result.get("ok", false)), "backup succeeds for a tiny explicit inventory", failures)
	TestAssertions.equal(filesystem.copy_calls, _inventory().size(), "each inventory file uses the verified local copy operation", failures)
	TestAssertions.truthy(DirAccess.dir_exists_absolute(output), "missing external parent directories are created safely", failures)
	for relative_path: String in _inventory():
		TestAssertions.equal(FileAccess.get_file_as_bytes(output.path_join(relative_path)), FileAccess.get_file_as_bytes(_source_root.path_join(relative_path)), "%s copies byte-for-byte" % relative_path, failures)
	TestAssertions.truthy(not FileAccess.file_exists(output.path_join("assets/not-in-inventory.bin")), "source files outside the declared inventory are not copied", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_source_root.path_join("project.godot")), before_project, "builder leaves project.godot byte-exact", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin")), before_item, "builder reads authoritative bytes without rewriting them", failures)

	var manifest_path := output.path_join(MANIFEST_NAME)
	TestAssertions.truthy(FileAccess.file_exists(manifest_path), "complete manifest is written after successful copies", failures)
	TestAssertions.truthy(not FileAccess.file_exists(output.path_join(PENDING_MANIFEST_NAME)), "successful atomic publication leaves no pending manifest", failures)
	var manifest := JSON.parse_string(FileAccess.get_file_as_string(manifest_path)) as Dictionary
	TestAssertions.equal(manifest.get("state", ""), "complete", "manifest records complete state", failures)
	TestAssertions.equal(manifest.get("expected_file_count", -1), _inventory().size(), "manifest records the exact inventory count", failures)
	var source := manifest.get("source", {}) as Dictionary
	TestAssertions.equal(source.get("commit", ""), COMMIT, "manifest records source commit", failures)
	TestAssertions.equal(source.get("branch", ""), BRANCH, "manifest records source branch", failures)
	TestAssertions.equal(source.get("worktree_status", ""), STATUS, "manifest records full dirty worktree status", failures)
	var files := manifest.get("files", []) as Array
	TestAssertions.equal(files.size(), _inventory().size(), "manifest has one row per declared path", failures)
	for index: int in files.size():
		var row := files[index] as Dictionary
		var relative_path := _inventory()[index]
		TestAssertions.equal(row.get("path", ""), relative_path, "%s records its relative path" % relative_path, failures)
		TestAssertions.equal(row.get("size", -1), FileAccess.get_file_as_bytes(_source_root.path_join(relative_path)).size(), "%s records size" % relative_path, failures)
		TestAssertions.equal(row.get("sha256", ""), FileAccess.get_sha256(_source_root.path_join(relative_path)), "%s records SHA-256 of copied bytes" % relative_path, failures)

	var second_output := _test_root.path_join("external").path_join("attempt-b")
	var repeated := _build(service, _request(second_output), _inventory())
	TestAssertions.truthy(bool(repeated.get("ok", false)), "same explicit source can be backed up to a fresh sibling", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(second_output.path_join(MANIFEST_NAME)), FileAccess.get_file_as_bytes(manifest_path), "manifest bytes are deterministic", failures)


func _test_failure_preservation(service: RefCounted, failures: Array[String]) -> void:
	var staging_root := _test_root.path_join("staging")
	_make_directory(staging_root, failures)
	var sibling_sentinel := staging_root.path_join("sibling-attempt.keep")
	_write_bytes(sibling_sentinel, "do not clean".to_utf8_buffer(), failures)
	var output := staging_root.path_join("failed-attempt")
	var inventory := _inventory()
	var filesystem := FixtureFilesystem.new()
	filesystem.read_overrides[_source_root.path_join("config/info.txt")] = {"error": "injected source read failure"}
	var result := _build(service, _request(output), inventory, filesystem)
	TestAssertions.truthy(not bool(result.get("ok", false)) and "config/info.txt" in String(result.get("error", "")), "copy failure reports the exact declared path", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(output.path_join("assets/item.bin")), FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin")), "failed attempt preserves copied bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists(output.path_join(MANIFEST_NAME)), "final manifest is absent when any copy fails", failures)
	TestAssertions.truthy(FileAccess.file_exists(output.path_join(FAILURE_NAME)), "failed attempt has a bounded failure marker", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(output.path_join(FAILURE_NAME)).size() <= 2048, "failure marker is bounded to 2048 bytes", failures)
	var partial := JSON.parse_string(FileAccess.get_file_as_string(output.path_join(PARTIAL_MANIFEST_NAME))) as Dictionary
	TestAssertions.equal(partial.get("state", ""), "failed", "partial ownership manifest records failed state", failures)
	TestAssertions.equal(partial.get("expected_file_count", -1), 2, "partial ownership manifest retains intended count", failures)
	TestAssertions.equal(partial.get("completed_file_count", -1), 1, "partial ownership manifest records only completed copies", failures)
	TestAssertions.equal(((partial.get("files", []) as Array)[0] as Dictionary).get("path", ""), "assets/item.bin", "partial ownership manifest owns only the copied inventory path", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(sibling_sentinel), "do not clean", "failure never recursively cleans the external staging root", failures)
	TestAssertions.truthy(bool(result.get("failure_marker_verified", false)) and bool(result.get("partial_manifest_verified", false)), "failure artifacts are read-back verified", failures)


func _test_output_creation_failure_preserves_ownership(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("output-create-failure")
	var filesystem := FixtureFilesystem.new()
	filesystem.ensure_failure_path = output
	var result := _build(service, _request(output), _inventory(), filesystem)
	TestAssertions.truthy(not bool(result.get("ok", false)) and "after directory creation" in String(result.get("error", "")), "failure after creating output aborts the attempt", failures)
	TestAssertions.truthy(bool(result.get("failure_marker_verified", false)) and bool(result.get("partial_manifest_verified", false)), "output-creation failure still emits verified failure artifacts", failures)
	var partial := {}
	var partial_path := output.path_join(PARTIAL_MANIFEST_NAME)
	if FileAccess.file_exists(partial_path):
		var partial_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(partial_path))
		if partial_variant is Dictionary:
			partial = partial_variant
	TestAssertions.truthy("." in (partial.get("owned_paths", []) as Array), "partially created output root is immediately recorded as owned", failures)


func _test_partial_write_ownership_and_preservation_reporting(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("partial-write-attempt")
	var filesystem := FixtureFilesystem.new()
	filesystem.create_modes[output.path_join("config/info.txt")] = "partial"
	var result := _build(service, _request(output), _inventory(), filesystem)
	TestAssertions.truthy(not bool(result.get("ok", false)) and "exclusive create" in String(result.get("error", "")), "partial destination write fails the attempt", failures)
	var partial := JSON.parse_string(FileAccess.get_file_as_string(output.path_join(PARTIAL_MANIFEST_NAME))) as Dictionary
	var owned_paths := partial.get("owned_paths", PackedStringArray()) as Array
	TestAssertions.truthy("config/info.txt" in owned_paths, "partial destination file is owned immediately", failures)
	TestAssertions.truthy("assets" in owned_paths and "config" in owned_paths and "." in owned_paths, "every created output directory is recorded as owned", failures)

	var marker_failure_output := _test_root.path_join("marker-write-failure")
	var marker_failure_fs := FixtureFilesystem.new()
	marker_failure_fs.create_modes[marker_failure_output.path_join(FAILURE_NAME)] = "fail"
	marker_failure_fs.read_overrides[_source_root.path_join("config/info.txt")] = {"error": "injected source read failure"}
	var marker_failure := _build(service, _request(marker_failure_output), _inventory(), marker_failure_fs)
	TestAssertions.truthy(not bool(marker_failure.get("failure_marker_verified", true)), "failed failure-marker write is not reported as verified", failures)
	TestAssertions.truthy("failure marker" in String(marker_failure.get("preservation_error", "")), "failure-marker write failure is reported", failures)
	TestAssertions.truthy(bool(marker_failure.get("partial_manifest_verified", false)), "partial manifest can still verify when marker creation fails", failures)


func _test_read_integrity_failures(service: RefCounted, failures: Array[String]) -> void:
	var source_path := _source_root.path_join("assets/item.bin")
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	var cases: Array[Dictionary] = [
		{"id": "source-short", "target": "source", "override": _read_result(source_bytes.slice(0, 3), source_bytes.size(), OK, _sha256(source_bytes.slice(0, 3))), "reason": "full-length"},
		{"id": "source-status", "target": "source", "override": _read_result(source_bytes, source_bytes.size(), ERR_FILE_CANT_READ, _sha256(source_bytes)), "reason": "read status"},
		{"id": "source-hash", "target": "source", "override": _read_result(source_bytes, source_bytes.size(), OK, "bad"), "reason": "SHA-256"},
		{"id": "destination-short", "target": "destination", "override": _read_result(source_bytes.slice(0, 2), source_bytes.size(), OK, _sha256(source_bytes.slice(0, 2))), "reason": "full-length"},
		{"id": "destination-status", "target": "destination", "override": _read_result(source_bytes, source_bytes.size(), ERR_FILE_CANT_READ, _sha256(source_bytes)), "reason": "read status"},
		{"id": "destination-hash", "target": "destination", "override": _read_result(source_bytes, source_bytes.size(), OK, "bad"), "reason": "SHA-256"},
		{"id": "hash-mismatch", "target": "destination", "override": _read_result(PackedByteArray([1, 2, 3, 4, 5, 6, 7]), source_bytes.size(), OK, _sha256(PackedByteArray([1, 2, 3, 4, 5, 6, 7]))), "reason": "hash mismatch"},
	]
	for test_case: Dictionary in cases:
		var output := _test_root.path_join(String(test_case["id"]))
		var filesystem := FixtureFilesystem.new()
		var target_path := source_path if test_case["target"] == "source" else output.path_join("assets/item.bin")
		filesystem.read_overrides[target_path] = test_case["override"]
		var result := _build(service, _request(output), PackedStringArray(["assets/item.bin"]), filesystem)
		TestAssertions.truthy(not bool(result.get("ok", false)) and String(test_case["reason"]) in String(result.get("error", "")), "%s read integrity fails closed" % test_case["id"], failures)
		TestAssertions.truthy(not FileAccess.file_exists(output.path_join(MANIFEST_NAME)), "%s never publishes a final manifest" % test_case["id"], failures)


func _test_no_overwrite_and_publish_failures(service: RefCounted, failures: Array[String]) -> void:
	var copy_output := _test_root.path_join("copy-collision")
	var copy_filesystem := FixtureFilesystem.new()
	copy_filesystem.create_modes[copy_output.path_join("assets/item.bin")] = "collision"
	var copy_result := _build(service, _request(copy_output), PackedStringArray(["assets/item.bin"]), copy_filesystem)
	TestAssertions.truthy(not bool(copy_result.get("ok", false)) and "collision" in String(copy_result.get("error", "")), "copied-file creation never overwrites an existing destination", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(copy_output.path_join("assets/item.bin")), "collision-sentinel", "collision bytes are never truncated or replaced", failures)
	var copy_partial := JSON.parse_string(FileAccess.get_file_as_string(copy_output.path_join(PARTIAL_MANIFEST_NAME))) as Dictionary
	TestAssertions.truthy("assets/item.bin" not in (copy_partial.get("owned_paths", []) as Array), "foreign collision file is not claimed as builder-owned", failures)

	var publish_output := _test_root.path_join("publish-collision")
	var publish_filesystem := FixtureFilesystem.new()
	publish_filesystem.publish_error = "collision"
	var publish_result := _build(service, _request(publish_output), PackedStringArray(["assets/item.bin"]), publish_filesystem)
	TestAssertions.truthy(not bool(publish_result.get("ok", false)) and "collision" in String(publish_result.get("error", "")), "atomic no-replace manifest publication fails closed on collision", failures)
	TestAssertions.truthy(not FileAccess.file_exists(publish_output.path_join(MANIFEST_NAME)), "failed publication never leaves success manifest.json", failures)
	var publish_partial := JSON.parse_string(FileAccess.get_file_as_string(publish_output.path_join(PARTIAL_MANIFEST_NAME))) as Dictionary
	TestAssertions.truthy(PENDING_MANIFEST_NAME in (publish_partial.get("owned_paths", []) as Array), "failed publication preserves and owns the pending manifest", failures)


func _test_inventory_escape_rejection(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("escape-attempt")
	var outside_before := FileAccess.get_file_as_bytes(_outside_file)
	var result := _build(service, _request(output), PackedStringArray(["../outside.dat"]))
	TestAssertions.truthy(not bool(result.get("ok", false)) and "inventory path=../outside.dat reason=must be normalized and relative" in String(result.get("error", "")), "inventory traversal is rejected before copying", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(output), "invalid inventory creates no external attempt", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_outside_file), outside_before, "escaped source candidate remains untouched", failures)


func _request(output: String, source_root: String = "") -> Dictionary:
	return {
		"source_root": _source_root if source_root.is_empty() else source_root,
		"output": output,
		"source_commit": COMMIT,
		"source_branch": BRANCH,
	}


func _inventory() -> PackedStringArray:
	return PackedStringArray(["assets/item.bin", "config/info.txt"])


func _metadata() -> Dictionary:
	return {"commit": COMMIT, "branch": BRANCH, "worktree_status": STATUS, "toplevel": _source_root}


func _build(service: RefCounted, request: Dictionary, inventory: PackedStringArray, filesystem: RefCounted = null) -> Dictionary:
	var adapter := filesystem if filesystem != null else FixtureFilesystem.new()
	var result := service.call(&"build_backup_with_filesystem", request, inventory, _metadata(), adapter) as Dictionary
	for path: String in adapter.get("created_files") as Array[String]:
		if path not in _created_files:
			_created_files.append(path)
	for directory: String in adapter.get("created_directories") as Array[String]:
		if directory not in _created_directories:
			_created_directories.append(directory)
	return result


func _read_result(bytes: PackedByteArray, expected_length: int, read_error: Error, sha256: String) -> Dictionary:
	return {"error": "", "bytes": bytes, "expected_length": expected_length, "bytes_read": bytes.size(), "position": bytes.size(), "read_error": read_error, "sha256": sha256}


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _make_directory(path: String, failures: Array[String]) -> void:
	var missing: Array[String] = []
	var cursor := path.replace("\\", "/")
	while not cursor.is_empty() and not DirAccess.dir_exists_absolute(cursor):
		missing.append(cursor)
		var parent := cursor.get_base_dir()
		if parent == cursor:
			break
		cursor = parent
	var error := DirAccess.make_dir_recursive_absolute(path)
	TestAssertions.truthy(error in [OK, ERR_ALREADY_EXISTS], "fixture directory creates: %s" % path, failures)
	missing.reverse()
	for directory: String in missing:
		_created_directories.append(directory)


func _write_bytes(path: String, bytes: PackedByteArray, failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "fixture file opens: %s" % path, failures)
	if file == null:
		return
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	TestAssertions.equal(error, OK, "fixture file writes: %s" % path, failures)
	_created_files.append(path)


func _cleanup_fixture(failures: Array[String]) -> void:
	for path: String in _created_files:
		if FileAccess.file_exists(path):
			TestAssertions.equal(DirAccess.remove_absolute(path), OK, "source fixture file removes: %s" % path, failures)
	_created_directories.reverse()
	for directory: String in _created_directories:
		if DirAccess.dir_exists_absolute(directory):
			TestAssertions.equal(DirAccess.remove_absolute(directory), OK, "fixture directory removes: %s" % directory, failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(_test_root), "disposable backup fixture is fully removed without recursive deletion", failures)
