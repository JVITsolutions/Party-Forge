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
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var run_hud := main.get_node("HUD/Margin") as Control
	_assert(manager != null, "main owns ProfileManager")
	_assert(manager.profiles().is_empty(), "fresh boot has no profiles")
	_assert(main.active_profile() == null, "fresh boot has no active profile")
	_assert(menu.is_open(), "fresh boot opens the main menu")
	_assert(not settings.is_open(), "fresh boot keeps Settings closed")
	_assert(not (main.get_node("HUD/ClassSelection") as ClassSelectionPanel).is_open(), "fresh boot keeps run setup hidden")
	_assert(main.leader == null, "fresh boot has no leader")
	_assert((main.get_node("GameRun") as GameRun).current_state() == RunStateMachine.State.SETUP, "fresh boot keeps the timer stopped")
	_assert((main.get_node("GameRun") as GameRun).elapsed_time() == 0.0, "fresh boot keeps elapsed time at zero")
	var primary := menu.get_node("PrimaryAction") as Button
	_assert(root.gui_get_focus_owner() == primary, "fresh boot focuses PrimaryAction")
	primary.pressed.emit()
	await process_frame
	_assert(tabs.get_tab_control(tabs.current_tab) == profiles, "fresh boot selects Profiles")
	_assert(profiles.initial_focus() == profile_name, "fresh Profiles target is ProfileName")
	_assert(root.gui_get_focus_owner() == profile_name, "fresh boot focuses ProfileName")
	_assert(not run_hud.visible, "pre-run arena HUD remains hidden")
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	profile_name.grab_focus()
	var ready_focus_fixture := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	root.add_child(ready_focus_fixture)
	_assert(root.gui_get_focus_owner() == profile_name, "run-setup ready preserves external ProfileName focus")
	ready_focus_fixture.free()
	profile_name.grab_focus()
	selector.configure(GameCatalog.load_defaults().classes)
	_assert(root.gui_get_focus_owner() == profile_name, "run-setup configure preserves external ProfileName focus")
	selector.open()
	var initial_class_focus := selector.get_node("Content/Scroll/Grid").get_child(0) as Button
	_assert(root.gui_get_focus_owner() == initial_class_focus, "explicit run-setup open claims eligible class focus")
	profile_name.grab_focus()

	profile_name.text = "Integration Profile"
	(profiles.get_node("Layout/CreateRow/Create") as Button).pressed.emit()
	await process_frame
	await process_frame
	var active := main.active_profile()
	var active_id := active.profile_id if active != null else ""
	_assert(active != null and active.display_name == "Integration Profile", "Profiles UI creates and selects the main active profile")
	_assert(manager.profiles().size() == 1, "Profiles UI persists one profile in the main manager")
	_assert(manager.active_profile() != null and manager.active_profile().profile_id == active_id, "manager selection matches main active profile")
	_assert(menu.is_open() and not settings.is_open(), "profile creation returns to the main menu")
	_assert(menu.projection().active_profile_text == "Active Profile: Integration Profile", "profile creation refreshes menu display name")
	_assert(not main.run_started and not selector.is_open(), "profile creation never auto-starts a run")
	_assert(root.gui_get_focus_owner() == primary, "profile creation restores PrimaryAction focus")
	var reloaded := ProfileManager.new()
	_assert(reloaded.bootstrap(profile_root).is_empty(), "profile root reloads without diagnostics")
	var persisted := reloaded.active_profile()
	_assert(persisted != null and persisted.profile_id == active_id, "active profile selection persists to disk")

	settings.open_profiles(primary)
	await process_frame
	profile_name.text = "Second Profile"
	(profiles.get_node("Layout/CreateRow/Create") as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert(main.active_profile() != null and main.active_profile().display_name == "Second Profile", "second profile creation returns with the new selection")
	_assert(menu.projection().active_profile_text == "Active Profile: Second Profile", "second profile refreshes the menu projection")
	_assert(not main.run_started and not selector.is_open(), "second profile creation still never auto-starts")
	settings.open_profiles(primary)
	await process_frame
	var list := profiles.get_node("Layout/ProfileList") as ItemList
	var first_index := -1
	for index: int in range(list.item_count):
		if str(list.get_item_metadata(index)) == active_id:
			first_index = index
			break
	_assert(first_index >= 0, "original profile remains selectable")
	if first_index >= 0:
		list.select(first_index)
		(profiles.get_node("Layout/Activate") as Button).pressed.emit()
		await process_frame
		await process_frame
	_assert(main.active_profile() != null and main.active_profile().display_name == "Integration Profile", "profile switching returns with the selected display name")
	_assert(menu.projection().active_profile_text == "Active Profile: Integration Profile", "profile switching refreshes the main menu projection")
	_assert(not main.run_started and root.gui_get_focus_owner() == primary, "profile switching returns to focused menu without starting")

	var menu_settings := menu.get_node("Settings") as Button
	menu_settings.pressed.emit()
	await process_frame
	settings.close()
	await process_frame
	_assert(root.gui_get_focus_owner() == menu_settings, "menu Settings restores its exact originating control")
	var prologue_before := main.active_profile().prologue_state
	primary.pressed.emit()
	await process_frame
	_assert(selector.is_open() and not menu.is_open(), "profile primary action opens run setup")
	_assert(main.active_profile().prologue_state == prologue_before, "temporary prologue route makes no durable mutation")
	var settings_control := main.get_node("HUD/ClassSelection/Content/Actions/Settings") as Control
	settings_control.grab_focus()
	selector.settings_requested.emit()
	await process_frame
	settings.close()
	await process_frame
	_assert(root.gui_get_focus_owner() == settings_control, "run-setup Settings restores its exact originating control")
	(selector.get_node("Content/Actions/Back") as Button).pressed.emit()
	await process_frame
	_assert(menu.is_open() and not selector.is_open(), "run-setup Back returns to the main menu")
	_assert(root.gui_get_focus_owner() == primary, "run-setup Back restores PrimaryAction focus")
	primary.pressed.emit()
	await process_frame
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
	_assert(run_hud.visible, "successful arena start reveals the run HUD")

	var original_main_id := main.get_instance_id()
	current_scene = main
	(main.get_node("RunPauseMenu") as RunPauseMenu).quit_run_confirmed.emit()
	await process_frame
	await process_frame
	var reset_main := current_scene as PartyForgeMain
	_assert(reset_main != null and reset_main.get_instance_id() != original_main_id, "confirmed Quit Run reloads a fresh composition root")
	if reset_main != null:
		var reset_menu := reset_main.get_node("MainMenuScreen") as MainMenuScreen
		var reset_selector := reset_main.get_node("HUD/ClassSelection") as ClassSelectionPanel
		var reset_run := reset_main.get_node("GameRun") as GameRun
		_assert(reset_menu.is_open(), "confirmed Quit Run returns to the main menu")
		_assert(not reset_selector.is_open(), "confirmed Quit Run resets run setup hidden")
		_assert(reset_main.leader == null and not reset_main.run_started, "confirmed Quit Run resets leader and run state")
		_assert(reset_run.current_state() == RunStateMachine.State.SETUP and reset_run.elapsed_time() == 0.0, "confirmed Quit Run resets the timer")
		_assert(not (reset_main.get_node("HUD/Margin") as Control).visible, "confirmed Quit Run resets the run HUD hidden")
		_assert(root.gui_get_focus_owner() == reset_menu.get_node("PrimaryAction"), "confirmed Quit Run restores main-menu focus")

	paused = false
	if reset_main != null:
		reset_main.free()
	current_scene = null
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
