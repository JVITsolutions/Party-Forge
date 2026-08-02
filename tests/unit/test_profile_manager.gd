extends RefCounted

var _root := ""

class FailingProfileIndexStore extends ProfileIndexStore:
	var save_error := ""

	func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
		if not save_error.is_empty():
			return save_error
		return super.save_index(index, root)

class CleanupFailingProfileManager extends ProfileManager:
	func _remove_created_profile_primary(_profile_id: String) -> Error:
		return ERR_CANT_CREATE

class CleanupFailingAtomicJsonStore extends AtomicJsonStore:
	var failure_path := ""

	func _remove(path: String) -> Error:
		if path == failure_path:
			return ERR_CANT_CREATE
		return super._remove(path)

func run() -> Array[String]:
	var failures: Array[String] = []
	_root = "user://tests/profile_manager_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_root)
	_test_create_select_and_reload(failures)
	_reset_root()
	_test_corrupt_index_recovers_most_recent_profile(failures)
	_reset_root()
	_test_orphans_and_corrupt_profiles_are_reconciled(failures)
	_reset_root()
	_test_refresh_and_copy_isolation(failures)
	_reset_root()
	_test_name_and_identifier_boundaries(failures)
	_reset_root()
	_test_selection_rolls_back_when_index_save_fails(failures)
	_reset_root()
	_test_index_numeric_validation(failures)
	_reset_root()
	_test_bootstrap_filesystem_failure(failures)
	_reset_root()
	_test_create_rolls_back_when_index_save_fails(failures)
	_reset_root()
	_test_create_rejects_stale_primary_and_backup_artifacts(failures)
	_reset_root()
	_test_create_rollback_cleanup_failure_is_surfaced(failures)
	_reset_root()
	_test_refresh_rolls_back_when_index_save_fails(failures)
	_reset_root()
	_test_invalid_id_is_rejected_before_filesystem_probe(failures)
	_reset_root()
	_test_post_commit_index_cleanup_does_not_rollback_create(failures)
	_reset_root()
	_test_bootstrap_exposes_profile_health_statuses(failures)
	ProfileTestSupport.remove_tree(_root)
	return failures

func _test_create_select_and_reload(failures: Array[String]) -> void:
	var ids: Array[String] = ["profile-aaaaaaaa", "profile-bbbbbbbb"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "empty root bootstraps", failures)
	var events: Array[String] = []
	manager.profiles_changed.connect(func() -> void: events.append("profiles"))
	manager.active_profile_changed.connect(func(_profile: ProfileState) -> void: events.append("active"))
	var first := manager.create_profile("Jacob", 1000)
	TestAssertions.truthy(first.ok(), "first profile creates", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Jacob", "first profile becomes active", failures)
	var duplicate := manager.create_profile("  jacob  ", 1001)
	TestAssertions.truthy(not duplicate.ok() and duplicate.error.contains("name already exists"), "names are unique case-insensitively", failures)
	var second := manager.create_profile("Guest", 1002)
	TestAssertions.truthy(second.ok(), "second profile creates", failures)
	TestAssertions.equal(manager.profiles().size(), 2, "manager lists both profiles", failures)
	TestAssertions.equal(manager.select_profile(first.profile.profile_id), "", "existing profile selects", failures)
	TestAssertions.equal(manager.active_profile().profile_id, first.profile.profile_id, "selection persists in memory", failures)
	var reloaded := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new())
	TestAssertions.equal(reloaded.bootstrap(_root), "", "manager reloads from disk", failures)
	TestAssertions.equal(reloaded.active_profile().profile_id, first.profile.profile_id, "active selection round trips", failures)
	TestAssertions.equal(events, ["profiles", "active", "profiles", "active", "active"], "mutations emit the documented signals", failures)

