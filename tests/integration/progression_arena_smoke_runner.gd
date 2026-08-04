extends SceneTree

var _failures: Array[String] = []
var _test_root := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var appdata := OS.get_environment("APPDATA")
	var localappdata := OS.get_environment("LOCALAPPDATA")
	_assert(not appdata.is_empty(), "caller supplies isolated APPDATA")
	_assert(not localappdata.is_empty(), "caller supplies isolated LOCALAPPDATA")

	_test_root = "user://tests/plan4a_task9_arena_smoke_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile_root := _test_root.path_join("profiles")
	var settings_path := _test_root.path_join("settings/settings.json")
	ProfileTestSupport.remove_tree(_test_root)

	var profile_id := "profile-plan4a-task9-smoke"
	var setup_manager := ProfileManager.new(
		ProfileStore.new(),
		ProfileIndexStore.new(),
		func() -> String: return profile_id,
	)
	_assert(setup_manager.bootstrap(profile_root).is_empty(), "ProfileManager bootstraps isolated profile root")
	var creation := setup_manager.create_profile("Plan 4A Arena Smoke", 1000)
	_assert(creation.ok(), "ProfileManager creates the smoke profile")
	_assert(setup_manager.select_profile(profile_id).is_empty(), "ProfileManager explicitly selects the smoke profile")
	var before_profile := setup_manager.active_profile()
	var profile_path := ProfileStore.new().profile_path(profile_id, profile_root)
	var before_bytes := FileAccess.get_file_as_bytes(profile_path)
	var before_hash := _sha256(before_bytes)
	_assert(before_profile != null, "selected profile is available before run")
	_assert(not before_bytes.is_empty(), "profile bytes exist before run")

	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = profile_root
	main.settings_path = settings_path
	root.add_child(main)
	await process_frame
	await process_frame
	_assert(main.active_profile() != null and main.active_profile().profile_id == profile_id, "production main loads the selected profile")
	_assert(main.select_leader_class(&"fighter"), "production select_leader_class starts Fighter")
	await process_frame

	var contexts := main.run_context_registry.all_contexts() if main.run_context_registry != null else []
	_assert(contexts.size() == 1, "production Arena registers one context")
	_assert(main.run_context_registry != null and main.run_context_registry.is_arena_roster_locked(), "production Arena locks its context registry")
	_assert(main.active_run_context != null and main.party_manager == main.active_run_context.party, "compatibility PartyManager is the active context party")
	var leader_member_id := main.party_manager.members[0].member_id if main.party_manager != null and not main.party_manager.members.is_empty() else 0
	_assert(main.leader != null and main.active_run_context.actor_for(leader_member_id) == main.leader, "production leader actor is bound to the active context")
	_assert(main.active_run_context.member_is_available(leader_member_id), "production leader actor is available")

	var orb := (load("res://scenes/progression/experience_orb.tscn") as PackedScene).instantiate() as ExperienceOrb
	main.get_node("Actors").add_child(orb)
	orb.configure(20, &"xp_task9_arena_smoke", main.leader, main.reward_distribution_service, 1.0)
	orb.global_position = main.leader.global_position
	orb.advance_collection(0.016)
	var state := main.active_run_context.progression_for(leader_member_id)
	_assert(orb.collected, "production-configured orb collects once")
	_assert(state != null and state.level == 2, "production-configured orb advances the active leader")
	_assert(main.active_run_context.pending_leader_levels() == [2], "exactly one leader upgrade is pending")
	var level_panel := main.get_node("HUD/LevelUpPanel") as LevelUpPanel
	_assert(main.game_run.current_state() == RunStateMachine.State.LEVEL_UP, "level-up presentation enters the level-up run state")
	_assert(level_panel.visible and level_panel.choices.size() > 0, "level-up panel presents production choices")

	main.hud.call("_refresh_status")
	var xp_bar := main.get_node("HUD/Margin/Status/Experience") as ProgressBar
	_assert(is_equal_approx(xp_bar.value, float(state.experience)), "HUD XP value matches active leader state")
	_assert(is_equal_approx(xp_bar.max_value, float(state.experience_required)), "HUD XP maximum matches active leader requirement")

	var ledger := main.character_ledger
	_assert(ledger.open_for_player(), "production ledger opens during level-up")
	ledger.refresh()
	var leader_row: Dictionary = {}
	for row: Dictionary in ledger.provider.member_rows():
		if int(row.get("member_id", 0)) == leader_member_id:
			leader_row = row
			break
	_assert(int(leader_row.get("character_level", 0)) == state.level, "ledger shows the leader's new level")
	var strength_detail := ledger.provider.stat_detail(leader_member_id, &"strength")
	var has_growth_source := Array(strength_detail.get("sources", [])).any(
		func(source: Dictionary) -> bool: return String(source.get("source_label", "")) == "Class Growth"
	)
	_assert(has_growth_source, "ledger shows the resolver-backed Class Growth source")
	var stats_page := ledger.get_node("Overlay/Frame/Layout/Body/PageHost/StatsLedgerPage") as StatsLedgerPage
	_assert(stats_page.select_stat(&"strength"), "ledger can select the grown Strength row")
	var identity := stats_page.get_node("Layout/Header/Identity") as Label
	_assert("Level 2" in identity.text, "visible ledger header shows Level 2")

	if ledger.is_open():
		ledger.close()
	paused = false
	var reloaded := ProfileManager.new()
	_assert(reloaded.bootstrap(profile_root).is_empty(), "profile reload completes without diagnostics")
	var after_profile := reloaded.active_profile()
	var after_bytes := FileAccess.get_file_as_bytes(profile_path)
	var after_hash := _sha256(after_bytes)
	var values_equal := before_profile != null and after_profile != null and before_profile.to_dictionary() == after_profile.to_dictionary()
	var bytes_equal := before_bytes == after_bytes
	_assert(values_equal, "profile values remain unchanged by run progression")
	_assert(bytes_equal, "profile bytes remain unchanged by run progression")
	_assert(before_hash == after_hash, "profile SHA-256 remains unchanged by run progression")
	print(
		"PROGRESSION_ARENA_PROFILE_IMMUTABLE profile=%s sha256_before=%s sha256_after=%s values_equal=%s bytes_equal=%s" % [
			profile_id, before_hash, after_hash, values_equal, bytes_equal,
		]
	)

	main.free()
	current_scene = null
	paused = false
	ProfileTestSupport.remove_tree(_test_root)
	_assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_test_root)), "runner removes only its unique profile/settings root")

	if _failures.is_empty():
		print("PROGRESSION_ARENA_SMOKE_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROGRESSION_ARENA_SMOKE_FAILURE: %s" % failure)
	print("PROGRESSION_ARENA_SMOKE_SUMMARY: FAIL failures=%d" % _failures.size())
	quit(1)


func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	hashing.update(bytes)
	return hashing.finish().hex_encode()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
