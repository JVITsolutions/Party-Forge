extends RefCounted

const DEVELOPER_REQUIRED_STATUS := "Save Developer Mode before using Developer Quick Start."
const PROFILE_REQUIRED_STATUS := "Choose a profile before using Developer Quick Start."
const UNAVAILABLE_STATUS := "Developer Quick Start is temporarily unavailable."


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_player_mode_direct_route_fails_closed(failures)
	_test_missing_profile_fails_closed(failures)
	_test_hidden_direct_route_preserves_active_surfaces(failures)
	_test_invalid_catalog_and_missing_fighter_fail_closed(failures)
	_test_saved_settings_store_authorizes_quick_start(failures)
	_test_developer_route_starts_fighter_without_profile_write(failures)
	return failures


func _test_player_mode_direct_route_fails_closed(failures: Array[String]) -> void:
	var root := _root("player")
	var main := _main(root)
	var created := main.profile_manager.create_profile("Player Route")
	TestAssertions.truthy(created.ok(), "Player direct-route fixture creates an active profile", failures)
	var player_settings := PartyForgeSettings.new()
	main.call("_on_settings_applied", player_settings)
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(main, DEVELOPER_REQUIRED_STATUS, "PrimaryAction", "Player Mode direct invocation", failures)
	_cleanup(main, root)


func _test_missing_profile_fails_closed(failures: Array[String]) -> void:
	var root := _root("missing-profile")
	var main := _main(root)
	main.call("_on_settings_applied", _developer_settings())
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(main, PROFILE_REQUIRED_STATUS, "PrimaryAction", "missing-profile Developer invocation", failures)
	_cleanup(main, root)


func _test_hidden_direct_route_preserves_active_surfaces(failures: Array[String]) -> void:
	var run_root := _root("hidden-running")
	var running_main := _developer_main_with_profile(run_root, "Hidden Running", failures)
	TestAssertions.truthy(running_main.call("select_leader_class", &"fighter"), "running-surface fixture starts", failures)
	_assert_hidden_route_unchanged(running_main, {"run_started": true, "menu_open": false, "selector_open": false, "settings_open": false, "tree_open": false}, "active run", failures)
	_cleanup(running_main, run_root)

	var settings_root := _root("hidden-settings")
	var settings_main := _developer_main_with_profile(settings_root, "Hidden Settings", failures)
	settings_main.call("_open_settings_from_main_menu")
	_assert_hidden_route_unchanged(settings_main, {"run_started": false, "menu_open": true, "selector_open": false, "settings_open": true, "tree_open": false}, "Settings", failures)
	_cleanup(settings_main, settings_root)

	var tree_root := _root("hidden-tree")
	var tree_main := _developer_main_with_profile(tree_root, "Hidden Tree", failures)
	tree_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_CITY_TREE)
	_assert_hidden_route_unchanged(tree_main, {"run_started": false, "menu_open": false, "selector_open": false, "settings_open": false, "tree_open": true}, "Passive Tree", failures)
	(tree_main.get_node("PassiveTreeScreen") as PassiveTreeScreen).close()
	_cleanup(tree_main, tree_root)

	var setup_root := _root("hidden-run-setup")
	var setup_main := _developer_main_with_profile(setup_root, "Hidden Run Setup", failures)
	setup_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_RUN_SETUP)
	_assert_hidden_route_unchanged(setup_main, {"run_started": false, "menu_open": false, "selector_open": true, "settings_open": false, "tree_open": false}, "run setup", failures)
	_cleanup(setup_main, setup_root)


func _assert_hidden_route_unchanged(main: PartyForgeMain, expected: Dictionary, label: String, failures: Array[String]) -> void:
	var before := _surface_snapshot(main)
	for key: String in expected:
		TestAssertions.equal(before.get(key), expected[key], "%s fixture starts with exact %s state" % [label, key], failures)
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	TestAssertions.equal(_surface_snapshot(main), before, "%s rejects hidden Quick Start without changing surface, status, focus, or run state" % label, failures)


