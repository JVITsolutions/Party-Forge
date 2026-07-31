extends RefCounted

const SETTINGS_SCENE_PATH := "res://scenes/ui/settings/settings_screen.tscn"
const ADDITIONAL_SETTINGS_SCENE_PATH := "res://scenes/ui/settings/additional_settings_page.tscn"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_additional_settings_page(failures)
	_test_settings_apply_cancel_and_save_error(failures)
	TestAssertions.truthy(ResourceLoader.exists(SETTINGS_SCENE_PATH), "Settings scene exists", failures)
	if not ResourceLoader.exists(SETTINGS_SCENE_PATH):
		return failures
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Settings scene loads", failures)
	if packed == null:
		return failures
	var screen := packed.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	(screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage)._ready()
	screen.call("_ready")
	var return_focus := Button.new()
	return_focus.name = "SettingsReturnFocus"

	var tabs := screen.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var expected := ["Game Settings", "Controls", "Graphics", "Audio", "Additional Settings"]
	var actual: Array[String] = []
	for index: int in range(tabs.get_tab_count()):
		actual.append(tabs.get_tab_title(index))
	TestAssertions.equal(actual, expected, "Settings tabs use approved order", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Game Settings/Content/State").text, "Coming Soon", "Game Settings is honest about availability", failures)
	TestAssertions.equal(screen.get_node_or_null("Overlay/Frame/Layout/Tabs/Controls/Content/State"), null, "Controls has no legacy hidden Task 4 state seam", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Graphics/Content/State").text, "Coming Soon", "Graphics is honest about availability", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/Tabs/Audio/Content/State").text, "Coming Soon", "Audio is honest about availability", failures)
	TestAssertions.truthy(screen.get_node_or_null("Overlay/Frame/Layout/Tabs/Additional Settings/Layout/Mode") != null, "Additional Settings tab contains functional controls", failures)
	TestAssertions.equal(screen.get_node("Overlay/Frame/Layout/NextRunNotice").text, "Run-affecting changes apply when the next run starts.", "Settings shows the next-run notice", failures)
	TestAssertions.equal(screen.process_mode, Node.PROCESS_MODE_ALWAYS, "Settings processes while gameplay is paused", failures)
	TestAssertions.truthy(not bool(screen.call("is_open")), "Settings starts hidden", failures)
	TestAssertions.truthy(screen.has_signal("settings_applied"), "Settings exposes its applied signal", failures)

	var supplied := PartyForgeSettings.new()
	supplied.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	supplied.party_capacity_override = 12
	screen.call("configure", PartyForgeSettingsStore.new(), supplied)
	supplied.party_capacity_override = 2
	var draft := screen.call("current_settings") as PartyForgeSettings
	TestAssertions.equal(draft.party_capacity_override, 12, "Settings drafts a copy of supplied values", failures)
	draft.party_capacity_override = 3
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 12, "Current settings returns an isolated copy", failures)
	_test_active_page_focus(screen, tabs, failures)

	screen.call("open", return_focus)
	TestAssertions.truthy(bool(screen.call("is_open")), "Settings opens modally", failures)
	TestAssertions.equal(screen.get("_return_focus"), return_focus, "Settings records the requested return focus", failures)
	screen.call("_unhandled_input", _action_event(&"ui_cancel"))
	TestAssertions.truthy(not bool(screen.call("is_open")), "Cancel closes Settings", failures)
	TestAssertions.equal(screen.get("_return_focus"), null, "Closing Settings clears the handled return focus", failures)

	screen.free()
	return_focus.free()
	return failures