func _test_corrupt_index_recovers_most_recent_profile(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var older := ProfileState.new_profile("profile-older001", "Older", 2000)
	var newer := ProfileState.new_profile("profile-newer001", "Newer", 2001)
	TestAssertions.equal(store.save_profile(older, _root), "", "older orphan fixture saves", failures)
	TestAssertions.equal(store.save_profile(newer, _root), "", "newer orphan fixture saves", failures)
	_write_text(_root.path_join(ProfileIndexStore.FILE_NAME), "{not valid json")
	var manager := ProfileManager.new()
	var error := manager.bootstrap(_root)
	TestAssertions.truthy(error.contains("PROFILE_BOOTSTRAP_ERROR") and error.contains("profile_index.json"), "corrupt index is surfaced during bootstrap", failures)
	TestAssertions.equal(manager.active_profile().profile_id, newer.profile_id, "corrupt index recovery selects most recent profile", failures)
	TestAssertions.equal(manager.profiles().size(), 2, "corrupt index does not hide valid profiles", failures)

func _test_orphans_and_corrupt_profiles_are_reconciled(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var orphan := ProfileState.new_profile("profile-orphan01", "Orphan", 3000)
	TestAssertions.equal(store.save_profile(orphan, _root), "", "orphan fixture saves", failures)
	_write_text(_root.path_join("profile-corrupt01.json"), "corrupt")
	var manager := ProfileManager.new()
	var error := manager.bootstrap(_root)
	TestAssertions.truthy(error.contains("PROFILE_BOOTSTRAP_ERROR") and error.contains("profile=profile-corrupt01") and error.contains("JSON_STORE_LOAD_ERROR"), "corrupt profile has stable profile-specific bootstrap diagnostic", failures)
	TestAssertions.equal(manager.profiles().size(), 1, "unreadable profile is not materialized", failures)
	TestAssertions.equal(manager.active_profile().profile_id, orphan.profile_id, "valid orphan remains selectable", failures)
	var duplicate_ids: Array[String] = ["profile-unique01"]
	var duplicate := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return duplicate_ids.pop_front())
	TestAssertions.truthy(not duplicate.bootstrap(_root).is_empty(), "corrupt profile remains surfaced on reload", failures)
	var create_duplicate := duplicate.create_profile("  oRpHaN ", 3001)
	TestAssertions.truthy(not create_duplicate.ok() and create_duplicate.error.contains("name already exists"), "orphan names participate in duplicate checks", failures)

func _test_refresh_and_copy_isolation(failures: Array[String]) -> void:
	var ids: Array[String] = ["profile-refresh01"]
	var store := ProfileStore.new()
	var manager := ProfileManager.new(store, ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "refresh manager bootstraps", failures)
	var created := manager.create_profile("Refresh", 4000)
	TestAssertions.truthy(created.ok(), "refresh fixture creates", failures)
	var external := created.profile.copy()
	external.gold = 25
	external.updated_at_unix = 4001
	TestAssertions.equal(store.save_profile(external, _root), "", "external profile update saves", failures)
	TestAssertions.equal(manager.refresh_profile(external.profile_id), "", "existing profile refreshes", failures)
	TestAssertions.equal(manager.active_profile().gold, 25, "refresh replaces in-memory profile", failures)
	var listed := manager.profiles()
	listed[0].gold = 99
	listed[0].tree_allocations["tree"] = ["node"]
	var active_copy := manager.active_profile()
	active_copy.display_name = "Changed copy"
	TestAssertions.equal(manager.profiles()[0].gold, 25, "profiles returns isolated copies", failures)
	TestAssertions.truthy(manager.profiles()[0].tree_allocations.is_empty(), "profiles isolates nested data", failures)
	TestAssertions.equal(manager.active_profile().display_name, "Refresh", "active profile returns an isolated copy", failures)
	_write_text(store.profile_path(external.profile_id, _root), "corrupt without backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.bak" % store.profile_path(external.profile_id, _root)))
	var refresh_error := manager.refresh_profile(external.profile_id)
	TestAssertions.truthy(refresh_error.contains("JSON_STORE_LOAD_ERROR"), "corrupt refresh is surfaced", failures)
	TestAssertions.equal(manager.active_profile().gold, 25, "failed refresh preserves readable in-memory profile", failures)
	var unknown_error := manager.refresh_profile("profile-unknown1")
	TestAssertions.truthy(unknown_error.contains("profile-unknown1"), "unknown refresh identifies the profile", failures)