func _test_invalid_catalog_and_missing_fighter_fail_closed(failures: Array[String]) -> void:
	var invalid_root := _root("invalid-catalog")
	var invalid_main := _main(invalid_root)
	TestAssertions.truthy(invalid_main.profile_manager.create_profile("Invalid Catalog").ok(), "invalid-catalog fixture creates an active profile", failures)
	invalid_main.call("_on_settings_applied", _developer_settings())
	invalid_main.catalog_valid = false
	invalid_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(invalid_main, UNAVAILABLE_STATUS, "DeveloperQuickStart", "invalid catalog", failures)
	_cleanup(invalid_main, invalid_root)

	var fighter_root := _root("missing-fighter")
	var fighter_main := _main(fighter_root)
	TestAssertions.truthy(fighter_main.profile_manager.create_profile("Missing Fighter").ok(), "missing-Fighter fixture creates an active profile", failures)
	fighter_main.call("_on_settings_applied", _developer_settings())
	fighter_main.catalog.classes = fighter_main.catalog.classes.filter(func(definition: ClassDefinition) -> bool: return definition != null and definition.id != &"fighter")
	fighter_main.catalog.upgrades = fighter_main.catalog.upgrades.filter(func(definition: UpgradeDefinition) -> bool: return definition != null and &"fighter" not in definition.allowed_class_ids)
	fighter_main.catalog_valid = true
	TestAssertions.truthy(fighter_main.catalog.validate().is_empty(), "closest isolated missing-Fighter fixture removes its class-specific upgrade dependency and remains globally valid", failures)
	fighter_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(fighter_main, UNAVAILABLE_STATUS, "DeveloperQuickStart", "missing Fighter", failures)
	TestAssertions.truthy(fighter_main.catalog_valid, "missing Fighter denial preserves healthy global catalog state", failures)
	TestAssertions.truthy(fighter_main.call("select_leader_class", &"ranger"), "ordinary Ranger launch remains available after missing-Fighter Quick Start denial", failures)
	_cleanup(fighter_main, fighter_root)


func _test_saved_settings_store_authorizes_quick_start(failures: Array[String]) -> void:
	var original_files := _backup_default_settings_artifacts()
	_cleanup_default_settings_artifacts()
	var store := PartyForgeSettingsStore.new()
	var player_settings := PartyForgeSettings.new()
	TestAssertions.equal(store.save_settings(player_settings), "", "saved-mode fixture writes Player Mode through the real store", failures)
	TestAssertions.equal(store.load_settings().mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "real store reloads saved Player Mode", failures)

	var draft_root := _root("unsaved-draft")
	var draft_main := _main(draft_root)
	TestAssertions.truthy(draft_main.profile_manager.create_profile("Unsaved Draft").ok(), "unsaved-draft fixture creates an active profile", failures)
	var settings_screen := draft_main.get_node("SettingsScreen") as SettingsScreen
	var menu := draft_main.get_node("MainMenuScreen") as MainMenuScreen
	var additional := settings_screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
	var mode := additional.get_node("Layout/Mode") as OptionButton
	settings_screen.open_additional(menu.get_node("Settings") as Control)
	mode.selected = PartyForgeSettings.Mode.DEVELOPER_MODE
	additional.call("_on_mode_changed", PartyForgeSettings.Mode.DEVELOPER_MODE)
	settings_screen.close()
	TestAssertions.equal(draft_main.saved_settings.mode, PartyForgeSettings.Mode.PLAYER_SIMULATION, "unsaved Developer draft never replaces main's saved settings", failures)
	draft_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(draft_main, DEVELOPER_REQUIRED_STATUS, "PrimaryAction", "unsaved Developer draft", failures)
	_cleanup(draft_main, draft_root)

	var developer_settings := _developer_settings()
	TestAssertions.equal(store.save_settings(developer_settings), "", "saved-mode fixture writes Developer Mode through the real store", failures)
	TestAssertions.equal(store.load_settings().mode, PartyForgeSettings.Mode.DEVELOPER_MODE, "real store reloads saved Developer Mode", failures)
	var saved_root := _root("saved-developer")
	var saved_main := _main(saved_root)
	TestAssertions.truthy(saved_main.profile_manager.create_profile("Saved Developer").ok(), "saved Developer fixture creates an active profile", failures)
	TestAssertions.equal(saved_main.saved_settings.mode, PartyForgeSettings.Mode.DEVELOPER_MODE, "main boot consumes the reloaded saved Developer Mode", failures)
	saved_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	TestAssertions.truthy(saved_main.run_started and saved_main.leader != null, "real saved Developer Mode authorizes Quick Start", failures)
	_cleanup(saved_main, saved_root)
	_cleanup_default_settings_artifacts()
	_restore_default_settings_artifacts(original_files)


