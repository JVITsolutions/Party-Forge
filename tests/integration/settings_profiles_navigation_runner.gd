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
	viewport.free()
	ProfileTestSupport.remove_tree(profile_root)

	if _failures.is_empty():
		print("PROFILE_SETTINGS_NAVIGATION_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PROFILE_SETTINGS_NAVIGATION_FAILURE: %s" % failure)
	print("PROFILE_SETTINGS_NAVIGATION_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _new_settings(viewport: SubViewport, manager: ProfileManager) -> SettingsScreen:
	var settings := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	settings.custom_viewport = viewport
	settings.configure(PartyForgeSettingsStore.new(), PartyForgeSettings.new(), manager)
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