func _test_name_and_identifier_boundaries(failures: Array[String]) -> void:
	var ids: Array[String] = ["profile-valid0001", "bad/id", "profile-valid0001"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "boundary manager bootstraps", failures)
	TestAssertions.truthy(not manager.create_profile("   ", 5000).ok(), "blank names are rejected", failures)
	TestAssertions.truthy(not manager.create_profile("x".repeat(33), 5000).ok(), "names longer than 32 characters are rejected", failures)
	var accepted := manager.create_profile("  %s  " % "x".repeat(32), 5000)
	TestAssertions.truthy(accepted.ok() and accepted.profile.display_name.length() == 32, "trimmed 32-character name is accepted", failures)
	var invalid_id := manager.create_profile("Invalid Id", 5001)
	TestAssertions.truthy(not invalid_id.ok() and invalid_id.error.contains("invalid profile id"), "invalid generated profile id is rejected", failures)
	var collision := manager.create_profile("Collision", 5002)
	TestAssertions.truthy(not collision.ok() and collision.error.contains("id collision"), "generated profile id collisions are rejected", failures)
	_reset_root()
	var random_manager := ProfileManager.new()
	TestAssertions.equal(random_manager.bootstrap(_root), "", "random id manager bootstraps", failures)
	var random_profile := random_manager.create_profile("Random", 5003)
	var random_id := random_profile.profile.profile_id if random_profile.ok() else ""
	TestAssertions.truthy(random_profile.ok() and random_id.begins_with("profile-") and random_id.length() == 40 and _is_lower_hex(random_id.trim_prefix("profile-")), "default profile ids use 128-bit lowercase hex randomness", failures)

func _test_selection_rolls_back_when_index_save_fails(failures: Array[String]) -> void:
	var index_store := FailingProfileIndexStore.new()
	var ids: Array[String] = ["profile-select001", "profile-select002"]
	var manager := ProfileManager.new(ProfileStore.new(), index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "selection failure manager bootstraps", failures)
	var first := manager.create_profile("First", 6000)
	var second := manager.create_profile("Second", 6001)
	TestAssertions.truthy(first.ok() and second.ok(), "selection failure fixtures create", failures)
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	var error := manager.select_profile(first.profile.profile_id)
	TestAssertions.equal(error, index_store.save_error, "selection persistence failure is surfaced", failures)
	TestAssertions.equal(manager.active_profile().profile_id, second.profile.profile_id, "failed selection rolls back active profile", failures)
	TestAssertions.truthy(manager.select_profile("profile-missing1").contains("PROFILE_SELECT_ERROR profile=profile-missing1"), "unknown selection has a stable profile-specific diagnostic", failures)

func _test_index_numeric_validation(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"suffix": "string", "schema": "1", "updated": 1, "reason": "unsupported schema"},
		{"suffix": "fractional_schema", "schema": 1.5, "updated": 1, "reason": "unsupported schema"},
		{"suffix": "fractional_timestamp", "schema": 1, "updated": 1.5, "reason": "entry fields have invalid types"},
		{"suffix": "string_timestamp", "schema": 1, "updated": "1", "reason": "entry fields have invalid types"},
	]
	for item: Dictionary in cases:
		var case_root := _root.path_join(str(item["suffix"]))
		var document := {
			"schema_version": item["schema"],
			"active_profile_id": "",
			"entries": [{"profile_id": "profile-numeric1", "display_name": "Numeric", "updated_at_unix": item["updated"]}],
		}
		_write_text(case_root.path_join(ProfileIndexStore.FILE_NAME), JSON.stringify(document))
		var loaded := ProfileIndexStore.new().load_index(case_root)
		TestAssertions.truthy(not loaded.ok() and loaded.error.contains(str(item["reason"])), "index rejects %s" % item["suffix"], failures)
	var valid_root := _root.path_join("integral")
	var valid_document := {
		"schema_version": 1.0,
		"active_profile_id": "profile-numeric1",
		"entries": [{"profile_id": "profile-numeric1", "display_name": "Numeric", "updated_at_unix": 7.0}],
	}
	_write_text(valid_root.path_join(ProfileIndexStore.FILE_NAME), JSON.stringify(valid_document))
	var valid := ProfileIndexStore.new().load_index(valid_root)
	TestAssertions.truthy(valid.ok() and typeof(valid.index.schema_version) == TYPE_INT and typeof(valid.index.entries[0]["updated_at_unix"]) == TYPE_INT, "integral JSON numerics decode to ints", failures)

