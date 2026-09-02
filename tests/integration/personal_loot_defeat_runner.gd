extends SceneTree

const PROFILE_ROOT := "user://tests/personal_loot_defeat_profiles"
const SETTINGS_PATH := "user://tests/personal_loot_defeat_settings.cfg"

var _failures: Array[String] = []
var _xp_failures := 0
var _guardian_failures := 0

func _initialize() -> void:
	if "--check-only" in OS.get_cmdline_args():
		quit(0)
		return
	call_deferred(&"_run")

func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	if not _runtime_terminal_contract_available():
		ProfileTestSupport.remove_tree(PROFILE_ROOT)
		_cleanup_settings()
		_finish()
		return
	var player := await _started_main(PartyForgeSettings.new())
	await _verify_enemy_defeat(player, false)
	_cleanup_main(player)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)

	var unlocked_player := await _started_main(PartyForgeSettings.new(), true)
	await _verify_enemy_defeat(unlocked_player, true)
	_cleanup_main(unlocked_player)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	var developer := await _started_main(developer_settings)
	var developer_profile_id: String = developer.active_profile().profile_id
	var developer_before := ProfileStore.new().load_profile(developer_profile_id, PROFILE_ROOT).profile
	await _verify_enemy_defeat(developer, true)
	var developer_after := ProfileStore.new().load_profile(developer_profile_id, PROFILE_ROOT).profile
	_assert(developer_before.permanent_feature_unlocks == developer_after.permanent_feature_unlocks, "Developer Unlock All drop adds no durable feature unlock")
	_assert(developer_before.inventory_columns == developer_after.inventory_columns, "Developer Unlock All temporary capacity adds no durable inventory column")
	await _verify_guardian_victory_and_zero_reward(developer)
	_cleanup_main(developer)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_finish()

func _verify_enemy_defeat(main: Node, expect_drop: bool) -> void:
	var director := main.get_node("SpawnDirector") as SpawnDirector
	var roll := main.get("personal_loot_roll_service") as PersonalLootRollService
	var registry := main.get("ground_item_registry") as GroundItemRegistry
	var profile_before := main.active_profile() as ProfileState
	var gold_before := profile_before.gold
	var passive_points_available_before := profile_before.passive_points_available
	var passive_points_lifetime_before := profile_before.passive_points_lifetime_earned
	_assert(roll != null and registry != null, "run creates the live personal-loot service graph")
	if roll == null or registry == null:
		return
	roll.loot_tuning.drop_basis_points[&"ordinary_melee"] = 10000
	var marker := Marker3D.new()
	marker.position = main.leader.position
	main.get_node("Arena").add_child(marker)
	director.spawn_markers = [marker]
	director.camera = null
	var orb_count_before := _experience_orb_count(main.get_node("Effects"))
	var enemy := director.spawn_enemy(&"swarmer") as EnemyActor
	_assert(enemy != null, "director spawns the real enemy fixture")
	if enemy == null:
		return
	enemy.position = main.leader.position
	enemy.defeat()
	enemy.defeat()
	_assert(_experience_orb_count(main.get_node("Effects")) == orb_count_before + 1, "repeated defeat preserves exactly one XP reward")
	_assert(registry.all_records().size() == (1 if expect_drop else 0), "feature access produces the expected owner-scoped ground record")
	var profile_after := main.active_profile() as ProfileState
	_assert(profile_after.gold == gold_before, "ordinary enemy item gating leaves profile gold unchanged")
	_assert(profile_after.passive_points_available == passive_points_available_before and profile_after.passive_points_lifetime_earned == passive_points_lifetime_before, "ordinary enemy item gating leaves passive-point rewards unchanged")
	if expect_drop:
		var before_terminal := registry.all_records().size()
		main.call(&"_show_defeat")
		await process_frame
		_assert(registry.all_records().size() == before_terminal, "defeat terminal capture retains live loot while extraction is pending")
		_assert(_active_chest_count(main) == before_terminal, "defeat terminal capture retains projected loot while extraction is pending")
		var flow: Variant = main.get("_terminal_flow")
		_assert(flow != null and int(flow.call(&"state")) == RunTerminalFlow.State.CHOOSING_EXTRACTION, "defeat terminal capture enters typed extraction choice")
	else:
		_assert(_active_chest_count(main) == 0, "feature-locked Player defeat projects no ground chest")
		var diagnostics := main.get("_ground_chest_diagnostics") as Dictionary
		var ineligible_reasons := diagnostics.get("ineligible_by_reason", {}) as Dictionary
		_assert(int(ineligible_reasons.get("feature_locked", 0)) == 1, "feature-locked Player defeat records the stable production diagnostic exactly once")

