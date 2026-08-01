extends RefCounted

var _root := ""

class FailingProfileIndexStore extends ProfileIndexStore:
	var save_error := ""

	func save_index(index: ProfileIndex, root: String = ProfileStore.DEFAULT_ROOT) -> String:
		if not save_error.is_empty():
			return save_error
		return super.save_index(index, root)

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
