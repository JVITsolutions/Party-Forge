extends RefCounted

const BADGE_SCENE_PATH := "res://scenes/ui/developer_mode_badge.tscn"
const MAIN_SCENE_PATH := "res://scenes/game/main.tscn"

var _profile_root := ""


func run() -> Array[String]:
	var failures: Array[String] = []
	_profile_root = "user://tests/developer_mode_integration-profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
	_test_badge_summary_uses_immutable_snapshot(failures)
	_test_main_configures_badge_from_active_run(failures)
	ProfileTestSupport.remove_tree(_profile_root)
	return failures


func _test_badge_summary_uses_immutable_snapshot(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(BADGE_SCENE_PATH), "Developer Mode badge scene exists", failures)
	if not ResourceLoader.exists(BADGE_SCENE_PATH):
		return
	var packed := load(BADGE_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Developer Mode badge scene loads", failures)
	if packed == null:
		return
	var badge := packed.instantiate()
	TestAssertions.truthy(badge.has_method(&"configure"), "badge exposes snapshot configuration", failures)
	TestAssertions.truthy(badge.has_method(&"summary_text"), "badge exposes stable summary text", failures)
	if not badge.has_method(&"configure") or not badge.has_method(&"summary_text"):
		badge.free()
		return

	badge.call(&"configure", null)
	TestAssertions.truthy(not badge.visible, "missing snapshot hides the badge", failures)
	TestAssertions.equal(badge.call(&"summary_text"), "", "missing snapshot clears the badge summary", failures)

	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.unlock_all_implemented_content = true
	player_settings.god_mode = true
	player_settings.party_capacity_override = 12
	player_settings.enemy_density_percent = 500
	badge.call(&"configure", RunRulesSnapshot.from_settings(player_settings))
	TestAssertions.truthy(not badge.visible, "Player Simulation hides retained developer values", failures)
	TestAssertions.equal(badge.call(&"summary_text"), "", "Player Simulation has no developer summary", failures)

	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	settings.god_mode = true
	settings.party_capacity_override = 12
	settings.enemy_density_percent = 500
	var snapshot := RunRulesSnapshot.from_settings(settings)
	badge.call(&"configure", snapshot)
	TestAssertions.truthy(badge.visible, "Developer Mode badge is visible", failures)
	TestAssertions.equal(
		badge.call(&"summary_text"),
		"DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%",
		"badge summarizes active overrides in stable policy order",
		failures,
	)
	settings.unlock_all_implemented_content = false
	settings.god_mode = false
	settings.party_capacity_override = 2
	settings.enemy_density_percent = 20
	TestAssertions.equal(
		badge.call(&"summary_text"),
		"DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%",
		"later saved-settings mutation cannot change the configured badge",
		failures,
	)

	var progression_settings := PartyForgeSettings.new()
	progression_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	progression_settings.experience_multiplier_percent = 500
	progression_settings.level_up_card_count = 7
	badge.call(&"configure", RunRulesSnapshot.from_settings(progression_settings))
	TestAssertions.equal(badge.call(&"summary_text"), "DEV MODE | XP 500% | CARDS 7", "badge appends non-default progression overrides in stable order", failures)
	var default_settings := PartyForgeSettings.new()
	default_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	badge.call(&"configure", RunRulesSnapshot.from_settings(default_settings))
	TestAssertions.equal(badge.call(&"summary_text"), "DEV MODE", "badge omits default progression values", failures)
	badge.free()


func _test_main_configures_badge_from_active_run(failures: Array[String]) -> void:
	if not ResourceLoader.exists(BADGE_SCENE_PATH):
		return
	var original_files := _backup_default_settings_artifacts()
	_cleanup_default_settings_artifacts()
	var store := PartyForgeSettingsStore.new()

	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.unlock_all_implemented_content = true
	player_settings.god_mode = true
	player_settings.party_capacity_override = 12
	player_settings.enemy_density_percent = 500
	TestAssertions.equal(store.save_settings(player_settings), "", "Player Simulation end-to-end fixture saves", failures)
	var player_main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_prepare_main(player_main)
	TestAssertions.truthy(player_main.call(&"select_leader_class", &"fighter"), "Player Simulation end-to-end fixture starts", failures)
	var player_badge := player_main.get_node_or_null("DeveloperModeBadge")
	TestAssertions.truthy(player_badge != null and not player_badge.visible, "Player Simulation run keeps the badge absent", failures)
	if player_badge != null:
		TestAssertions.equal(player_badge.call(&"summary_text"), "", "Player Simulation run has no badge summary", failures)
	_cleanup_main(player_main)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	developer_settings.god_mode = true
	developer_settings.party_capacity_override = 12
	developer_settings.enemy_density_percent = 500
	TestAssertions.equal(store.save_settings(developer_settings), "", "Developer Mode end-to-end fixture saves", failures)
	var developer_main := (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	_prepare_main(developer_main)
	TestAssertions.truthy(developer_main.call(&"select_leader_class", &"fighter"), "Developer Mode end-to-end fixture starts", failures)
	var developer_badge := developer_main.get_node_or_null("DeveloperModeBadge")
	TestAssertions.truthy(developer_badge != null and developer_badge.visible, "Developer Mode run shows the configured badge", failures)
	if developer_badge != null:
		TestAssertions.equal(developer_badge.call(&"summary_text"), "DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%", "main passes the active snapshot to the badge", failures)
		var saved := developer_main.get("saved_settings") as PartyForgeSettings
		saved.unlock_all_implemented_content = false
		saved.god_mode = false
		saved.party_capacity_override = 2
		saved.enemy_density_percent = 20
		TestAssertions.equal(developer_badge.call(&"summary_text"), "DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%", "running main badge ignores later saved-settings mutation", failures)
	_cleanup_main(developer_main)
	_cleanup_default_settings_artifacts()
	_restore_default_settings_artifacts(original_files)


func _cleanup_main(main: Node) -> void:
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _prepare_main(main: Node) -> void:
	main.set("profile_root", _profile_root)
	main.call(&"_ready")
	var manager := main.get("profile_manager") as ProfileManager
	if manager.active_profile() == null:
		manager.create_profile("Test Profile")
	(main.get_node("SettingsScreen") as SettingsScreen).close()


func _cleanup_default_settings_artifacts() -> void:
	for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _backup_default_settings_artifacts() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
		if FileAccess.file_exists(path):
			result[path] = FileAccess.get_file_as_bytes(path)
	return result


func _restore_default_settings_artifacts(files: Dictionary) -> void:
	for path: String in files:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(files[path] as PackedByteArray)
