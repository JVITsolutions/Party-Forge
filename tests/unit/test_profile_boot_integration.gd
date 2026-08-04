extends RefCounted

const PROFILE_ROOT_PREFIX := "user://tests/profile_boot_integration"


func run() -> Array[String]:
	var failures: Array[String] = []
	var root := "%s_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(root)
	_test_fresh_boot_and_run_gate(root, failures)
	ProfileTestSupport.remove_tree(root)

	var error_root := "%s_error_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(error_root)
	_test_bootstrap_error_routes_to_profiles(error_root, failures)
	_remove_file(error_root)

	var mixed_root := "%s_mixed_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(mixed_root)
	_test_mixed_healthy_and_damaged_boot(mixed_root, failures)
	ProfileTestSupport.remove_tree(mixed_root)

	var diagnostic_root := "%s_diagnostic_%d_%d" % [PROFILE_ROOT_PREFIX, OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(diagnostic_root)
	_test_bootstrap_diagnostic_survives_profile_lifecycle(diagnostic_root, failures)
	ProfileTestSupport.remove_tree(diagnostic_root)
	return failures


func _test_fresh_boot_and_run_gate(root: String, failures: Array[String]) -> void:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	TestAssertions.truthy(main.get("profile_manager") is ProfileManager, "main creates ProfileManager", failures)
	TestAssertions.equal(main.call("active_profile"), null, "fresh boot has no active profile", failures)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var run_hud := main.get_node("HUD/Margin") as Control
	var game_run := main.get_node("GameRun") as GameRun
	TestAssertions.truthy(menu != null, "fresh boot composes MainMenuScreen", failures)
	if menu == null:
		(Engine.get_main_loop() as SceneTree).paused = false
		main.free()
		return
	var primary := menu.get_node("PrimaryAction") as Button
	TestAssertions.truthy(menu.is_open(), "fresh boot opens the main menu", failures)
	TestAssertions.truthy(not settings.is_open(), "fresh boot keeps Settings closed", failures)
	TestAssertions.truthy(not selector.is_open(), "fresh boot keeps run setup hidden", failures)
	TestAssertions.truthy(not run_hud.visible, "fresh boot keeps the run HUD hidden", failures)
	TestAssertions.equal(main.get("leader"), null, "fresh boot creates no leader", failures)
	TestAssertions.equal(game_run.current_state(), RunStateMachine.State.SETUP, "fresh boot keeps the run timer in setup", failures)
	TestAssertions.near(game_run.elapsed_time(), 0.0, 0.001, "fresh boot keeps elapsed run time at zero", failures)
	TestAssertions.equal(primary.text, "Play", "fresh boot presents the no-profile Play action", failures)
	menu.route_requested.emit(menu.projection().primary_route_id)
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	TestAssertions.truthy(settings.is_open(), "no-profile Play opens Settings", failures)
	TestAssertions.equal(settings.get("_return_focus"), primary, "no-profile Play preserves PrimaryAction return focus", failures)
	TestAssertions.equal(profiles.initial_focus(), profile_name, "no-profile Play targets ProfileName as initial focus", failures)

	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "run launch rejects missing profile", failures)
	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "repeated run launch still rejects missing profile", failures)
	TestAssertions.equal(main.get("run_started"), false, "missing profile leaves gameplay unstarted", failures)
	TestAssertions.equal(main.get("leader"), null, "missing profile creates no leader", failures)
	TestAssertions.truthy(settings.is_open(), "missing profile keeps Profiles Settings open", failures)

	var manager := main.get("profile_manager") as ProfileManager
	var created := manager.create_profile("Jacob", 1000)
	TestAssertions.truthy(created.ok(), "profile creates through boot manager", failures)
	var exposed := main.call("active_profile") as ProfileState
	TestAssertions.truthy(exposed != null, "main exposes the selected profile", failures)
	if exposed != null:
		exposed.display_name = "Mutated Copy"
		TestAssertions.equal((main.call("active_profile") as ProfileState).display_name, "Jacob", "main active profile is a defensive copy", failures)
	TestAssertions.truthy(menu.is_open() and not settings.is_open(), "profile creation returns to the main menu", failures)
	TestAssertions.equal(menu.projection().active_profile_text, "Active Profile: Jacob", "profile creation refreshes the selected display name", failures)
	TestAssertions.equal(main.get("run_started"), false, "profile creation never auto-starts a run", failures)
	TestAssertions.truthy(not selector.is_open() and not run_hud.visible, "profile creation leaves run setup and HUD hidden", failures)
	var before_prologue := (main.call("active_profile") as ProfileState).prologue_state
	menu.route_requested.emit(menu.projection().primary_route_id)
	TestAssertions.truthy(selector.is_open() and not menu.is_open(), "prologue start routes to current run setup", failures)
	TestAssertions.equal((main.call("active_profile") as ProfileState).prologue_state, before_prologue, "temporary prologue start route does not mutate profile progress", failures)
	TestAssertions.truthy(main.call("select_leader_class", &"fighter"), "active profile permits existing arena launch", failures)
	TestAssertions.equal(main.get("run_started"), true, "profile-backed class selection starts gameplay", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _test_bootstrap_error_routes_to_profiles(root: String, failures: Array[String]) -> void:
	var file := FileAccess.open(root, FileAccess.WRITE)
	TestAssertions.truthy(file != null, "bootstrap error fixture creates an exact conflicting root", failures)
	if file == null:
		return
	file.store_string("not a profile directory")
	file.close()
	var expected_error := "PROFILE_BOOTSTRAP_ERROR root=%s stage=validate-root reason=path is not a directory" % root
	TestAssertions.equal(ProfileManager.new().bootstrap(root), expected_error, "bootstrap error source includes the exact injected root", failures)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
	TestAssertions.equal(main.call("active_profile"), null, "bootstrap error exposes no active profile", failures)
	TestAssertions.equal(settings.get("_profile_manager"), main.get("profile_manager"), "bootstrap error routes the main manager to Profiles Settings", failures)
	TestAssertions.truthy(menu != null, "bootstrap error composes MainMenuScreen", failures)
	if menu == null:
		(Engine.get_main_loop() as SceneTree).paused = false
		main.free()
		return
	TestAssertions.truthy(menu.is_open() and not settings.is_open(), "bootstrap error still boots to the main menu", failures)
	TestAssertions.truthy(not menu.projection().status_text.contains("PROFILE_") and not menu.projection().status_text.contains(root), "bootstrap error menu status is nontechnical", failures)
	menu.route_requested.emit(menu.projection().primary_route_id)
	var technical := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles/Layout/TechnicalDetails") as Label
	TestAssertions.truthy(settings.is_open() and technical.text.contains(expected_error), "Profiles retains bootstrap technical details", failures)
	TestAssertions.truthy(not main.call("select_leader_class", &"fighter"), "bootstrap error cannot launch a run", failures)
	TestAssertions.equal(main.get("run_started"), false, "bootstrap error leaves gameplay unstarted", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()

func _test_mixed_healthy_and_damaged_boot(root: String, failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var healthy := ProfileState.new_profile("profile-bootgood1", "Healthy", 1000)
	TestAssertions.equal(store.save_profile(healthy, root), "", "mixed boot healthy fixture saves", failures)
	var corrupt_path := root.path_join("profile-bootbad01.json")
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("corrupt without backup")
		corrupt.close()
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.set("profile_root", root)
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var menu := main.get_node_or_null("MainMenuScreen") as MainMenuScreen
	var list := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles/Layout/ProfileList") as ItemList
	TestAssertions.truthy(menu != null, "mixed boot composes MainMenuScreen", failures)
	if menu == null:
		(Engine.get_main_loop() as SceneTree).paused = false
		main.free()
		return
	TestAssertions.truthy(menu.is_open() and not settings.is_open(), "mixed healthy and damaged boot opens the main menu", failures)
	TestAssertions.truthy(not menu.projection().status_text.contains("PROFILE_"), "mixed boot exposes only a safe menu status", failures)
	settings.open_profiles(menu.get_node("Settings") as Control)
	TestAssertions.equal(list.item_count, 2, "mixed boot visibly retains healthy and damaged profiles", failures)
	TestAssertions.equal((main.call("active_profile") as ProfileState).profile_id, healthy.profile_id, "mixed boot retains the healthy active profile", failures)
	var damaged_index := -1
	for index: int in range(list.item_count):
		if list.get_item_text(index).contains("[Damaged]"):
			damaged_index = index
	TestAssertions.truthy(damaged_index >= 0 and list.is_item_disabled(damaged_index), "mixed boot disables the damaged profile row", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _test_bootstrap_diagnostic_survives_profile_lifecycle(root: String, failures: Array[String]) -> void:
	var store := ProfileStore.new()
	var healthy := ProfileState.new_profile("profile-diagnostic1", "Healthy Diagnostic", 1000)
	TestAssertions.equal(store.save_profile(healthy, root), "", "diagnostic boot healthy fixture saves", failures)
	var index_file := FileAccess.open(root.path_join(ProfileIndexStore.FILE_NAME), FileAccess.WRITE)
	TestAssertions.truthy(index_file != null, "diagnostic boot malformed index fixture opens", failures)
	if index_file == null:
		return
	index_file.store_string("{not valid json")
	index_file.close()
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = root
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	main.call("_ready")
	var raw_diagnostic := main.profile_bootstrap_error
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var profiles := main.get_node("SettingsScreen/Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var status := profiles.get_node("Layout/Status") as Label
	var technical := profiles.get_node("Layout/TechnicalDetails") as Label
	TestAssertions.truthy(not raw_diagnostic.is_empty(), "malformed index produces a bootstrap diagnostic", failures)
	_assert_safe_bootstrap_disclosure(status, technical, menu, raw_diagnostic, root, "initial bootstrap", failures)
	# Repair the injected index artifact so successful profile operations can
	# exercise both manager signals after the original boot diagnostic.
	_remove_file(root.path_join(ProfileIndexStore.FILE_NAME))

	var manager := main.profile_manager
	var created := manager.create_profile("Created After Diagnostic", 2000)
	TestAssertions.truthy(created.ok(), "profile creation succeeds after recoverable index diagnostic", failures)
	_assert_safe_bootstrap_disclosure(status, technical, menu, raw_diagnostic, root, "profiles_changed and active_profile_changed", failures)
	TestAssertions.equal(manager.select_profile(healthy.profile_id), "", "healthy profile can be selected after bootstrap diagnostic", failures)
	_assert_safe_bootstrap_disclosure(status, technical, menu, raw_diagnostic, root, "active_profile_changed selection", failures)
	TestAssertions.equal(manager.refresh_profile(healthy.profile_id), "", "healthy profile refresh succeeds after bootstrap diagnostic", failures)
	_assert_safe_bootstrap_disclosure(status, technical, menu, raw_diagnostic, root, "profiles_changed refresh", failures)
	var immediate_error := "PROFILE_ACTION_ERROR reason=forced immediate failure"
	profiles.call("_show_error", "The selected profile action could not be completed.", immediate_error)
	TestAssertions.equal(manager.refresh_profile(healthy.profile_id), "", "profile refresh still succeeds while an action error is displayed", failures)
	TestAssertions.equal(status.text, "The selected profile action could not be completed.", "profile refresh does not erase the immediate action status", failures)
	TestAssertions.truthy(technical.text.contains(immediate_error), "profile refresh retains immediate action technical details", failures)
	TestAssertions.truthy(technical.text.contains(raw_diagnostic), "immediate action disclosure keeps bootstrap technical details available", failures)
	TestAssertions.truthy(not menu.projection().status_text.contains(immediate_error), "immediate action diagnostic never enters main-menu text", failures)
	(Engine.get_main_loop() as SceneTree).paused = false
	main.free()


func _assert_safe_bootstrap_disclosure(
	status: Label,
	technical: Label,
	menu: MainMenuScreen,
	raw_diagnostic: String,
	root: String,
	stage: String,
	failures: Array[String]
) -> void:
	TestAssertions.truthy(not status.text.is_empty(), "%s keeps a player-safe Profiles status" % stage, failures)
	TestAssertions.truthy(not status.text.contains("PROFILE_") and not status.text.contains(root), "%s keeps raw diagnostics out of Profiles status" % stage, failures)
	TestAssertions.truthy(not status.tooltip_text.contains("PROFILE_") and not status.tooltip_text.contains(root), "%s keeps raw diagnostics out of Profiles tooltip" % stage, failures)
	TestAssertions.truthy(technical.visible and technical.text.contains(raw_diagnostic), "%s retains raw Profiles technical details" % stage, failures)
	TestAssertions.truthy(not menu.projection().status_text.contains("PROFILE_") and not menu.projection().status_text.contains(root), "%s keeps the main menu nontechnical" % stage, failures)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
