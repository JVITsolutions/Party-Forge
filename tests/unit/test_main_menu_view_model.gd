extends RefCounted

const CITY_TREE_ID := "party-forge-city-v1"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_route_ids_are_stable(failures)
	_test_no_profile_has_only_first_launch_actions(failures)
	_test_every_prologue_state_selects_its_route(failures)
	_test_recovery_overrides_every_profile_progress_route(failures)
	_test_recovery_status_precedes_unavailable_city_status(failures)
	_test_completed_discovery_exposes_city_tree(failures)
	_test_player_mode_ignores_developer_overrides(failures)
	_test_developer_mode_exposes_nonpersistent_tools(failures)
	_test_unavailable_city_tree_fails_closed(failures)
	_test_malformed_inputs_return_a_safe_projection(failures)
	_test_projection_is_copy_owned_and_value_only(failures)
	_test_armoury_and_warehouse_feature_access(failures)
	return failures

func _test_route_ids_are_stable(failures: Array[String]) -> void:
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROFILES, &"profiles", "Profiles route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROLOGUE_START, &"prologue_start", "prologue-start route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROLOGUE_RESUME, &"prologue_resume", "prologue-resume route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_RUN_SETUP, &"run_setup", "run-setup route ID is stable", failures)
	TestAssertions.truthy(_view_model_source().contains("const ROUTE_RUN_RECOVERY: StringName = &\"run_recovery\""), "run-recovery route ID is declared as a stable constant", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_CITY_TREE, &"city_tree", "City-tree route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_ARMOURY, &"armoury", "Armoury route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_WAREHOUSE, &"warehouse", "Warehouse route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_DEVELOPER_QUICK_START, &"developer_quick_start", "Developer Quick Start route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_SETTINGS, &"settings", "Settings route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_QUIT, &"quit", "Quit route ID is stable", failures)

func _test_no_profile_has_only_first_launch_actions(failures: Array[String]) -> void:
	var projection := MainMenuViewModel.build(null, PartyForgeSettings.new(), true)
	TestAssertions.equal(projection.primary_label, "Play", "first launch labels the main action Play", failures)
	TestAssertions.equal(projection.primary_route_id, &"profiles", "first launch Play routes to Profiles", failures)
	TestAssertions.truthy(projection.primary_visible and projection.primary_enabled, "first launch Play is actionable", failures)
	TestAssertions.equal(projection.active_profile_text, "No active profile", "first launch explains that no profile is active", failures)
	TestAssertions.equal(projection.status_text, "Create or choose a profile to play.", "first launch status is player-facing", failures)
	TestAssertions.truthy(not projection.city_tree_visible and not projection.developer_quick_start_visible, "first launch hides returning and developer actions", failures)
	TestAssertions.equal(_visible_action_count(projection), 3, "first launch exposes exactly Play, Settings, and Quit", failures)
	_assert_common_actions(projection, failures)

func _test_every_prologue_state_selects_its_route(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.NOT_STARTED)
	var settings := PartyForgeSettings.new()
	var not_started := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.equal(not_started.primary_label, "Play", "not-started profile labels the main action Play", failures)
	TestAssertions.equal(not_started.primary_route_id, &"prologue_start", "not-started profile uses the replaceable prologue-start seam", failures)

	profile.prologue_state = ProfileState.PrologueState.IN_PROGRESS
	var in_progress := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.equal(in_progress.primary_label, "Continue", "in-progress profile labels the main action Continue", failures)
	TestAssertions.equal(in_progress.primary_route_id, &"prologue_resume", "in-progress profile uses the replaceable prologue-resume seam", failures)

	profile.prologue_state = ProfileState.PrologueState.COMPLETED
	var completed := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.equal(completed.primary_label, "Begin Run", "completed profile labels the main action Begin Run", failures)
	TestAssertions.equal(completed.primary_route_id, &"run_setup", "completed profile routes to current run setup", failures)
	TestAssertions.equal(completed.active_profile_text, "Active Profile: Menu Tester", "active profile text uses the supplied display name", failures)
	TestAssertions.truthy(not completed.city_tree_visible, "completed profile without discovery does not see City services", failures)

func _test_recovery_overrides_every_profile_progress_route(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	for prologue_state: ProfileState.PrologueState in [
		ProfileState.PrologueState.NOT_STARTED,
		ProfileState.PrologueState.IN_PROGRESS,
		ProfileState.PrologueState.COMPLETED,
	]:
		var profile := _profile(prologue_state)
		profile.resumable_run = {"malformed_but_nonempty": true}
		var projection := MainMenuViewModel.build(profile, settings, true)
		TestAssertions.equal(projection.primary_label, "Resume Run", "recovery overrides normal play label for state %d" % prologue_state, failures)
		TestAssertions.equal(projection.primary_route_id, &"run_recovery", "recovery uses explicit route for state %d" % prologue_state, failures)
		TestAssertions.equal(projection.status_text, "An interrupted run is ready to recover.", "recovery explains the route for state %d" % prologue_state, failures)


func _test_recovery_status_precedes_unavailable_city_status(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	profile.resumable_run = {"malformed_but_nonempty": true}
	profile.discovered_trees.append(CITY_TREE_ID)
	var projection := MainMenuViewModel.build(profile, PartyForgeSettings.new(), false)
	TestAssertions.truthy(projection.city_tree_visible and not projection.city_tree_enabled, "recovery fixture retains unavailable City projection", failures)
	TestAssertions.equal(projection.primary_route_id, MainMenuViewModel.ROUTE_RUN_RECOVERY, "recovery remains the primary route while City is unavailable", failures)
	TestAssertions.equal(projection.status_text, "An interrupted run is ready to recover.", "recovery status takes precedence over unavailable City status", failures)

func _test_completed_discovery_exposes_city_tree(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	profile.discovered_trees.append(CITY_TREE_ID)
	var projection := MainMenuViewModel.build(profile, PartyForgeSettings.new(), true)
	TestAssertions.equal(projection.city_tree_label, "City Passive Tree", "durably discovered City tree has a player label", failures)
	TestAssertions.equal(projection.city_tree_route_id, &"city_tree", "durably discovered City tree uses its stable route", failures)
	TestAssertions.truthy(projection.city_tree_visible and projection.city_tree_enabled, "completed discovery exposes available City tree", failures)
	TestAssertions.truthy(not projection.developer_quick_start_visible, "Player Mode never exposes Developer Quick Start", failures)

	profile.prologue_state = ProfileState.PrologueState.IN_PROGRESS
	var incomplete := MainMenuViewModel.build(profile, PartyForgeSettings.new(), true)
	TestAssertions.truthy(not incomplete.city_tree_visible, "durable discovery alone cannot expose City tree before completion", failures)

func _test_player_mode_ignores_developer_overrides(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	settings.unlock_all_implemented_content = true
	settings.reduced_motion = true
	var projection := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.truthy(not projection.city_tree_visible, "Player Mode unlock-all does not masquerade as City discovery", failures)
	TestAssertions.truthy(not projection.developer_quick_start_visible, "Player Mode unlock-all does not expose Quick Start", failures)
	TestAssertions.truthy(not projection.armoury_visible and not projection.warehouse_visible, "Player Mode unlock-all never exposes hidden storage interfaces", failures)
	TestAssertions.truthy(projection.reduced_motion, "valid reduced-motion setting reaches the value projection", failures)

func _test_developer_mode_exposes_nonpersistent_tools(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.IN_PROGRESS)
	var before := profile.to_dictionary()
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	var projection := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.equal(projection.primary_label, "Continue", "Developer Mode preserves the profile-state main action", failures)
	TestAssertions.equal(projection.primary_route_id, &"prologue_resume", "Developer Mode preserves the profile-state route", failures)
	TestAssertions.equal(projection.city_tree_label, "Developer City Preview", "developer City access is clearly labeled as a preview", failures)
	TestAssertions.truthy(projection.city_tree_visible and projection.city_tree_enabled, "Developer Mode exposes available City preview", failures)
	TestAssertions.equal(projection.developer_quick_start_label, "Developer Quick Start", "developer quick action is clearly labeled", failures)
	TestAssertions.equal(projection.developer_quick_start_route_id, &"developer_quick_start", "developer quick action uses its stable route", failures)
	TestAssertions.truthy(projection.developer_quick_start_visible and projection.developer_quick_start_enabled, "Developer Mode with an active profile exposes Quick Start", failures)
	TestAssertions.equal(profile.to_dictionary(), before, "Developer overrides never mutate durable profile discovery or progression", failures)

func _test_unavailable_city_tree_fails_closed(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	profile.discovered_trees.append(CITY_TREE_ID)
	var player := MainMenuViewModel.build(profile, PartyForgeSettings.new(), false)
	TestAssertions.truthy(player.city_tree_visible and not player.city_tree_enabled, "eligible City service stays visible but cannot route without tree data", failures)
	TestAssertions.equal(player.status_text, "City services are temporarily unavailable.", "unavailable tree data uses nontechnical status text", failures)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	var developer := MainMenuViewModel.build(profile, developer_settings, false)
	TestAssertions.truthy(developer.city_tree_visible and not developer.city_tree_enabled, "Developer preview cannot route without tree data", failures)
	TestAssertions.truthy(developer.developer_quick_start_enabled, "tree availability does not disable Developer Quick Start", failures)

func _test_malformed_inputs_return_a_safe_projection(failures: Array[String]) -> void:
	var invalid_profile := _profile(ProfileState.PrologueState.COMPLETED)
	invalid_profile.profile_id = ""
	invalid_profile.discovered_trees.append(CITY_TREE_ID)
	var invalid_settings := PartyForgeSettings.new()
	invalid_settings.mode = 99
	invalid_settings.unlock_all_implemented_content = true
	invalid_settings.reduced_motion = true
	var malformed := MainMenuViewModel.build(invalid_profile, invalid_settings, "available")
	TestAssertions.equal(malformed.primary_route_id, &"profiles", "malformed profile fails closed to profile selection", failures)
	TestAssertions.truthy(not malformed.city_tree_visible and not malformed.developer_quick_start_visible, "malformed inputs do not grant routes", failures)
	TestAssertions.truthy(not malformed.reduced_motion, "malformed settings fail closed to safe defaults", failures)
	_assert_common_actions(malformed, failures)

	var wrong_types := MainMenuViewModel.build(RefCounted.new(), RefCounted.new(), null)
	TestAssertions.equal(wrong_types.primary_route_id, &"profiles", "wrong input types return a safe first-launch projection", failures)
	TestAssertions.equal(_visible_action_count(wrong_types), 3, "wrong input types expose only safe first-launch actions", failures)

func _test_projection_is_copy_owned_and_value_only(failures: Array[String]) -> void:
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	profile.discovered_trees.append(CITY_TREE_ID)
	var settings := PartyForgeSettings.new()
	settings.reduced_motion = true
	var projection := MainMenuViewModel.build(profile, settings, true)
	profile.display_name = "Changed Later"
	profile.discovered_trees.clear()
	settings.reduced_motion = false
	TestAssertions.equal(projection.active_profile_text, "Active Profile: Menu Tester", "projection owns profile display values", failures)
	TestAssertions.truthy(projection.city_tree_visible and projection.reduced_motion, "projection is unaffected by later input mutation", failures)

	var copied := projection.copy()
	copied.primary_label = "Changed Copy"
	copied.city_tree_visible = false
	TestAssertions.equal(projection.primary_label, "Begin Run", "projection copy owns action labels", failures)
	TestAssertions.truthy(projection.city_tree_visible, "projection copy owns visibility flags", failures)

func _profile(prologue_state: ProfileState.PrologueState) -> ProfileState:
	var profile := ProfileState.new_profile("profile-menu-1234", "Menu Tester", 1000)
	profile.prologue_state = prologue_state
	return profile

func _view_model_source() -> String:
	var file := FileAccess.open("res://scripts/ui/main_menu/main_menu_view_model.gd", FileAccess.READ)
	return file.get_as_text() if file != null else ""

func _test_armoury_and_warehouse_feature_access(failures: Array[String]) -> void:
	var settings := PartyForgeSettings.new()
	var profile := _profile(ProfileState.PrologueState.COMPLETED)
	var locked := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.truthy(not locked.armoury_visible and not locked.warehouse_visible, "player mode hides locked storage routes", failures)
	profile.permanent_feature_unlocks = ["equipment_inventory"]
	var equipment := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.truthy(equipment.armoury_visible and equipment.armoury_enabled, "equipment unlock exposes Armoury", failures)
	TestAssertions.truthy(not equipment.warehouse_visible, "equipment unlock does not expose Warehouse", failures)
	profile.permanent_feature_unlocks.append("stash")
	var stash := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.truthy(stash.warehouse_visible and stash.warehouse_enabled, "stash unlock exposes Warehouse", failures)
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	profile.permanent_feature_unlocks.clear()
	var preview := MainMenuViewModel.build(profile, settings, true)
	TestAssertions.truthy(preview.armoury_visible and preview.armoury_enabled and preview.armoury_label.contains("Developer"), "Developer Mode exposes Armoury preview without persistence mutation", failures)
	TestAssertions.truthy(preview.warehouse_visible and preview.warehouse_enabled and preview.warehouse_label.contains("Developer"), "Developer Mode exposes Warehouse preview without persistence mutation", failures)

func _assert_common_actions(projection: MainMenuProjection, failures: Array[String]) -> void:
	TestAssertions.equal(projection.settings_label, "Settings", "Settings label is stable", failures)
	TestAssertions.equal(projection.settings_route_id, &"settings", "Settings route is stable", failures)
	TestAssertions.truthy(projection.settings_visible and projection.settings_enabled, "Settings is always actionable", failures)
	TestAssertions.equal(projection.quit_label, "Quit", "Quit label is stable", failures)
	TestAssertions.equal(projection.quit_route_id, &"quit", "Quit route is stable", failures)
	TestAssertions.truthy(projection.quit_visible and projection.quit_enabled, "Quit is always actionable", failures)

func _visible_action_count(projection: MainMenuProjection) -> int:
	return int(projection.primary_visible) \
		+ int(projection.city_tree_visible) \
		+ int(projection.developer_quick_start_visible) \
		+ int(projection.settings_visible) \
		+ int(projection.quit_visible)
