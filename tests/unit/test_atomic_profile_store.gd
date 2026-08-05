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
	_test_failed_schema_migration_promotion_preserves_generations(failures)
	_test_successful_schema_migration_promotes_and_retains_source(failures)
	_test_schema_migration_promoted_current_verification_restores_generations(failures)
	_test_profile_load_rejects_traversal_and_mismatched_document(failures)
	_test_profile_load_rejects_oversized_current_stash(failures)
	_test_recovered_schema_one_backup_migrates_with_artifact(failures)
	_test_recovered_schema_one_backup_failed_promotion_remains_recoverable(failures)
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

func _test_failed_schema_migration_promotion_preserves_generations(failures: Array[String]) -> void:
	var path := ProfileStore.new().profile_path("profile-migrate03", _root)
	var documents := AtomicJsonStore.new()
	var older := _schema_two_document("profile-migrate03", 10, 1000)
	var primary := _schema_two_document("profile-migrate03", 20, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	if not loadable_validator.is_valid():
		TestAssertions.truthy(false, "failed migration fixture has a loadable profile validator", failures)
		return
	TestAssertions.equal(documents.save_document(path, older, loadable_validator), "", "failed migration fixture writes older schema-two generation", failures)
	TestAssertions.equal(documents.save_document(path, primary, loadable_validator), "", "failed migration fixture writes schema-two primary", failures)
	var primary_bytes := FileAccess.get_file_as_bytes(path)
	var backup_bytes := FileAccess.get_file_as_bytes("%s.bak" % path)
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var loaded := failing.load_profile("profile-migrate03", _root)
	TestAssertions.truthy(not loaded.ok() and loaded.profile == null and loaded.error.contains("stage=promote"), "failed migration promotion reports no partial profile", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_bytes, "failed migration preserves schema-two primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_bytes, "failed migration preserves schema-two backup bytes", failures)

func _test_successful_schema_migration_promotes_and_retains_source(failures: Array[String]) -> void:
	var path := ProfileStore.new().profile_path("profile-migrate04", _root)
	var documents := AtomicJsonStore.new()
	var older := _schema_one_document("profile-migrate04", 10, 1000)
	var primary := _schema_one_document("profile-migrate04", 20, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	if not loadable_validator.is_valid():
		TestAssertions.truthy(false, "successful migration fixture has a loadable profile validator", failures)
		return
	TestAssertions.equal(documents.save_document(path, older, loadable_validator), "", "successful migration fixture writes older schema-one generation", failures)
	TestAssertions.equal(documents.save_document(path, primary, loadable_validator), "", "successful migration fixture writes schema-one primary", failures)
	var source_primary_bytes := FileAccess.get_file_as_bytes(path)
	var loaded := ProfileStore.new().load_profile("profile-migrate04", _root)
	TestAssertions.truthy(loaded.ok() and loaded.migrated and loaded.source_schema_version == 1, "successful migration reports schema-one source", failures)
	var promoted := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var retained := JSON.parse_string(FileAccess.get_file_as_string("%s.bak" % path)) as Dictionary
	TestAssertions.equal(promoted.get("schema_version", -1), 3, "successful migration stores schema-three primary", failures)
	TestAssertions.equal(retained.get("schema_version", -1), 1, "successful migration retains schema-one backup", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), source_primary_bytes, "successful migration backup exactly retains source primary bytes", failures)

func _test_schema_migration_promoted_current_verification_restores_generations(failures: Array[String]) -> void:
	var profile_id := "profile-migrate05"
	var path := ProfileStore.new().profile_path(profile_id, _root)
	var documents := AtomicJsonStore.new()
	var older := _schema_two_document(profile_id, 10, 1000)
	var primary := _schema_two_document(profile_id, 20, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	TestAssertions.equal(documents.save_document(path, older, loadable_validator), "", "current verification fixture writes older schema-two generation", failures)
	TestAssertions.equal(documents.save_document(path, primary, loadable_validator), "", "current verification fixture writes schema-two primary", failures)
	var primary_bytes := FileAccess.get_file_as_bytes(path)
	var backup_bytes := FileAccess.get_file_as_bytes("%s.bak" % path)
	var schema_two_promoter := func(temporary: String, target: String) -> Error:
		var promote_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
		if promote_error != OK:
			return promote_error
		var promoted := FileAccess.open(target, FileAccess.WRITE)
		if promoted == null:
			return FileAccess.get_open_error()
		promoted.store_string(JSON.stringify(primary, "\t", false))
		var write_error := promoted.get_error()
		promoted.close()
		return write_error
	var loaded := ProfileStore.new(AtomicJsonStore.new(schema_two_promoter)).load_profile(profile_id, _root)
	TestAssertions.truthy(not loaded.ok() and loaded.profile == null, "promoted schema-two substitution exposes no profile", failures)
	TestAssertions.truthy(loaded.error.contains("stage=verify-promoted") and loaded.error.contains("PROFILE_SCHEMA_ERROR"), "promoted candidate is verified with the current validator inside atomic save", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_bytes, "promoted current-verification failure restores schema-two primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_bytes, "promoted current-verification failure restores schema-two backup bytes", failures)

func _test_profile_load_rejects_traversal_and_mismatched_document(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var suffix := str(Time.get_ticks_usec())
	var traversal_root := _root.path_join("traversal_%s" % suffix)
	var escaped_path := _root.path_join("escaped_%s.json" % suffix)
	var traversal := store.load_profile("../escaped_%s" % suffix, traversal_root)
	TestAssertions.truthy(not traversal.ok() and traversal.error.contains("field=profile_id") and traversal.error.contains("invalid profile id"), "traversal profile id is rejected before path construction", failures)
	TestAssertions.truthy(not FileAccess.file_exists(escaped_path), "traversal load creates no escaped file", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(traversal_root)), "traversal load creates no profile root", failures)
	var requested_id := "profile-request01"
	var loaded_id := "profile-loaded001"
	var path := store.profile_path(requested_id, _root)
	var mismatch_document := _schema_one_document(loaded_id, 35, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	TestAssertions.equal(AtomicJsonStore.new().save_document(path, mismatch_document, loadable_validator), "", "mismatched profile fixture writes at requested path", failures)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var mismatch := store.load_profile(requested_id, _root)
	TestAssertions.truthy(not mismatch.ok() and mismatch.profile == null and mismatch.error.contains("profile id mismatch"), "loaded profile id must match the requested id", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "mismatched profile rejection preserves primary bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.bak" % path), "mismatched profile rejection creates no backup", failures)

func _test_profile_load_rejects_oversized_current_stash(failures: Array[String]) -> void:
	var profile_id := "profile-stashcap2"
	var store := ProfileStore.new()
	var path := store.profile_path(profile_id, _root)
	var document := ProfileState.new_profile(profile_id, "Stash Cap", 1000).to_dictionary()
	var tabs: Array[Dictionary] = []
	for index: int in 101:
		tabs.append(ItemSlotContainer.create(
			StringName("stash-tab-%03d" % index),
			ItemSlotContainer.PROFILE_STASH_TAB,
			profile_id,
			ItemSlotContainer.STASH_CAPACITY
		).to_dictionary())
	document["stash_tabs"] = tabs
	_write_text(path, JSON.stringify(document, "\t", false))
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var loaded := store.load_profile(profile_id, _root)
	TestAssertions.truthy(not loaded.ok() and loaded.profile == null and loaded.error.contains("field=stash_tabs") and loaded.error.contains("maximum 100"), "profile load rejects 101 valid unique stash tabs", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "oversized stash load rejection preserves exact primary bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists("%s.bak" % path), "oversized stash load rejection creates no backup generation", failures)

func _test_recovered_schema_one_backup_migrates_with_artifact(failures: Array[String]) -> void:
	var profile_id := "profile-migrate06"
	var path := ProfileStore.new().profile_path(profile_id, _root)
	var documents := AtomicJsonStore.new()
	var backup_source := _schema_one_document(profile_id, 10, 1000)
	var primary_source := _schema_one_document(profile_id, 20, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	TestAssertions.equal(documents.save_document(path, backup_source, loadable_validator), "", "recovered migration fixture writes backup source", failures)
	TestAssertions.equal(documents.save_document(path, primary_source, loadable_validator), "", "recovered migration fixture writes primary source", failures)
	var backup_bytes := FileAccess.get_file_as_bytes("%s.bak" % path)
	var corrupt_bytes := "corrupt schema-one primary before migration"
	_write_text(path, corrupt_bytes)
	var loaded := ProfileStore.new().load_profile(profile_id, _root)
	TestAssertions.truthy(loaded.ok() and loaded.recovered_from_backup and loaded.migrated and loaded.source_schema_version == 1, "recovered schema-one backup migrates with source metadata", failures)
	TestAssertions.equal(loaded.profile.gold if loaded.ok() else -1, 10, "recovered migration returns the backup generation", failures)
	var promoted := JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	TestAssertions.equal(promoted.get("schema_version", -1), 3, "recovered migration promotes schema-three primary", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_bytes, "recovered migration retains schema-one backup bytes", failures)
	var artifact_path := _corrupt_artifact_path(profile_id, DirAccess.get_files_at(_root))
	TestAssertions.truthy(not artifact_path.is_empty(), "recovered migration preserves corrupt-primary artifact", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(artifact_path) if not artifact_path.is_empty() else "", corrupt_bytes, "recovered migration artifact retains corrupt bytes", failures)

func _test_recovered_schema_one_backup_failed_promotion_remains_recoverable(failures: Array[String]) -> void:
	var profile_id := "profile-migrate07"
	var path := ProfileStore.new().profile_path(profile_id, _root)
	var documents := AtomicJsonStore.new()
	var backup_source := _schema_one_document(profile_id, 10, 1000)
	var primary_source := _schema_one_document(profile_id, 20, 1001)
	var loadable_validator := Callable(ProfileCodec, "validate_loadable_document")
	TestAssertions.equal(documents.save_document(path, backup_source, loadable_validator), "", "recovered failure fixture writes backup source", failures)
	TestAssertions.equal(documents.save_document(path, primary_source, loadable_validator), "", "recovered failure fixture writes primary source", failures)
	var backup_bytes := FileAccess.get_file_as_bytes("%s.bak" % path)
	var corrupt_bytes := "corrupt schema-one primary before failed migration"
	_write_text(path, corrupt_bytes)
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var loaded := failing.load_profile(profile_id, _root)
	TestAssertions.truthy(not loaded.ok() and loaded.profile == null and loaded.error.contains("stage=promote"), "failed recovered migration exposes no partial profile", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_bytes, "failed recovered migration preserves backup bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), backup_bytes, "failed recovered migration restores a loadable schema-one primary", failures)
	var artifact_path := _corrupt_artifact_path(profile_id, DirAccess.get_files_at(_root))
	TestAssertions.equal(FileAccess.get_file_as_string(artifact_path) if not artifact_path.is_empty() else "", corrupt_bytes, "failed recovered migration retains corrupt artifact bytes", failures)
	var recoverable := AtomicJsonStore.new().load_document(path, loadable_validator, false)
	TestAssertions.truthy(recoverable.ok() and int(recoverable.document.get("schema_version", -1)) == 1, "failed recovered migration remains loadable from schema one", failures)

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

func _schema_one_document(profile_id: String, gold: int, updated_at_unix: int) -> Dictionary:
	return {
		"schema_version": 1,
		"profile_id": profile_id,
		"display_name": "Legacy",
		"created_at_unix": 1000,
		"updated_at_unix": updated_at_unix,
		"prologue_state": ProfileState.PrologueState.NOT_STARTED,
		"last_safe_checkpoint": {},
		"gold": gold,
		"passive_points_available": 0,
		"passive_points_lifetime_earned": 0,
		"milestones": [],
		"permanent_feature_unlocks": [],
		"discovered_buildings": [],
		"discovered_trees": [],
		"tree_allocations": {},
		"tree_visibility_progress": {},
		"owned_characters": {},
		"squad_capacity": 1,
		"inventory_columns": 0,
		"stash_tabs": [],
		"extraction_capacity": 0,
		"run_history": [],
		"resumable_run": {},
		"applied_transactions": {},
	}

func _schema_two_document(profile_id: String, gold: int, updated_at_unix: int) -> Dictionary:
	var document := _schema_one_document(profile_id, gold, updated_at_unix)
	var item_id := "item-%s-sword" % profile_id
	document["schema_version"] = 2
	document["item_records"] = {
		"schema_version": 1,
		"items": [{
			"affixes": [],
			"base_definition_id": "forge_vanguard_sword",
			"instance_id": item_id,
			"item_level": 28,
			"origin": {
				"issuer_namespace": "profile:%s" % profile_id,
				"seed": 4402,
				"sequence": 0,
				"source": "schema_two_atomic_fixture",
			},
			"rarity_id": "common",
			"schema_version": 1,
		}],
	}
	document["stash_tabs"] = [ItemSlotContainer.create(
		&"stash-tab-000",
		ItemSlotContainer.PROFILE_STASH_TAB,
		profile_id,
		ItemSlotContainer.STASH_CAPACITY,
		{42: item_id}
	).to_dictionary()]
	document["next_item_sequence"] = 1
	return document

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _cleanup() -> void:
	ProfileTestSupport.remove_tree(_root)