func _test_bootstrap_filesystem_failure(failures: Array[String]) -> void:
	var blocker := _root.path_join("blocker")
	_write_text(blocker, "file blocks nested directory creation")
	var blocked_root := blocker.path_join("nested")
	var manager := ProfileManager.new()
	var error := manager.bootstrap(blocked_root)
	TestAssertions.truthy(error.begins_with("PROFILE_BOOTSTRAP_ERROR root=%s stage=mkdir code=" % blocked_root), "bootstrap surfaces a stable root-specific filesystem diagnostic", failures)
	var exact_file_root := _root.path_join("exact_root_file")
	_write_text(exact_file_root, "file occupies exact requested root")
	var exact_manager := ProfileManager.new()
	var exact_error := exact_manager.bootstrap(exact_file_root)
	TestAssertions.equal(exact_error, "PROFILE_BOOTSTRAP_ERROR root=%s stage=validate-root reason=path is not a directory" % exact_file_root, "bootstrap rejects a file at the exact root before discovery", failures)
	TestAssertions.truthy(not FileAccess.file_exists(exact_file_root.path_join(ProfileIndexStore.FILE_NAME)), "exact file root is not used for index persistence", failures)

func _test_create_rolls_back_when_index_save_fails(failures: Array[String]) -> void:
	var index_store := FailingProfileIndexStore.new()
	var profile_store := ProfileStore.new()
	var ids: Array[String] = ["profile-rollback01", "profile-rollback02"]
	var manager := ProfileManager.new(profile_store, index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "create rollback manager bootstraps", failures)
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	var failed := manager.create_profile("Retryable", 7000)
	TestAssertions.truthy(not failed.ok() and failed.error.contains(index_store.save_error) and failed.error.contains("rollback_remove_code=0"), "create index failure reports successful file rollback", failures)
	var failed_path := profile_store.profile_path("profile-rollback01", _root)
	TestAssertions.truthy(not FileAccess.file_exists(failed_path) and not FileAccess.file_exists("%s.bak" % failed_path), "failed create leaves no primary or backup artifact", failures)
	TestAssertions.truthy(manager.profiles().is_empty() and manager.active_profile() == null, "failed create restores manager memory", failures)
	var reloaded := ProfileManager.new()
	TestAssertions.equal(reloaded.bootstrap(_root), "", "subsequent bootstrap succeeds after create rollback", failures)
	TestAssertions.truthy(reloaded.profiles().is_empty() and reloaded.active_profile() == null, "subsequent bootstrap does not discover a failed-create orphan", failures)
	index_store.save_error = ""
	var retried := manager.create_profile("  Retryable  ", 7001)
	TestAssertions.truthy(retried.ok() and retried.profile.profile_id == "profile-rollback02", "failed create restores display-name availability", failures)

func _test_create_rejects_stale_primary_and_backup_artifacts(failures: Array[String]) -> void:
	var profile_store := ProfileStore.new()
	var primary_root := _root.path_join("primary_collision")
	var primary_ids: Array[String] = ["profile-artifact01"]
	var primary_manager := ProfileManager.new(profile_store, ProfileIndexStore.new(), func() -> String: return primary_ids.pop_front())
	TestAssertions.equal(primary_manager.bootstrap(primary_root), "", "primary collision manager bootstraps", failures)
	var existing_primary := ProfileState.new_profile("profile-artifact01", "Existing Primary", 7100)
	existing_primary.gold = 17
	TestAssertions.equal(profile_store.save_profile(existing_primary, primary_root), "", "stale primary fixture saves after bootstrap", failures)
	var primary_collision := primary_manager.create_profile("Replacement", 7101)
	var preserved_primary := profile_store.load_profile(existing_primary.profile_id, primary_root)
	TestAssertions.truthy(not primary_collision.ok() and primary_collision.error.contains("id collision"), "create rejects an exact primary artifact absent from manager memory", failures)
	TestAssertions.equal(preserved_primary.profile.gold if preserved_primary.ok() else -1, 17, "primary collision preserves the existing generation", failures)
	var backup_root := _root.path_join("backup_collision")
	var backup_ids: Array[String] = ["profile-artifact02"]
	var backup_manager := ProfileManager.new(profile_store, ProfileIndexStore.new(), func() -> String: return backup_ids.pop_front())
	TestAssertions.equal(backup_manager.bootstrap(backup_root), "", "backup collision manager bootstraps", failures)
	var backup_profile := ProfileState.new_profile("profile-artifact02", "Existing Backup", 7200)
	var backup_path := "%s.bak" % profile_store.profile_path(backup_profile.profile_id, backup_root)
	_write_text(backup_path, ProfileCodec.encode(backup_profile))
	var backup_bytes := FileAccess.get_file_as_string(backup_path)
	var backup_collision := backup_manager.create_profile("Replacement Backup", 7201)
	TestAssertions.truthy(not backup_collision.ok() and backup_collision.error.contains("id collision"), "create rejects an exact backup artifact absent from manager memory", failures)
	TestAssertions.truthy(not FileAccess.file_exists(profile_store.profile_path(backup_profile.profile_id, backup_root)), "backup collision does not create a new primary", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(backup_path), backup_bytes, "backup collision preserves the existing generation", failures)

