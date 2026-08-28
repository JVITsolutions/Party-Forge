extends RefCounted

var _root := ""

class CleanupFailingAtomicJsonStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

class PostCommitReportingFailureAtomicJsonStore extends AtomicJsonStore:
	func _cleanup_paths(_paths: Array[String]) -> Error:
		return ERR_CANT_CREATE

	func _sanitize_remaining_artifacts(
		_paths: Array[String],
		_contents: String,
		_validator: Callable,
		_expected_canonical: String
	) -> Error:
		return ERR_CANT_CREATE

class PreflightArtifactFailureAtomicJsonStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

	func _write_text(path: String, contents: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._write_text(path, contents)

class GeneratedReadFailureAtomicJsonStore extends AtomicJsonStore:
	var target := ""
	var target_reads := 0

	func _generated_read_bytes(path: String) -> Dictionary:
		if path == target:
			target_reads += 1
			if target_reads == 3:
				return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return super._generated_read_bytes(path)

class GeneratedCleanupFailureAtomicJsonStore extends AtomicJsonStore:
	func _generated_cleanup_directory(_path: String) -> Error:
		return ERR_CANT_CREATE

class GeneratedWriteFailureAtomicJsonStore extends AtomicJsonStore:
	func _generated_write_bytes(path: String, bytes: PackedByteArray) -> Error:
		if path.ends_with("candidate.json"):
			return ERR_CANT_CREATE
		return super._generated_write_bytes(path, bytes)

class GeneratedRestoreFailureAtomicJsonStore extends AtomicJsonStore:
	var target := ""

	func _generated_write_bytes(path: String, bytes: PackedByteArray) -> Error:
		if path == target:
			return ERR_CANT_CREATE
		return super._generated_write_bytes(path, bytes)

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_store_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_cleanup()
	_test_round_trip_and_backup_recovery(failures)
	_test_irreversible_save_replaces_both_recovery_generations(failures)
	_test_irreversible_promotion_order_keeps_a_discoverable_generation(failures)
	_test_irreversible_save_second_promotion_failure_restores_exact_generations(failures)
	_test_irreversible_reported_promotion_failure_accepts_verified_commit(failures)
	_test_irreversible_post_commit_reporting_failure_returns_success(failures)
	_test_irreversible_cleanup_debt_is_sanitized(failures)
	_test_irreversible_preflight_failure_preserves_active_generations(failures)
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
	_test_generated_document_boundary(failures)
	_test_generated_recovery_preflight(failures)
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

func _test_irreversible_save_replaces_both_recovery_generations(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-irrev-ok", "Irreversible", 1100)
	profile.gold = 1
	TestAssertions.equal(store.save_profile(profile, _root), "", "irreversible fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1101
	TestAssertions.equal(store.save_profile(profile, _root), "", "irreversible fixture creates an older recovery generation", failures)
	profile.gold = 99
	profile.updated_at_unix = 1102
	TestAssertions.equal(store.save_profile_irreversible(profile, _root), "", "irreversible save commits two sanitized generations", failures)
	var path := store.profile_path(profile.profile_id, _root)
	TestAssertions.equal(_decode_file(path).profile.gold, 99, "irreversible primary contains the committed state", failures)
	TestAssertions.equal(_decode_file("%s.bak" % path).profile.gold, 99, "irreversible backup contains the committed state", failures)
	for file_name: String in DirAccess.get_files_at(_root):
		TestAssertions.truthy(not file_name.contains("profile-irrev-ok.json.irreversible") and file_name != "profile-irrev-ok.json.bak.previous", "irreversible success leaves no displaced recovery artifact", failures)
	_write_text(path, "corrupt irreversible primary")
	var recovered := store.load_profile(profile.profile_id, _root)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "irreversible state recovers from its sanitized backup", failures)
	TestAssertions.equal(recovered.profile.gold if recovered.ok() else -1, 99, "irreversible recovery cannot restore the displaced state", failures)

func _test_irreversible_promotion_order_keeps_a_discoverable_generation(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-irrev-order", "Irreversible Order", 1150)
	profile.gold = 1
	TestAssertions.equal(good.save_profile(profile, _root), "", "irreversible ordering fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1151
	TestAssertions.equal(good.save_profile(profile, _root), "", "irreversible ordering fixture creates recovery generation", failures)
	var path := good.profile_path(profile.profile_id, _root)
	var backup := "%s.bak" % path
	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes(backup)
	var observed_targets: Array[String] = []
	var recoverable_at_boundary: Array[bool] = []
	var documents := AtomicJsonStore.new(func(temporary: String, target: String) -> Error:
		observed_targets.append(target)
		var recovered := ProfileStore.new().load_profile(profile.profile_id, _root)
		recoverable_at_boundary.append(recovered.ok())
		if observed_targets.size() == 2:
			return ERR_CANT_CREATE
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	)
	profile.gold = 99
	profile.updated_at_unix = 1152
	var error := ProfileStore.new(documents).save_profile_irreversible(profile, _root)
	TestAssertions.truthy(not error.is_empty(), "irreversible boundary fixture reports its injected second-promotion failure", failures)
	TestAssertions.equal(observed_targets, [backup, path], "irreversible promotion is backup-first then primary", failures)
	TestAssertions.equal(recoverable_at_boundary, [true, true], "a discoverable profile generation exists at every promotion boundary", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_before, "boundary failure restores exact primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(backup), backup_before, "boundary failure restores exact backup bytes", failures)

func _test_irreversible_save_second_promotion_failure_restores_exact_generations(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-irrev-fail", "Irreversible Failure", 1200)
	profile.gold = 1
	TestAssertions.equal(good.save_profile(profile, _root), "", "irreversible failure fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1201
	TestAssertions.equal(good.save_profile(profile, _root), "", "irreversible failure fixture creates recovery generation", failures)
	var path := good.profile_path(profile.profile_id, _root)
	var primary_before := FileAccess.get_file_as_bytes(path)
	var backup_before := FileAccess.get_file_as_bytes("%s.bak" % path)
	var promotions := [0]
	var failing_documents := AtomicJsonStore.new(func(temporary: String, target: String) -> Error:
		promotions[0] += 1
		if promotions[0] == 2:
			return ERR_CANT_CREATE
		return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	)
	profile.gold = 99
	profile.updated_at_unix = 1202
	var error := ProfileStore.new(failing_documents).save_profile_irreversible(profile, _root)
	TestAssertions.truthy(error.contains("stage=promote-primary"), "irreversible second-promotion failure is reported", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_before, "irreversible second-promotion failure restores exact primary bytes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes("%s.bak" % path), backup_before, "irreversible second-promotion failure restores exact backup bytes", failures)
	for file_name: String in DirAccess.get_files_at(_root):
		TestAssertions.truthy(not file_name.contains("profile-irrev-fail.json.irreversible"), "irreversible failure leaves no staging artifact", failures)

func _test_irreversible_reported_promotion_failure_accepts_verified_commit(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-irrev-reported", "Reported Failure", 1250)
	profile.gold = 1
	TestAssertions.equal(good.save_profile(profile, _root), "", "reported-failure fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1251
	TestAssertions.equal(good.save_profile(profile, _root), "", "reported-failure fixture creates recovery generation", failures)
	var path := good.profile_path(profile.profile_id, _root)
	var promotions := [0]
	var reporting_documents := AtomicJsonStore.new(func(temporary: String, target: String) -> Error:
		promotions[0] += 1
		var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
		if promotions[0] == 2 and rename_error == OK:
			return ERR_CANT_CREATE
		return rename_error
	)
	profile.gold = 99
	profile.updated_at_unix = 1252
	var error := ProfileStore.new(reporting_documents).save_profile_irreversible(profile, _root)
	TestAssertions.equal(error, "", "a reported late promotion failure returns committed success when both active generations verify", failures)
	TestAssertions.equal(_decode_file(path).profile.gold, 99, "reported-failure primary retains the verified committed generation", failures)
	TestAssertions.equal(_decode_file("%s.bak" % path).profile.gold, 99, "reported-failure backup retains the verified committed generation", failures)

func _test_irreversible_post_commit_reporting_failure_returns_success(failures: Array[String]) -> void:
	var documents := PostCommitReportingFailureAtomicJsonStore.new()
	var store := ProfileStore.new(documents)
	var profile := ProfileState.new_profile("profile-irrev-committed", "Committed", 1275)
	profile.gold = 1
	TestAssertions.equal(store.save_profile(profile, _root), "", "post-commit fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1276
	TestAssertions.equal(store.save_profile(profile, _root), "", "post-commit fixture creates recovery generation", failures)
	profile.gold = 99
	profile.updated_at_unix = 1277
	var error := store.save_profile_irreversible(profile, _root)
	var path := store.profile_path(profile.profile_id, _root)
	TestAssertions.equal(error, "", "post-commit cleanup and sanitize reporting failures cannot surface an ordinary save failure", failures)
	TestAssertions.equal(_decode_file(path).profile.gold, 99, "post-commit reporting failure leaves sanitized primary active", failures)
	TestAssertions.equal(_decode_file("%s.bak" % path).profile.gold, 99, "post-commit reporting failure leaves sanitized backup active", failures)
	for file_name: String in DirAccess.get_files_at(_root):
		TestAssertions.truthy(not file_name.contains("profile-irrev-committed.json.irreversible"), "post-commit reporting failure leaves no rollback artifact with displaced data", failures)

func _test_irreversible_cleanup_debt_is_sanitized(failures: Array[String]) -> void:
	var documents := CleanupFailingAtomicJsonStore.new()
	var store := ProfileStore.new(documents)
	var profile := ProfileState.new_profile("profile-irrev-debt", "Irreversible Debt", 1300)
	profile.gold = 1
	TestAssertions.equal(store.save_profile(profile, _root), "", "irreversible cleanup fixture saves original generation", failures)
	profile.gold = 2
	profile.updated_at_unix = 1301
	TestAssertions.equal(store.save_profile(profile, _root), "", "irreversible cleanup fixture creates recovery generation", failures)
	var path := store.profile_path(profile.profile_id, _root)
	documents.failure_path = "%s.bak.previous" % path
	var debt_file := FileAccess.open(documents.failure_path, FileAccess.WRITE)
	debt_file.store_buffer(FileAccess.get_file_as_bytes(path))
	debt_file.close()
	profile.gold = 99
	profile.updated_at_unix = 1302
	TestAssertions.equal(store.save_profile_irreversible(profile, _root), "", "irreversible cleanup debt remains a committed success", failures)
	TestAssertions.equal(_decode_file(path).profile.gold, 99, "cleanup-debt primary is sanitized", failures)
	TestAssertions.equal(_decode_file("%s.bak" % path).profile.gold, 99, "cleanup-debt backup is sanitized", failures)
	TestAssertions.equal(_decode_file(documents.failure_path).profile.gold, 99, "undeletable displaced artifact is overwritten with sanitized state", failures)
	profile.gold = 100
	profile.updated_at_unix = 1303
	TestAssertions.equal(store.save_profile_irreversible(profile, _root), "", "a retained sanitized cleanup artifact does not poison the next irreversible save", failures)
	TestAssertions.equal(_decode_file(path).profile.gold, 100, "cleanup-debt retry updates primary", failures)
	TestAssertions.equal(_decode_file("%s.bak" % path).profile.gold, 100, "cleanup-debt retry updates backup", failures)
	TestAssertions.equal(_decode_file(documents.failure_path).profile.gold, 100, "cleanup-debt retry re-sanitizes the retained artifact", failures)

func _test_irreversible_preflight_failure_preserves_active_generations(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"id": "profile-preflight-prev", "suffix": ".bak.previous", "label": "legacy displaced backup"},
		{"id": "profile-preflight-primary-corrupt", "suffix": ".corrupt-1700000000", "label": "profile corrupt artifact"},
		{"id": "profile-preflight-backup-corrupt", "suffix": ".bak.corrupt-1700000000", "label": "backup corrupt artifact"},
	]
	for test_case: Dictionary in cases:
		var profile_id := String(test_case["id"])
		var label := String(test_case["label"])
		var good := ProfileStore.new()
		var profile := ProfileState.new_profile(profile_id, "Preflight", 1350)
		profile.gold = 1
		TestAssertions.equal(good.save_profile(profile, _root), "", "%s fixture saves original generation" % label, failures)
		profile.gold = 2
		profile.updated_at_unix = 1351
		TestAssertions.equal(good.save_profile(profile, _root), "", "%s fixture creates recovery generation" % label, failures)
		var path := good.profile_path(profile_id, _root)
		var backup := "%s.bak" % path
		var primary_before := FileAccess.get_file_as_bytes(path)
		var backup_before := FileAccess.get_file_as_bytes(backup)
		var residual_path := "%s%s" % [path, String(test_case["suffix"])]
		var doomed_bytes := primary_before
		var residual := FileAccess.open(residual_path, FileAccess.WRITE)
		if residual != null:
			residual.store_buffer(doomed_bytes)
			residual.close()
		var other_profile_artifact := _root.path_join("profile-preflight-neighbor.json.corrupt-%s" % profile_id)
		var other_bytes := ("other profile sentinel for %s" % profile_id).to_utf8_buffer()
		var other := FileAccess.open(other_profile_artifact, FileAccess.WRITE)
		if other != null:
			other.store_buffer(other_bytes)
			other.close()
		var documents := PreflightArtifactFailureAtomicJsonStore.new()
		documents.failure_path = residual_path
		profile.gold = 99
		profile.updated_at_unix = 1352
		var error := ProfileStore.new(documents).save_profile_irreversible(profile, _root)
		TestAssertions.truthy(error.contains("stage=preflight-artifacts"), "%s sanitation failure aborts at preflight" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), primary_before, "%s preflight failure preserves exact primary bytes" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(backup), backup_before, "%s preflight failure preserves exact backup bytes" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(residual_path), doomed_bytes, "%s failed sanitation does not disguise the residual artifact" % label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(other_profile_artifact), other_bytes, "%s preflight does not touch another profile artifact" % label, failures)

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
	TestAssertions.equal(promoted.get("schema_version", -1), 5, "successful migration stores schema-five primary", failures)
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
	TestAssertions.equal(promoted.get("schema_version", -1), 5, "recovered migration promotes schema-five primary", failures)
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

func _test_generated_document_boundary(failures: Array[String]) -> void:
	var target := _root.path_join("generated-target.json")
	var staging_root := _root.path_join("generated-staging")
	var original := "{\"original\":true}\n".to_utf8_buffer()
	_write_bytes(target, original)
	var oversized_staging_root := _root.path_join("generated-oversized-staging")
	var oversized_document := _generated_maximum_multibyte_document()
	var compact := JSON.stringify(oversized_document).to_utf8_buffer()
	var canonical := (JSON.stringify(oversized_document, "  ", false) + "\n").to_utf8_buffer()
	TestAssertions.truthy(compact.size() <= CityAccessSnapshotLoader.MAX_BYTES and canonical.size() > CityAccessSnapshotLoader.MAX_BYTES, "generated oversized fixture crosses only the canonical byte ceiling", failures)
	var oversized_result: Variant = AtomicJsonStore.new().save_generated_document(target, oversized_document, Callable(CityAccessSnapshotLoader, "validate_document"), oversized_staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_stage(oversized_result), "encode", "generated canonical bytes over production limit reject during encode", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(target) == original, "generated canonical byte rejection preserves exact target bytes", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(oversized_staging_root)), "generated canonical byte rejection creates no staging root", failures)
	ProfileTestSupport.remove_tree(oversized_staging_root)
	_write_bytes(target, original)
	var over_limit_staging_root := _root.path_join("generated-over-limit-staging")
	var over_limit_result: Variant = AtomicJsonStore.new().save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), over_limit_staging_root, Callable(self, "_encode_generated_over_limit"))
	TestAssertions.equal(_generated_stage(over_limit_result), "encode", "generated encoder bytes over production limit reject during encode", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(target) == original, "generated over-limit encoder rejection preserves exact target bytes", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(over_limit_staging_root)), "generated over-limit encoder rejection creates no staging root", failures)
	ProfileTestSupport.remove_tree(over_limit_staging_root)
	_write_bytes(target, original)
	var exact_invalid_staging_root := _root.path_join("generated-exact-invalid-staging")
	var exact_invalid_result: Variant = AtomicJsonStore.new().save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), exact_invalid_staging_root, Callable(self, "_encode_generated_replacement_character"))
	TestAssertions.equal(_generated_stage(exact_invalid_result), "encode", "generated bytes rejected by the production loader reject during encode", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(target) == original, "generated production-loader rejection preserves exact target bytes", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(exact_invalid_staging_root)), "generated production-loader rejection creates no staging root", failures)
	ProfileTestSupport.remove_tree(exact_invalid_staging_root)
	_write_bytes(target, original)
	var rejected: Variant = AtomicJsonStore.new().save_generated_document(target, _generated_document(), func(_document: Dictionary): return "rejected", staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(rejected, "rejected", false, "validate", "validator-rejected", "generated validation rejects before disk mutation", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "rejected generated document preserves exact target bytes", failures)
	TestAssertions.truthy(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(staging_root)), "rejected generated document creates no staging root", failures)
	var write_failure := GeneratedWriteFailureAtomicJsonStore.new()
	var write_error: Variant = write_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(write_error, "rejected", false, "write", "code-%d-cleanup-0" % ERR_CANT_CREATE, "generated staged-write failure reports its stage", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "generated staged-write failure preserves exact target bytes", failures)

	var promoted_paths: Array[String] = []
	var promote_failure := AtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		promoted_paths.append(temporary)
		return ERR_CANT_CREATE
	)
	var failed: Variant = promote_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(failed, "rejected", false, "promote", "code-%d-restore-0-cleanup-0" % ERR_CANT_CREATE, "generated promotion failure reports its stage", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "generated pre-promotion failure preserves exact target bytes", failures)
	TestAssertions.truthy(promoted_paths.size() == 1 and promoted_paths[0].begins_with(staging_root.path_join("invocation-")), "generated temporary promotion path stays beneath staging root", failures)
	var traversal_root := staging_root.path_join("nominal/../canonical")
	var traversal_paths: Array[String] = []
	var traversal_failure := AtomicJsonStore.new(func(temporary: String, _promoted_target: String) -> Error:
		traversal_paths.append(temporary)
		return ERR_CANT_CREATE
	)
	var traversal_error: Variant = traversal_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), traversal_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	var canonical_root := ProjectSettings.globalize_path(traversal_root.simplify_path()).simplify_path()
	var canonical_temporary := ProjectSettings.globalize_path(traversal_paths[0]).simplify_path() if traversal_paths.size() == 1 else ""
	TestAssertions.equal(_generated_stage(traversal_error), "promote", "canonical traversal fixture reaches the injected promotion boundary", failures)
	TestAssertions.truthy(traversal_paths.size() == 1 and not traversal_paths[0].contains("..") and _is_strict_descendant(canonical_temporary, canonical_root), "generated staging paths are canonical strict descendants rather than textual prefixes", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "canonical traversal failure preserves exact target bytes", failures)
	var unconfined_promotions := [0]
	var unconfined := AtomicJsonStore.new(func(_temporary: String, _promoted_target: String) -> Error:
		unconfined_promotions[0] += 1
		return ERR_CANT_CREATE
	)
	var unconfined_error: Variant = unconfined.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), "", Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.truthy(_generated_stage(unconfined_error) == "confinement" and unconfined_promotions[0] == 0, "unprovable staging containment rejects before promotion", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "unprovable staging containment preserves exact target bytes", failures)
	var wrong_bytes := "{\"wrong\":true}".to_utf8_buffer()
	var wrong_promotion := AtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	var wrong_error: Variant = wrong_promotion.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(wrong_error, "rejected", false, "promote", "code-%d-restore-0-cleanup-0" % ERR_CANT_CREATE, "wrong-byte reported promotion failure reports verified rejection", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "wrong-byte reported promotion failure restores exact previous bytes", failures)

	var mismatching_promotion := AtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return OK
	)
	var mismatch_error: Variant = mismatching_promotion.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(mismatch_error), "rejected", "promoted-byte mismatch reports verified rejection", failures)
	TestAssertions.equal(_generated_stage(mismatch_error), "verify-promoted", "promoted-byte mismatch reports verification stage", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "promoted-byte mismatch restores exact previous bytes", failures)

	var late_error_promotion := AtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		var promote_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(promoted_target))
		return ERR_CANT_CREATE if promote_error == OK else promote_error
	)
	var late_error_result: Variant = late_error_promotion.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(late_error_result, "committed", false, "verified", "", "reported promotion failure accepts exact verified candidate", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(target) == CityAccessSnapshotCodec.encode_document(_generated_document()), "reported promotion failure retains exact committed candidate", failures)
	_write_bytes(target, original)

	var no_target := _root.path_join("generated-no-target.json")
	var no_target_failure := AtomicJsonStore.new(func(_temporary: String, _promoted_target: String) -> Error: return ERR_CANT_CREATE)
	var no_target_error: Variant = no_target_failure.save_generated_document(no_target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.truthy(_generated_state(no_target_error) == "rejected" and _generated_stage(no_target_error) == "promote" and not FileAccess.file_exists(no_target), "generated failure without prior target verifies restored absence", failures)

	var read_failure := GeneratedReadFailureAtomicJsonStore.new()
	read_failure.target = target
	var read_error: Variant = read_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.truthy(_generated_state(read_error) == "rejected" and _generated_stage(read_error) == "verify-promoted", "generated promoted-byte read failure reports verified rejection: %s" % [str(read_error)], failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original, "generated promoted-byte failure restores exact previous bytes", failures)

	var restore_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	restore_failure.target = target
	var indeterminate: Variant = restore_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(indeterminate as Dictionary, {"ok": false, "state": "indeterminate", "cleanupDebt": false, "stage": "restore", "reason": "code-%d" % ERR_CANT_CREATE}, "restore failure reports exact indeterminate contract", failures)
	TestAssertions.truthy(FileAccess.get_file_as_bytes(target) == wrong_bytes, "restore failure does not claim exact previous bytes", failures)
	var recovery_record := staging_root.path_join("pending-transaction.json")
	TestAssertions.truthy(FileAccess.file_exists(recovery_record), "restore failure retains a recovery record", failures)
	TestAssertions.truthy(_all_files_are_descendants(staging_root), "restore failure keeps all evidence beneath staging root", failures)
	var recovered: Variant = AtomicJsonStore.new().save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(recovered), "committed", "later invocation resolves interrupted rollback before committing", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_generated_document()), "interrupted transaction recovery commits exact candidate", failures)
	TestAssertions.truthy(not FileAccess.file_exists(recovery_record), "successful interrupted recovery clears recovery record", failures)

	var alternate_document := _generated_document()
	alternate_document["source"]["sha256"] = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
	var second_restore_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	second_restore_failure.target = target
	var second_indeterminate: Variant = second_restore_failure.save_generated_document(target, alternate_document, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(second_indeterminate), "indeterminate", "second restore failure retains another pending transaction", failures)
	_write_bytes(target, CityAccessSnapshotCodec.encode_document(alternate_document))
	var recovered_commit: Variant = AtomicJsonStore.new().save_generated_document(target, alternate_document, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(recovered_commit), "unchanged", "pending verified candidate continues to the current unchanged comparison", failures)
	TestAssertions.truthy(not FileAccess.file_exists(recovery_record), "recovered committed candidate clears recovery record", failures)

	var entry_recovery_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	entry_recovery_failure.target = target
	var entry_indeterminate: Variant = entry_recovery_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(entry_indeterminate), "indeterminate", "entry-order fixture retains pending recovery", failures)
	var invalid_after_pending: Variant = AtomicJsonStore.new().save_generated_document(target, {}, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.truthy(_generated_state(invalid_after_pending) == "rejected" and _generated_stage(invalid_after_pending) == "validate", "writer resolves pending recovery before rejecting a new invalid document", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(alternate_document), "entry recovery restores the exact prior target before new-document validation", failures)
	TestAssertions.truthy(not FileAccess.file_exists(recovery_record), "entry recovery clears the retained record before new-document validation", failures)

	var missing_validator_target := _root.path_join("generated-missing-validator-target.json")
	var missing_validator_staging := _root.path_join("generated-missing-validator-staging")
	var alternate_bytes := CityAccessSnapshotCodec.encode_document(alternate_document)
	_write_bytes(missing_validator_target, alternate_bytes)
	var missing_validator_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	missing_validator_failure.target = missing_validator_target
	var missing_validator_pending: Variant = missing_validator_failure.save_generated_document(missing_validator_target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), missing_validator_staging, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(missing_validator_pending), "indeterminate", "missing-validator fixture retains pending recovery", failures)
	_write_bytes(missing_validator_target, CityAccessSnapshotCodec.encode_document(_generated_document()))
	var missing_validator_result: Variant = AtomicJsonStore.new().save_generated_document(missing_validator_target, {}, Callable(), missing_validator_staging, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(missing_validator_result, "rejected", false, "validate", "validator-or-encoder-is-missing", "missing validator rejects only after pending recovery", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(missing_validator_target), alternate_bytes, "missing validator invocation restores exact recorded prior bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists(missing_validator_staging.path_join("pending-transaction.json")), "missing validator invocation clears resolved recovery evidence", failures)

	var missing_encoder_target := _root.path_join("generated-missing-encoder-target.json")
	var missing_encoder_staging := _root.path_join("generated-missing-encoder-staging")
	_write_bytes(missing_encoder_target, alternate_bytes)
	var missing_encoder_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, wrong_bytes)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	missing_encoder_failure.target = missing_encoder_target
	var missing_encoder_pending: Variant = missing_encoder_failure.save_generated_document(missing_encoder_target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), missing_encoder_staging, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(missing_encoder_pending), "indeterminate", "missing-encoder fixture retains pending recovery", failures)
	_write_bytes(missing_encoder_target, CityAccessSnapshotCodec.encode_document(_generated_document()))
	var missing_encoder_result: Variant = AtomicJsonStore.new().save_generated_document(missing_encoder_target, {}, Callable(CityAccessSnapshotLoader, "validate_document"), missing_encoder_staging, Callable())
	_assert_generated_outcome(missing_encoder_result, "rejected", false, "validate", "validator-or-encoder-is-missing", "missing encoder rejects only after pending recovery", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(missing_encoder_target), alternate_bytes, "missing encoder invocation restores exact recorded prior bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists(missing_encoder_staging.path_join("pending-transaction.json")), "missing encoder invocation clears resolved recovery evidence", failures)

	var unchanged: Variant = AtomicJsonStore.new().save_generated_document(target, alternate_document, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(unchanged, "unchanged", false, "compare", "", "exact target parity returns unchanged without a transaction", failures)

	var cleanup_failure := GeneratedCleanupFailureAtomicJsonStore.new()
	var cleanup_result: Variant = cleanup_failure.save_generated_document(target, _generated_document(), Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	_assert_generated_outcome(cleanup_result, "committed", true, "cleanup", "code-%d" % ERR_CANT_CREATE, "generated cleanup debt returns committed success", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), CityAccessSnapshotCodec.encode_document(_generated_document()), "generated cleanup debt retains canonical committed bytes", failures)

func _assert_generated_outcome(result: Variant, state: String, cleanup_debt: bool, stage: String, reason: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(result is Dictionary, label, failures)
	if result is Dictionary:
		TestAssertions.equal(result as Dictionary, {"ok": state in ["unchanged", "committed"], "state": state, "cleanupDebt": cleanup_debt, "stage": stage, "reason": reason}, label, failures)

func _assert_generated_recovery(result: Variant, resolution: String, cleanup_debt: bool, stage: String, reason: String, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(result is Dictionary, label, failures)
	if result is Dictionary:
		TestAssertions.equal(result as Dictionary, {"resolution": resolution, "cleanupDebt": cleanup_debt, "stage": stage, "reason": reason}, label, failures)

func _test_generated_recovery_preflight(failures: Array[String]) -> void:
	var store := AtomicJsonStore.new()
	if not store.has_method("recover_generated_document"):
		TestAssertions.truthy(false, "generated store exposes a writer-owned recovery preflight", failures)
		return
	var target := _root.path_join("generated-recovery-preflight.json")
	var staging_root := _root.path_join("generated-recovery-preflight-staging")
	var original := _generated_document()
	var candidate := _generated_document()
	candidate["source"]["sha256"] = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
	var original_bytes := CityAccessSnapshotCodec.encode_document(original)
	var candidate_bytes := CityAccessSnapshotCodec.encode_document(candidate)
	_write_bytes(target, original_bytes)
	_assert_generated_recovery(
		store.call("recover_generated_document", target, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root),
		"none", false, "recovery", "", "no pending generated transaction is proven safe", failures,
	)

	var restore_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, "{\"wrong\":true}".to_utf8_buffer())
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	restore_failure.target = target
	var pending: Variant = restore_failure.save_generated_document(target, candidate, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))
	TestAssertions.equal(_generated_state(pending), "indeterminate", "rollback failure retains recovery evidence for preflight", failures)
	_assert_generated_recovery(
		store.call("recover_generated_document", target, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root),
		"rolled_back", false, "recovery", "", "recovery preflight restores and verifies the prior target", failures,
	)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), original_bytes, "recovery preflight restores exact prior bytes", failures)
	TestAssertions.truthy(not FileAccess.file_exists(staging_root.path_join("pending-transaction.json")), "verified rollback clears pending evidence", failures)

	var candidate_failure := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, "{\"wrong\":true}".to_utf8_buffer())
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	candidate_failure.target = target
	TestAssertions.equal(_generated_state(candidate_failure.save_generated_document(target, candidate, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))), "indeterminate", "candidate recovery fixture retains evidence", failures)
	_write_bytes(target, candidate_bytes)
	_assert_generated_recovery(
		store.call("recover_generated_document", target, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root),
		"candidate_verified", false, "verified", "", "recovery preflight accepts an already verified candidate", failures,
	)
	TestAssertions.equal(FileAccess.get_file_as_bytes(target), candidate_bytes, "verified candidate recovery preserves candidate bytes", failures)

	_write_bytes(target, original_bytes)
	var unresolved_fixture := GeneratedRestoreFailureAtomicJsonStore.new(func(temporary: String, promoted_target: String) -> Error:
		_write_bytes(promoted_target, "{\"wrong\":true}".to_utf8_buffer())
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ERR_CANT_CREATE
	)
	unresolved_fixture.target = target
	TestAssertions.equal(_generated_state(unresolved_fixture.save_generated_document(target, candidate, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root, Callable(CityAccessSnapshotCodec, "encode_document"))), "indeterminate", "unresolved recovery fixture retains evidence", failures)
	var unresolved_store := GeneratedRestoreFailureAtomicJsonStore.new()
	unresolved_store.target = target
	_assert_generated_recovery(
		unresolved_store.call("recover_generated_document", target, Callable(CityAccessSnapshotLoader, "validate_document"), staging_root),
		"indeterminate", false, "restore", "code-%d" % ERR_CANT_CREATE, "unprovable recovery remains indeterminate", failures,
	)
	TestAssertions.truthy(FileAccess.file_exists(staging_root.path_join("pending-transaction.json")), "unprovable recovery retains transaction evidence", failures)
	ProfileTestSupport.remove_tree(staging_root)
	_write_bytes(target, original_bytes)

