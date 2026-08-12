extends SceneTree

const PROFILE_ROOT := "user://tests/personal_loot_defeat_profiles"
const SETTINGS_PATH := "user://tests/personal_loot_defeat_settings.cfg"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	var player := await _started_main(PartyForgeSettings.new())
	_verify_enemy_defeat(player, false)
	_cleanup_main(player)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)

	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	var developer := await _started_main(developer_settings)
	_verify_enemy_defeat(developer, true)
	_verify_guardian_victory_and_zero_reward(developer)
	_cleanup_main(developer)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_finish()

func _verify_enemy_defeat(main: PartyForgeMain, expect_drop: bool) -> void:
	var director := main.get_node("SpawnDirector") as SpawnDirector
	var roll := main.get("personal_loot_roll_service") as PersonalLootRollService
	var registry := main.get("ground_item_registry") as GroundItemRegistry
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

func _verify_guardian_victory_and_zero_reward(main: PartyForgeMain) -> void:
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
	_assert(registry.all_records().is_empty(), "Guardian victory creates no zero-chance boss reward and clears prior run-owned loot")

func _started_main(settings: PartyForgeSettings) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = PROFILE_ROOT
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	await process_frame
	var manager := main.profile_manager as ProfileManager
	if manager.active_profile() == null:
		manager.create_profile("Personal Loot Integration")
	main.saved_settings = settings.copy()
	_assert(main.select_leader_class(&"fighter"), "configured profile starts the arena run")
	return main

func _experience_orb_count(parent: Node) -> int:
	var count := 0
	for child: Node in parent.get_children():
		if child.scene_file_path == "res://scenes/progression/experience_orb.tscn":
			count += 1
	return count

func _cleanup_main(main: PartyForgeMain) -> void:
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
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
