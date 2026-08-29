extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_defaults_and_normalization(failures)
	_test_personal_loot_controls(failures)
	_test_city_access_snapshot_setting(failures)
	_test_reduced_motion_setting(failures)
	_test_accessibility_display_settings(failures)
	_test_round_trip_and_inactive_retention(failures)
	_test_missing_unknown_and_malformed_fields(failures)
	_test_failed_save_preserves_previous_file(failures)
	_test_failed_restore_retains_backup(failures)
	return failures

func _test_personal_loot_controls(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	TestAssertions.equal(settings.get("personal_drop_multiplier_percent"), 100, "personal-drop multiplier defaults to production 100 percent", failures)
	TestAssertions.equal(settings.get("force_personal_drops"), false, "forced personal drops default off", failures)
	TestAssertions.equal(settings.get("personal_drop_source_category_override"), &"", "personal-drop source defaults to automatic", failures)
	TestAssertions.equal(settings.get("personal_drop_item_level_override"), 0, "personal-drop item level defaults to automatic", failures)
	TestAssertions.equal(settings.get("show_ground_chest_diagnostics"), false, "ground-chest diagnostics default off", failures)

	settings.set("personal_drop_multiplier_percent", 20000)
	settings.set("personal_drop_item_level_override", 2000)
	settings.set("personal_drop_source_category_override", &"not_a_source")
	settings.call("normalize")
	TestAssertions.equal(settings.get("personal_drop_multiplier_percent"), 10000, "personal-drop multiplier clamps to 10000 percent", failures)
	TestAssertions.equal(settings.get("personal_drop_item_level_override"), 1000, "personal-drop item level clamps to 1000", failures)
	TestAssertions.equal(settings.get("personal_drop_source_category_override"), &"", "unknown personal-drop source resets to automatic", failures)
	settings.set("personal_drop_multiplier_percent", -1)
	settings.set("personal_drop_item_level_override", -1)
	settings.call("normalize")
	TestAssertions.equal(settings.get("personal_drop_multiplier_percent"), 0, "personal-drop multiplier clamps to zero", failures)
	TestAssertions.equal(settings.get("personal_drop_item_level_override"), 0, "personal-drop item level clamps to automatic", failures)

	var path := "user://party_forge_settings_personal_loot_test.cfg"
	var stored := PartyForgeSettings.new()
	stored.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	stored.set("personal_drop_multiplier_percent", 375)
	stored.set("force_personal_drops", true)
	stored.set("personal_drop_source_category_override", &"ordinary_specialist")
	stored.set("personal_drop_item_level_override", 777)
	stored.set("show_ground_chest_diagnostics", true)
	var store := PartyForgeSettingsStore.new()
	TestAssertions.equal(store.save_settings(stored, path), "", "personal-loot controls save", failures)
	var loaded := store.load_settings(path)
	TestAssertions.equal([
		loaded.get("personal_drop_multiplier_percent"),
		loaded.get("force_personal_drops"),
		loaded.get("personal_drop_source_category_override"),
		loaded.get("personal_drop_item_level_override"),
		loaded.get("show_ground_chest_diagnostics"),
	], [375, true, &"ordinary_specialist", 777, true], "all five personal-loot controls round trip", failures)

	var player_source := loaded.copy()
	player_source.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	var player_rules := RunRulesSnapshot.from_settings(player_source)
	TestAssertions.equal([
		player_rules.call("personal_drop_multiplier_percent"),
		player_rules.call("force_personal_drops"),
		player_rules.call("personal_drop_source_category_override"),
		player_rules.call("personal_drop_item_level_override"),
		player_rules.call("show_ground_chest_diagnostics"),
	], [100, false, &"", 0, false], "Player Simulation resets saved developer loot controls to production defaults", failures)
	var developer_rules := RunRulesSnapshot.from_settings(loaded)
	loaded.set("personal_drop_multiplier_percent", 1)
	loaded.set("force_personal_drops", false)
	loaded.set("personal_drop_source_category_override", &"boss")
	loaded.set("personal_drop_item_level_override", 1)
	loaded.set("show_ground_chest_diagnostics", false)
	TestAssertions.equal([
		developer_rules.call("personal_drop_multiplier_percent"),
		developer_rules.call("force_personal_drops"),
		developer_rules.call("personal_drop_source_category_override"),
		developer_rules.call("personal_drop_item_level_override"),
		developer_rules.call("show_ground_chest_diagnostics"),
	], [375, true, &"ordinary_specialist", 777, true], "Developer Mode snapshot captures immutable normalized loot controls", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_city_access_snapshot_setting(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	TestAssertions.equal(settings.get("use_city_access_snapshot"), false, "City access snapshot defaults off", failures)
	settings.set("use_city_access_snapshot", true)
	var copied := settings.copy()
	settings.set("use_city_access_snapshot", false)
	TestAssertions.equal(copied.get("use_city_access_snapshot"), true, "settings copy preserves City access snapshot selection", failures)

	var path := "user://party_forge_settings_city_access_snapshot_test.cfg"
	var store := PartyForgeSettingsStore.new()
	TestAssertions.equal(store.save_settings(copied, path), "", "City access snapshot selection saves", failures)
	TestAssertions.equal(store.load_settings(path).get("use_city_access_snapshot"), true, "City access snapshot selection round trips", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var missing_path := "user://party_forge_settings_city_access_snapshot_missing_test.cfg"
	var missing := ConfigFile.new()
	missing.set_value("settings", "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	missing.set_value("settings", "mode", PartyForgeSettings.Mode.DEVELOPER_MODE)
	missing.save(missing_path)
	TestAssertions.equal(store.load_settings(missing_path).get("use_city_access_snapshot"), false, "schema v1 files without City access snapshot selection default false", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_path))

	var malformed_path := "user://party_forge_settings_city_access_snapshot_malformed_test.cfg"
	var malformed := ConfigFile.new()
	malformed.set_value("settings", "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	malformed.set_value("settings", "use_city_access_snapshot", "true")
	malformed.save(malformed_path)
	TestAssertions.equal(store.load_settings(malformed_path).get("use_city_access_snapshot"), false, "wrong City access snapshot type fails closed", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(malformed_path))

	var retained_path := "user://party_forge_settings_city_access_snapshot_retained_test.cfg"
	var retained := PartyForgeSettings.new()
	retained.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	retained.set("use_city_access_snapshot", true)
	TestAssertions.equal(store.save_settings(retained, retained_path), "", "inactive City access snapshot selection saves", failures)
	TestAssertions.equal(store.load_settings(retained_path).get("use_city_access_snapshot"), true, "Player Simulation retains inactive City access snapshot selection", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(retained_path))

func _test_reduced_motion_setting(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	var has_reduced_motion := settings.get_property_list().any(func(property: Dictionary) -> bool:
		return property.get("name", "") == "reduced_motion"
	)
	TestAssertions.truthy(has_reduced_motion, "settings expose reduced motion", failures)
	if not has_reduced_motion:
		return
	TestAssertions.equal(settings.get("reduced_motion"), false, "reduced motion defaults off", failures)
	settings.set("reduced_motion", true)
	var copied := settings.copy()
	settings.set("reduced_motion", false)
	TestAssertions.equal(copied.get("reduced_motion"), true, "settings copy isolates reduced motion", failures)

	var path := "user://party_forge_settings_reduced_motion_test.cfg"
	var store := PartyForgeSettingsStore.new()
	TestAssertions.equal(store.save_settings(copied, path), "", "reduced motion saves", failures)
	TestAssertions.equal(store.load_settings(path).get("reduced_motion"), true, "reduced motion round trips", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	for mode: PartyForgeSettings.Mode in [PartyForgeSettings.Mode.PLAYER_SIMULATION, PartyForgeSettings.Mode.DEVELOPER_MODE]:
		var snapshot_source := PartyForgeSettings.new()
		snapshot_source.mode = mode
		snapshot_source.set("reduced_motion", true)
		var snapshot := RunRulesSnapshot.from_settings(snapshot_source)
		var has_snapshot_value := snapshot.has_method(&"reduced_motion")
		TestAssertions.truthy(has_snapshot_value, "run snapshot exposes reduced motion in mode %d" % mode, failures)
		if has_snapshot_value:
			TestAssertions.equal(snapshot.call(&"reduced_motion"), true, "run snapshot captures reduced motion in mode %d" % mode, failures)


func _test_accessibility_display_settings(failures: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests/living_forge_settings"))
	var settings := PartyForgeSettings.new()
	settings.set("high_contrast", true)
	settings.set("ui_scale_percent", 85)
	settings.set("text_scale_percent", 124)
	settings.call("normalize")
	TestAssertions.equal(settings.get("ui_scale_percent"), 90, "UI scale tie normalizes upward", failures)
	TestAssertions.equal(settings.get("text_scale_percent"), 125, "text scale normalizes to a supported value", failures)
	var copied := settings.copy()
	TestAssertions.equal(copied.get("high_contrast"), true, "copy preserves high contrast", failures)
	TestAssertions.equal(copied.get("ui_scale_percent"), 90, "copy preserves UI scale", failures)
	TestAssertions.equal(copied.get("text_scale_percent"), 125, "copy preserves text scale", failures)
	settings.set("ui_scale_percent", 1)
	settings.set("text_scale_percent", 999)
	settings.call("normalize")
	TestAssertions.equal(settings.get("ui_scale_percent"), 80, "UI scale clamps to the lowest supported option", failures)
	TestAssertions.equal(settings.get("text_scale_percent"), 150, "text scale clamps to the highest supported option", failures)
	settings.set("ui_scale_percent", 110)
	settings.set("text_scale_percent", 150)
	settings.call("normalize")
	TestAssertions.equal([settings.get("ui_scale_percent"), settings.get("text_scale_percent")], [110, 150], "UI and text scale values remain independent", failures)

	var path := "user://tests/living_forge_settings/accessibility_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var store := PartyForgeSettingsStore.new()
	TestAssertions.equal(store.save_settings(settings, path), "", "accessibility display settings save", failures)
	var loaded := store.load_settings(path)
	TestAssertions.equal([loaded.get("high_contrast"), loaded.get("ui_scale_percent"), loaded.get("text_scale_percent")], [true, 110, 150], "accessibility display settings round trip", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var legacy_path := "user://tests/living_forge_settings/accessibility_legacy_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	legacy.save(legacy_path)
	loaded = store.load_settings(legacy_path)
	TestAssertions.equal([loaded.get("high_contrast"), loaded.get("ui_scale_percent"), loaded.get("text_scale_percent")], [false, 100, 100], "schema v1 files without display accessibility keys use legacy defaults", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	var malformed_path := "user://tests/living_forge_settings/accessibility_malformed_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var malformed := ConfigFile.new()
	malformed.set_value("settings", "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	malformed.set_value("settings", "high_contrast", "true")
	malformed.set_value("settings", "ui_scale_percent", "110")
	malformed.set_value("settings", "text_scale_percent", true)
	malformed.save(malformed_path)
	loaded = store.load_settings(malformed_path)
	TestAssertions.equal([loaded.get("high_contrast"), loaded.get("ui_scale_percent"), loaded.get("text_scale_percent")], [false, 100, 100], "wrong display accessibility value types use legacy defaults", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(malformed_path))

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
	TestAssertions.equal(loaded.get("reduced_motion"), false, "schema v1 files without reduced motion use the false fallback", failures)
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[settings]\nmode=\"1\"\ngod_mode=\"true\"\npersonal_drop_multiplier_percent=\"500\"\nforce_personal_drops=\"true\"\npersonal_drop_source_category_override=14\npersonal_drop_item_level_override=\"80\"\nshow_ground_chest_diagnostics=\"true\"\n")
	file.close()
	loaded = PartyForgeSettingsStore.new().load_settings(path)
	TestAssertions.equal(loaded.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "wrong mode type cannot enable Developer Mode", failures)
	TestAssertions.truthy(not loaded.god_mode, "wrong Boolean type fails closed", failures)
	TestAssertions.equal([loaded.get("personal_drop_multiplier_percent"), loaded.get("force_personal_drops"), loaded.get("personal_drop_source_category_override"), loaded.get("personal_drop_item_level_override"), loaded.get("show_ground_chest_diagnostics")], [100, false, &"", 0, false], "malformed personal-loot fields use production defaults", failures)
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