func _generated_state(result: Variant) -> String:
	return String((result as Dictionary).get("state", "")) if result is Dictionary else ""

func _generated_stage(result: Variant) -> String:
	return String((result as Dictionary).get("stage", "")) if result is Dictionary else ""

func _all_files_are_descendants(root: String) -> bool:
	var absolute_root: String = ProjectSettings.globalize_path(root).simplify_path()
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var directory_path: String = directories.pop_back()
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			return false
		for child: String in directory.get_directories():
			directories.append(directory_path.path_join(child))
		for file_name: String in directory.get_files():
			if not _is_strict_descendant(ProjectSettings.globalize_path(directory_path.path_join(file_name)).simplify_path(), absolute_root):
				return false
	return true

func _generated_document() -> Dictionary:
	return {
		"format": CityAccessSnapshotLoader.FORMAT,
		"version": CityAccessSnapshotLoader.VERSION,
		"source": {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-runtime", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},
		"locations": [{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]}],
	}

func _generated_maximum_multibyte_document() -> Dictionary:
	var document := _generated_document()
	var conditions: Array[Dictionary] = []
	for index: int in CityAccessSnapshotLoader.MAX_CONDITIONS:
		var unit := "é" if index < 4 else "x"
		conditions.append({"kind": "permanent_unlock", "value": unit.repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS)})
	var locations: Array[Dictionary] = []
	for index: int in CityAccessSnapshotLoader.MAX_LOCATIONS:
		var id_prefix := "l%03d" % index
		var destination_prefix := "d%03d" % index
		locations.append({
			"id": id_prefix + "i".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS - id_prefix.length()),
			"destinationId": destination_prefix + "d".repeat(CityAccessSnapshotLoader.MAX_TEXT_UNITS - destination_prefix.length()),
			"visibleWhen": conditions.duplicate(true),
			"availableWhen": conditions.duplicate(true),
		})
	document["locations"] = locations
	return document

func _encode_generated_over_limit(document: Dictionary) -> PackedByteArray:
	var text := JSON.stringify(document)
	return (text + " ".repeat(CityAccessSnapshotLoader.MAX_BYTES + 1 - text.to_utf8_buffer().size())).to_utf8_buffer()

func _encode_generated_replacement_character(document: Dictionary) -> PackedByteArray:
	var encoded_document := document.duplicate(true)
	encoded_document["source"]["adapter"] = "future�adapter"
	return JSON.stringify(encoded_document).to_utf8_buffer()

func _is_strict_descendant(path: String, ancestor: String) -> bool:
	var cursor := path.simplify_path()
	var normalized_ancestor := ancestor.simplify_path()
	while cursor != cursor.get_base_dir():
		cursor = cursor.get_base_dir()
		if cursor == normalized_ancestor:
			return true
	return false

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

func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()

func _cleanup() -> void:
	ProfileTestSupport.remove_tree(_root)
