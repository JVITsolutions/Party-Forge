extends RefCounted

const VALIDATOR_PATH := "res://tools/validate_modular_equipment_backup.gd"
const EXPECTED_PATHS := ["assets/item.bin", "config/info.txt"]
const COMMIT := "0123456789abcdef0123456789abcdef01234567"

var _test_root := ""
var _created_files: Array[String] = []
var _created_directories: Array[String] = []
var _captured_lines: Array[String] = []


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_root = ProjectSettings.globalize_path("user://modular-equipment-backup-validator-fixture-%d" % Time.get_ticks_usec())
	TestAssertions.truthy(FileAccess.file_exists(ProjectSettings.globalize_path(VALIDATOR_PATH)), "backup validator implementation exists", failures)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(VALIDATOR_PATH)):
		return failures

	var validator_script := load(VALIDATOR_PATH) as Script
	TestAssertions.truthy(validator_script != null, "backup validator loads", failures)
	if validator_script == null:
		return failures
	var entry_point: Object = validator_script.new()
	TestAssertions.truthy(entry_point.has_method(&"new_service"), "backup validator exposes an independent service", failures)
	TestAssertions.truthy(entry_point.has_method(&"run_cli"), "entry point exposes its actual CLI control flow for direct coverage", failures)
	if not entry_point.has_method(&"new_service"):
		return failures
	var service := entry_point.call(&"new_service") as RefCounted
	TestAssertions.truthy(service != null and service.has_method(&"verify_backup"), "backup verifier service exposes verification", failures)
	if service == null or not service.has_method(&"verify_backup"):
		return failures

	_test_valid_backup(service, validator_script, failures)
	_test_missing_and_extra_files(service, failures)
	_test_size_and_hash_mismatch(service, failures)
	_test_duplicate_and_escaped_paths(service, failures)
	_test_wrong_expected_count(service, failures)
	_test_malformed_json_and_absent_source(service, failures)
	_test_invalid_utf8_manifest(service, failures)
	_test_source_path_metadata(service, failures)
	_test_virtual_paths_rejected(service, entry_point, failures)
	_test_corrupt_manifest_totals(service, failures)
	_test_single_line_dynamic_errors(service, failures)
	_test_unicode_line_separator_errors(service, entry_point, failures)
	_test_deterministic_error_order(service, failures)
	if entry_point.has_method(&"run_cli"):
		_test_cli_behavior(entry_point, failures)
	_cleanup_fixture(failures)
	entry_point.free()
	return failures


func _test_valid_backup(service: RefCounted, validator_script: Script, failures: Array[String]) -> void:
	var root := _make_valid_fixture("valid", failures)
	var before := _snapshot(root)
	var manifest_bytes := FileAccess.get_file_as_bytes(root.path_join("manifest.json"))
	var result := service.call(&"verify_backup", root, PackedStringArray(EXPECTED_PATHS)) as Dictionary
	TestAssertions.truthy(bool(result.get("ok", false)), "valid backup verifies", failures)
	TestAssertions.equal(result.get("errors", PackedStringArray()), PackedStringArray(), "valid backup has no errors", failures)
	TestAssertions.equal(result.get("file_count", -1), 2, "success reports verified file count", failures)
	TestAssertions.equal(result.get("total_bytes", -1), 11, "success reports verified byte count", failures)
	TestAssertions.equal(result.get("manifest_sha256", ""), _sha256(manifest_bytes), "success reports SHA-256 of exact manifest bytes", failures)
	TestAssertions.equal(_snapshot(root), before, "verification leaves every fixture path and byte unchanged", failures)
	var dependencies := ResourceLoader.get_dependencies(VALIDATOR_PATH)
	TestAssertions.truthy("res://tools/build_modular_equipment_backup.gd" not in dependencies, "validator does not depend on or invoke the builder", failures)


