extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var profile_root := "user://tests/profile_boot_main_flow_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(profile_root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = profile_root
	root.add_child(main)
	await process_frame
	await process_frame

	var manager := main.profile_manager
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	_assert(manager != null, "main owns ProfileManager")
	_assert(manager.profiles().is_empty(), "fresh boot has no profiles")
	_assert(main.active_profile() == null, "fresh boot has no active profile")
	_assert(settings.is_open(), "fresh boot opens Settings")
	_assert(tabs.get_tab_control(tabs.current_tab) == profiles, "fresh boot selects Profiles")
	_assert(profiles.initial_focus() == profile_name, "fresh Profiles target is ProfileName")
	_assert(root.gui_get_focus_owner() == profile_name, "fresh boot focuses ProfileName")

	profile_name.text = "Integration Profile"
	(profiles.get_node("Layout/CreateRow/Create") as Button).pressed.emit()
	await process_frame
	await process_frame
	var active := main.active_profile()
	var active_id := active.profile_id if active != null else ""
	_assert(active != null and active.display_name == "Integration Profile", "Profiles UI creates and selects the main active profile")
	_assert(manager.profiles().size() == 1, "Profiles UI persists one profile in the main manager")
	_assert(manager.active_profile() != null and manager.active_profile().profile_id == active_id, "manager selection matches main active profile")
	var reloaded := ProfileManager.new()
	_assert(reloaded.bootstrap(profile_root).is_empty(), "profile root reloads without diagnostics")
	var persisted := reloaded.active_profile()
	_assert(persisted != null and persisted.profile_id == active_id, "active profile selection persists to disk")

	settings.close()
	await process_frame
	var settings_control := main.get_node("HUD/ClassSelection/Content/Actions/Settings") as Control
	_assert(root.gui_get_focus_owner() == settings_control, "closing Profiles restores class-selection Settings focus")
	var fighter := main.get_node("HUD/ClassSelection/Content/Scroll/Grid/Class_fighter") as Button
	fighter.pressed.emit()
	await process_frame
	var party := main.get_node("PartyManager") as PartyManager
	var game_run := main.get_node("GameRun") as GameRun
	_assert(main.run_started, "Fighter button starts the run")
	_assert(main.leader != null and main.leader.get_parent() == main.get_node("Actors"), "Fighter launch creates the arena leader")
	_assert(party.members.size() == 1 and party.members[0].class_definition.id == &"fighter", "Fighter launch initializes the party")
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING, "Fighter launch begins the arena flow")
	_assert(not (main.get_node("HUD/ClassSelection") as Control).visible, "arena flow closes class selection")

	paused = false
	main.free()
	ProfileTestSupport.remove_tree(profile_root)
	if _failures.is_empty():
		print("PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROFILE_BOOT_MAIN_FLOW_FAILURE: %s" % failure)
	print("PROFILE_BOOT_MAIN_FLOW_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
