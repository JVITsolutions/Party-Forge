extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_defaults_and_normalization(failures)
	_test_round_trip_and_inactive_retention(failures)
	_test_missing_unknown_and_malformed_fields(failures)
	_test_failed_save_preserves_previous_file(failures)
	_test_failed_restore_retains_backup(failures)
	return failures

func _test_defaults_and_normalization(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	TestAssertions.equal(settings.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "settings default to Player Simulation", failures)
	TestAssertions.equal(settings.party_capacity_override, 4, "developer party cap defaults to four", failures)
	TestAssertions.equal(settings.enemy_density_percent, 100, "enemy density defaults to 100 percent", failures)
	TestAssertions.equal(settings.experience_multiplier_percent, 100, "experience multiplier defaults to 100 percent", failures)
	TestAssertions.equal(settings.level_up_card_count, 5, "level-up card count defaults to five", failures)
	settings.party_capacity_override = -50
	settings.enemy_density_percent = 5000
	settings.experience_multiplier_percent = -50
	settings.level_up_card_count = -10
	settings.normalize()
	TestAssertions.equal(settings.party_capacity_override, 1, "party cap clamps to one", failures)
	TestAssertions.equal(settings.enemy_density_percent, 1000, "density clamps to 1000", failures)
	TestAssertions.equal(settings.experience_multiplier_percent, 100, "experience multiplier clamps to 100", failures)
	TestAssertions.equal(settings.level_up_card_count, 1, "level-up card count clamps to one", failures)
	settings.experience_multiplier_percent = 5000
	settings.level_up_card_count = 50
	settings.normalize()
	TestAssertions.equal(settings.experience_multiplier_percent, 1000, "experience multiplier clamps to 1000", failures)
	TestAssertions.equal(settings.level_up_card_count, 8, "level-up card count clamps to eight", failures)
	var copied := settings.copy()
	settings.experience_multiplier_percent = 100
	settings.level_up_card_count = 1
	TestAssertions.equal(copied.experience_multiplier_percent, 1000, "settings copy isolates experience multiplier", failures)
	TestAssertions.equal(copied.level_up_card_count, 8, "settings copy isolates level-up card count", failures)

func _test_round_trip_and_inactive_retention(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_test.cfg"
	var store := PartyForgeSettingsStore.new()
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	settings.unlock_all_implemented_content = true
	settings.god_mode = true
	settings.party_capacity_override = 17
	settings.enemy_density_percent = 650
	settings.experience_multiplier_percent = 725
	settings.level_up_card_count = 7
	TestAssertions.equal(store.save_settings(settings, path), "", "valid settings save", failures)
	var loaded := store.load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "mode round trips", failures)
	TestAssertions.truthy(loaded.god_mode and loaded.unlock_all_implemented_content, "inactive developer values remain stored", failures)
	TestAssertions.equal(loaded.party_capacity_override, 17, "party cap round trips", failures)
	TestAssertions.equal(loaded.enemy_density_percent, 650, "density round trips", failures)
	TestAssertions.equal(loaded.experience_multiplier_percent, 725, "experience multiplier round trips", failures)
	TestAssertions.equal(loaded.level_up_card_count, 7, "level-up card count round trips", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_missing_unknown_and_malformed_fields(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_malformed_test.cfg"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[settings]\nmode=99\nparty_capacity_override=-3\nunknown_future_key=\"safe\"\n")
	file.close()
	var loaded := PartyForgeSettingsStore.new().load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "unknown mode fails closed", failures)
	TestAssertions.equal(loaded.party_capacity_override, 1, "loaded cap clamps", failures)
	TestAssertions.equal(loaded.enemy_density_percent, 100, "missing density uses default", failures)
	TestAssertions.equal(loaded.experience_multiplier_percent, 100, "missing experience multiplier uses default", failures)
	TestAssertions.equal(loaded.level_up_card_count, 5, "missing level-up card count uses default", failures)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[settings]\nmode=\"1\"\ngod_mode=\"true\"\n")
	file.close()
	loaded = PartyForgeSettingsStore.new().load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "wrong mode type cannot enable Developer Mode", failures)
	TestAssertions.truthy(not loaded.god_mode, "wrong Boolean type fails closed", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var future_path := "user://party_forge_settings_future_test.cfg"
	var future := ConfigFile.new()
	future.set_value("settings", "schema_version", 999)
	future.set_value("settings", "mode", PartyForgeSettings.Mode.DEVELOPER_MODE)
	future.save(future_path)
	TestAssertions.equal(PartyForgeSettingsStore.new().load_settings(future_path).mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "unsupported version cannot enable Developer Mode", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(future_path))

func _test_failed_save_preserves_previous_file(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_preserve_test.cfg"
	var store := PartyForgeSettingsStore.new()
	var original := PartyForgeSettings.new()
	original.party_capacity_override = 8
	TestAssertions.equal(store.save_settings(original, path), "", "baseline save succeeds", failures)
	var failing_store := PartyForgeSettingsStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	var changed := original.copy()
	changed.party_capacity_override = 24
	TestAssertions.truthy(not failing_store.save_settings(changed, path).is_empty(), "failed promotion reports failure", failures)
	TestAssertions.equal(store.load_settings(path).party_capacity_override, 8, "previous valid file is unchanged", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_failed_restore_retains_backup(failures: Array[String]) -> void:
	var path := "user://party_forge_settings_restore_failure_test.cfg"
	var backup := "%s.bak" % path
	var temporary := "%s.tmp" % path
	_cleanup_restore_failure_artifacts(path, backup, temporary)
	var store := PartyForgeSettingsStore.new()
	var original := PartyForgeSettings.new()
	original.party_capacity_override = 8
	TestAssertions.equal(store.save_settings(original, path), "", "restore-failure baseline save succeeds", failures)
	var failing_store := PartyForgeSettingsStore.new(func(_temporary: String, target: String) -> Error:
		var make_directory_error := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(target))
		return ERR_CANT_CREATE if make_directory_error == OK else make_directory_error
	)
	var save_error := failing_store.save_settings(original.copy(), path)
	TestAssertions.truthy(save_error.contains("stage=restore"), "restore failure is reported distinctly: %s" % save_error, failures)
	TestAssertions.truthy(not FileAccess.file_exists(path), "failed restore leaves the canonical file absent", failures)
	TestAssertions.truthy(FileAccess.file_exists(backup), "failed restore retains the backup artifact", failures)
	TestAssertions.equal(store.load_settings(backup).party_capacity_override, 8, "retained backup remains recoverable", failures)
	_cleanup_restore_failure_artifacts(path, backup, temporary)

func _cleanup_restore_failure_artifacts(path: String, backup: String, temporary: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