func _test_create_rollback_cleanup_failure_is_surfaced(failures: Array[String]) -> void:
	var index_store := FailingProfileIndexStore.new()
	var ids: Array[String] = ["profile-cleanfail1"]
	var manager := CleanupFailingProfileManager.new(ProfileStore.new(), index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "cleanup failure manager bootstraps", failures)
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	var failed := manager.create_profile("Cleanup Failure", 7300)
	TestAssertions.truthy(not failed.ok() and failed.error.contains(index_store.save_error) and failed.error.contains("rollback_remove_code=%d" % ERR_CANT_CREATE), "create rollback removal failure is surfaced", failures)
	TestAssertions.truthy(manager.profiles().is_empty() and manager.active_profile() == null, "cleanup failure still restores manager memory", failures)

func _test_refresh_rolls_back_when_index_save_fails(failures: Array[String]) -> void:
	var index_store := FailingProfileIndexStore.new()
	var profile_store := ProfileStore.new()
	var ids: Array[String] = ["profile-refresh11", "profile-refresh12"]
	var manager := ProfileManager.new(profile_store, index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "refresh rollback manager bootstraps", failures)
	var first := manager.create_profile("First Refresh", 7400)
	var second := manager.create_profile("Second Refresh", 7401)
	TestAssertions.truthy(first.ok() and second.ok(), "refresh rollback fixtures create", failures)
	var external := first.profile.copy()
	external.gold = 88
	external.updated_at_unix = 7402
	TestAssertions.equal(profile_store.save_profile(external, _root), "", "newer external refresh fixture saves", failures)
	var events: Array[String] = []
	manager.profiles_changed.connect(func() -> void: events.append("profiles"))
	manager.active_profile_changed.connect(func(_profile: ProfileState) -> void: events.append("active"))
	index_store.save_error = "PROFILE_INDEX_SAVE_ERROR path=profile_index.json stage=forced"
	var error := manager.refresh_profile(first.profile.profile_id)
	TestAssertions.equal(error, index_store.save_error, "refresh index persistence failure is surfaced", failures)
	TestAssertions.equal(manager.active_profile().profile_id, second.profile.profile_id, "failed refresh preserves active selection", failures)
	var profiles := manager.profiles()
	var restored_first := profiles[1] if profiles.size() > 1 else null
	TestAssertions.truthy(profiles.size() == 2 and profiles[0].profile_id == second.profile.profile_id, "failed refresh restores index-visible ordering", failures)
	TestAssertions.equal(restored_first.gold if restored_first != null else -1, 0, "failed refresh restores last good in-memory profile data", failures)
	TestAssertions.truthy(events.is_empty(), "failed refresh emits no success signals", failures)

func _test_invalid_id_is_rejected_before_filesystem_probe(failures: Array[String]) -> void:
	var manager_root := _root.path_join("invalid_id_manager")
	var sentinel_path := _root.path_join("escape_profile.json")
	var sentinel_bytes := "outside manager root sentinel"
	_write_text(sentinel_path, sentinel_bytes)
	var ids: Array[String] = ["../escape_profile"]
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(manager_root), "", "invalid id manager bootstraps", failures)
	var result := manager.create_profile("Traversal", 7500)
	TestAssertions.truthy(not result.ok() and result.error.contains("invalid profile id") and not result.error.contains("id collision"), "invalid id is validated before artifact probing", failures)
	TestAssertions.equal(FileAccess.get_file_as_string(sentinel_path), sentinel_bytes, "invalid id causes no filesystem side effect outside manager root", failures)

