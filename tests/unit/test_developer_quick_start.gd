extends RefCounted

const DEVELOPER_REQUIRED_STATUS := "Save Developer Mode before using Developer Quick Start."
const PROFILE_REQUIRED_STATUS := "Choose a profile before using Developer Quick Start."
const UNAVAILABLE_STATUS := "Developer Quick Start is temporarily unavailable."


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_player_mode_direct_route_fails_closed(failures)
	_test_missing_profile_fails_closed(failures)
	_test_invalid_catalog_and_missing_fighter_fail_closed(failures)
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
	_assert_failed_route(main, DEVELOPER_REQUIRED_STATUS, false, "Player Mode direct invocation", failures)
	_cleanup(main, root)


func _test_missing_profile_fails_closed(failures: Array[String]) -> void:
	var root := _root("missing-profile")
	var main := _main(root)
	main.call("_on_settings_applied", _developer_settings())
	main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(main, PROFILE_REQUIRED_STATUS, false, "missing-profile Developer invocation", failures)
	_cleanup(main, root)


func _test_invalid_catalog_and_missing_fighter_fail_closed(failures: Array[String]) -> void:
	var invalid_root := _root("invalid-catalog")
	var invalid_main := _main(invalid_root)
	TestAssertions.truthy(invalid_main.profile_manager.create_profile("Invalid Catalog").ok(), "invalid-catalog fixture creates an active profile", failures)
	invalid_main.call("_on_settings_applied", _developer_settings())
	invalid_main.catalog_valid = false
	invalid_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(invalid_main, UNAVAILABLE_STATUS, true, "invalid catalog", failures)
	_cleanup(invalid_main, invalid_root)

	var fighter_root := _root("missing-fighter")
	var fighter_main := _main(fighter_root)
	TestAssertions.truthy(fighter_main.profile_manager.create_profile("Missing Fighter").ok(), "missing-Fighter fixture creates an active profile", failures)
	fighter_main.call("_on_settings_applied", _developer_settings())
	fighter_main.catalog.classes = fighter_main.catalog.classes.filter(func(definition: ClassDefinition) -> bool: return definition != null and definition.id != &"fighter")
	fighter_main.catalog_valid = true
	fighter_main.call("_on_main_menu_route_requested", MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START)
	_assert_failed_route(fighter_main, UNAVAILABLE_STATUS, true, "missing Fighter", failures)
	_cleanup(fighter_main, fighter_root)


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
	_cleanup(main, root)


func _assert_failed_route(main: PartyForgeMain, expected_status: String, quick_focus_available: bool, label: String, failures: Array[String]) -> void:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var quick_button := menu.get_node("DeveloperQuickStart") as Button
	TestAssertions.truthy(menu.is_open() and not selector.is_open(), "%s keeps the recoverable main menu open" % label, failures)
	TestAssertions.truthy(not main.run_started and main.leader == null, "%s starts no run" % label, failures)
	TestAssertions.equal((menu.get_node("Status") as Label).text, expected_status, "%s shows a player-facing status" % label, failures)
	if quick_focus_available:
		var focus_target: Control
		if main.is_inside_tree():
			focus_target = main.get_tree().root.gui_get_focus_owner()
		else:
			focus_target = menu.get("_pending_preferred_focus") as Control
		TestAssertions.equal(focus_target, quick_button, "%s restores exact DeveloperQuickStart focus" % label, failures)


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