func _test_additional_settings_page(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(ADDITIONAL_SETTINGS_SCENE_PATH), "Additional Settings page scene exists", failures)
	if not ResourceLoader.exists(ADDITIONAL_SETTINGS_SCENE_PATH):
		return
	var packed := load(ADDITIONAL_SETTINGS_SCENE_PATH) as PackedScene
	TestAssertions.truthy(packed != null, "Additional Settings page scene loads", failures)
	if packed == null:
		return
	var page := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(page)
	page.call("_ready")
	var mode := page.get_node("Layout/Mode") as OptionButton
	var unlock_all := page.get_node("Layout/UnlockAll") as CheckButton
	var god_mode := page.get_node("Layout/GodMode") as CheckButton
	var party_capacity := page.get_node("Layout/PartyCapacity/Value") as HSlider
	var enemy_density := page.get_node("Layout/EnemyDensity/Value") as HSlider
	var inactive_status := page.get_node_or_null("Layout/InactiveStatus") as Label
	TestAssertions.equal(mode.item_count, 2, "Mode exposes exactly two choices", failures)
	TestAssertions.equal(mode.get_item_text(0), "Player Simulation", "Mode starts with Player Simulation", failures)
	TestAssertions.equal(mode.get_item_text(1), "Developer Mode", "Mode includes Developer Mode", failures)
	TestAssertions.equal(Vector3(party_capacity.min_value, party_capacity.max_value, party_capacity.step), Vector3(1.0, 24.0, 1.0), "party capacity uses approved range and step", failures)
	TestAssertions.equal(Vector3(enemy_density.min_value, enemy_density.max_value, enemy_density.step), Vector3(0.0, 1000.0, 10.0), "enemy density uses approved range and step", failures)

	var saved := PartyForgeSettings.new()
	saved.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	saved.unlock_all_implemented_content = true
	saved.god_mode = true
	saved.party_capacity_override = 17
	saved.enemy_density_percent = 650
	page.call("bind", saved)
	TestAssertions.truthy(unlock_all.disabled, "Player Simulation disables Unlock All", failures)
	TestAssertions.truthy(god_mode.disabled and party_capacity.editable == false and enemy_density.editable == false, "Player Simulation disables every developer override", failures)
	TestAssertions.truthy(inactive_status != null and inactive_status.visible, "Player Simulation shows a non-color inactive explanation", failures)
	if inactive_status != null:
		TestAssertions.truthy(inactive_status.text.contains("retained") and inactive_status.text.contains("Developer Mode"), "inactive explanation states values are retained until Developer Mode", failures)
		TestAssertions.truthy(inactive_status.focus_mode != Control.FOCUS_NONE, "inactive explanation is controller and keyboard focusable", failures)
		TestAssertions.equal(mode.focus_next, mode.get_path_to(inactive_status), "Player Simulation focus reaches the inactive explanation after Mode", failures)
		TestAssertions.equal(inactive_status.focus_next, inactive_status.get_path_to(page.get_node("Layout/ResetDeveloperOptions")), "Player Simulation focus continues from the explanation to actions", failures)
	for control: Control in [unlock_all, god_mode, party_capacity, enemy_density]:
		TestAssertions.truthy(control.tooltip_text.contains("retained") and control.tooltip_text.contains("Developer Mode"), "%s exposes the inactive reason in its tooltip" % control.name, failures)
	TestAssertions.equal(int(party_capacity.value), 17, "inactive party cap stays visible", failures)
	TestAssertions.equal(int(enemy_density.value), 650, "inactive density stays visible", failures)
	mode.selected = PartyForgeSettings.Mode.DEVELOPER_MODE
	page.call("_on_mode_changed", PartyForgeSettings.Mode.DEVELOPER_MODE)
	TestAssertions.truthy(not unlock_all.disabled, "Developer Mode enables overrides", failures)
	TestAssertions.truthy(not god_mode.disabled and party_capacity.editable and enemy_density.editable, "Developer Mode enables every override", failures)
	TestAssertions.truthy(inactive_status != null and not inactive_status.visible, "Developer Mode hides the inactive explanation", failures)
	TestAssertions.truthy(page.has_method(&"initial_focus"), "Additional Settings exposes the Settings page focus contract", failures)
	if page.has_method(&"initial_focus"):
		TestAssertions.equal(page.call(&"initial_focus"), mode, "Additional Settings initially focuses Mode", failures)
	_test_additional_focus_traversal(page, failures)
	party_capacity.value = 9
	enemy_density.value = 230
	page.call("_on_party_capacity_changed", party_capacity.value)
	page.call("_on_enemy_density_changed", enemy_density.value)
	TestAssertions.equal((page.get_node("Layout/PartyCapacity/Label") as Label).text, "9", "party capacity label tracks the slider", failures)
	TestAssertions.equal((page.get_node("Layout/EnemyDensity/Label") as Label).text, "230%", "enemy density label tracks the slider", failures)
	page.call("reset_developer_options")
	TestAssertions.truthy(not unlock_all.button_pressed and not god_mode.button_pressed, "reset clears developer toggles", failures)
	TestAssertions.equal(int(party_capacity.value), 4, "reset restores party capacity", failures)
	TestAssertions.equal(int(enemy_density.value), 100, "reset restores enemy density", failures)
	var written := PartyForgeSettings.new()
	page.call("write_to", written)
	TestAssertions.equal(written.mode, PartyForgeSettings.Mode.DEVELOPER_MODE, "page writes selected mode", failures)
	TestAssertions.equal(written.party_capacity_override, 4, "page writes reset capacity", failures)
	page.free()


