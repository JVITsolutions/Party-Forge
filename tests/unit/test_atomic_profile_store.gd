extends RefCounted

var _root := ""

class CleanupFailingAtomicJsonStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_store_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_cleanup()
	_test_round_trip_and_backup_recovery(failures)
	_test_backup_only_is_discoverable(failures)
	_test_corrupt_primary_is_preserved_before_resave(failures)
	_test_failed_promotion_restores_primary_and_older_backup(failures)
	_test_corrupt_primary_without_backup_refuses_overwrite(failures)
	_test_corrupt_primary_failed_promotion_keeps_recovery(failures)
	_test_promoted_verification_failure_restores_generations(failures)
	_test_valid_but_different_promotion_restores_generations(failures)
	_test_post_commit_cleanup_failure_retains_committed_state(failures)
	_test_malformed_schema_field_recovers_backup(failures)
	_test_missing_profile_is_distinct(failures)
	_test_absent_profile_root_lists_cleanly(failures)
	_cleanup()
	return failures

func _test_round_trip_and_backup_recovery(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var first := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	first.gold = 10
	TestAssertions.equal(store.save_profile(first, _root), "", "first profile save succeeds", failures)
	var second := first.copy()
	second.gold = 20
	second.updated_at_unix = 1001
	TestAssertions.equal(store.save_profile(second, _root), "", "second save creates backup", failures)
	var primary_path := store.profile_path(first.profile_id, _root)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	var recovered := store.load_profile(first.profile_id, _root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "corrupt primary recovers verified backup", failures)
	TestAssertions.equal(recovered.profile.gold, 10, "recovery returns previous committed generation", failures)

func _test_failed_promotion_restores_primary_and_older_backup(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var original := ProfileState.new_profile("profile-abcdefgh", "Original", 2000)
	original.gold = 1
	TestAssertions.equal(good.save_profile(original, _root), "", "promotion fixture first save succeeds", failures)
	var current := original.copy()
	current.gold = 2
	current.updated_at_unix = 2001
	TestAssertions.equal(good.save_profile(current, _root), "", "promotion fixture creates older backup", failures)
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var changed := current.copy()
	changed.display_name = "Changed"
	changed.gold = 3
	changed.updated_at_unix = 2002
	TestAssertions.truthy(not failing.save_profile(changed, _root).is_empty(), "failed promotion reports error", failures)
	var primary_path := good.profile_path(original.profile_id, _root)
	var restored_primary := _decode_file(primary_path)
	var restored_backup := _decode_file("%s.bak" % primary_path)
	TestAssertions.equal(restored_primary.profile.gold if restored_primary.ok() else -1, 2, "failed promotion restores current primary", failures)
	TestAssertions.equal(restored_backup.profile.gold if restored_backup.ok() else -1, 1, "failed promotion retains older backup", failures)

func _test_backup_only_is_discoverable(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-backup01", "Backup", 3000)
	TestAssertions.equal(store.save_profile(profile, _root), "", "backup-only fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 3001
	TestAssertions.equal(store.save_profile(profile, _root), "", "backup-only fixture creates backup", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.profile_path(profile.profile_id, _root)))
	TestAssertions.truthy(profile.profile_id in store.profile_ids(_root), "backup-only profile remains discoverable", failures)

func _test_corrupt_primary_is_preserved_before_resave(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-corrupt1", "Corrupt", 4000)
	TestAssertions.equal(store.save_profile(profile, _root), "", "corrupt fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 4001
	TestAssertions.equal(store.save_profile(profile, _root), "", "corrupt fixture creates verified backup", failures)
	var primary_path := store.profile_path(profile.profile_id, _root)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt original bytes")
	corrupt.close()
	var recovered := store.load_profile(profile.profile_id, _root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "fixture recovers backup", failures)
	recovered.profile.gold = 3
	recovered.profile.updated_at_unix = 4002
	TestAssertions.equal(store.save_profile(recovered.profile, _root), "", "recovered profile resaves", failures)
	var artifacts := DirAccess.get_files_at(_root)
	TestAssertions.truthy(not _corrupt_artifact_path(profile.profile_id, artifacts).is_empty(), "corrupt primary is preserved for diagnosis", failures)
	TestAssertions.equal(store.load_profile(profile.profile_id, _root).profile.gold, 3, "resaved primary is current", failures)

func _test_corrupt_primary_without_backup_refuses_overwrite(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-no-backup", "No Backup", 5000)
	TestAssertions.equal(store.save_profile(profile, _root), "", "no-backup fixture saves", failures)
	var primary_path := store.profile_path(profile.profile_id, _root)
	var corrupt_bytes := "corrupt bytes without backup"
	_write_text(primary_path, corrupt_bytes)
	profile.gold = 5
	profile.updated_at_unix = 5001
	var error := store.save_profile(profile, _root)
	TestAssertions.truthy(error.contains("stage=validate-existing"), "corrupt primary without backup refuses overwrite", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(primary_path), corrupt_bytes, "refused overwrite preserves corrupt bytes", failures)

func _test_corrupt_primary_failed_promotion_keeps_recovery(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var first := ProfileState.new_profile("profile-corrupt2", "Recoverable", 6000)
	first.gold = 1
	TestAssertions.equal(good.save_profile(first, _root), "", "corrupt failure fixture first save succeeds", failures)
	var current := first.copy()
	current.gold = 2
	current.updated_at_unix = 6001
	TestAssertions.equal(good.save_profile(current, _root), "", "corrupt failure fixture creates backup", failures)
	var primary_path := good.profile_path(first.profile_id, _root)
	var corrupt_bytes := "corrupt before failed promotion"
	_write_text(primary_path, corrupt_bytes)
	var replacement := current.copy()
	replacement.gold = 3
	replacement.updated_at_unix = 6002
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	TestAssertions.truthy(not failing.save_profile(replacement, _root).is_empty(), "corrupt primary promotion failure reports error", failures)
	var backup := _decode_file("%s.bak" % primary_path)
	TestAssertions.equal(backup.profile.gold if backup.ok() else -1, 1, "failed corrupt promotion retains valid backup", failures)
	var artifact_path := _corrupt_artifact_path(first.profile_id, DirAccess.get_files_at(_root))
	TestAssertions.truthy(not artifact_path.is_empty(), "failed corrupt promotion preserves diagnostic artifact", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(artifact_path) if not artifact_path.is_empty() else "", corrupt_bytes, "diagnostic artifact preserves corrupt bytes", failures)
	TestAssertions.truthy(good.load_profile(first.profile_id, _root).ok(), "failed corrupt promotion remains recoverable", failures)

func _test_promoted_verification_failure_restores_generations(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var first := ProfileState.new_profile("profile-verify01", "Verify", 7000)
	first.gold = 1
	TestAssertions.equal(good.save_profile(first, _root), "", "verification fixture first save succeeds", failures)
	var current := first.copy()
	current.gold = 2
	current.updated_at_unix = 7001
	TestAssertions.equal(good.save_profile(current, _root), "", "verification fixture creates backup", failures)
	var corrupting_promoter := func(temporary: String, target: String) -> Error:
		var promote_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
		if promote_error != OK:
			return promote_error
		var promoted := FileAccess.open(target, FileAccess.WRITE)
		if promoted == null:
			return FileAccess.get_open_error()
		promoted.store_string("corrupt promoted bytes")
		var write_error := promoted.get_error()
		promoted.close()
		return write_error
	var replacement := current.copy()
	replacement.gold = 3
	replacement.updated_at_unix = 7002
	var failing := ProfileStore.new(AtomicJsonStore.new(corrupting_promoter))
	var error := failing.save_profile(replacement, _root)
	TestAssertions.truthy(error.contains("stage=verify-promoted") and error.contains("target_remove_code=0") and error.contains("restore_code=0"), "verification failure reports removal and restoration", failures)
	var primary_path := good.profile_path(first.profile_id, _root)
	var restored_primary := _decode_file(primary_path)
	var restored_backup := _decode_file("%s.bak" % primary_path)
	TestAssertions.equal(restored_primary.profile.gold if restored_primary.ok() else -1, 2, "verification failure restores current primary", failures)
	TestAssertions.equal(restored_backup.profile.gold if restored_backup.ok() else -1, 1, "verification failure restores older backup", failures)

func _test_valid_but_different_promotion_restores_generations(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var first := ProfileState.new_profile("profile-verify02", "Verify Exact", 7100)
	first.gold = 1
	TestAssertions.equal(good.save_profile(first, _root), "", "exact verification fixture first save succeeds", failures)
	var current := first.copy()
	current.gold = 2
	current.updated_at_unix = 7101
	TestAssertions.equal(good.save_profile(current, _root), "", "exact verification fixture creates backup", failures)
	var substitute := current.copy()
	substitute.gold = 99
	substitute.updated_at_unix = 7102
	var substituting_promoter := func(temporary: String, target: String) -> Error:
		var promote_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
		if promote_error != OK:
			return promote_error
		var promoted := FileAccess.open(target, FileAccess.WRITE)
		if promoted == null:
			return FileAccess.get_open_error()
		promoted.store_string(ProfileCodec.encode(substitute))
		var write_error := promoted.get_error()
		promoted.close()
		return write_error
	var replacement := current.copy()
	replacement.gold = 3
	replacement.updated_at_unix = 7103
	var failing := ProfileStore.new(AtomicJsonStore.new(substituting_promoter))
	var error := failing.save_profile(replacement, _root)
	TestAssertions.truthy(error.contains("stage=verify-promoted") and error.contains("reason=promoted document differs from verified temporary"), "valid but different promotion reports exact verification failure", failures)
	var primary_path := good.profile_path(first.profile_id, _root)
	var restored_primary := _decode_file(primary_path)
	var restored_backup := _decode_file("%s.bak" % primary_path)
	TestAssertions.equal(restored_primary.profile.gold if restored_primary.ok() else -1, 2, "different valid promotion restores current primary", failures)
	TestAssertions.equal(restored_backup.profile.gold if restored_backup.ok() else -1, 1, "different valid promotion restores older backup", failures)

func _test_post_commit_cleanup_failure_retains_committed_state(failures: Array[String]) -> void:
	var documents := CleanupFailingAtomicJsonStore.new()
	var store := ProfileStore.new(documents)
	var first := ProfileState.new_profile("profile-cleanup1", "Cleanup", 8000)
	TestAssertions.equal(store.save_profile(first, _root), "", "cleanup fixture first save succeeds", failures)
	var second := first.copy()
	second.gold = 2
	second.updated_at_unix = 8001
	TestAssertions.equal(store.save_profile(second, _root), "", "cleanup fixture creates backup", failures)
	documents.failure_path = "%s.bak.previous" % store.profile_path(first.profile_id, _root)
	var third := second.copy()
	third.gold = 3
	third.updated_at_unix = 8002
	var error := store.save_profile(third, _root)
	TestAssertions.equal(error, "", "post-commit cleanup failure does not report the verified promotion as failed", failures)
	var primary_path := store.profile_path(first.profile_id, _root)
	var committed := _decode_file(primary_path)
	var previous := _decode_file("%s.bak" % primary_path)
	var cleanup_debt := _decode_file("%s.bak.previous" % primary_path)
	TestAssertions.equal(committed.profile.gold if committed.ok() else -1, 3, "post-commit cleanup failure retains the committed primary", failures)
	TestAssertions.equal(previous.profile.gold if previous.ok() else -1, 2, "post-commit cleanup failure retains the verified backup", failures)
	TestAssertions.equal(cleanup_debt.profile.gold if cleanup_debt.ok() else -1, 0, "post-commit cleanup debt remains recoverable", failures)

func _test_malformed_schema_field_recovers_backup(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-types001", "Types", 9000)
	profile.gold = 10
	TestAssertions.equal(store.save_profile(profile, _root), "", "typed recovery fixture first save succeeds", failures)
	profile.gold = 20
	profile.updated_at_unix = 9001
	TestAssertions.equal(store.save_profile(profile, _root), "", "typed recovery fixture creates backup", failures)
	var path := store.profile_path(profile.profile_id, _root)
	var malformed := profile.to_dictionary()
	malformed["gold"] = "20"
	_write_text(path, JSON.stringify(malformed))
	var recovered := store.load_profile(profile.profile_id, _root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "malformed schema field triggers verified backup recovery", failures)
	TestAssertions.equal(recovered.profile.gold if recovered.ok() else -1, 10, "typed recovery returns the previous valid generation", failures)

func _test_missing_profile_is_distinct(failures: Array[String]) -> void:
	var missing := ProfileStore.new().load_profile("profile-missing1", _root)
	TestAssertions.truthy(missing.missing and not missing.ok(), "missing profile is not treated as corruption", failures)

func _test_absent_profile_root_lists_cleanly(failures: Array[String]) -> void:
	var absent_root := _root.path_join("absent_%d" % Time.get_ticks_usec())
	ProfileTestSupport.remove_tree(absent_root)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(absent_root)), "absent profile root fixture starts missing", failures)
	TestAssertions.truthy(ProfileStore.new().profile_ids(absent_root).is_empty(), "absent profile root lists as empty", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(absent_root)), "listing absent profile root has no filesystem side effect", failures)

func _corrupt_artifact_path(profile_id: String, names: PackedStringArray) -> String:
	for name: String in names:
		if name.begins_with("%s.json.corrupt-" % profile_id):
			return _root.path_join(name)
	return ""

func _decode_file(path: String) -> ProfileLoadResult:
	return ProfileCodec.decode(FileAccess.get_file_as_string(path))

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _cleanup() -> void:
	ProfileTestSupport.remove_tree(_root)