func _test_developer_route_starts_fighter_without_profile_write(failures: Array[String]) -> void:
	var root := _root("success")
	var main := _main(root)
	var created := main.profile_manager.create_profile("Quick Start Durable", 1000)
	TestAssertions.truthy(created.ok(), "Developer success fixture creates an active profile", failures)
	if not created.ok():
		_cleanup(main, root)
		return
	var profile_id := created.profile.profile_id
	var store := ProfileStore.new()
	var fixture := store.load_profile(profile_id, root).profile
	fixture.updated_at_unix = 1100
	fixture.prologue_state = ProfileState.PrologueState.IN_PROGRESS
	fixture.passive_points_available = 4
	fixture.passive_points_lifetime_earned = 9
	fixture.milestones = ["prologue-entered"]
	fixture.permanent_feature_unlocks = ["starter-unlock"]
	fixture.discovered_buildings = ["training-yard"]
	fixture.discovered_trees = ["legacy-tree"]
	fixture.tree_allocations = {"legacy-tree": ["legacy-root"]}
	fixture.tree_visibility_progress = {"legacy-tree": 2}
	TestAssertions.equal(store.save_profile(fixture, root), "", "durable quick-start fixture saves", failures)
	var committed := ProfileMutationService.new(store).complete_prologue(profile_id, "quick-start-fixture", root)
	TestAssertions.truthy(committed.ok(), "durable quick-start fixture records applied progression transaction", failures)
	TestAssertions.equal(main.profile_manager.refresh_profile(profile_id), "", "durable quick-start fixture refreshes active profile", failures)

	var settings := _developer_settings()
	settings.unlock_all_implemented_content = true
	settings.god_mode = true
	settings.party_capacity_override = 7
	settings.enemy_density_percent = 240
	settings.experience_multiplier_percent = 175
	settings.level_up_card_count = 6
	settings.reduced_motion = true
	main.call("_on_settings_applied", settings)
	var expected_rules := RunRulesSnapshot.from_settings(settings)
	var profile_path := store.profile_path(profile_id, root)
	var before_bytes := FileAccess.get_file_as_bytes(profile_path)
	var before_modified := FileAccess.get_modified_time(profile_path)
	var before_profile := store.load_profile(profile_id, root).profile.to_dictionary()
	var before_root := _snapshot_root(root)
	var profile_events: Array[int] = [0]
	var active_events: Array[int] = [0]
	main.profile_manager.profiles_changed.connect(func() -> void: profile_events[0] += 1)
	main.profile_manager.active_profile_changed.connect(func(_profile: ProfileState) -> void: active_events[0] += 1)

	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)

	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var party := main.get_node("PartyManager") as PartyManager
	TestAssertions.truthy(main.run_started and main.leader != null, "Developer Quick Start starts the normal arena", failures)
	TestAssertions.truthy(not menu.is_open() and not selector.is_open(), "successful Quick Start closes front-end surfaces", failures)
	TestAssertions.truthy(not party.members.is_empty() and party.members[0].class_definition.id == &"fighter", "Developer Quick Start launches Fighter", failures)
	_assert_rules(main.active_run_rules, expected_rules, failures)
	var after_profile := store.load_profile(profile_id, root).profile.to_dictionary()
	TestAssertions.equal(after_profile, before_profile, "Quick Start preserves the whole durable profile dictionary", failures)
	TestAssertions.equal(FileAccess.get_file_as_bytes(profile_path), before_bytes, "Quick Start performs no profile-content write", failures)
	TestAssertions.equal(FileAccess.get_modified_time(profile_path), before_modified, "Quick Start performs no profile-file write", failures)
	TestAssertions.equal(_snapshot_root(root), before_root, "Quick Start preserves every profile-root path, byte, length, and file time", failures)
	TestAssertions.equal(profile_events[0], 0, "Quick Start emits no profile-list mutation signal", failures)
	TestAssertions.equal(active_events[0], 0, "Quick Start emits no active-profile mutation signal", failures)
	_cleanup(main, root)