func _test_post_commit_index_cleanup_does_not_rollback_create(failures: Array[String]) -> void:
	var documents := CleanupFailingAtomicJsonStore.new()
	var index_store := ProfileIndexStore.new(documents)
	var profile_store := ProfileStore.new()
	var ids: Array[String] = ["profile-commit001", "profile-commit002"]
	var manager := ProfileManager.new(profile_store, index_store, func() -> String: return ids.pop_front())
	TestAssertions.equal(manager.bootstrap(_root), "", "post-commit manager fixture bootstraps", failures)
	TestAssertions.truthy(manager.create_profile("First", 8000).ok(), "post-commit manager fixture creates first profile", failures)
	documents.failure_path = _root.path_join("%s.bak.previous" % ProfileIndexStore.FILE_NAME)
	var second := manager.create_profile("Second", 8001)
	TestAssertions.truthy(second.ok(), "verified index promotion is not rolled back for cleanup debt", failures)
	TestAssertions.equal(manager.active_profile().display_name if manager.active_profile() != null else "", "Second", "post-commit create remains active in memory", failures)
	TestAssertions.truthy(FileAccess.file_exists(profile_store.profile_path("profile-commit002", _root)), "post-commit create retains its profile primary", failures)
	var reloaded := ProfileManager.new()
	TestAssertions.equal(reloaded.bootstrap(_root), "", "post-commit create reloads without index inconsistency", failures)
	TestAssertions.equal(reloaded.active_profile().display_name if reloaded.active_profile() != null else "", "Second", "post-commit active selection persists", failures)

func _test_bootstrap_exposes_profile_health_statuses(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var healthy := ProfileState.new_profile("profile-healthy01", "Healthy", 9000)
	var recovered := ProfileState.new_profile("profile-recover01", "Recovered", 8000)
	TestAssertions.equal(store.save_profile(healthy, _root), "", "health status healthy fixture saves", failures)
	TestAssertions.equal(store.save_profile(recovered, _root), "", "health status recovered fixture first save succeeds", failures)
	recovered.gold = 2
	recovered.updated_at_unix = 8001
	TestAssertions.equal(store.save_profile(recovered, _root), "", "health status recovered fixture creates backup", failures)
	_write_text(store.profile_path(recovered.profile_id, _root), "corrupt recovered primary")
	_write_text(_root.path_join("profile-damaged01.json"), "corrupt without backup")
	var manager := ProfileManager.new()
	var error := manager.bootstrap(_root)
	TestAssertions.truthy(error.contains("profile=profile-damaged01"), "damaged profile remains a bootstrap diagnostic", failures)
	var has_status_api := manager.has_method(&"profile_statuses")
	TestAssertions.truthy(has_status_api, "manager exposes structured profile health statuses", failures)
	if not has_status_api:
		return
	var statuses: Array = manager.call(&"profile_statuses")
	TestAssertions.equal(statuses.size(), 3, "health status list retains healthy recovered and damaged profiles", failures)
	var by_id: Dictionary = {}
	for status: Variant in statuses:
		by_id[status.get("profile_id")] = status
	TestAssertions.equal(by_id[healthy.profile_id].call(&"state_name"), "healthy", "healthy profile is identified", failures)
	TestAssertions.equal(by_id[recovered.profile_id].call(&"state_name"), "recovered", "verified backup recovery is identified", failures)
	TestAssertions.truthy(bool(by_id[recovered.profile_id].get("recovered")), "recovered profile retains recovery evidence", failures)
	TestAssertions.equal(by_id["profile-damaged01"].call(&"state_name"), "damaged", "unrecoverable profile remains visible as damaged", failures)
	TestAssertions.truthy(not str(by_id["profile-damaged01"].get("error")).is_empty(), "damaged profile retains technical details", failures)

func _reset_root() -> void:
	ProfileTestSupport.remove_tree(_root)

func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func _is_lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true
