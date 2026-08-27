extends RefCounted

const Entry = preload("res://tools/import_latticewright_access_snapshot.gd")
const GeneratedWriter = preload("res://scripts/tools/generated_json_document_writer.gd")

var _lines: Array[String] = []
var _writes := 0
var _target := PackedByteArray([1, 2, 3])

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_import_and_parity(failures)
	_test_rejected_paths_do_not_write(failures)
	_test_production_default_writer_lifetime(failures)
	return failures

func _test_import_and_parity(failures: Array[String]) -> void:
	_target = PackedByteArray([1, 2, 3]); _writes = 0; _lines.clear()
	var candidate := _candidate()
	var service: Variant = Entry.new_service(_dependencies(candidate, PackedByteArray([4, 5, 6])))
	var imported: Variant = service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(imported, 0, "service imports a changed candidate", failures)
	TestAssertions.equal(_writes, 1, "changed candidate writes exactly once", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=IMPORTED adapter=latticewright-runtime-v3-city-access stage=verified"], "service prints one imported marker", failures)
	_target = PackedByteArray([1, 2, 3]); _writes = 0; _lines.clear()
	var debt_dependencies := _dependencies(candidate, PackedByteArray([4, 5, 6]))
	debt_dependencies["writer"] = Callable(self, "_write_cleanup_debt")
	var debt_service: Variant = Entry.new_service(debt_dependencies)
	TestAssertions.equal(debt_service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture")), 0, "committed cleanup debt remains imported", failures)
	TestAssertions.truthy(debt_service.last_cleanup_debt is bool and debt_service.last_cleanup_debt == true, "service preserves truthful committed cleanup debt", failures)
	_target = PackedByteArray([4, 5, 6]); _writes = 0; _lines.clear()
	var unchanged: Variant = Entry.new_service(_dependencies(candidate, PackedByteArray([4, 5, 6]))).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(unchanged, 0, "target-byte parity exits zero", failures)
	TestAssertions.equal(_writes, 0, "target-byte parity does not write", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare"], "service prints one unchanged marker", failures)

func _test_rejected_paths_do_not_write(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"label": "missing arguments", "args": PackedStringArray(), "dependencies": _dependencies(_candidate(), PackedByteArray([4]))},
		{"label": "repeated arguments", "args": PackedStringArray(["--source", "a", "--source", "b"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]))},
		{"label": "unknown arguments", "args": PackedStringArray(["--other", "a"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]))},
		{"label": "read failure", "args": PackedStringArray(["--source", "a"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]), Callable(self, "_read_failure"))},
		{"label": "translate failure", "args": PackedStringArray(["--source", "a"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]), Callable(self, "_read_success"), Callable(self, "_translate_failure"))},
		{"label": "validate failure", "args": PackedStringArray(["--source", "a"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]), Callable(self, "_read_success"), Callable(self, "_translate_success"), Callable(self, "_validate_failure"))},
		{"label": "writer failure", "args": PackedStringArray(["--source", "a"]), "dependencies": _dependencies(_candidate(), PackedByteArray([4]), Callable(self, "_read_success"), Callable(self, "_translate_success"), Callable(self, "_validate_success"), Callable(self, "_encode_success"), Callable(self, "_write_failure"))},
	]:
		_target = PackedByteArray([9, 8, 7]); _writes = 0; _lines.clear()
		var exit_code: Variant = Entry.new_service(test_case["dependencies"] as Dictionary).run(test_case["args"] as PackedStringArray, Callable(self, "_capture"))
		TestAssertions.equal(exit_code, 1, "%s exits rejected" % test_case["label"], failures)
		TestAssertions.equal(_writes, 0, "%s never writes" % test_case["label"], failures)
		TestAssertions.equal(_target, PackedByteArray([9, 8, 7]), "%s preserves exact target bytes" % test_case["label"], failures)
		TestAssertions.equal(_lines.size(), 1, "%s prints exactly one terminal marker" % test_case["label"], failures)
		TestAssertions.truthy(_lines[0].begins_with("PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage="), "%s has sanitized rejected marker" % test_case["label"], failures)
		TestAssertions.truthy(not _lines[0].contains("secret"), "%s marker omits source details" % test_case["label"], failures)
	_target = PackedByteArray([9, 8, 7]); _writes = 0; _lines.clear()
	var corrupting := _dependencies(_candidate(), PackedByteArray([4, 5, 6]))
	corrupting["writer"] = Callable(self, "_write_corrupt")
	corrupting["target_restorer"] = Callable(self, "_restore_target")
	var verify_exit: Variant = Entry.new_service(corrupting).run(PackedStringArray(["--source", "a"]), Callable(self, "_capture"))
	TestAssertions.equal(verify_exit, 1, "post-write byte mismatch rejects", failures)
	TestAssertions.equal(_target, PackedByteArray([9, 8, 7]), "post-write byte mismatch restores exact target bytes", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage=verified"], "post-write mismatch has one verified marker", failures)
	_target = PackedByteArray([9, 8, 7]); _writes = 0; _lines.clear()
	var failed_commit := _dependencies(_candidate(), PackedByteArray([4, 5, 6]))
	failed_commit["writer"] = Callable(self, "_write_mutating_failure")
	failed_commit["target_restorer"] = Callable(self, "_restore_target")
	var promote_exit: Variant = Entry.new_service(failed_commit).run(PackedStringArray(["--source", "a"]), Callable(self, "_capture"))
	TestAssertions.equal(promote_exit, 1, "writer failure after mutation rejects", failures)
	TestAssertions.equal(_target, PackedByteArray([9, 8, 7]), "writer failure after mutation restores exact target bytes", failures)
	_target = PackedByteArray([9, 8, 7]); _writes = 0; _lines.clear()
	var legacy_writer := _dependencies(_candidate(), PackedByteArray([4, 5, 6]))
	legacy_writer["writer"] = Callable(self, "_write_legacy_success")
	legacy_writer["target_restorer"] = Callable(self, "_restore_target")
	var legacy_exit: Variant = Entry.new_service(legacy_writer).run(PackedStringArray(["--source", "a"]), Callable(self, "_capture"))
	TestAssertions.equal(legacy_exit, 1, "legacy writer return shape rejects", failures)
	TestAssertions.equal(_target, PackedByteArray([9, 8, 7]), "legacy writer return shape restores exact target bytes", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage=write"], "legacy writer has one write marker", failures)

func _test_production_default_writer_lifetime(failures: Array[String]) -> void:
	var target := GeneratedWriter.TARGET
	var access_directory := target.get_base_dir()
	var world_directory := access_directory.get_base_dir()
	var staging_directory := GeneratedWriter.STAGING_ROOT
	var staging_parent := staging_directory.get_base_dir()
	var target_existed := FileAccess.file_exists(target)
	var target_bytes := FileAccess.get_file_as_bytes(target) if target_existed else PackedByteArray()
	var access_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(access_directory))
	var world_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_directory))
	var staging_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_directory))
	var staging_parent_existed := DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_parent))
	_lines.clear()
	var service: Variant = Entry.new_service({"reader": Callable(self, "_read_success"), "translator": Callable(self, "_translate_success")})
	var exit_code: Variant = service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(exit_code, 0, "production default writer remains callable for the service lifetime", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=IMPORTED adapter=latticewright-runtime-v3-city-access stage=verified"], "production default writer emits imported marker", failures)
	TestAssertions.truthy(FileAccess.file_exists(target), "production default writer writes the fixed target", failures)
	_restore_production_artifacts(target, target_existed, target_bytes, access_directory, access_existed, world_directory, world_existed, staging_directory, staging_existed, staging_parent, staging_parent_existed)
	TestAssertions.equal(FileAccess.file_exists(target), target_existed, "production default writer restores fixed target existence", failures)
	if target_existed:
		TestAssertions.equal(FileAccess.get_file_as_bytes(target), target_bytes, "production default writer restores fixed target bytes", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(access_directory)), access_existed, "production default writer restores target directory", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_directory)), world_existed, "production default writer restores target parent directory", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_directory)), staging_existed, "production default writer restores staging directory", failures)
	TestAssertions.equal(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_parent)), staging_parent_existed, "production default writer restores staging parent directory", failures)