func _assert_failed_route(main: PartyForgeMain, expected_status: String, expected_focus_path: String, label: String, failures: Array[String]) -> void:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	TestAssertions.truthy(menu.is_open() and not selector.is_open(), "%s keeps the recoverable main menu open" % label, failures)
	TestAssertions.truthy(not main.run_started and main.leader == null, "%s starts no run" % label, failures)
	TestAssertions.equal((menu.get_node("Status") as Label).text, expected_status, "%s shows a player-facing status" % label, failures)
	var focus_target: Control
	if main.is_inside_tree():
		focus_target = main.get_tree().root.gui_get_focus_owner()
	else:
		focus_target = menu.get("_pending_preferred_focus") as Control
	TestAssertions.equal(focus_target, menu.get_node(expected_focus_path), "%s restores exact %s focus" % [label, expected_focus_path], failures)


func _assert_rules(actual: RunRulesSnapshot, expected: RunRulesSnapshot, failures: Array[String]) -> void:
	TestAssertions.truthy(actual != null, "Quick Start captures an immutable RunRulesSnapshot", failures)
	if actual == null:
		return
	TestAssertions.equal(actual.developer_mode_active(), expected.developer_mode_active(), "Quick Start snapshot preserves mode", failures)
	TestAssertions.equal(actual.unlock_all_implemented_content(), expected.unlock_all_implemented_content(), "Quick Start snapshot preserves unlock-all", failures)
	TestAssertions.equal(actual.god_mode(), expected.god_mode(), "Quick Start snapshot preserves God Mode", failures)
	TestAssertions.equal(actual.party_capacity(), expected.party_capacity(), "Quick Start snapshot preserves party capacity", failures)
	TestAssertions.equal(actual.enemy_density_percent(), expected.enemy_density_percent(), "Quick Start snapshot preserves enemy density", failures)
	TestAssertions.equal(actual.experience_multiplier_percent(), expected.experience_multiplier_percent(), "Quick Start snapshot preserves experience multiplier", failures)
	TestAssertions.equal(actual.level_up_card_count(), expected.level_up_card_count(), "Quick Start snapshot preserves card count", failures)
	TestAssertions.equal(actual.reduced_motion(), expected.reduced_motion(), "Quick Start snapshot preserves reduced motion", failures)


func _developer_settings() -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	return result


func _developer_main_with_profile(root: String, display_name: String, failures: Array[String]) -> PartyForgeMain:
	var main := _main(root)
	TestAssertions.truthy(main.profile_manager.create_profile(display_name).ok(), "%s fixture creates an active profile" % display_name, failures)
	main.call("_on_settings_applied", _developer_settings())
	return main


func _surface_snapshot(main: PartyForgeMain) -> Dictionary:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var tree := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
	return {
		"run_started": main.run_started,
		"leader": main.leader,
		"party_size": main.party_manager.members.size(),
		"menu_open": menu.is_open(),
		"menu_status": (menu.get_node("Status") as Label).text,
		"menu_pending_focus": menu.get("_pending_preferred_focus"),
		"selector_open": selector.is_open(),
		"selector_pending_focus": selector.get("_pending_initial_focus"),
		"settings_open": settings.is_open(),
		"settings_pending_open": settings.get("_pending_open"),
		"settings_return_focus": settings.get("_return_focus"),
		"tree_open": tree.is_open(),
		"tree_return_focus": tree.get("_return_focus"),
		"focus_owner": main.get_tree().root.gui_get_focus_owner() if main.is_inside_tree() else null,
	}


func _snapshot_root(root: String) -> Dictionary:
	var result: Dictionary = {}
	_snapshot_directory(ProjectSettings.globalize_path(root), "", result)
	return result


func _snapshot_directory(absolute_directory: String, relative_directory: String, result: Dictionary) -> void:
	var directory := DirAccess.open(absolute_directory)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if name not in [".", ".."]:
			var absolute_path := absolute_directory.path_join(name)
			var relative_path := name if relative_directory.is_empty() else relative_directory.path_join(name)
			if directory.current_is_dir():
				_snapshot_directory(absolute_path, relative_path, result)
			else:
				var bytes := FileAccess.get_file_as_bytes(absolute_path)
				result[relative_path] = {
					"bytes": bytes,
					"length": bytes.size(),
					"modified": FileAccess.get_modified_time(absolute_path),
				}
		name = directory.get_next()
	directory.list_dir_end()


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


func _main(root: String) -> PartyForgeMain:
	ProfileTestSupport.remove_tree(root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = root
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	return main


func _root(label: String) -> String:
	return "user://tests/developer_quick_start_%s_%d_%d" % [label, OS.get_process_id(), Time.get_ticks_usec()]


func _cleanup(main: PartyForgeMain, root: String) -> void:
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()
	ProfileTestSupport.remove_tree(root)
