extends RefCounted

const ROOT := "user://tests/profile_store"

func run() -> Array[String]:
	var failures: Array[String] = []
	_cleanup()
	_test_round_trip_and_backup_recovery(failures)
	_test_backup_only_is_discoverable(failures)
	_test_corrupt_primary_is_preserved_before_resave(failures)
	_test_failed_promotion_preserves_primary(failures)
	_test_missing_profile_is_distinct(failures)
	_cleanup()
	return failures

func _test_round_trip_and_backup_recovery(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var first := ProfileState.new_profile("profile-12345678", "Jacob", 1000)
	first.gold = 10
	TestAssertions.equal(store.save_profile(first, ROOT), "", "first profile save succeeds", failures)
	var second := first.copy()
	second.gold = 20
	second.updated_at_unix = 1001
	TestAssertions.equal(store.save_profile(second, ROOT), "", "second save creates backup", failures)
	var primary_path := store.profile_path(first.profile_id, ROOT)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt")
	corrupt.close()
	var recovered := store.load_profile(first.profile_id, ROOT)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "corrupt primary recovers verified backup", failures)
	TestAssertions.equal(recovered.profile.gold, 10, "recovery returns previous committed generation", failures)

func _test_failed_promotion_preserves_primary(failures: Array[String]) -> void:
	var good := ProfileStore.new()
	var original := ProfileState.new_profile("profile-abcdefgh", "Original", 2000)
	TestAssertions.equal(good.save_profile(original, ROOT), "", "baseline save succeeds", failures)
	var failing := ProfileStore.new(AtomicJsonStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE))
	var changed := original.copy()
	changed.display_name = "Changed"
	TestAssertions.truthy(not failing.save_profile(changed, ROOT).is_empty(), "failed promotion reports error", failures)
	TestAssertions.equal(good.load_profile(original.profile_id, ROOT).profile.display_name, "Original", "failed promotion preserves primary", failures)

func _test_backup_only_is_discoverable(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-backup01", "Backup", 3000)
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "backup-only fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 3001
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "backup-only fixture creates backup", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.profile_path(profile.profile_id, ROOT)))
	TestAssertions.truthy(profile.profile_id in store.profile_ids(ROOT), "backup-only profile remains discoverable", failures)

func _test_corrupt_primary_is_preserved_before_resave(failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var profile := ProfileState.new_profile("profile-corrupt1", "Corrupt", 4000)
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "corrupt fixture first save succeeds", failures)
	profile.gold = 2
	profile.updated_at_unix = 4001
	TestAssertions.equal(store.save_profile(profile, ROOT), "", "corrupt fixture creates verified backup", failures)
	var primary_path := store.profile_path(profile.profile_id, ROOT)
	var corrupt := FileAccess.open(primary_path, FileAccess.WRITE)
	corrupt.store_string("corrupt original bytes")
	corrupt.close()
	var recovered := store.load_profile(profile.profile_id, ROOT)
	TestAssertions.truthy(recovered.ok() and recovered.recovered_from_backup, "fixture recovers backup", failures)
	recovered.profile.gold = 3
	recovered.profile.updated_at_unix = 4002
	TestAssertions.equal(store.save_profile(recovered.profile, ROOT), "", "recovered profile resaves", failures)
	var artifacts := DirAccess.get_files_at(ROOT)
	TestAssertions.truthy(_has_corrupt_artifact(artifacts), "corrupt primary is preserved for diagnosis", failures)
	TestAssertions.equal(store.load_profile(profile.profile_id, ROOT).profile.gold, 3, "resaved primary is current", failures)

func _test_missing_profile_is_distinct(failures: Array[String]) -> void:
	var missing := ProfileStore.new().load_profile("profile-missing1", ROOT)
	TestAssertions.truthy(missing.missing and not missing.ok(), "missing profile is not treated as corruption", failures)

func _has_corrupt_artifact(names: PackedStringArray) -> bool:
	for name: String in names:
		if name.begins_with("profile-corrupt1.json.corrupt-"):
			return true
	return false

func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(ROOT)
	if DirAccess.dir_exists_absolute(absolute):
		_remove_tree(absolute)

func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory != null:
		for name: String in directory.get_files():
			DirAccess.remove_absolute(path.path_join(name))
		for name: String in directory.get_directories():
			_remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