func _dependencies(candidate: Dictionary, encoded: PackedByteArray, reader: Callable = Callable(), translator: Callable = Callable(), validator: Callable = Callable(), encoder: Callable = Callable(), writer: Callable = Callable()) -> Dictionary:
	return {"reader": reader if reader.is_valid() else Callable(self, "_read_success"), "translator": translator if translator.is_valid() else Callable(self, "_translate_success"), "validator": validator if validator.is_valid() else Callable(self, "_validate_success"), "encoder": encoder if encoder.is_valid() else Callable(self, "_encode_success"), "writer": writer if writer.is_valid() else Callable(self, "_write_success"), "target_reader": Callable(self, "_target_reader"), "target_restorer": Callable(self, "_restore_target"), "candidate": candidate, "encoded": encoded}

func _read_success(_path: String, _maximum: int) -> Dictionary:
	return {"ok": true, "document": {"source": true}, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}

func _read_failure(_path: String, _maximum: int) -> Dictionary:
	return {"ok": false, "stage": "read path=secret", "reason": "not readable"}

func _translate_success(_document: Dictionary, _sha: String) -> Dictionary:
	return {"ok": true, "candidate": _candidate()}

func _translate_failure(_document: Dictionary, _sha: String) -> Dictionary:
	return {"ok": false, "stage": "translate source=secret", "reason": "invalid"}

