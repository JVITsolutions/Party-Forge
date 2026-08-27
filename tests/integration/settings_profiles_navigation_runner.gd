extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var profile_root := "user://tests/settings_profiles_navigation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(profile_root)
	var manager := ProfileManager.new()
	var bootstrap_error := manager.bootstrap(profile_root)
	if not bootstrap_error.is_empty():
		_failures.append("manager bootstrap failed: %s" % bootstrap_error)

	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var return_focus := Button.new()
	return_focus.name = "ProfilesReturnFocus"
	return_focus.text = "Return"
	viewport.add_child(return_focus)

	var settings := _new_settings(viewport, manager)
	settings.open_profiles(return_focus)
	viewport.add_child(settings)
	await _wait_for_layout()
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var expected_focus := profiles.initial_focus()
	_assert(settings.is_open(), "pre-tree open_profiles survives tree entry")
	_assert(tabs.get_tab_control(tabs.current_tab) == profiles, "pre-tree open_profiles selects Profiles by control identity")
	_assert(viewport.gui_get_focus_owner() == expected_focus, "pre-tree open_profiles focuses %s" % expected_focus.get_path())
	settings.close()
	await process_frame
	_assert(not settings.is_open(), "in-tree close hides pre-tree-opened Settings")
	_assert(viewport.gui_get_focus_owner() == return_focus, "in-tree close restores the pre-tree return focus")
	settings.free()

	var cancellation_focus := Button.new()
	cancellation_focus.name = "CancellationFocus"
	cancellation_focus.text = "Cancellation focus"
	viewport.add_child(cancellation_focus)
	cancellation_focus.grab_focus()
	await process_frame
	var cancelled := _new_settings(viewport, manager)
	cancelled.open_profiles(return_focus)
	cancelled.close()
	_assert(viewport.gui_get_focus_owner() == cancellation_focus, "pre-tree close cancels pending focus without moving current focus")
	viewport.add_child(cancelled)
	await _wait_for_layout()
	_assert(not cancelled.is_open(), "pre-tree close cancels pending visibility")
	_assert(cancelled.get("_return_focus") == null, "pre-tree close clears pending return focus")
	var has_pending_open := _has_property(cancelled, &"_pending_open")
	var has_pending_profiles := _has_property(cancelled, &"_pending_profiles_tab")
	_assert(has_pending_open, "Settings exposes pending-open state")
	_assert(has_pending_profiles, "Settings exposes pending-Profiles state")
	if has_pending_open:
		_assert(not bool(cancelled.get("_pending_open")), "pre-tree close clears pending-open state")
	if has_pending_profiles:
		_assert(not bool(cancelled.get("_pending_profiles_tab")), "pre-tree close clears pending-Profiles state")
	cancelled.free()
	cancellation_focus.free()

	var startup := _new_settings(viewport, manager)
	viewport.add_child(startup)
	await _wait_for_layout()
	_assert(not startup.is_open(), "startup without an open request remains hidden")
	startup.free()

	_assert(manager.create_profile("Navigation Alpha", 1000).ok(), "deletion navigation creates replacement profile")
	_assert(manager.create_profile("Navigation Beta", 2000).ok(), "deletion navigation creates active profile")
	var run_active: Array[bool] = [false]
	var deletion := _new_settings(viewport, manager, func() -> bool: return run_active[0])
	viewport.add_child(deletion)
	deletion.open_profiles(return_focus)
	await _wait_for_layout()
	var deletion_profiles := deletion.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var deletion_list := deletion_profiles.get_node("Layout/ProfileList") as ItemList
	var delete := deletion_profiles.get_node("Layout/DeleteProfile") as Button
	var confirmation := deletion_profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	_assert(not delete.disabled, "inactive run leaves selected active profile deletable")
	run_active[0] = true
	deletion.open_profiles(return_focus)
	_assert(delete.disabled, "opening Settings recomputes active-run deletion gating")
	run_active[0] = false
	deletion.open_profiles(return_focus)
	delete.pressed.emit()
	_assert(confirmation.dialog_text.contains("Navigation Beta"), "real Settings confirmation names the active profile")
	confirmation.hide()
	confirmation.canceled.emit()
	_assert(manager.profiles().size() == 2, "confirmation cancellation mutates no profiles")
	_assert(viewport.gui_get_focus_owner() == delete, "confirmation cancellation returns focus to Delete")
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	_assert(deletion.is_open(), "active deletion keeps real Settings navigation open")
	_assert(deletion_list.item_count == 1 and deletion_list.get_item_text(0).contains("Navigation Alpha"), "active deletion refreshes the replacement row")
	_assert(viewport.gui_get_focus_owner() == deletion_list, "active deletion focuses the replacement row in real Settings navigation")
	delete.pressed.emit()
	confirmation.hide()
	confirmation.confirmed.emit()
	_assert(deletion_list.item_count == 0 and (deletion_profiles.get_node("Layout/EmptyState") as Label).visible, "final deletion shows the existing empty state")
	_assert(viewport.gui_get_focus_owner() == deletion_profiles.get_node("Layout/CreateRow/ProfileName"), "final deletion focuses the profile name field")
	deletion.free()

	var failure_root := "%s_failure" % profile_root
	ProfileTestSupport.remove_tree(failure_root)
	var failing_manager := ProfileManager.new(
		ProfileStore.new(),
		ProfileIndexStore.new(),
		func() -> String: return "profile-navigation-failure",
		ProfileDeletionService.new(func(_path: String) -> Error: return ERR_CANT_CREATE),
	)
	_assert(failing_manager.bootstrap(failure_root).is_empty(), "noncommit navigation fixture bootstraps")
	_assert(failing_manager.create_profile("Navigation Failure", 3000).ok(), "noncommit navigation fixture creates a profile")
	var noncommit := _new_settings(viewport, failing_manager)
	viewport.add_child(noncommit)
	noncommit.open_profiles(return_focus)
	await _wait_for_layout()
	var noncommit_profiles := noncommit.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var noncommit_list := noncommit_profiles.get_node("Layout/ProfileList") as ItemList
	var noncommit_delete := noncommit_profiles.get_node("Layout/DeleteProfile") as Button
	var noncommit_confirmation := noncommit_profiles.get_node("DeleteConfirmation") as ConfirmationDialog
	var selected_id := String(noncommit_list.get_item_metadata(noncommit_list.get_selected_items()[0]))
	noncommit_delete.pressed.emit()
	noncommit_confirmation.hide()
	noncommit_confirmation.confirmed.emit()
	_assert(String(noncommit_list.get_item_metadata(noncommit_list.get_selected_items()[0])) == selected_id, "noncommitted deletion retains the selected profile")
	_assert(viewport.gui_get_focus_owner() == noncommit_delete, "noncommitted deletion returns focus to Delete in real Settings navigation")
	_assert((noncommit_profiles.get_node("Layout/TechnicalDetails") as Label).text.contains("PROFILE_DELETE_ERROR"), "noncommitted deletion preserves technical detail")
	noncommit.free()
	ProfileTestSupport.remove_tree(failure_root)
	viewport.free()
	ProfileTestSupport.remove_tree(profile_root)

	if _failures.is_empty():
		print("SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROFILE_SETTINGS_NAVIGATION_FAILURE: %s" % failure)
	print("SETTINGS_PROFILES_NAVIGATION_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _new_settings(viewport: SubViewport, manager: ProfileManager, run_active_query: Callable = Callable()) -> SettingsScreen:
	var settings := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	settings.custom_viewport = viewport
	settings.configure(PartyForgeSettingsStore.new(), PartyForgeSettings.new(), manager, PartyForgeSettingsStore.DEFAULT_PATH, run_active_query)
	return settings


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
