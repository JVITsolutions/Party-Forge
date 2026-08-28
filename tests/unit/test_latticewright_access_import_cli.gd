extends RefCounted

const Entry = preload("res://tools/import_latticewright_access_snapshot.gd")
const GeneratedWriter = preload("res://scripts/tools/generated_json_document_writer.gd")

class FixedTargetRestoreFailureStore extends AtomicJsonStore:
	var target := ""

	func _generated_write_bytes(path: String, bytes: PackedByteArray) -> Error:
		if path == target:
			return ERR_CANT_CREATE
		return super._generated_write_bytes(path, bytes)

var _lines: Array[String] = []
var _writes := 0
var _target := PackedByteArray([1, 2, 3])
var _restore_calls := 0
var _recovery_calls := 0
var _reader_calls := 0
var _translator_calls := 0
var _validator_calls := 0
var _encoder_calls := 0
var _test_root := ""

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_root = "user://tests/latticewright_access_import_cli_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_test_root)
	var fixed_target_bytes := FileAccess.get_file_as_bytes(GeneratedWriter.TARGET)
	TestAssertions.truthy(_tree_entries(GeneratedWriter.STAGING_ROOT).is_empty(), "CLI fixed staging root starts without evidence", failures)
	_test_import_and_parity(failures)
	_test_rejected_paths_do_not_write(failures)
	var supports_isolation := _assert_isolated_writer_seam(failures)
	if supports_isolation:
		_test_real_pending_recovery_precedes_later_rejections(failures)
	_test_recovery_preflight_precedes_source_workflow(failures)
	_test_unresolved_recovery_stops_every_source_dependency(failures)
	_test_invalid_recovery_contract_stops_every_source_dependency(failures)
	_test_writer_stages_remain_sanitized(failures)
	if supports_isolation:
		_test_generated_writer_lifetime_with_isolated_filesystem(failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(GeneratedWriter.TARGET), fixed_target_bytes, "CLI tests never alter the fixed checked-in snapshot bytes", failures)
	TestAssertions.truthy(_tree_entries(GeneratedWriter.STAGING_ROOT).is_empty(), "CLI tests leave no fixed staging evidence", failures)
	ProfileTestSupport.remove_tree(_test_root)
	return failures

