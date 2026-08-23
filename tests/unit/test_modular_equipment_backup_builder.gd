extends RefCounted

const BUILDER_PATH := "res://tools/build_modular_equipment_backup.gd"
const MANIFEST_NAME := "manifest.json"
const FAILURE_NAME := "backup.failure.json"
const PARTIAL_MANIFEST_NAME := "partial-manifest.json"
const COMMIT := "0123456789abcdef0123456789abcdef01234567"
const BRANCH := "feat/test-backup"
const STATUS := " M assets/item.bin\n?? notes/untracked.txt\n"

var _test_root := ""
var _source_root := ""
var _outside_file := ""
var _created_files: Array[String] = []
var _created_directories: Array[String] = []


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
	if not entry_point.has_method(&"parse_named_args") or not entry_point.has_method(&"new_service"):
		entry_point.free()
		return failures

	_prepare_fixture(failures)
	var service := entry_point.call(&"new_service") as RefCounted
	TestAssertions.truthy(service != null and service.has_method(&"build_backup"), "pure backup service is available without a subprocess", failures)
	if service != null and service.has_method(&"build_backup"):
		_test_named_argument_parsing(entry_point, failures)
		_test_request_rejections(service, failures)
		_test_successful_byte_exact_backup(service, failures)
		_test_failure_preservation(service, failures)
		_test_inventory_escape_rejection(service, failures)
	_cleanup_fixture(failures)
	entry_point.free()
	return failures


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


