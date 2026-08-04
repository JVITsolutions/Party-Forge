extends SceneTree

const ResponsiveGeometry := preload("res://tests/support/responsive_geometry.gd")
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as HUD
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	var run_setup := hud.get_node("ClassSelection") as ClassSelectionPanel
	run_setup.configure(GameCatalog.load_defaults().classes)
	var run_setup_actions := run_setup.get_node("Content/Actions") as HBoxContainer
	var run_setup_settings := run_setup.get_node("Content/Actions/Settings") as Button
	var run_setup_back := run_setup.get_node("Content/Actions/Back") as Button
	if (hud.get_node("Margin") as Control).visible:
		_failures.append("run HUD status is visible before a confirmed run start")

	var settings := (load("res://scenes/ui/settings/settings_screen.tscn") as PackedScene).instantiate() as SettingsScreen
	settings.custom_viewport = viewport
	viewport.add_child(settings)
	settings.visible = true
	var badge := (load("res://scenes/ui/developer_mode_badge.tscn") as PackedScene).instantiate() as DeveloperModeBadge
	badge.custom_viewport = viewport
	viewport.add_child(badge)
	var developer_settings := PartyForgeSettings.new()
	developer_settings.mode = PartyForgeSettings.Mode.DEVELOPER_MODE
	developer_settings.unlock_all_implemented_content = true
	developer_settings.god_mode = true
	developer_settings.party_capacity_override = 12
	developer_settings.enemy_density_percent = 500
	var profile_root := "user://tests/responsive_profiles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(profile_root)
	var profile_manager := ProfileManager.new()
	var bootstrap_error := profile_manager.bootstrap(profile_root)
	if not bootstrap_error.is_empty():
		_failures.append("Profiles geometry manager bootstrap failed: %s" % bootstrap_error)
	var created := profile_manager.create_profile("Geometry Profile")
	if not created.ok():
		_failures.append("Profiles geometry fixture create failed: %s" % created.error)
	badge.configure(RunRulesSnapshot.from_settings(developer_settings))
	await _wait_for_layout()
	await _assert_settings_focus_input(settings, viewport, developer_settings)

	var overlay := settings.get_node("Overlay") as Control
	var frame := settings.get_node("Overlay/Frame") as Control
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var controls := settings.get_node("Overlay/Frame/Layout/Tabs/Controls") as Control
	var controls_scroll := settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout/Scroll") as ScrollContainer
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var profile_explanation := profiles.get_node("Layout/Explanation") as Label
	var profile_empty := profiles.get_node("Layout/EmptyState") as Label
	var profile_list := profiles.get_node("Layout/ProfileList") as ItemList
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var profile_create := profiles.get_node("Layout/CreateRow/Create") as Button
	var profile_activate := profiles.get_node("Layout/Activate") as Button
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as Control
	var reset := additional.get_node("Layout/ResetDeveloperOptions") as Button
	var apply := additional.get_node("Layout/ApplyAndReturn") as Button
	var cancel := additional.get_node("Layout/Cancel") as Button
	var notice := settings.get_node("Overlay/Frame/Layout/NextRunNotice") as Label
	var status := settings.get_node("Overlay/Frame/Layout/Status") as Label
	var badge_anchor := badge.get_node("Anchor") as Control
	var badge_margin := badge.get_node("Anchor/Margin") as MarginContainer
	var badge_label := badge.get_node("Anchor/Margin/Label") as Label

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var failure_count_before := _failures.size()
		viewport.size = viewport_size
		run_setup.open()
		await _wait_for_layout()
		var run_setup_failure_count_before := _failures.size()
		var run_setup_rect := run_setup.get_global_rect()
		var actions_rect := run_setup_actions.get_global_rect()
		var run_setup_settings_rect := run_setup_settings.get_global_rect()
		var run_setup_back_rect := run_setup_back.get_global_rect()
		_assert_visible_contained(run_setup_actions, run_setup_rect, "Run setup actions", viewport_size)
		_assert_visible_contained(run_setup_settings, actions_rect, "Run setup Settings", viewport_size)
		_assert_visible_contained(run_setup_back, actions_rect, "Run setup Back", viewport_size)
		if not is_equal_approx(run_setup_settings_rect.position.y, run_setup_back_rect.position.y):
			_failures.append("Run setup Settings and Back do not share a row at %dx%d" % [viewport_size.x, viewport_size.y])
		if run_setup_settings_rect.end.x > run_setup_back_rect.position.x:
			_failures.append("Run setup Settings overlaps Back at %dx%d" % [viewport_size.x, viewport_size.y])
		if _failures.size() == run_setup_failure_count_before:
			print("RUN_SETUP_ACTIONS_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])
		run_setup.close()
		_select_tab(tabs, controls, "Controls")
		await _wait_for_layout()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert_rect_near(overlay.get_global_rect(), viewport_rect, "Settings overlay", viewport_size)
		var expected_frame := Rect2(Vector2(48.0, 36.0), Vector2(viewport_size) - Vector2(96.0, 72.0))
		_assert_rect_near(frame.get_global_rect(), expected_frame, "Settings frame", viewport_size)

		_assert_visible_contained(tabs.get_tab_bar(), expected_frame, "Settings tab row", viewport_size)
		_assert_visible_contained(controls_scroll, expected_frame, "Controls scroll", viewport_size)

		settings.configure(PartyForgeSettingsStore.new(), developer_settings)
		_select_tab(tabs, profiles, "Profiles")
		await _wait_for_layout()
		for control: Control in [profiles, profile_explanation, profile_empty, profile_name, profile_create, profile_activate]:
			_assert_visible_contained(control, expected_frame, "Profiles %s" % control.name, viewport_size)
		_assert_initial_focus(profiles, profile_name, expected_frame, viewport_size, "empty")

		settings.configure(PartyForgeSettingsStore.new(), developer_settings, profile_manager)
		await _wait_for_layout()
		for control: Control in [profiles, profile_explanation, profile_list, profile_name, profile_create, profile_activate]:
			_assert_visible_contained(control, expected_frame, "Populated Profiles %s" % control.name, viewport_size)
		_assert_initial_focus(profiles, profile_list, expected_frame, viewport_size, "populated")

		_select_tab(tabs, additional, "Additional Settings")
		await _wait_for_layout()
		for action: Button in [reset, apply, cancel]:
			_assert_visible_contained(action, expected_frame, "Additional Settings %s" % action.name, viewport_size)
		_assert_visible_contained(notice, expected_frame, "Settings notice", viewport_size)
		_assert_visible_contained(status, expected_frame, "Settings status", viewport_size)

		_assert_rect_near(badge_anchor.get_global_rect(), viewport_rect, "badge anchor", viewport_size)
		var expected_badge := Rect2(Vector2(float(viewport_size.x) - 720.0, 16.0), Vector2(704.0, 56.0))
		_assert_rect_near(badge_margin.get_global_rect(), expected_badge, "badge margin", viewport_size)
		_assert_visible_contained(badge_label, expected_badge, "badge label", viewport_size)
		if _failures.size() == failure_count_before:
			print("RESPONSIVE_GEOMETRY_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	viewport.free()
	ProfileTestSupport.remove_tree(profile_root)
	if _failures.is_empty():
		print("RESPONSIVE_GEOMETRY_SUMMARY: PASS (%d sizes)" % VIEWPORT_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("RESPONSIVE_GEOMETRY_FAILURE: %s" % failure)
	print("RESPONSIVE_GEOMETRY_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _assert_settings_focus_input(settings: SettingsScreen, viewport: SubViewport, developer_settings: PartyForgeSettings) -> void:
	settings.configure(PartyForgeSettingsStore.new(), developer_settings)
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer
	var controls := settings.get_node("Overlay/Frame/Layout/Tabs/Controls") as Control
	var graphics := settings.get_node("Overlay/Frame/Layout/Tabs/Graphics") as Control
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
	_select_tab(tabs, controls, "Controls")
	settings.open()
	await process_frame
	_assert_focus(viewport, settings.get_node("Overlay/Frame/Layout/Tabs/Controls/Layout/Footer") as Control, "Controls initial focus")

	var bumper := InputEventJoypadButton.new()
	bumper.button_index = JOY_BUTTON_RIGHT_SHOULDER
	bumper.pressed = true
	viewport.push_input(bumper)
	await process_frame
	if tabs.get_tab_control(tabs.current_tab) != graphics:
		_failures.append("controller bumper did not advance Controls to Graphics")
	_assert_focus(viewport, settings.get_node("Overlay/Frame/Layout/Tabs/Graphics/Content/State") as Control, "Graphics controller focus")

	_select_tab(tabs, additional, "Additional Settings")
	settings.call(&"_focus_active_page")
	await process_frame
	var page := additional
	var mode := page.get_node("Layout/Mode") as Control
	var unlock_all := page.get_node("Layout/UnlockAll") as Control
	_assert_focus(viewport, mode, "Additional Settings initial focus")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	viewport.push_input(tab)
	await process_frame
	_assert_focus(viewport, unlock_all, "keyboard Tab focus")
	mode.grab_focus()
	var dpad_down := InputEventJoypadButton.new()
	dpad_down.button_index = JOY_BUTTON_DPAD_DOWN
	dpad_down.pressed = true
	viewport.push_input(dpad_down)
	await process_frame
	_assert_focus(viewport, unlock_all, "controller D-pad focus")

	var failing_store := PartyForgeSettingsStore.new(func(_temporary: String, _target: String) -> Error: return ERR_CANT_CREATE)
	settings.configure(failing_store, developer_settings)
	settings.open()
	var apply := page.get_node("Layout/ApplyAndReturn") as Button
	var technical_toggle := settings.get_node("Overlay/Frame/Layout/ShowTechnicalDetails") as Button
	var technical_details := settings.get_node("Overlay/Frame/Layout/TechnicalDetails") as LineEdit
	apply.pressed.emit()
	if not technical_toggle.visible:
		_failures.append("save failure did not expose the technical-details action")
	_assert_focus(viewport, technical_toggle, "save failure technical-details focus")
	var keyboard_accept := InputEventKey.new()
	keyboard_accept.keycode = KEY_ENTER
	keyboard_accept.pressed = true
	viewport.push_input(keyboard_accept)
	var keyboard_accept_release := keyboard_accept.duplicate() as InputEventKey
	keyboard_accept_release.pressed = false
	viewport.push_input(keyboard_accept_release)
	await process_frame
	_assert_disclosed_diagnostic(viewport, technical_details, "keyboard activation")

	settings.open()
	apply.pressed.emit()
	_assert_focus(viewport, technical_toggle, "second save failure technical-details focus")
	var controller_accept := InputEventJoypadButton.new()
	controller_accept.device = 0
	controller_accept.button_index = JOY_BUTTON_A
	controller_accept.pressed = true
	if not controller_accept.is_action_pressed(&"ui_accept"):
		_failures.append("controller A is not mapped to ui_accept")
	viewport.push_input(controller_accept)
	var controller_accept_release := controller_accept.duplicate() as InputEventJoypadButton
	controller_accept_release.pressed = false
	viewport.push_input(controller_accept_release)
	await process_frame
	_assert_disclosed_diagnostic(viewport, technical_details, "controller activation")
	settings.open()


func _select_tab(tabs: TabContainer, control: Control, label: String) -> void:
	for index: int in range(tabs.get_tab_count()):
		if tabs.get_tab_control(index) == control:
			tabs.current_tab = index
			return
	_failures.append("%s tab control was not found" % label)


func _assert_initial_focus(profiles: ProfilesSettingsPage, expected: Control, frame: Rect2, viewport_size: Vector2i, state: String) -> void:
	var initial_focus := profiles.initial_focus()
	if initial_focus != expected:
		_failures.append("%s Profiles initial focus mismatch at %dx%d" % [state, viewport_size.x, viewport_size.y])
	_assert_visible_contained(initial_focus, frame, "%s Profiles initial focus" % state, viewport_size)
	if initial_focus.focus_mode == Control.FOCUS_NONE:
		_failures.append("%s Profiles initial focus is not focusable at %dx%d" % [state, viewport_size.x, viewport_size.y])
	if initial_focus is LineEdit and not (initial_focus as LineEdit).editable:
		_failures.append("%s Profiles initial focus is not editable at %dx%d" % [state, viewport_size.x, viewport_size.y])
	if initial_focus is ItemList and (initial_focus as ItemList).item_count == 0:
		_failures.append("%s Profiles initial list is empty at %dx%d" % [state, viewport_size.x, viewport_size.y])


func _assert_focus(viewport: SubViewport, expected: Control, label: String) -> void:
	var actual := viewport.gui_get_focus_owner()
	if actual != expected:
		_failures.append("%s mismatch: expected=%s actual=%s" % [label, expected.get_path(), actual.get_path() if actual != null else NodePath()])


func _assert_disclosed_diagnostic(viewport: SubViewport, details: LineEdit, label: String) -> void:
	if not details.visible:
		_failures.append("%s did not reveal technical details" % label)
	if not details.text.begins_with("PARTY_FORGE_SETTINGS_SAVE_ERROR"):
		_failures.append("%s did not preserve the raw save diagnostic: %s" % [label, details.text])
	_assert_focus(viewport, details, "%s technical-details focus" % label)


func _assert_visible_contained(control: Control, outer: Rect2, label: String, viewport_size: Vector2i) -> void:
	var rect := control.get_global_rect()
	if not control.is_visible_in_tree():
		_failures.append("%s is not visible at %dx%d" % [label, viewport_size.x, viewport_size.y])
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_failures.append("%s has non-positive post-layout size at %dx%d: %s" % [label, viewport_size.x, viewport_size.y, rect])
	if not ResponsiveGeometry.contains(outer, rect):
		_failures.append("%s overflows at %dx%d: outer=%s actual=%s" % [label, viewport_size.x, viewport_size.y, outer, rect])


func _assert_rect_near(actual: Rect2, expected: Rect2, label: String, viewport_size: Vector2i) -> void:
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s geometry differs at %dx%d: expected=%s actual=%s" % [label, viewport_size.x, viewport_size.y, expected, actual])
