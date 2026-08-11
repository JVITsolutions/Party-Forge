extends SceneTree

const PROFILE_ROOT := "user://tests/live_loot_lifecycle_profiles"
const SETTINGS_PATH := "user://tests/live_loot_lifecycle_settings.cfg"

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	for exit_path: StringName in [&"victory", &"defeat", &"restart", &"front_end", &"aborted_startup"]:
		_verify_exit_path(exit_path)
		paused = false
	var subsequent := _started_main("subsequent")
	if subsequent != null:
		_assert((subsequent.get("ground_item_registry") as GroundItemRegistry).all_records().is_empty(), "subsequent run starts with zero ground records")
		_assert(_active_chest_count(subsequent) == 0, "subsequent run starts with zero projected chests")
		_assert(_diagnostics_text(subsequent) == _zero_diagnostics_text(), "subsequent run immediately presents fresh zero diagnostics after prior activity")
		_cleanup_main(subsequent)
	ProfileTestSupport.remove_tree(PROFILE_ROOT)
	_cleanup_settings()
	_finish()

func _verify_exit_path(exit_path: StringName) -> void:
	var main := _started_main(String(exit_path))
	if main == null:
		return
	var registry := main.get("ground_item_registry") as GroundItemRegistry
	var controller := main.get("ground_item_world_controller") as Node
	_assert(registry != null and controller != null, "%s constructs one registry and world controller" % exit_path)
	if registry == null or controller == null:
		_cleanup_main(main)
		return
	var event := EnemyDefeatEvent.create(1337, 700 + int(exit_path.length()), 700 + int(exit_path.length()), &"swarmer", &"ordinary_melee", (main.get("leader") as PartyActor).position, 30.0)
	var report := (main.get("personal_loot_drop_coordinator") as PersonalLootDropCoordinator).resolve_defeat(event)
	main.call("_record_personal_loot_report", report)
	_assert(registry.all_records().size() == 1, "%s fixture creates one authoritative ground record" % exit_path)
	_assert(_active_chest_count(main) == 1, "%s fixture projects one live chest" % exit_path)
	controller.status_changed.emit("GROUND_ITEM_PICKUP_INVENTORY_FULL")
	var badge := main.get_node("DeveloperModeBadge") as DeveloperModeBadge
	_assert(String(badge.call("diagnostics_text")).contains("LIVE 1 | PEAK 1"), "%s diagnostics observe live and peak counts" % exit_path)
	_assert(String(badge.call("diagnostics_text")).contains("COLLECTION inventory_full=1"), "%s diagnostics observe collection outcomes" % exit_path)
	match exit_path:
		&"victory": main.call("_show_victory")
		&"defeat": main.call("_show_defeat")
		&"restart": main.call("_restart")
		&"front_end": main.call("_return_to_front_end")
		&"aborted_startup": main.call("_abort_run_start", PackedStringArray())
	_assert(registry.all_records().is_empty(), "%s clears all authoritative ground records" % exit_path)
	_assert(_active_chest_count(main) == 0, "%s destroys every projected chest" % exit_path)
	_assert(main.get("ground_item_registry") == null and main.get("personal_loot_drop_coordinator") == null and main.get("personal_loot_roll_service") == null, "%s releases the live personal-loot graph" % exit_path)
	_assert(controller.get("_registry") == null, "%s disconnects controller registry signals" % exit_path)
	_assert(String(badge.call("diagnostics_text")).is_empty(), "%s clears session-only diagnostics" % exit_path)
	_cleanup_main(main)

func _started_main(suffix: String) -> PartyForgeMain:
	var settings := PartyForgeSettings.new()
	settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	settings.unlock_all_implemented_content = true
	settings.set("force_personal_drops", true)
	settings.set("personal_drop_source_category_override", &"ordinary_specialist")
	settings.set("personal_drop_item_level_override", 777)
	settings.set("show_ground_chest_diagnostics", true)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = PROFILE_ROOT.path_join(suffix)
	main.settings_path = SETTINGS_PATH
	root.add_child(main)
	var manager := main.profile_manager as ProfileManager
	if manager.active_profile() == null:
		manager.create_profile("Lifecycle %s" % suffix)
	main.saved_settings = settings.copy()
	if not main.select_leader_class(&"fighter"):
		_assert(false, "%s run starts" % suffix)
		main.free()
		return null
	_assert(_diagnostics_text(main) == _zero_diagnostics_text(), "%s run immediately presents complete zero diagnostics" % suffix)
	var roll := main.personal_loot_roll_service as PersonalLootRollService
	var decision := roll.resolve(EnemyDefeatEvent.create(1337, 600, 600, &"swarmer", &"ordinary_melee", main.leader.position, 30.0))[0] as PersonalLootDecision
	_assert(decision.success and decision.source_category == &"ordinary_specialist" and decision.item_level == 777, "%s applies deterministic source and item-level overrides only through the immutable Developer snapshot" % suffix)
	return main

func _active_chest_count(main: Node) -> int:
	var controller := main.get_node("GroundItemWorldController") as Node
	return (controller.get("_chest_by_drop") as Dictionary).size()

func _diagnostics_text(main: Node) -> String:
	return String((main.get_node("DeveloperModeBadge") as DeveloperModeBadge).diagnostics_text())

func _zero_diagnostics_text() -> String:
	return "SESSION LOOT DIAGNOSTICS\nLIVE 0 | PEAK 0\nROLL SUCCESS none\nROLL MISS none\nGENERATION FAILURES 0\nDIAGNOSTIC STAGES none\nDIAGNOSTIC CODES none\nCOLLECTION none"

func _cleanup_main(main: Node) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.free()

func _cleanup_settings() -> void:
	for path: String in [SETTINGS_PATH, "%s.tmp" % SETTINGS_PATH, "%s.bak" % SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	if _failures.is_empty():
		print("LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVE_LOOT_LIFECYCLE_INTEGRATION: %s" % failure)
	quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
