extends RefCounted

const CITY_TREE_ID := "party-forge-city-v1"

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_route_ids_are_stable(failures)
	_test_no_profile_has_only_first_launch_actions(failures)
	_test_every_prologue_state_selects_its_route(failures)
	_test_completed_discovery_exposes_city_tree(failures)
	_test_player_mode_ignores_developer_overrides(failures)
	_test_developer_mode_exposes_nonpersistent_tools(failures)
	_test_unavailable_city_tree_fails_closed(failures)
	_test_malformed_inputs_return_a_safe_projection(failures)
	_test_projection_is_copy_owned_and_value_only(failures)
	return failures

func _test_route_ids_are_stable(failures: Array[String]) -> void:
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROFILES, &"profiles", "Profiles route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROLOGUE_START, &"prologue_start", "prologue-start route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_PROLOGUE_RESUME, &"prologue_resume", "prologue-resume route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_RUN_SETUP, &"run_setup", "run-setup route ID is stable", failures)
	TestAssertions.equal(MainMenuViewModel.ROUTE_CITY_TREE, &"city_tree", "City-tree route ID is stable", failures)
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
