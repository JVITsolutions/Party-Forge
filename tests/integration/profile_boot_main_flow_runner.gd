extends SceneTree

class RecordingForfeitService extends RunRecoveryService:
	var calls: Array[Dictionary] = []
	var corrupt_after_success := false
	var committed_profile: ProfileState

	func forfeit(profile_id: String, run_id: StringName, profile_root: String = ProfileStore.DEFAULT_ROOT) -> ProfileMutationResult:
		calls.append({"profile_id": profile_id, "run_id": run_id, "profile_root": profile_root})
		var result := super.forfeit(profile_id, run_id, profile_root)
		if corrupt_after_success and result.ok():
			committed_profile = result.profile.copy()
			var file := FileAccess.open(ProfileStore.new().profile_path(profile_id, profile_root), FileAccess.WRITE)
			if file != null:
				file.store_string("{ post_forfeit_refresh_failure")
		return result

class FailingRefreshProfileManager extends ProfileManager:
	var delegate: ProfileManager
	var failures_remaining := 2

	func active_profile() -> ProfileState:
		return delegate.active_profile()

	func refresh_profile(profile_id: String) -> String:
		if failures_remaining > 0:
			failures_remaining -= 1
			return "PROFILE_LOAD_ERROR reason=injected post-forfeit refresh failure"
		return delegate.refresh_profile(profile_id)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not _abandon_runtime_contract_available():
		_failures.append("Task 12 active-run Abandon runtime binding is unavailable")
		_finish()
		return
	var fixture_root := "user://tests/profile_boot_main_flow/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile_root := fixture_root.path_join("profiles")
	var settings_path := fixture_root.path_join("settings.json")
	ProfileTestSupport.remove_tree(fixture_root)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = profile_root
	main.settings_path = settings_path
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
	var initial_class_focus := selector.selection_focus(&"fighter") as Button
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
	var settings_control := selector.action_focus(&"settings")
	settings_control.grab_focus()
	selector.settings_requested.emit()
	await process_frame
	settings.close()
	await process_frame
	_assert(root.gui_get_focus_owner() == settings_control, "run-setup Settings restores its exact originating control")
	(selector.action_focus(&"back") as Button).pressed.emit()
	await process_frame
	_assert(menu.is_open() and not selector.is_open(), "run-setup Back returns to the main menu")
	_assert(root.gui_get_focus_owner() == primary, "run-setup Back restores PrimaryAction focus")
	primary.pressed.emit()
	await process_frame
	var fighter := selector.selection_focus(&"fighter") as Button
	fighter.pressed.emit()
	await process_frame
	_assert(not main.run_started and selector.selected_class_id() == &"fighter", "Fighter confirmation selects without starting")
	(selector.action_focus(&"start") as Button).pressed.emit()
	await process_frame
	var party := main.get_node("PartyManager") as PartyManager
	var game_run := main.get_node("GameRun") as GameRun
	_assert(main.run_started, "separate Start Run action starts the run")
	_assert(main.leader != null and main.leader.get_parent() == main.get_node("Actors"), "Fighter launch creates the arena leader")
	_assert(party.members.size() == 1 and party.members[0].class_definition.id == &"fighter", "Fighter launch initializes the party")
	_assert(game_run.current_state() == RunStateMachine.State.RUNNING, "Fighter launch begins the arena flow")
	_assert(not (main.get_node("HUD/ClassSelection") as Control).visible, "arena flow closes class selection")
	_assert(run_hud.visible, "successful arena start reveals the run HUD")

	var active_context := main.active_run_context as PlayerRunContext
	var active_run_id := active_context.run_id if active_context != null else &""
	var pause_menu := main.get_node("RunPauseMenu") as RunPauseMenu
	var abandon_run := pause_menu.get_node_or_null("Overlay/Panel/Content/AbandonRun") as Button
	var confirmation := pause_menu.get_node_or_null("Overlay/AbandonConfirmation") as Control
	var confirm := pause_menu.get_node_or_null("Overlay/AbandonConfirmation/Panel/Content/Confirm") as Button
	_assert(abandon_run != null and abandon_run.text == "Abandon Run", "active pause action has exact Abandon Run copy")
	_assert(confirm != null and confirm.text == "Abandon Run", "Abandon confirmation has exact Abandon Run copy")
	_assert(pause_menu.has_signal(&"abandon_run_confirmed"), "RunPauseMenu exposes authoritative abandon_run_confirmed signal")
	var successful_forfeit := RecordingForfeitService.new()
	main._run_recovery = successful_forfeit
	if abandon_run != null and confirm != null and pause_menu.has_signal(&"abandon_run_confirmed"):
		pause_menu.open()
		abandon_run.pressed.emit()
		await process_frame
		_assert(confirmation != null and confirmation.visible, "Abandon Run opens its confirmation before forfeiting")
		confirm.pressed.emit()
		await process_frame
		await process_frame
		_assert(successful_forfeit.calls.size() == 1, "confirmed Abandon calls the forfeit authority exactly once")
		if successful_forfeit.calls.size() == 1:
			var call := successful_forfeit.calls[0]
			_assert(call.profile_id == active_id and call.run_id == active_run_id and call.profile_root == profile_root, "Abandon passes exact active profile/run identity to forfeit")
		var durable_after_abandon := ProfileStore.new().load_profile(active_id, profile_root)
		_assert(durable_after_abandon.ok() and durable_after_abandon.profile.resumable_run.is_empty(), "Abandon durably revokes the resumable run before front-end return")
		_assert(main.active_profile() != null and main.active_profile().resumable_run.is_empty(), "successful profile refresh precedes the front-end reset")
		_assert(not main.run_started and (main.get_node("MainMenuScreen") as MainMenuScreen).is_open(), "successful Abandon returns to the front end")

	main.queue_free()
	await process_frame
	await process_frame
	var refresh_failure_main := await _new_main(profile_root, settings_path)
	if refresh_failure_main != null:
		await _start_fighter(refresh_failure_main)
		var failure_context := refresh_failure_main.active_run_context as PlayerRunContext
		var failure_run_id := failure_context.run_id if failure_context != null else &""
		var failure_pause := refresh_failure_main.get_node("RunPauseMenu") as RunPauseMenu
		var failure_abandon := failure_pause.get_node_or_null("Overlay/Panel/Content/AbandonRun") as Button
		var failure_confirm := failure_pause.get_node_or_null("Overlay/AbandonConfirmation/Panel/Content/Confirm") as Button
		var retry_return := failure_pause.get_node_or_null("Overlay/AbandonCommittedError/Panel/Content/RetryReturnToForge") as Button
		var committed_error := failure_pause.get_node_or_null("Overlay/AbandonCommittedError") as Control
		var failing_forfeit := RecordingForfeitService.new()
		refresh_failure_main._run_recovery = failing_forfeit
		var failing_manager := FailingRefreshProfileManager.new()
		failing_manager.delegate = refresh_failure_main.profile_manager
		refresh_failure_main.profile_manager = failing_manager
		if failure_abandon != null and failure_confirm != null and failure_pause.has_signal(&"abandon_run_confirmed"):
			failure_pause.open()
			failure_abandon.pressed.emit()
			await process_frame
			failure_confirm.pressed.emit()
			await process_frame
			await process_frame
			_assert(failing_forfeit.calls.size() == 1 and failing_forfeit.calls[0].profile_id == active_id and failing_forfeit.calls[0].run_id == failure_run_id, "post-forfeit failure still commits one exact forfeit")
			_assert(committed_error != null and committed_error.visible and retry_return != null and retry_return.visible and not retry_return.disabled, "post-forfeit refresh failure exposes only Retry Return to Forge")
			_assert(paused and failure_pause.visible and root.gui_get_focus_owner() == retry_return, "committed refresh failure stays paused and focuses Retry Return to Forge")
			failure_pause.close()
			await _send_action(&"ui_cancel")
			await _send_action(&"pause_menu")
			_assert(failure_pause.visible and paused, "committed refresh failure consumes close, ui_cancel, and pause without resuming")
			failure_abandon.pressed.emit()
			await process_frame
			_assert(failing_forfeit.calls.size() == 1, "committed refresh failure cannot forfeit twice")
			if retry_return != null:
				retry_return.pressed.emit()
				await process_frame
				_assert(failing_forfeit.calls.size() == 1 and failure_pause.visible and paused, "retry refresh failure is bounded, non-dismissible, and never forfeits again")
				if failing_forfeit.committed_profile != null:
					_assert(ProfileStore.new().save_profile(failing_forfeit.committed_profile, profile_root).is_empty(), "fixture restores the committed forfeit document for retry")
					retry_return.pressed.emit()
					await process_frame
					await process_frame
					_assert(failing_forfeit.calls.size() == 1 and not refresh_failure_main.run_started and (refresh_failure_main.get_node("MainMenuScreen") as MainMenuScreen).is_open(), "successful Retry Return to Forge refreshes only then returns to the front end")

	paused = false
	if refresh_failure_main != null:
		refresh_failure_main.queue_free()
		await process_frame
		await process_frame
	current_scene = null
	ProfileTestSupport.remove_tree(fixture_root)
	_finish()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _abandon_runtime_contract_available() -> bool:
	var main_source := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	var pause_source := FileAccess.get_file_as_string("res://scripts/ui/run_pause_menu.gd")
	return (
		"signal abandon_run_confirmed" in pause_source
		and "signal retry_abandon_refresh_requested" in pause_source
		and "func _on_active_run_abandon_confirmed(" in main_source
		and "func _on_retry_abandon_refresh_requested(" in main_source
		and "run_pause_menu.abandon_run_confirmed" in main_source
	)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROFILE_BOOT_MAIN_FLOW_FAILURE: %s" % failure)
	print("PROFILE_BOOT_MAIN_FLOW_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _new_main(profile_root: String, settings_path: String) -> PartyForgeMain:
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = profile_root
	main.settings_path = settings_path
	root.add_child(main)
	await process_frame
	await process_frame
	return main


func _start_fighter(main: PartyForgeMain) -> void:
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	(menu.get_node("PrimaryAction") as Button).pressed.emit()
	await process_frame
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var fighter := selector.selection_focus(&"fighter") as Button
	if fighter != null:
		fighter.pressed.emit()
		await process_frame
	var start := selector.action_focus(&"start") as Button
	if start != null:
		start.pressed.emit()
		await process_frame
		await process_frame
	_assert(main.run_started, "refresh-failure fixture starts a second active Fighter run")


func _send_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	await process_frame
	var released := event.duplicate() as InputEventAction
	released.pressed = false
	root.push_input(released)
	await process_frame