func _test_missing_and_extra_files(service: RefCounted, failures: Array[String]) -> void:
	var missing_root := _make_valid_fixture("missing", failures)
	_remove_fixture_file(missing_root.path_join("config/info.txt"), failures)
	var missing := _verify_unchanged(service, missing_root, "missing-file failure is read-only", failures)
	_assert_has_error(missing, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=files path=config/info.txt reason=missing", "missing backup file rejects", failures)

	var extra_root := _make_valid_fixture("extra", failures)
	_make_directory(extra_root.path_join("other"), failures)
	_write_bytes(extra_root.path_join("other/unlisted.dat"), PackedByteArray([9]), failures)
	var extra := _verify_unchanged(service, extra_root, "extra-file failure is read-only", failures)
	_assert_has_error(extra, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=files path=other/unlisted.dat reason=unexpected", "extra backup file rejects", failures)


func _test_size_and_hash_mismatch(service: RefCounted, failures: Array[String]) -> void:
	var size_root := _make_valid_fixture("size", failures)
	_write_bytes(size_root.path_join("assets/item.bin"), PackedByteArray([77, 69, 84, 65, 88]), failures)
	var size_result := _verify_unchanged(service, size_root, "size failure is read-only", failures)
	_assert_has_error(size_result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=content path=assets/item.bin reason=size expected=4 actual=5", "size mismatch rejects", failures)

	var hash_root := _make_valid_fixture("hash", failures)
	_write_bytes(hash_root.path_join("assets/item.bin"), PackedByteArray([68, 82, 73, 70]), failures)
	var hash_result := _verify_unchanged(service, hash_root, "hash failure is read-only", failures)
	_assert_has_error(hash_result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=content path=assets/item.bin reason=sha256 mismatch", "hash mismatch rejects", failures)


func _test_duplicate_and_escaped_paths(service: RefCounted, failures: Array[String]) -> void:
	var duplicate_root := _make_valid_fixture("duplicate", failures)
	var duplicate_manifest := _read_manifest(duplicate_root)
	(duplicate_manifest["files"] as Array).append((duplicate_manifest["files"] as Array)[0].duplicate(true))
	_write_manifest(duplicate_root, duplicate_manifest, failures)
	var duplicate := _verify_unchanged(service, duplicate_root, "duplicate-path failure is read-only", failures)
	_assert_has_error(duplicate, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest path=assets/item.bin reason=duplicate", "duplicate manifest path rejects", failures)

	var escaped_root := _make_valid_fixture("escaped", failures)
	var escaped_manifest := _read_manifest(escaped_root)
	(escaped_manifest["files"] as Array)[0]["path"] = "../outside.dat"
	_write_manifest(escaped_root, escaped_manifest, failures)
	var escaped := _verify_unchanged(service, escaped_root, "escaped-path failure is read-only", failures)
	_assert_has_error(escaped, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest path=../outside.dat reason=must be normalized and relative", "escaped manifest path rejects before access", failures)


func _test_wrong_expected_count(service: RefCounted, failures: Array[String]) -> void:
	var root := _make_valid_fixture("count", failures)
	var manifest := _read_manifest(root)
	manifest["expected_file_count"] = 3
	_write_manifest(root, manifest, failures)
	var result := _verify_unchanged(service, root, "expected-count failure is read-only", failures)
	_assert_has_error(result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=expected_file_count expected=2 actual=3", "wrong expected count rejects", failures)


func _test_malformed_json_and_absent_source(service: RefCounted, failures: Array[String]) -> void:
	var malformed_root := _make_valid_fixture("malformed", failures)
	_write_bytes(malformed_root.path_join("manifest.json"), "{not-json".to_utf8_buffer(), failures)
	var malformed := _verify_unchanged(service, malformed_root, "malformed-JSON failure is read-only", failures)
	_assert_has_error(malformed, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest reason=malformed JSON", "malformed JSON rejects", failures)

	var source_root := _make_valid_fixture("source", failures)
	var source_manifest := _read_manifest(source_root)
	source_manifest.erase("source")
	_write_manifest(source_root, source_manifest, failures)
	var absent_source := _verify_unchanged(service, source_root, "absent-source failure is read-only", failures)
	_assert_has_error(absent_source, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=source reason=missing metadata", "absent source metadata rejects", failures)


func _test_invalid_utf8_manifest(service: RefCounted, failures: Array[String]) -> void:
	var root := _make_valid_fixture("invalid-utf8", failures)
	var invalid_bytes := PackedByteArray([123, 34, 120, 34, 58, 34, 195, 40, 34, 125])
	_write_bytes(root.path_join("manifest.json"), invalid_bytes, failures)
	var result := _verify_unchanged(service, root, "invalid-UTF-8 failure is read-only", failures)
	_assert_has_error(result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest reason=invalid UTF-8", "invalid UTF-8 rejects before JSON parsing", failures)
	TestAssertions.equal(result.get("manifest_sha256", ""), _sha256(invalid_bytes), "invalid UTF-8 still reports raw manifest-byte SHA-256", failures)


func _test_source_path_metadata(service: RefCounted, failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"id": "relative-root", "field": "root", "value": "relative/source"},
		{"id": "unnormalized-root", "field": "root", "value": "C:/trusted/../party-forge"},
		{"id": "unc-root", "field": "root", "value": "//server/share/party-forge"},
		{"id": "device-root", "field": "root", "value": "//?/C:/trusted/party-forge"},
		{"id": "relative-toplevel", "field": "toplevel", "value": "relative/source"},
		{"id": "unc-toplevel", "field": "toplevel", "value": "//server/share/party-forge"},
	]
	for test_case: Dictionary in cases:
		var root := _make_valid_fixture(String(test_case["id"]), failures)
		var manifest := _read_manifest(root)
		(manifest["source"] as Dictionary)[test_case["field"]] = test_case["value"]
		_write_manifest(root, manifest, failures)
		var result := _verify_unchanged(service, root, "%s source-path failure is read-only" % test_case["id"], failures)
		_assert_has_error(result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=source.%s reason=must be a normalized local absolute path" % test_case["field"], "%s source path rejects" % test_case["id"], failures)

	var mismatch_root := _make_valid_fixture("source-mismatch", failures)
	var mismatch_manifest := _read_manifest(mismatch_root)
	(mismatch_manifest["source"] as Dictionary)["toplevel"] = "C:/trusted/other-checkout"
	_write_manifest(mismatch_root, mismatch_manifest, failures)
	var mismatch := _verify_unchanged(service, mismatch_root, "source identity mismatch is read-only", failures)
	_assert_has_error(mismatch, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=source reason=root and toplevel must identify the same path", "source root and top-level mismatch rejects", failures)

	var case_root := _make_valid_fixture("source-case", failures)
	var case_manifest := _read_manifest(case_root)
	(case_manifest["source"] as Dictionary)["toplevel"] = "c:/TRUSTED/PARTY-FORGE"
	_write_manifest(case_root, case_manifest, failures)
	var case_result := service.call(&"verify_backup", case_root, PackedStringArray(EXPECTED_PATHS)) as Dictionary
	TestAssertions.truthy(bool(case_result.get("ok", false)), "source root and top-level compare case-insensitively", failures)


func _test_virtual_paths_rejected(service: RefCounted, entry_point: Object, failures: Array[String]) -> void:
	var schemes := ["res://", "user://", "custom://backup"]
	for scheme: String in schemes:
		var service_result := service.call(&"verify_backup", scheme, PackedStringArray(EXPECTED_PATHS)) as Dictionary
		_assert_has_error(service_result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=request field=backup_root reason=must be an explicit local absolute path", "%s service backup root rejects" % scheme, failures)
		_captured_lines.clear()
		var cli_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--backup-root", scheme]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
		TestAssertions.equal(cli_exit, 1, "%s CLI backup root exits nonzero" % scheme, failures)
		TestAssertions.equal(_captured_lines, ["PARTY_FORGE_MODULAR_BACKUP_ERROR stage=request field=backup_root reason=must be an explicit local absolute path"], "%s CLI backup root rejects as local-drive error" % scheme, failures)

	for field: String in ["root", "toplevel"]:
		for scheme: String in schemes:
			var root := _make_valid_fixture("virtual-%s-%s" % [field, scheme.get_slice(":", 0)], failures)
			var manifest := _read_manifest(root)
			(manifest["source"] as Dictionary)[field] = scheme
			_write_manifest(root, manifest, failures)
			var service_result := _verify_unchanged(service, root, "%s %s service failure is read-only" % [field, scheme], failures)
			var expected := "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=source.%s reason=must be a normalized local absolute path" % field
			_assert_has_error(service_result, expected, "%s %s service source metadata rejects" % [field, scheme], failures)
			var before := _snapshot(root)
			_captured_lines.clear()
			var cli_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--backup-root", root]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
			TestAssertions.equal(cli_exit, 1, "%s %s CLI source metadata exits nonzero" % [field, scheme], failures)
			TestAssertions.truthy(expected in _captured_lines, "%s %s CLI source metadata rejects" % [field, scheme], failures)
			TestAssertions.equal(_snapshot(root), before, "%s %s CLI source failure is read-only" % [field, scheme], failures)


func _test_corrupt_manifest_totals(service: RefCounted, failures: Array[String]) -> void:
	var count_root := _make_valid_fixture("file-count", failures)
	var count_manifest := _read_manifest(count_root)
	count_manifest["file_count"] = 3
	_write_manifest(count_root, count_manifest, failures)
	var count_result := _verify_unchanged(service, count_root, "file-count failure is read-only", failures)
	_assert_has_error(count_result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=file_count expected=2 actual=3", "corrupt file_count rejects directly", failures)

	var bytes_root := _make_valid_fixture("total-bytes", failures)
	var bytes_manifest := _read_manifest(bytes_root)
	bytes_manifest["total_bytes"] = 12
	_write_manifest(bytes_root, bytes_manifest, failures)
	var bytes_result := _verify_unchanged(service, bytes_root, "total-bytes failure is read-only", failures)
	_assert_has_error(bytes_result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest field=total_bytes expected=11 actual=12", "corrupt total_bytes rejects directly", failures)


func _test_single_line_dynamic_errors(service: RefCounted, failures: Array[String]) -> void:
	var root := _make_valid_fixture("single-line", failures)
	var manifest := _read_manifest(root)
	(manifest["files"] as Array)[0]["path"] = "bad\r\n%s.dat" % String.chr(1)
	_write_manifest(root, manifest, failures)
	var result := _verify_unchanged(service, root, "control-character failure is read-only", failures)
	_assert_has_error(result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest path=bad%0D%0A%01.dat reason=must be normalized and relative", "dynamic controls are percent-encoded", failures)
	_assert_physical_error_lines(result.get("errors", PackedStringArray()) as PackedStringArray, "service errors", failures)


func _test_unicode_line_separator_errors(service: RefCounted, entry_point: Object, failures: Array[String]) -> void:
	var root := _make_valid_fixture("unicode-lines", failures)
	var manifest := _read_manifest(root)
	(manifest["files"] as Array)[0]["path"] = "bad%svalue%s.dat" % [String.chr(0x2028), String.chr(0x2029)]
	_write_manifest(root, manifest, failures)
	var result := _verify_unchanged(service, root, "Unicode-separator service failure is read-only", failures)
	_assert_has_error(result, "PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest path=bad%2028value%2029.dat reason=unexpected", "service encodes Unicode line separators", failures)
	_assert_physical_error_lines(result.get("errors", PackedStringArray()) as PackedStringArray, "Unicode service errors", failures)

	_captured_lines.clear()
	var cli_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--bad%svalue%s" % [String.chr(0x2028), String.chr(0x2029)]]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
	TestAssertions.equal(cli_exit, 1, "CLI rejects Unicode-separator argument", failures)
	_assert_physical_error_lines(PackedStringArray(_captured_lines), "Unicode CLI errors", failures)
	TestAssertions.truthy("argument=--bad%2028value%2029" in _captured_lines[1 if _captured_lines.size() > 1 else 0], "CLI encodes Unicode line separators", failures)


func _test_deterministic_error_order(service: RefCounted, failures: Array[String]) -> void:
	var root := _make_valid_fixture("ordering", failures)
	_remove_fixture_file(root.path_join("config/info.txt"), failures)
	_write_bytes(root.path_join("z-extra.dat"), PackedByteArray([1]), failures)
	var manifest := _read_manifest(root)
	manifest["expected_file_count"] = 9
	(manifest["files"] as Array).append((manifest["files"] as Array)[0].duplicate(true))
	_write_manifest(root, manifest, failures)
	var before := _snapshot(root)
	var first := service.call(&"verify_backup", root, PackedStringArray(EXPECTED_PATHS)) as Dictionary
	var second := service.call(&"verify_backup", root, PackedStringArray(EXPECTED_PATHS)) as Dictionary
	TestAssertions.equal(_snapshot(root), before, "repeated combined-error verification is read-only", failures)
	var errors := first.get("errors", PackedStringArray()) as PackedStringArray
	var sorted_errors := errors.duplicate()
	sorted_errors.sort()
	TestAssertions.truthy(not errors.is_empty(), "combined invalid fixture produces errors", failures)
	TestAssertions.equal(errors, sorted_errors, "all errors have stable ordinal ordering", failures)
	TestAssertions.equal(second.get("errors", PackedStringArray()), errors, "repeated verification returns identical errors", failures)


func _test_cli_behavior(entry_point: Object, failures: Array[String]) -> void:
	var success_root := _make_valid_fixture("cli-success", failures)
	var success_manifest_bytes := FileAccess.get_file_as_bytes(success_root.path_join("manifest.json"))
	_captured_lines.clear()
	var success_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--backup-root", success_root]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
	TestAssertions.equal(success_exit, 0, "actual CLI control flow returns zero for a valid backup", failures)
	TestAssertions.equal(_captured_lines, ["PARTY_FORGE_MODULAR_BACKUP_OK files=2 bytes=11 manifest_sha256=%s" % _sha256(success_manifest_bytes)], "actual CLI prints success counts and raw manifest SHA", failures)

	_captured_lines.clear()
	var argument_exit := int(entry_point.call(&"run_cli", PackedStringArray(), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
	TestAssertions.equal(argument_exit, 1, "actual CLI control flow returns nonzero for missing arguments", failures)
	TestAssertions.equal(_captured_lines, ["PARTY_FORGE_MODULAR_BACKUP_ERROR stage=request argument=--backup-root reason=required"], "actual CLI prints the stable missing-argument error", failures)

	var malformed_root := _make_valid_fixture("cli-malformed", failures)
	_write_bytes(malformed_root.path_join("manifest.json"), "{broken".to_utf8_buffer(), failures)
	var before := _snapshot(malformed_root)
	_captured_lines.clear()
	var malformed_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--backup-root=%s" % malformed_root]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
	TestAssertions.equal(malformed_exit, 1, "actual CLI control flow returns nonzero for invalid backup", failures)
	TestAssertions.equal(_captured_lines, ["PARTY_FORGE_MODULAR_BACKUP_ERROR stage=manifest reason=malformed JSON"], "actual CLI prints one stable verifier error per problem", failures)
	TestAssertions.equal(_snapshot(malformed_root), before, "actual failing CLI control flow is read-only", failures)

	_captured_lines.clear()
	var control_exit := int(entry_point.call(&"run_cli", PackedStringArray(["--bad\r\n%s" % String.chr(2)]), PackedStringArray(EXPECTED_PATHS), Callable(self, &"_capture_line")))
	TestAssertions.equal(control_exit, 1, "actual CLI rejects unknown control-bearing arguments", failures)
	_assert_physical_error_lines(PackedStringArray(_captured_lines), "CLI errors", failures)
	TestAssertions.truthy("argument=--bad%0D%0A%02" in _captured_lines[1 if _captured_lines.size() > 1 else 0], "CLI encodes dynamic argument controls", failures)


func _make_valid_fixture(id: String, failures: Array[String]) -> String:
	var root := _test_root.path_join(id)
	_make_directory(root.path_join("assets"), failures)
	_make_directory(root.path_join("config"), failures)
	_write_bytes(root.path_join("assets/item.bin"), PackedByteArray([77, 69, 84, 65]), failures)
	_write_bytes(root.path_join("config/info.txt"), "fixture".to_utf8_buffer(), failures)
	_write_manifest(root, _valid_manifest(root), failures)
	return root


func _valid_manifest(root: String) -> Dictionary:
	var item_bytes := FileAccess.get_file_as_bytes(root.path_join("assets/item.bin"))
	var info_bytes := FileAccess.get_file_as_bytes(root.path_join("config/info.txt"))
	return {
		"schema_version": 1,
		"state": "complete",
		"source": {
			"root": "C:/trusted/party-forge",
			"commit": COMMIT,
			"branch": "feat/fixture",
			"worktree_status": " M fixture.txt\n",
			"toplevel": "C:/trusted/party-forge",
		},
		"expected_file_count": 2,
		"file_count": 2,
		"total_bytes": item_bytes.size() + info_bytes.size(),
		"files": [
			{"path": "assets/item.bin", "size": item_bytes.size(), "sha256": _sha256(item_bytes)},
			{"path": "config/info.txt", "size": info_bytes.size(), "sha256": _sha256(info_bytes)},
		],
	}


func _read_manifest(root: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(root.path_join("manifest.json"))) as Dictionary


func _write_manifest(root: String, manifest: Dictionary, failures: Array[String]) -> void:
	_write_bytes(root.path_join("manifest.json"), JSON.stringify(manifest, "\t", true).to_utf8_buffer(), failures)


func _verify_unchanged(service: RefCounted, root: String, label: String, failures: Array[String]) -> Dictionary:
	var before := _snapshot(root)
	var result := service.call(&"verify_backup", root, PackedStringArray(EXPECTED_PATHS)) as Dictionary
	TestAssertions.equal(_snapshot(root), before, label, failures)
	return result


func _capture_line(line: String) -> void:
	_captured_lines.append(line)


func _assert_physical_error_lines(lines: PackedStringArray, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not lines.is_empty(), "%s are present" % label, failures)
	for line: String in lines:
		TestAssertions.truthy(line.begins_with("PARTY_FORGE_MODULAR_BACKUP_ERROR "), "%s retain the exact prefix: %s" % [label, line], failures)
		TestAssertions.truthy(not _has_physical_line_separator(line), "%s contain no physical line separators: %s" % [label, line], failures)


func _has_physical_line_separator(value: String) -> bool:
	for index: int in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) or codepoint in [0x2028, 0x2029]:
			return true
	return false


func _assert_has_error(result: Dictionary, expected: String, label: String, failures: Array[String]) -> void:
	var errors := result.get("errors", PackedStringArray()) as PackedStringArray
	TestAssertions.truthy(not bool(result.get("ok", true)) and expected in errors, "%s: %s" % [label, errors], failures)


func _snapshot(root: String) -> Dictionary:
	var snapshot := {}
	_snapshot_directory(root, root, snapshot)
	return snapshot


func _snapshot_directory(root: String, directory_path: String, snapshot: Dictionary) -> void:
	var relative_directory := directory_path.trim_prefix(root).trim_prefix("/").trim_prefix("\\")
	for file_name: String in DirAccess.get_files_at(directory_path):
		var relative_path := file_name if relative_directory.is_empty() else relative_directory.path_join(file_name).replace("\\", "/")
		snapshot[relative_path] = FileAccess.get_file_as_bytes(directory_path.path_join(file_name))
	for directory_name: String in DirAccess.get_directories_at(directory_path):
		_snapshot_directory(root, directory_path.path_join(directory_name), snapshot)


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
		if directory not in _created_directories:
			_created_directories.append(directory)


func _write_bytes(path: String, bytes: PackedByteArray, failures: Array[String]) -> void:
	var existed := FileAccess.file_exists(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "fixture file opens: %s" % path, failures)
	if file == null:
		return
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	TestAssertions.equal(error, OK, "fixture file writes: %s" % path, failures)
	if not existed:
		_created_files.append(path)


func _remove_fixture_file(path: String, failures: Array[String]) -> void:
	TestAssertions.equal(DirAccess.remove_absolute(path), OK, "fixture setup removes: %s" % path, failures)
	_created_files.erase(path)


func _cleanup_fixture(failures: Array[String]) -> void:
	for path: String in _created_files:
		if FileAccess.file_exists(path):
			TestAssertions.equal(DirAccess.remove_absolute(path), OK, "fixture file removes: %s" % path, failures)
	_created_directories.reverse()
	for directory: String in _created_directories:
		if DirAccess.dir_exists_absolute(directory):
			TestAssertions.equal(DirAccess.remove_absolute(directory), OK, "fixture directory removes: %s" % directory, failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(_test_root), "disposable validator fixtures are fully removed", failures)