func _validate_success(_document: Dictionary) -> Dictionary:
	return {"ok": true}

func _validate_failure(_document: Dictionary) -> Dictionary:
	return {"ok": false, "stage": "validate source=secret", "reason": "invalid"}

func _encode_success(_document: Dictionary) -> PackedByteArray:
	return PackedByteArray([4, 5, 6])

func _write_success(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([4, 5, 6])
	return {"ok": true, "committed": true, "cleanupDebt": false, "stage": "verified", "reason": ""}

func _write_failure(_document: Dictionary) -> Dictionary:
	return {"ok": false, "committed": false, "cleanupDebt": false, "stage": "promote source=secret", "reason": "failed"}

func _write_corrupt(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([0])
	return {"ok": true, "committed": true, "cleanupDebt": false, "stage": "verified", "reason": ""}

func _write_cleanup_debt(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([4, 5, 6])
	return {"ok": true, "committed": true, "cleanupDebt": true, "stage": "cleanup", "reason": "code-20"}

func _write_mutating_failure(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([0])
	return {"ok": false, "committed": false, "cleanupDebt": false, "stage": "promote", "reason": "failed"}

func _write_legacy_success(_document: Dictionary) -> String:
	_writes += 1
	_target = PackedByteArray([4, 5, 6])
	return ""

func _restore_target(before: Dictionary) -> Dictionary:
	_target = (before.get("bytes", PackedByteArray()) as PackedByteArray).duplicate()
	return {"ok": true}

func _restore_production_artifacts(target: String, target_existed: bool, target_bytes: PackedByteArray, access_directory: String, access_existed: bool, world_directory: String, world_existed: bool, staging_directory: String, staging_existed: bool, staging_parent: String, staging_parent_existed: bool) -> void:
	if target_existed:
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file != null:
			file.store_buffer(target_bytes)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	_remove_if_created(access_directory, access_existed)
	_remove_if_created(world_directory, world_existed)
	_remove_if_created(staging_directory, staging_existed)
	_remove_if_created(staging_parent, staging_parent_existed)

func _remove_if_created(path: String, existed: bool) -> void:
	if not existed and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _target_reader() -> Dictionary:
	return {"ok": true, "exists": true, "bytes": _target.duplicate()}

func _capture(line: String) -> void:
	_lines.append(line)

func _candidate() -> Dictionary:
	return {"format": "party-forge-access-snapshot", "version": 1, "source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-progression", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}, "locations": [{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]}]}
