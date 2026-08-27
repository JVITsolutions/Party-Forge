extends RefCounted

const SERVICE_PATH := "res://scripts/profile/profile_deletion_service.gd"
const RESULT_PATH := "res://scripts/profile/profile_deletion_result.gd"

var _root := ""


class RestoreFailingProfileDeletionService extends ProfileDeletionService:
	var failure_path := ""

	func _init(remove_file: Callable, injected_failure_path: String) -> void:
		super(remove_file)
		failure_path = injected_failure_path

	func _write_snapshot(path: String, bytes: PackedByteArray) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_buffer(bytes)
		var write_error := file.get_error()
		file.close()
		return write_error

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_deletion_service_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_root)
	if not ResourceLoader.exists(RESULT_PATH):
		failures.append("profile deletion result class exists")
	if not ResourceLoader.exists(SERVICE_PATH):
		failures.append("profile deletion service class exists")
	if not failures.is_empty():
		return failures
	_test_result_contract(failures)
	_reset_root()
	_test_rejects_unsafe_and_undiscovered_identity_before_remove(failures)
	_reset_root()
	_test_existing_file_root_fails_before_remove(failures)
	_reset_root()
	_test_removes_only_exact_allowlisted_artifacts(failures)
	_reset_root()
	_test_deletes_backup_only_and_damaged_generations(failures)
	_reset_root()
	_test_remove_failure_restores_every_snapshot(failures)
	_reset_root()
	_test_restore_failure_marks_indeterminate_partial_outcome(failures)
	_reset_root()
	_test_absence_verification_failure_restores_every_snapshot(failures)
	ProfileTestSupport.remove_tree(_root)
	return failures

func _test_result_contract(failures: Array[String]) -> void:
	var script := load(RESULT_PATH) as Script
	var result := script.new() as RefCounted
	TestAssertions.truthy(result != null, "deletion result constructs", failures)
	if result == null:
		return
	TestAssertions.truthy(not bool(result.get("committed")), "deletion result starts noncommitted", failures)
	TestAssertions.truthy(not bool(result.get("cleanup_debt")), "deletion result starts without cleanup debt", failures)
	TestAssertions.equal(result.get("deleted_profile_id"), "", "deletion result starts without a deleted identity", failures)
	TestAssertions.equal(result.get("next_active_profile_id"), "", "deletion result starts without a replacement identity", failures)
	TestAssertions.equal(result.get("error"), "", "deletion result starts without an error", failures)
	TestAssertions.truthy(not bool(result.call(&"ok")), "noncommitted deletion result is not successful", failures)
	result.set("committed", true)
	TestAssertions.truthy(bool(result.call(&"ok")), "committed deletion without cleanup debt is successful", failures)
	result.set("cleanup_debt", true)
	TestAssertions.truthy(not bool(result.call(&"ok")), "cleanup debt prevents an ok result", failures)
	var truth_table: Array[Dictionary] = [
		{"committed": false, "cleanup_debt": false, "ok": false, "meaning": "fully restored clean noncommit"},
		{"committed": true, "cleanup_debt": false, "ok": true, "meaning": "fully deleted"},
		{"committed": true, "cleanup_debt": true, "ok": false, "meaning": "deleted with index cleanup debt"},
		{"committed": false, "cleanup_debt": true, "ok": false, "meaning": "indeterminate partial rollback failure"},
	]
	for row: Dictionary in truth_table:
		result.set("committed", bool(row["committed"]))
		result.set("cleanup_debt", bool(row["cleanup_debt"]))
		TestAssertions.equal(bool(result.call(&"ok")), bool(row["ok"]), "deletion outcome truth table: %s" % String(row["meaning"]), failures)