func _test_settings_apply_cancel_and_save_error(failures: Array[String]) -> void:
	if not ResourceLoader.exists(SETTINGS_SCENE_PATH) or not ResourceLoader.exists(ADDITIONAL_SETTINGS_SCENE_PATH):
		return
	var original_files := _backup_default_settings_artifacts()
	_cleanup_default_settings_artifacts()
	var tree := Engine.get_main_loop() as SceneTree
	var screen := (load(SETTINGS_SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(screen)
	(screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage)._ready()
	screen.call("_ready")
	var saved := PartyForgeSettings.new()
	saved.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	saved.party_capacity_override = 12
	screen.call("configure", PartyForgeSettingsStore.new(), saved)
	screen.call("open")
	var page := screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings")
	(page.get_node("Layout/PartyCapacity/Value") as HSlider).value = 3
	(page.get_node("Layout/Cancel") as Button).pressed.emit()
	TestAssertions.truthy(not bool(screen.call("is_open")), "Cancel button closes Settings", failures)
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 12, "Cancel leaves current settings unchanged", failures)
	screen.call("open")
	TestAssertions.equal(int((page.get_node("Layout/PartyCapacity/Value") as HSlider).value), 12, "open creates a fresh draft from current settings", failures)
	(page.get_node("Layout/PartyCapacity/Value") as HSlider).value = 9
	(page.get_node("Layout/ResetDeveloperOptions") as Button).pressed.emit()
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 12, "Reset changes draft controls without changing current settings", failures)
	(page.get_node("Layout/PartyCapacity/Value") as HSlider).value = 9
	var applied: Array[PartyForgeSettings] = []
	screen.connect("settings_applied", func(settings: PartyForgeSettings) -> void: applied.append(settings))
	(page.get_node("Layout/ApplyAndReturn") as Button).pressed.emit()
	TestAssertions.truthy(not bool(screen.call("is_open")), "successful Apply closes Settings", failures)
	TestAssertions.equal(applied.size(), 1, "successful Apply emits once", failures)
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 9, "successful Apply replaces current settings", failures)
	TestAssertions.equal(PartyForgeSettingsStore.new().load_settings().party_capacity_override, 9, "successful Apply persists through the store", failures)
	if not applied.is_empty():
		applied[0].party_capacity_override = 2
	TestAssertions.equal((screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 9, "applied signal receives an isolated copy", failures)
	screen.free()
	_cleanup_default_settings_artifacts()

	var failing_screen := (load(SETTINGS_SCENE_PATH) as PackedScene).instantiate()
	tree.root.add_child(failing_screen)
	(failing_screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage)._ready()
	failing_screen.call("_ready")
	var failing_store := PartyForgeSettingsStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	failing_screen.call("configure", failing_store, saved)
	failing_screen.call("open")
	var failing_page := failing_screen.get_node("Overlay/Frame/Layout/Tabs/Additional Settings")
	(failing_page.get_node("Layout/PartyCapacity/Value") as HSlider).value = 8
	(failing_page.get_node("Layout/ApplyAndReturn") as Button).pressed.emit()
	var expected_error := "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=promote" % [PartyForgeSettingsStore.DEFAULT_PATH, ERR_CANT_CREATE]
	var status := failing_screen.get_node("Overlay/Frame/Layout/Status") as Label
	var technical_toggle := failing_screen.get_node_or_null("Overlay/Frame/Layout/ShowTechnicalDetails") as Button
	var technical_details := failing_screen.get_node_or_null("Overlay/Frame/Layout/TechnicalDetails") as LineEdit
	TestAssertions.truthy(bool(failing_screen.call("is_open")), "failed Apply keeps Settings open", failures)
	TestAssertions.equal(status.text, "Settings could not be saved. Check that the settings folder is writable, then try again.", "failed Apply shows friendly actionable primary text", failures)
	TestAssertions.equal(status.tooltip_text, expected_error, "failed Apply preserves the raw diagnostic in the status tooltip", failures)
	TestAssertions.truthy(technical_toggle != null and technical_toggle.visible and technical_toggle.focus_mode != Control.FOCUS_NONE, "failed Apply exposes a focusable technical-details action", failures)
	TestAssertions.truthy(technical_details != null and not technical_details.visible, "raw technical details stay hidden until requested", failures)
	if technical_toggle != null and technical_details != null:
		technical_toggle.pressed.emit()
		TestAssertions.truthy(technical_details.visible, "keyboard or controller activation reveals technical details", failures)
		TestAssertions.equal(technical_details.text, expected_error, "revealed details preserve the raw store diagnostic", failures)
		TestAssertions.truthy(not technical_details.editable and technical_details.focus_mode != Control.FOCUS_NONE, "revealed details are read-only, selectable, and focusable", failures)
		failing_screen.call("open")
		TestAssertions.truthy(not technical_toggle.visible and not technical_details.visible and technical_details.text.is_empty(), "opening Settings resets technical disclosure state", failures)
		(failing_page.get_node("Layout/ApplyAndReturn") as Button).pressed.emit()
		technical_toggle.pressed.emit()
		TestAssertions.truthy(technical_details.visible, "second save failure can disclose details again", failures)
		failing_screen.call("configure", PartyForgeSettingsStore.new(), saved)
		(failing_page.get_node("Layout/ApplyAndReturn") as Button).pressed.emit()
		TestAssertions.truthy(not technical_toggle.visible and not technical_details.visible and technical_details.text.is_empty(), "successful Apply resets technical disclosure state", failures)
	TestAssertions.equal((failing_screen.call("current_settings") as PartyForgeSettings).party_capacity_override, 12, "failed Apply leaves current settings unchanged", failures)
	failing_screen.free()
	_cleanup_default_settings_artifacts()
	_restore_default_settings_artifacts(original_files)


func _cleanup_default_settings_artifacts() -> void:
	for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _backup_default_settings_artifacts() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
		if FileAccess.file_exists(path):
			result[path] = FileAccess.get_file_as_bytes(path)
	return result


func _restore_default_settings_artifacts(files: Dictionary) -> void:
	for path: String in files:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(files[path] as PackedByteArray)


func _action_event(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _test_active_page_focus(screen: CanvasLayer, tabs: TabContainer, failures: Array[String]) -> void:
	screen.call("open")
	TestAssertions.truthy(screen.has_method(&"_focus_target_for_active_page"), "Settings exposes a deterministic active-page focus resolver", failures)
	if screen.has_method(&"_focus_target_for_active_page"):
		TestAssertions.equal(screen.call(&"_focus_target_for_active_page"), screen.get_node("Overlay/Frame/Layout/Tabs/Game Settings/Content/State"), "opening Settings resolves the active page's meaningful target", failures)
	var next_tab := InputEventJoypadButton.new()
	next_tab.button_index = JOY_BUTTON_RIGHT_SHOULDER
	next_tab.pressed = true
	TestAssertions.truthy(next_tab.is_action_pressed(&"settings_next_tab"), "right shoulder is the controller Settings-tab action", failures)
	var controller_accept := InputEventJoypadButton.new()
	controller_accept.device = 0
	controller_accept.button_index = JOY_BUTTON_A
	controller_accept.pressed = true
	TestAssertions.truthy(controller_accept.is_action_pressed(&"ui_accept"), "controller A maps to the standard UI accept action", failures)
	var accept_events := InputMap.action_get_events(&"ui_accept")
	for keycode: Key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		TestAssertions.truthy(accept_events.any(func(event: InputEvent) -> bool:
			return event is InputEventKey and event.keycode == keycode
		), "ui_accept preserves keyboard binding %s" % keycode, failures)


func _test_additional_focus_traversal(page: Control, failures: Array[String]) -> void:
	var ordered: Array[Control] = [
		page.get_node("Layout/Mode") as Control,
		page.get_node("Layout/UnlockAll") as Control,
		page.get_node("Layout/GodMode") as Control,
		page.get_node("Layout/PartyCapacity/Value") as Control,
		page.get_node("Layout/EnemyDensity/Value") as Control,
		page.get_node("Layout/ResetDeveloperOptions") as Control,
		page.get_node("Layout/ApplyAndReturn") as Control,
		page.get_node("Layout/Cancel") as Control,
	]
	for index: int in range(ordered.size()):
		var current := ordered[index]
		var next := ordered[(index + 1) % ordered.size()]
		var previous := ordered[posmod(index - 1, ordered.size())]
		TestAssertions.equal(current.focus_next, current.get_path_to(next), "%s has stable forward focus traversal" % current.name, failures)
		TestAssertions.equal(current.focus_previous, current.get_path_to(previous), "%s has stable backward focus traversal" % current.name, failures)
		TestAssertions.equal(current.focus_neighbor_bottom, current.get_path_to(next), "%s has stable controller-down focus traversal" % current.name, failures)
		TestAssertions.equal(current.focus_neighbor_top, current.get_path_to(previous), "%s has stable controller-up focus traversal" % current.name, failures)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	TestAssertions.truthy(tab.is_action_pressed(&"ui_focus_next"), "Tab is the keyboard forward-focus action", failures)
	var dpad_down := InputEventJoypadButton.new()
	dpad_down.button_index = JOY_BUTTON_DPAD_DOWN
	dpad_down.pressed = true
	TestAssertions.truthy(dpad_down.is_action_pressed(&"ui_down"), "D-pad Down is the controller focus action", failures)