func _test_import_and_parity(failures: Array[String]) -> void:
	_target = PackedByteArray([1, 2, 3]); _writes = 0; _restore_calls = 0; _lines.clear()
	var candidate := _candidate()
	var service: Variant = Entry.new_service(_dependencies(candidate, PackedByteArray([4, 5, 6])))
	var imported: Variant = service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(imported, 0, "service imports a changed candidate", failures)
	TestAssertions.equal(_writes, 1, "changed candidate writes exactly once", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=COMMITTED adapter=latticewright-runtime-v3-city-access stage=verified"], "service prints one committed marker", failures)
	_target = PackedByteArray([1, 2, 3]); _writes = 0; _lines.clear()
	var debt_dependencies := _dependencies(candidate, PackedByteArray([4, 5, 6]))
	debt_dependencies["writer"] = Callable(self, "_write_cleanup_debt")
	var debt_service: Variant = Entry.new_service(debt_dependencies)
	TestAssertions.equal(debt_service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture")), 0, "committed cleanup debt remains imported", failures)
	TestAssertions.truthy(debt_service.last_cleanup_debt is bool and debt_service.last_cleanup_debt == true, "service preserves truthful committed cleanup debt", failures)
	_target = PackedByteArray([1, 2, 3]); _writes = 0; _lines.clear()
	var unchanged_dependencies := _dependencies(candidate, PackedByteArray([4, 5, 6]))
	unchanged_dependencies["writer"] = Callable(self, "_write_unchanged")
	var unchanged: Variant = Entry.new_service(unchanged_dependencies).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(unchanged, 0, "writer-owned target-byte parity exits zero", failures)
	TestAssertions.equal(_writes, 0, "writer-owned target-byte parity does not replace", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare"], "service prints one unchanged marker", failures)
	TestAssertions.equal(_restore_calls, 0, "successful writer states never invoke an independent CLI restore", failures)
	var recovered_debt_dependencies := _dependencies(candidate, PackedByteArray([4, 5, 6]))
	recovered_debt_dependencies["recovery"] = Callable(self, "_recover_cleanup_debt")
	recovered_debt_dependencies["writer"] = Callable(self, "_write_unchanged")
	var recovered_debt_service: Variant = Entry.new_service(recovered_debt_dependencies)
	TestAssertions.equal(recovered_debt_service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture")), 0, "resolved recovery cleanup debt does not block safe source workflow", failures)
	TestAssertions.truthy(recovered_debt_service.last_cleanup_debt, "service retains recovery cleanup debt after a debt-free write", failures)
	for resolution: String in ["rolled_back", "candidate_verified"]:
		_reader_calls = 0; _translator_calls = 0; _lines.clear()
		var resolved_dependencies := _dependencies(candidate, PackedByteArray([4, 5, 6]), Callable(self, "_counting_read_success"), Callable(self, "_counting_translate_success"))
		resolved_dependencies["recovery"] = func() -> Dictionary:
			return {"resolution": resolution, "cleanupDebt": false, "stage": "recovery", "reason": ""}
		resolved_dependencies["writer"] = Callable(self, "_write_unchanged")
		var resolved_exit: Variant = Entry.new_service(resolved_dependencies).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
		TestAssertions.equal(resolved_exit, 0, "%s recovery continues to the current writer outcome" % resolution, failures)
		TestAssertions.equal([_reader_calls, _translator_calls], [1, 1], "%s recovery performs the current source workflow" % resolution, failures)
		TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare"], "%s recovery emits only the current comparison outcome" % resolution, failures)

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
		_target = PackedByteArray([9, 8, 7]); _writes = 0; _restore_calls = 0; _lines.clear()
		var exit_code: Variant = Entry.new_service(test_case["dependencies"] as Dictionary).run(test_case["args"] as PackedStringArray, Callable(self, "_capture"))
		TestAssertions.equal(exit_code, 1, "%s exits rejected" % test_case["label"], failures)
		TestAssertions.equal(_writes, 0, "%s never writes" % test_case["label"], failures)
		TestAssertions.equal(_target, PackedByteArray([9, 8, 7]), "%s preserves exact target bytes" % test_case["label"], failures)
		TestAssertions.equal(_lines.size(), 1, "%s prints exactly one terminal marker" % test_case["label"], failures)
		TestAssertions.truthy(_lines[0].begins_with("PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage="), "%s has sanitized rejected marker" % test_case["label"], failures)
		TestAssertions.truthy(not _lines[0].contains("secret"), "%s marker omits source details" % test_case["label"], failures)
		TestAssertions.equal(_restore_calls, 0, "%s never invokes an independent CLI restore" % test_case["label"], failures)
	_target = PackedByteArray([9, 8, 7]); _writes = 0; _restore_calls = 0; _lines.clear()
	var failed_commit := _dependencies(_candidate(), PackedByteArray([4, 5, 6]))
	failed_commit["writer"] = Callable(self, "_write_mutating_failure")
	var promote_exit: Variant = Entry.new_service(failed_commit).run(PackedStringArray(["--source", "a"]), Callable(self, "_capture"))
	TestAssertions.equal(promote_exit, 1, "writer indeterminate state exits nonzero", failures)
	TestAssertions.equal(_target, PackedByteArray([0]), "CLI does not run a second restore protocol after writer indeterminate state", failures)
	TestAssertions.equal(_restore_calls, 0, "writer indeterminate state never invokes CLI restore", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=INDETERMINATE adapter=latticewright-runtime-v3-city-access stage=restore"], "restore failure prints one indeterminate marker", failures)
	_target = PackedByteArray([9, 8, 7]); _writes = 0; _restore_calls = 0; _lines.clear()
	var legacy_writer := _dependencies(_candidate(), PackedByteArray([4, 5, 6]))
	legacy_writer["writer"] = Callable(self, "_write_legacy_success")
	var legacy_exit: Variant = Entry.new_service(legacy_writer).run(PackedStringArray(["--source", "a"]), Callable(self, "_capture"))
	TestAssertions.equal(legacy_exit, 1, "legacy writer return shape is indeterminate", failures)
	TestAssertions.equal(_target, PackedByteArray([4, 5, 6]), "invalid writer contract is not independently restored by CLI", failures)
	TestAssertions.equal(_restore_calls, 0, "invalid writer contract never invokes CLI restore", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=INDETERMINATE adapter=latticewright-runtime-v3-city-access stage=write"], "invalid writer contract has one indeterminate marker", failures)

func _test_generated_writer_lifetime_with_isolated_filesystem(failures: Array[String]) -> void:
	var root := _test_root.path_join("writer-lifetime")
	var target := root.path_join("target.json")
	var staging_directory := root.path_join("staging")
	var writer: Variant = _new_isolated_writer(AtomicJsonStore.new(), target, staging_directory)
	_lines.clear()
	var service: Variant = Entry.new_service({
		"reader": Callable(self, "_read_success"),
		"translator": Callable(self, "_translate_success"),
		"recovery": Callable(writer, "recover"),
		"writer": Callable(writer, "write"),
	})
	var exit_code: Variant = service.run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(exit_code, 0, "injected generated writer runs against the isolated filesystem", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=COMMITTED adapter=latticewright-runtime-v3-city-access stage=verified"], "isolated generated writer emits committed marker", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_candidate()), "isolated generated writer commits exact canonical bytes", failures)
	TestAssertions.truthy(_tree_entries(staging_directory).is_empty(), "isolated generated writer clears staging evidence", failures)

func _dependencies(candidate: Dictionary, encoded: PackedByteArray, reader: Callable = Callable(), translator: Callable = Callable(), validator: Callable = Callable(), encoder: Callable = Callable(), writer: Callable = Callable()) -> Dictionary:
	return {"recovery": Callable(self, "_recover_none"), "reader": reader if reader.is_valid() else Callable(self, "_read_success"), "translator": translator if translator.is_valid() else Callable(self, "_translate_success"), "validator": validator if validator.is_valid() else Callable(self, "_validate_success"), "encoder": encoder if encoder.is_valid() else Callable(self, "_encode_success"), "writer": writer if writer.is_valid() else Callable(self, "_write_success"), "target_reader": Callable(self, "_target_reader"), "target_restorer": Callable(self, "_restore_target"), "candidate": candidate, "encoded": encoded}

func _test_recovery_preflight_precedes_source_workflow(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"label": "request", "args": PackedStringArray(), "reader": Callable(self, "_counting_read_success"), "translator": Callable(self, "_counting_translate_success")},
		{"label": "read", "args": PackedStringArray(["--source", "fixture.json"]), "reader": Callable(self, "_counting_read_failure"), "translator": Callable(self, "_counting_translate_success")},
		{"label": "translate", "args": PackedStringArray(["--source", "fixture.json"]), "reader": Callable(self, "_counting_read_success"), "translator": Callable(self, "_counting_translate_failure")},
	]:
		_recovery_calls = 0; _reader_calls = 0; _translator_calls = 0; _lines.clear()
		var dependencies := _dependencies(_candidate(), PackedByteArray([4]), test_case["reader"] as Callable, test_case["translator"] as Callable)
		dependencies["recovery"] = Callable(self, "_recover_none")
		var exit_code: Variant = Entry.new_service(dependencies).run(test_case["args"] as PackedStringArray, Callable(self, "_capture"))
		TestAssertions.equal(exit_code, 1, "%s rejection follows successful recovery preflight" % test_case["label"], failures)
		TestAssertions.equal(_recovery_calls, 1, "%s rejection runs recovery exactly once first" % test_case["label"], failures)
		TestAssertions.equal(_restore_calls, 0, "%s rejection has no CLI-owned restore path" % test_case["label"], failures)

func _test_real_pending_recovery_precedes_later_rejections(failures: Array[String]) -> void:
	for test_case: Dictionary in [
		{"label": "request", "args": PackedStringArray(), "reader": Callable(self, "_read_success"), "translator": Callable(self, "_translate_success"), "stage": "request"},
		{"label": "read", "args": PackedStringArray(["--source", "fixture.json"]), "reader": Callable(self, "_read_failure"), "translator": Callable(self, "_translate_success"), "stage": "unknown"},
		{"label": "translate", "args": PackedStringArray(["--source", "fixture.json"]), "reader": Callable(self, "_read_success"), "translator": Callable(self, "_translate_failure"), "stage": "unknown"},
	]:
		var root := _test_root.path_join("real-pending-%s" % String(test_case["label"]))
		var target := root.path_join("target.json")
		var staging_directory := root.path_join("staging")
		ProfileTestSupport.remove_tree(root)
		var prior_document := _candidate()
		prior_document["source"]["sha256"] = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
		var prior_bytes := CityAccessSnapshotCodec.encode_document(prior_document)
		_write_fixed_bytes(target, prior_bytes)
		var failure_store := FixedTargetRestoreFailureStore.new(func(temporary: String, promoted_target: String) -> Error:
			_write_fixed_bytes(promoted_target, "{\"wrong\":true}".to_utf8_buffer())
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return ERR_CANT_CREATE
		)
		failure_store.target = target
		var pending_writer: Variant = _new_isolated_writer(failure_store, target, staging_directory)
		var pending: Variant = pending_writer.call("write", _candidate())
		TestAssertions.equal((pending as Dictionary).get("state", "") if pending is Dictionary else "", "indeterminate", "%s fixture retains a real isolated transaction" % test_case["label"], failures)
		TestAssertions.truthy(FileAccess.file_exists(staging_directory.path_join("pending-transaction.json")), "%s fixture has real pending evidence" % test_case["label"], failures)
		_restore_calls = 0; _lines.clear()
		var dependencies := _dependencies(_candidate(), PackedByteArray([4]), test_case["reader"] as Callable, test_case["translator"] as Callable)
		var recovery_writer: Variant = _new_isolated_writer(AtomicJsonStore.new(), target, staging_directory)
		dependencies["recovery"] = Callable(recovery_writer, "recover")
		var exit_code: Variant = Entry.new_service(dependencies).run(test_case["args"] as PackedStringArray, Callable(self, "_capture"))
		TestAssertions.equal(exit_code, 1, "%s rejects only after real pending recovery" % test_case["label"], failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(target), prior_bytes, "%s restores exact prior target before rejection" % test_case["label"], failures)
		TestAssertions.truthy(not FileAccess.file_exists(staging_directory.path_join("pending-transaction.json")), "%s clears verified pending evidence before rejection" % test_case["label"], failures)
		TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage=%s" % test_case["stage"]], "%s emits only the later rejection" % test_case["label"], failures)
		TestAssertions.equal(_restore_calls, 0, "%s recovery stays writer-owned", failures)
		ProfileTestSupport.remove_tree(root)

func _test_unresolved_recovery_stops_every_source_dependency(failures: Array[String]) -> void:
	_recovery_calls = 0; _reader_calls = 0; _translator_calls = 0; _validator_calls = 0; _encoder_calls = 0; _writes = 0; _restore_calls = 0; _lines.clear()
	var dependencies := {
		"recovery": Callable(self, "_recover_indeterminate"),
		"reader": Callable(self, "_counting_read_success"),
		"translator": Callable(self, "_counting_translate_success"),
		"validator": Callable(self, "_counting_validate_success"),
		"encoder": Callable(self, "_counting_encode_success"),
		"writer": Callable(self, "_write_success"),
		"target_restorer": Callable(self, "_restore_target"),
	}
	var exit_code: Variant = Entry.new_service(dependencies).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
	TestAssertions.equal(exit_code, 1, "unresolved recovery exits nonzero", failures)
	TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=INDETERMINATE adapter=latticewright-runtime-v3-city-access stage=restore"], "unresolved recovery emits one sanitized indeterminate marker", failures)
	TestAssertions.equal([_reader_calls, _translator_calls, _validator_calls, _encoder_calls, _writes, _restore_calls], [0, 0, 0, 0, 0, 0], "unresolved recovery runs no source workflow, writer, or CLI restore", failures)

func _test_invalid_recovery_contract_stops_every_source_dependency(failures: Array[String]) -> void:
	for invalid: Dictionary in [
		{"ok": true, "state": "unchanged", "cleanupDebt": false, "stage": "recovery", "reason": ""},
		{"resolution": "committed", "cleanupDebt": false, "stage": "recovery", "reason": ""},
		{"resolution": "none", "cleanupDebt": false, "stage": "recovery", "reason": "", "extra": true},
	]:
		_reader_calls = 0; _translator_calls = 0; _validator_calls = 0; _encoder_calls = 0; _writes = 0; _lines.clear()
		var dependencies := {
			"recovery": func() -> Dictionary: return invalid,
			"reader": Callable(self, "_counting_read_success"),
			"translator": Callable(self, "_counting_translate_success"),
			"validator": Callable(self, "_counting_validate_success"),
			"encoder": Callable(self, "_counting_encode_success"),
			"writer": Callable(self, "_write_success"),
		}
		var exit_code: Variant = Entry.new_service(dependencies).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture"))
		TestAssertions.equal(exit_code, 1, "invalid recovery contract exits indeterminate", failures)
		TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=INDETERMINATE adapter=latticewright-runtime-v3-city-access stage=recovery"], "invalid recovery contract emits one sanitized indeterminate marker", failures)
		TestAssertions.equal([_reader_calls, _translator_calls, _validator_calls, _encoder_calls, _writes], [0, 0, 0, 0, 0], "invalid recovery contract runs no source or write work", failures)

func _test_writer_stages_remain_sanitized(failures: Array[String]) -> void:
	for stage: String in ["confinement", "mkdir", "mkdir-target", "stage-previous", "verify-previous"]:
		_lines.clear()
		var dependencies := _dependencies(_candidate(), PackedByteArray([4]))
		dependencies["writer"] = func(_document: Dictionary) -> Dictionary:
			return {"ok": false, "state": "rejected", "cleanupDebt": false, "stage": stage, "reason": "fixture"}
		TestAssertions.equal(Entry.new_service(dependencies).run(PackedStringArray(["--source", "fixture.json"]), Callable(self, "_capture")), 1, "%s writer stage exits rejected" % stage, failures)
		TestAssertions.equal(_lines, ["PARTY_FORGE_CITY_ACCESS_IMPORT status=REJECTED adapter=latticewright-runtime-v3-city-access stage=%s" % stage], "%s remains in the sanitized stage allowlist" % stage, failures)

func _recover_none() -> Dictionary:
	_recovery_calls += 1
	return {"resolution": "none", "cleanupDebt": false, "stage": "recovery", "reason": ""}

func _recover_indeterminate() -> Dictionary:
	_recovery_calls += 1
	return {"resolution": "indeterminate", "cleanupDebt": false, "stage": "restore", "reason": "failed"}

func _recover_cleanup_debt() -> Dictionary:
	_recovery_calls += 1
	return {"resolution": "rolled_back", "cleanupDebt": true, "stage": "cleanup", "reason": "code-20"}

func _counting_read_success(path: String, maximum: int) -> Dictionary:
	_reader_calls += 1
	return _read_success(path, maximum)

func _counting_read_failure(path: String, maximum: int) -> Dictionary:
	_reader_calls += 1
	return _read_failure(path, maximum)

func _counting_translate_success(document: Dictionary, sha: String) -> Dictionary:
	_translator_calls += 1
	return _translate_success(document, sha)

func _counting_translate_failure(document: Dictionary, sha: String) -> Dictionary:
	_translator_calls += 1
	return _translate_failure(document, sha)

func _counting_validate_success(document: Dictionary) -> Dictionary:
	_validator_calls += 1
	return _validate_success(document)

func _counting_encode_success(document: Dictionary) -> PackedByteArray:
	_encoder_calls += 1
	return _encode_success(document)

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
	return {"ok": true, "state": "committed", "cleanupDebt": false, "stage": "verified", "reason": ""}

func _write_failure(_document: Dictionary) -> Dictionary:
	return {"ok": false, "state": "rejected", "cleanupDebt": false, "stage": "promote source=secret", "reason": "failed"}

func _write_cleanup_debt(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([4, 5, 6])
	return {"ok": true, "state": "committed", "cleanupDebt": true, "stage": "cleanup", "reason": "code-20"}

func _write_unchanged(_document: Dictionary) -> Dictionary:
	return {"ok": true, "state": "unchanged", "cleanupDebt": false, "stage": "compare", "reason": ""}

func _write_mutating_failure(_document: Dictionary) -> Dictionary:
	_writes += 1
	_target = PackedByteArray([0])
	return {"ok": false, "state": "indeterminate", "cleanupDebt": false, "stage": "restore", "reason": "failed"}

func _write_legacy_success(_document: Dictionary) -> String:
	_writes += 1
	_target = PackedByteArray([4, 5, 6])
	return ""

func _restore_target(before: Dictionary) -> Dictionary:
	_restore_calls += 1
	_target = (before.get("bytes", PackedByteArray()) as PackedByteArray).duplicate()
	return {"ok": true}

func _target_reader() -> Dictionary:
	return {"ok": true, "exists": true, "bytes": _target.duplicate()}

func _capture(line: String) -> void:
	_lines.append(line)

func _write_fixed_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _assert_isolated_writer_seam(failures: Array[String]) -> bool:
	var argument_count := -1
	var probe := GeneratedWriter.new()
	for method: Dictionary in probe.get_script().get_script_method_list():
		if StringName(method.get("name", &"")) == &"_init":
			argument_count = (method.get("args", []) as Array).size()
			break
	TestAssertions.equal(argument_count, 3, "CLI real-filesystem tests can inject target and staging roots", failures)
	return argument_count == 3

func _new_isolated_writer(documents: AtomicJsonStore, target: String, staging_root: String) -> Variant:
	var writer := GeneratedWriter.new()
	writer.call("_init", documents, target, staging_root)
	return writer

func _tree_entries(root: String) -> Array[String]:
	var entries: Array[String] = []
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var current: String = pending.pop_back()
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			entries.append(current.path_join(file_name))
		for directory_name: String in directory.get_directories():
			var child := current.path_join(directory_name)
			entries.append(child)
			pending.append(child)
	entries.sort()
	return entries

func _candidate() -> Dictionary:
	return {"format": "party-forge-access-snapshot", "version": 1, "source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-progression", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}, "locations": [{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]}]}