func _test_rejects_unsafe_and_undiscovered_identity_before_remove(failures: Array[String]) -> void:
	var sentinel := _root.path_join("profile-a.json")
	var sentinel_bytes := "identity sentinel".to_utf8_buffer()
	_write_bytes(sentinel, sentinel_bytes)
	var remove_calls: Array[String] = []
	var service := _new_service(func(path: String) -> Error:
		remove_calls.append(path)
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	)
	var unsafe_ids: Array[String] = ["../profile-a", "C:\\profile-a", "folder/profile-a", "folder\\profile-a"]
	for profile_id: String in unsafe_ids:
		var result: RefCounted = service.call(
			&"delete_profile_artifacts",
			profile_id,
			PackedStringArray([profile_id]),
			_root,
		)
		TestAssertions.truthy(not bool(result.get("committed")) and str(result.get("error")).contains("unsafe discovered profile id"), "%s is rejected as an unsafe discovered identity" % profile_id, failures)
	var undiscovered: RefCounted = service.call(
		&"delete_profile_artifacts",
		"profile-valid01",
		PackedStringArray(["profile-other01"]),
		_root,
	)
	TestAssertions.truthy(not bool(undiscovered.get("committed")) and str(undiscovered.get("error")).contains("undiscovered profile"), "valid but undiscovered identity is rejected", failures)
	TestAssertions.truthy(remove_calls.is_empty(), "identity failures occur before the remover is called", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(sentinel), sentinel_bytes, "identity failures preserve exact sentinel bytes", failures)

func _test_existing_file_root_fails_before_remove(failures: Array[String]) -> void:
	var file_root := _root.path_join("profiles-as-file")
	var root_bytes := "root file bytes must remain exact".to_utf8_buffer()
	_write_bytes(file_root, root_bytes)
	var remove_calls: Array[String] = []
	var service := _new_service(func(path: String) -> Error:
		remove_calls.append(path)
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	)
	var profile_id := "profile-file-root"
	var result: RefCounted = service.call(
		&"delete_profile_artifacts",
		profile_id,
		PackedStringArray([profile_id]),
		file_root,
	)
	TestAssertions.truthy(not bool(result.get("committed")) and str(result.get("error")).contains("confined artifact targets unavailable"), "an existing file at the configured root fails closed before deletion", failures)
	TestAssertions.truthy(remove_calls.is_empty(), "an unscannable configured root never invokes the remover", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(file_root), root_bytes, "an existing root file keeps its exact bytes", failures)

func _test_removes_only_exact_allowlisted_artifacts(failures: Array[String]) -> void:
	var profile_id := "profile-a"
	var primary := ProfileStore.new().profile_path(profile_id, _root)
	var permitted: Array[String] = [
		primary,
		"%s.bak" % primary,
		"%s.tmp" % primary,
		"%s.bak.previous" % primary,
		"%s.irreversible-primary.tmp" % primary,
		"%s.irreversible-backup.tmp" % primary,
		"%s.corrupt-0" % primary,
		"%s.corrupt-001" % primary,
		"%s.corrupt-1700000000" % primary,
		"%s.bak.corrupt-9" % primary,
		"%s.bak.corrupt-1700000001" % primary,
	]
	for index: int in permitted.size():
		_write_text(permitted[index], "permitted-%d" % index)
	var protected: Array[String] = [
		_root.path_join("profile-a2.json"),
		"%s.corrupt-text" % primary,
		"%s.corrupt-" % primary,
		"%s.corrupt--1" % primary,
		"%s.corrupt-1x" % primary,
		"%s.corrupt-١" % primary,
		"%s.bak.corrupt-text" % primary,
		"%s.bak.corrupt-2x" % primary,
		"%s.irreversible-primary.previous" % primary,
		"%s.irreversible-backup.previous" % primary,
		_root.path_join(ProfileIndexStore.FILE_NAME),
		_root.path_join("%s.bak" % ProfileIndexStore.FILE_NAME),
		_root.path_join("profile-neighbor01.json"),
		_root.path_join("profile-neighbor01.json.bak"),
	]
	var protected_bytes: Dictionary = {}
	for index: int in protected.size():
		var bytes := ("protected-%d" % index).to_utf8_buffer()
		protected_bytes[protected[index]] = bytes
		_write_bytes(protected[index], bytes)
	var remove_calls: Array[String] = []
	var service := _new_service(func(path: String) -> Error:
		remove_calls.append(path)
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	)
	var result: RefCounted = service.call(
		&"delete_profile_artifacts",
		profile_id,
		PackedStringArray([profile_id, "profile-neighbor01"]),
		_root,
	)
	TestAssertions.truthy(bool(result.get("committed")) and bool(result.call(&"ok")), "exact allowlisted deletion commits", failures)
	TestAssertions.equal(result.get("deleted_profile_id"), profile_id, "committed service result identifies the deleted profile", failures)
	TestAssertions.equal(result.get("next_active_profile_id"), "", "service leaves replacement selection to the manager", failures)
	var expected_calls := permitted.duplicate()
	expected_calls.sort()
	remove_calls.sort()
	TestAssertions.equal(remove_calls, expected_calls, "remover receives every and only exact existing allowlisted artifact", failures)
	for path: String in permitted:
		TestAssertions.truthy(not FileAccess.file_exists(path), "allowlisted artifact is absent after commit: %s" % path.get_file(), failures)
	for path: String in protected:
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), protected_bytes[path], "lookalike or neighboring artifact bytes remain exact: %s" % path.get_file(), failures)
	var root_absolute := ProjectSettings.globalize_path(_root).simplify_path()
	for path: String in remove_calls:
		var candidate_absolute := ProjectSettings.globalize_path(path).simplify_path()
		TestAssertions.equal(candidate_absolute.get_base_dir(), root_absolute, "every remover target is confined to the exact root", failures)