func _test_request_rejections(service: RefCounted, failures: Array[String]) -> void:
	var relative_request := _request("relative/output")
	var relative_result := service.call(&"build_backup", relative_request, _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(not bool(relative_result.get("ok", false)) and "output reason=must be absolute" in String(relative_result.get("error", "")), "relative output is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(_test_root.path_join("relative/output")), "relative-output rejection creates no target", failures)

	var inside_output := _source_root.path_join("backup")
	var inside_result := service.call(&"build_backup", _request(inside_output), _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(not bool(inside_result.get("ok", false)) and "output reason=must be outside source root" in String(inside_result.get("error", "")), "output inside the Godot project is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(inside_output), "inside-project rejection never writes to the source", failures)

	var nonempty_output := _test_root.path_join("existing-nonempty")
	_make_directory(nonempty_output, failures)
	var sentinel := nonempty_output.path_join("keep.txt")
	_write_bytes(sentinel, "keep".to_utf8_buffer(), failures)
	var nonempty_result := service.call(&"build_backup", _request(nonempty_output), _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(not bool(nonempty_result.get("ok", false)) and "output reason=must be empty" in String(nonempty_result.get("error", "")), "existing non-empty target is rejected", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(sentinel), "keep", "non-empty target rejection preserves existing bytes", failures)

	var bad_commit_output := _test_root.path_join("bad-commit")
	var bad_commit_request := _request(bad_commit_output)
	bad_commit_request["source_commit"] = "abc123"
	var bad_commit_result := service.call(&"build_backup", bad_commit_request, _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(not bool(bad_commit_result.get("ok", false)) and "source_commit reason=must be exactly 40 hexadecimal characters" in String(bad_commit_result.get("error", "")), "malformed source commit is rejected", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(bad_commit_output), "commit rejection creates no target", failures)

	var nested_project_root := _test_root.path_join("not-project-root")
	_make_directory(nested_project_root.path_join("nested"), failures)
	_write_bytes(nested_project_root.path_join("nested/project.godot"), "[application]\n".to_utf8_buffer(), failures)
	var wrong_root_result := service.call(&"build_backup", _request(_test_root.path_join("wrong-root-output"), nested_project_root), _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(not bool(wrong_root_result.get("ok", false)) and "source_root reason=project.godot must exist directly under source root" in String(wrong_root_result.get("error", "")), "source must be the exact Party Forge project root", failures)


func _test_successful_byte_exact_backup(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("external").path_join("parents-created").path_join("attempt-a")
	var before_project := FileAccess.get_file_as_bytes(_source_root.path_join("project.godot"))
	var before_item := FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin"))
	var result := service.call(&"build_backup", _request(output), _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(bool(result.get("ok", false)), "backup succeeds for a tiny explicit inventory", failures)
	TestAssertions.truthy(DirAccess.dir_exists_absolute(output), "missing external parent directories are created safely", failures)
	for relative_path: String in _inventory():
		TestAssertions.equal(FileAccess.get_file_as_bytes(output.path_join(relative_path)), FileAccess.get_file_as_bytes(_source_root.path_join(relative_path)), "%s copies byte-for-byte" % relative_path, failures)
	TestAssertions.truthy(not FileAccess.file_exists(output.path_join("assets/not-in-inventory.bin")), "source files outside the declared inventory are not copied", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_source_root.path_join("project.godot")), before_project, "builder leaves project.godot byte-exact", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(_source_root.path_join("assets/item.bin")), before_item, "builder reads authoritative bytes without rewriting them", failures)

	var manifest_path := output.path_join(MANIFEST_NAME)
	TestAssertions.truthy(FileAccess.file_exists(manifest_path), "complete manifest is written after successful copies", failures)
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
	var repeated := service.call(&"build_backup", _request(second_output), _inventory(), STATUS) as Dictionary
	TestAssertions.truthy(bool(repeated.get("ok", false)), "same explicit source can be backed up to a fresh sibling", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(second_output.path_join(MANIFEST_NAME)), FileAccess.get_file_as_bytes(manifest_path), "manifest bytes are deterministic", failures)


func _test_failure_preservation(service: RefCounted, failures: Array[String]) -> void:
	var staging_root := _test_root.path_join("staging")
	_make_directory(staging_root, failures)
	var sibling_sentinel := staging_root.path_join("sibling-attempt.keep")
	_write_bytes(sibling_sentinel, "do not clean".to_utf8_buffer(), failures)
	var output := staging_root.path_join("failed-attempt")
	var inventory := PackedStringArray(["assets/item.bin", "config/missing.txt"])
	var result := service.call(&"build_backup", _request(output), inventory, STATUS) as Dictionary
	TestAssertions.truthy(not bool(result.get("ok", false)) and "config/missing.txt" in String(result.get("error", "")), "copy failure reports the exact declared path", failures)
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


func _test_inventory_escape_rejection(service: RefCounted, failures: Array[String]) -> void:
	var output := _test_root.path_join("escape-attempt")
	var outside_before := FileAccess.get_file_as_bytes(_outside_file)
	var result := service.call(&"build_backup", _request(output), PackedStringArray(["../outside.dat"]), STATUS) as Dictionary
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
	var generated_files := [
		_test_root.path_join("external/parents-created/attempt-a/assets/item.bin"),
		_test_root.path_join("external/parents-created/attempt-a/config/info.txt"),
		_test_root.path_join("external/parents-created/attempt-a/manifest.json"),
		_test_root.path_join("external/attempt-b/assets/item.bin"),
		_test_root.path_join("external/attempt-b/config/info.txt"),
		_test_root.path_join("external/attempt-b/manifest.json"),
		_test_root.path_join("staging/failed-attempt/assets/item.bin"),
		_test_root.path_join("staging/failed-attempt/backup.failure.json"),
		_test_root.path_join("staging/failed-attempt/partial-manifest.json"),
	]
	for path: String in generated_files:
		if FileAccess.file_exists(path):
			TestAssertions.equal(DirAccess.remove_absolute(path), OK, "generated fixture file removes: %s" % path, failures)
	for path: String in _created_files:
		if FileAccess.file_exists(path):
			TestAssertions.equal(DirAccess.remove_absolute(path), OK, "source fixture file removes: %s" % path, failures)
	var generated_directories := [
		_test_root.path_join("external/parents-created/attempt-a/assets"),
		_test_root.path_join("external/parents-created/attempt-a/config"),
		_test_root.path_join("external/parents-created/attempt-a"),
		_test_root.path_join("external/parents-created"),
		_test_root.path_join("external/attempt-b/assets"),
		_test_root.path_join("external/attempt-b/config"),
		_test_root.path_join("external/attempt-b"),
		_test_root.path_join("external"),
		_test_root.path_join("staging/failed-attempt/assets"),
		_test_root.path_join("staging/failed-attempt"),
	]
	for directory: String in generated_directories:
		if DirAccess.dir_exists_absolute(directory):
			TestAssertions.equal(DirAccess.remove_absolute(directory), OK, "generated fixture directory removes: %s" % directory, failures)
	_created_directories.reverse()
	for directory: String in _created_directories:
		if DirAccess.dir_exists_absolute(directory):
			TestAssertions.equal(DirAccess.remove_absolute(directory), OK, "fixture directory removes: %s" % directory, failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(_test_root), "disposable backup fixture is fully removed without recursive deletion", failures)