func _verify_guardian_victory_and_zero_reward(main: Node) -> void:
	var coordinator := main.get("personal_loot_drop_coordinator") as PersonalLootDropCoordinator
	var registry := main.get("ground_item_registry") as GroundItemRegistry
	_assert(coordinator != null and registry != null, "Guardian regression uses the configured coordinator")
	if coordinator == null or registry == null:
		return
	var before := registry.all_records().size()
	coordinator.resolve_defeat(EnemyDefeatEvent.create(1337, 2, 2, &"forge_guardian", &"boss", main.leader.position, 300.0))
	_assert(registry.all_records().size() == before, "zero boss basis points suppress the Guardian chest")
	var game_run := main.get_node("GameRun") as GameRun
	var victories: Array[int] = [0]
	game_run.victory.connect(func() -> void: victories[0] += 1)
	game_run.advance_run_time(300.0)
	var guardian := main.get("boss") as ForgeGuardian
	_assert(guardian != null, "boss phase spawns the Forge Guardian")
	if guardian != null:
		guardian.defeat()
		guardian.defeat()
	_assert(victories[0] == 1 and game_run.current_state() == RunStateMachine.State.VICTORY, "existing Guardian signal reaches exactly one victory")
	var live_after_victory := registry.all_records().size()
	_guardian_assert(live_after_victory > 0, "Guardian victory creates no zero-chance boss reward but retains prior run-owned loot")
	_guardian_assert(_active_chest_count(main) == live_after_victory, "Guardian victory retains every projected prior loot chest until accepted recap")
	var flow: Variant = main.get("_terminal_flow")
	_guardian_assert(flow != null and int(flow.call(&"state")) == RunTerminalFlow.State.CHOOSING_EXTRACTION, "Guardian victory enters the typed extraction choice before cleanup")
	var extraction := main.get_node_or_null("HUD/TerminalExtraction") as TerminalExtractionPanel
	if flow != null and extraction != null:
		extraction.confirm_requested.emit()
		var finalized := await _wait_for_terminal_state(flow, RunTerminalFlow.State.FINALIZED)
		_guardian_assert(finalized, "Guardian extraction confirmation reaches one accepted durable recap")
		_guardian_assert(registry.all_records().is_empty(), "Guardian accepted durable recap clears prior run-owned loot exactly once")

func _wait_for_terminal_state(flow: Variant, expected_state: int, maximum_frames: int = 120) -> bool:
	for _frame: int in maximum_frames:
		if flow != null and int(flow.call(&"state")) == expected_state:
			return true
		await process_frame
	return flow != null and int(flow.call(&"state")) == expected_state

func _started_main(settings: PartyForgeSettings, grant_player_item_access: bool = false) -> Node:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as Node
	main.profile_root = PROFILE_ROOT
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	await process_frame
	var manager := main.profile_manager as ProfileManager
	if manager.active_profile() == null:
		manager.create_profile("Personal Loot Integration")
	if grant_player_item_access:
		var profile := manager.active_profile()
		profile.permanent_feature_unlocks = ["equipment_inventory", "inventory"]
		profile.inventory_columns = 1
		_assert(ProfileStore.new().save_profile(profile, PROFILE_ROOT).is_empty(), "unlocked Player fixture persists both item features and one inventory column")
		_assert(manager.refresh_profile(profile.profile_id).is_empty(), "unlocked Player fixture refreshes the authoritative profile")
	main.saved_settings = settings.copy()
	_assert(main.select_leader_class(&"fighter"), "configured profile starts the arena run")
	return main

func _experience_orb_count(parent: Node) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child.scene_file_path == "res://scenes/progression/experience_orb.tscn":
			count += 1
	return count

func _active_chest_count(main: Node) -> int:
	var controller := main.get("ground_item_world_controller") as Node
	return int((controller.get("_chest_by_drop") as Dictionary).size()) if controller != null else -1

func _runtime_terminal_contract_available() -> bool:
	# Narrow RED guard for a half-applied Main binding: avoid turning an
	# expected Task12 failure into parser/leak noise before runtime can load.
	var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	for method_name: String in [
		"func _on_terminal(", "func _on_terminal_extraction_confirmed(",
		"func _on_terminal_resolution_accepted(",
	]:
		if not main_source.contains(method_name):
			_guardian_assert(false, "Task12 terminal Main binding includes %s" % method_name)
			return false
	var packed := load("res://scenes/game/main.tscn") as PackedScene
	if packed == null:
		_guardian_assert(false, "Task12 terminal runtime scene loads")
		return false
	var main := packed.instantiate() as Node
	if main == null:
		_guardian_assert(false, "Task12 terminal runtime Main instantiates")
		return false
	var available := true
	for method_name: StringName in [&"_on_terminal", &"_on_terminal_extraction_confirmed", &"_on_terminal_resolution_accepted"]:
		if not main.has_method(method_name):
			_guardian_assert(false, "Task12 terminal runtime exposes %s" % method_name)
			available = false
	main.free()
	return available

func _cleanup_main(main: Node) -> void:
	paused = false
	if main != null:
		main.free()

func _cleanup_settings() -> void:
	for path: String in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH, "%s.bak" % SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	if _failures.is_empty():
		print("PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS")
		print("PERSONAL_LOOT_XP_REGRESSION: PASS")
		print("FORGE_GUARDIAN_VICTORY_REGRESSION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PERSONAL_LOOT_DEFEAT_INTEGRATION: %s" % failure)
	print("PERSONAL_LOOT_DEFEAT_INTEGRATION: FAIL (%d failures)" % _failures.size())
	if _xp_failures > 0:
		print("PERSONAL_LOOT_XP_REGRESSION: FAIL (%d failures)" % _xp_failures)
	if _guardian_failures > 0:
		print("FORGE_GUARDIAN_VICTORY_REGRESSION: FAIL (%d failures)" % _guardian_failures)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _guardian_assert(condition: bool, message: String) -> void:
	if not condition:
		_guardian_failures += 1
		_failures.append(message)