func _test_deletes_backup_only_and_damaged_generations(failures: Array[String]) -> void:
	var service := _new_service()
	var backup_id := "profile-backup01"
	var backup_primary := ProfileStore.new().profile_path(backup_id, _root)
	_write_text("%s.bak" % backup_primary, "backup-only bytes")
	var backup_result: RefCounted = service.call(
		&"delete_profile_artifacts",
		backup_id,
		PackedStringArray([backup_id]),
		_root,
	)
	TestAssertions.truthy(bool(backup_result.get("committed")), "backup-only discovered artifacts delete", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.bak" % backup_primary), "backup-only generation is absent", failures)
	var damaged_id := "profile-damaged01"
	var damaged_primary := ProfileStore.new().profile_path(damaged_id, _root)
	_write_text(damaged_primary, "damaged primary bytes")
	_write_text("%s.bak" % damaged_primary, "damaged backup bytes")
	_write_text("%s.corrupt-42" % damaged_primary, "damaged corrupt evidence")
	var damaged_result: RefCounted = service.call(
		&"delete_profile_artifacts",
		damaged_id,
		PackedStringArray([damaged_id]),
		_root,
	)
	TestAssertions.truthy(bool(damaged_result.get("committed")), "damaged discovered artifacts delete without decoding", failures)
	for path: String in [damaged_primary, "%s.bak" % damaged_primary, "%s.corrupt-42" % damaged_primary]:
		TestAssertions.truthy(not FileAccess.file_exists(path), "damaged artifact is absent after commit: %s" % path.get_file(), failures)

func _test_remove_failure_restores_every_snapshot(failures: Array[String]) -> void:
	var profile_id := "profile-rollback01"
	var primary := ProfileStore.new().profile_path(profile_id, _root)
	var targets: Array[String] = [
		primary,
		"%s.bak" % primary,
		"%s.tmp" % primary,
		"%s.corrupt-73" % primary,
	]
	var snapshots: Dictionary = {}
	for index: int in targets.size():
		var bytes := ("rollback-%d" % index).to_utf8_buffer()
		snapshots[targets[index]] = bytes
		_write_bytes(targets[index], bytes)
	var neighbor := _root.path_join("profile-rollback02.json")
	var neighbor_bytes := "rollback neighbor".to_utf8_buffer()
	_write_bytes(neighbor, neighbor_bytes)
	var remove_calls: Array[String] = []
	var service := _new_service(func(path: String) -> Error:
		remove_calls.append(path)
		if remove_calls.size() == 2:
			return ERR_CANT_CREATE
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	)
	var result: RefCounted = service.call(
		&"delete_profile_artifacts",
		profile_id,
		PackedStringArray([profile_id]),
		_root,
	)
	TestAssertions.truthy(not bool(result.get("committed")) and str(result.get("error")).contains("stage=remove") and str(result.get("error")).contains("restore_code=0"), "remove failure reports a fully restored noncommit", failures)
	TestAssertions.equal(remove_calls.size(), 2, "remove failure stops additional removals", failures)
	for path: String in targets:
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), snapshots[path], "remove failure restores exact artifact bytes: %s" % path.get_file(), failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(neighbor), neighbor_bytes, "remove failure preserves neighboring bytes", failures)


func _test_restore_failure_marks_indeterminate_partial_outcome(failures: Array[String]) -> void:
	var profile_id := "profile-partial01"
	var primary := ProfileStore.new().profile_path(profile_id, _root)
	var backup := "%s.bak" % primary
	var primary_bytes := "partial primary must be restored".to_utf8_buffer()
	var backup_bytes := "partial backup remains authoritative".to_utf8_buffer()
	_write_bytes(primary, primary_bytes)
	_write_bytes(backup, backup_bytes)
	var remove_calls: Array[String] = []
	var service := RestoreFailingProfileDeletionService.new(func(path: String) -> Error:
		remove_calls.append(path)
		if remove_calls.size() == 1:
			return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return ERR_CANT_CREATE
	, primary)
	var result: RefCounted = service.call(
		&"delete_profile_artifacts",
		profile_id,
		PackedStringArray([profile_id]),
		_root,
	)
	TestAssertions.equal(remove_calls, [primary, backup], "partial rollback fixture removes one artifact before a later remove failure", failures)
	TestAssertions.truthy(not bool(result.get("committed")) and bool(result.get("cleanup_debt")), "unrestored original bytes use the indeterminate false/true outcome", failures)
	var technical := str(result.get("error"))
	TestAssertions.truthy(technical.contains("PROFILE_DELETE_INDETERMINATE") and technical.contains("committed=false") and technical.contains("cleanup_debt=true") and technical.contains("stage=rollback"), "partial rollback exposes a precise technical outcome", failures)
	TestAssertions.truthy(not FileAccess.file_exists(primary), "partial rollback proof leaves the removed primary unrestored", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(backup), backup_bytes, "partial rollback proof retains the later backup artifact exactly", failures)

func _test_absence_verification_failure_restores_every_snapshot(failures: Array[String]) -> void:
	var profile_id := "profile-verify01"
	var primary := ProfileStore.new().profile_path(profile_id, _root)
	var backup := "%s.bak" % primary
	var primary_bytes := "verify primary".to_utf8_buffer()
	var backup_bytes := "verify backup".to_utf8_buffer()
	_write_bytes(primary, primary_bytes)
	_write_bytes(backup, backup_bytes)
	var remove_calls: Array[String] = []
	var service := _new_service(func(path: String) -> Error:
		remove_calls.append(path)
		if path == backup:
			return OK
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	)
	var result: RefCounted = service.call(
		&"delete_profile_artifacts",
		profile_id,
		PackedStringArray([profile_id]),
		_root,
	)
	TestAssertions.truthy(not bool(result.get("committed")) and str(result.get("error")).contains("stage=verify") and str(result.get("error")).contains("restore_code=0"), "reported removal without absence is a restored noncommit", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(primary), primary_bytes, "verification failure restores primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(backup), backup_bytes, "verification failure preserves backup bytes", failures)

func _new_service(remove_file: Callable = Callable()) -> RefCounted:
	var script := load(SERVICE_PATH) as Script
	return script.new(remove_file) as RefCounted

func _write_text(path: String, contents: String) -> void:
	_write_bytes(path, contents.to_utf8_buffer())

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _reset_root() -> void:
	ProfileTestSupport.remove_tree(_root)
