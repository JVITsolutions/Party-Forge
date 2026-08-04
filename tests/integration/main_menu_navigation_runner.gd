extends SceneTree

const TREE_ID := "party-forge-city-v1"

var _failures: Array[String] = []
var _profile_root := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/main_menu_navigation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
	_cleanup_settings_fixture()
	var fixture_error := PartyForgeSettingsStore.new().save_settings(PartyForgeSettings.new())
	_assert(fixture_error.is_empty(), "fixture setup: navigation starts from saved Player Mode")
	if not fixture_error.is_empty():
		await _finish(null)
		return
	var viewport: Viewport = root
	root.size = Vector2i(1920, 1080)
	viewport.gui_focus_changed.connect(_on_focus_changed)
	var main_scene := load("res://scenes/game/main.tscn") as PackedScene
	_assert(main_scene != null, "fixture setup: composed main scene loads")
	if main_scene == null:
		await _finish(null)
		return
	var main := main_scene.instantiate() as PartyForgeMain
	main.profile_root = _profile_root
	root.add_child(main)
	await _frames(3)

	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var passive_tree := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
	var primary := menu.get_node("PrimaryAction") as Button
	var city := menu.get_node("CityTree") as Button
	var quick_start := menu.get_node("DeveloperQuickStart") as Button
	var menu_settings := menu.get_node("Settings") as Button
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var profile_create := profiles.get_node("Layout/CreateRow/Create") as Button
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer

	_assert(main.active_profile() == null and menu.is_open(), "fresh boot opens the real menu without a profile")
	_assert_focus(viewport, primary, "fresh boot PrimaryAction")
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert(settings.is_open() and tabs.get_tab_control(tabs.current_tab) == profiles, "controller south face opens Profiles from first-boot Play")
	_assert_focus(viewport, profile_name, "first-boot Profiles name")
	profile_name.text = "Task 8 Navigation"
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
	_assert_focus(viewport, profile_create, "D-pad moves from profile name to Create")
	await _joy_button(viewport, JOY_BUTTON_A)
	await _frames(2)
	_assert(main.active_profile() != null and main.active_profile().display_name == "Task 8 Navigation", "controller activation creates the profile")
	_assert(menu.is_open() and not settings.is_open(), "profile creation returns to the main menu")
	_assert_focus(viewport, primary, "profile creation exact PrimaryAction return")
	if main.active_profile() == null:
		await _finish(main)
		return

	_assert(_ui_joy_mapping_has_device(&"ui_accept", JOY_BUTTON_A, -1), "ui_accept maps controller south face for any device")
	_assert(_ui_joy_mapping_has_device(&"ui_cancel", JOY_BUTTON_B, -1), "ui_cancel maps controller B/Circle for any device")
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN, 1)
	_assert_focus(viewport, menu_settings, "device-1 D-pad uses standard ui_down")
	await _joy_button(viewport, JOY_BUTTON_A, 1)
	_assert(settings.is_open(), "device-1 south face activates main-menu Settings")
	if not settings.is_open():
		await _key(viewport, KEY_ENTER)
	await _joy_button(viewport, JOY_BUTTON_B, 1)
	_assert(not settings.is_open(), "device-1 B/Circle closes Settings")
	if settings.is_open():
		await _key(viewport, KEY_ESCAPE)
	_assert_focus(viewport, menu_settings, "device-1 cancel exact Settings return")
	await _key(viewport, KEY_UP)
	_assert_focus(viewport, primary, "alternate-device flow returns to PrimaryAction")

	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 1.0)
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 0.0)
	_assert_focus(viewport, menu_settings, "left stick uses standard ui_down on the main menu")
	await _key(viewport, KEY_ENTER)
	_assert(settings.is_open(), "keyboard Enter activates main-menu Settings")
	var tab_before := tabs.current_tab
	await _joy_button(viewport, JOY_BUTTON_RIGHT_SHOULDER)
	_assert(tabs.current_tab == posmod(tab_before + 1, tabs.get_tab_count()), "right shoulder advances the Settings tab")
	var settings_focus := viewport.gui_get_focus_owner()
	_assert_focus_is_available(settings_focus, settings, "shoulder-selected Settings page")
	await _joy_button(viewport, JOY_BUTTON_LEFT_SHOULDER)
	_assert(tabs.current_tab == tab_before, "left shoulder restores the Settings tab")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(not settings.is_open() and menu.is_open(), "controller B closes Settings")
	if settings.is_open():
		await _key(viewport, KEY_ESCAPE)
	_assert_focus(viewport, menu_settings, "controller cancel exact Settings return")

	await _key(viewport, KEY_UP)
	_assert_focus(viewport, primary, "keyboard arrow returns to PrimaryAction")
	await _key(viewport, KEY_SPACE)
	_assert(selector.is_open() and not menu.is_open(), "keyboard Space activates run setup")
	var fighter := selector.get_node("Content/Scroll/Grid/Class_fighter") as Button
	_assert_focus(viewport, fighter, "run setup initial Fighter")
	await _key(viewport, KEY_ESCAPE)
	_assert(menu.is_open() and not selector.is_open(), "keyboard Escape returns from run setup")
	_assert_focus(viewport, primary, "run-setup cancel exact PrimaryAction return")

	var profile_id := main.active_profile().profile_id
	var mutation := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "task-8-complete", _profile_root)
	_assert(mutation.ok(), "completed-profile fixture uses the production prologue mutation")
	_assert(main.profile_manager.refresh_profile(profile_id).is_empty(), "main profile manager refreshes completed profile")
	await _frames(2)
	_assert(city.visible and not city.disabled, "completed profile exposes City")
	await _key(viewport, KEY_TAB)
	_assert_focus(viewport, city, "keyboard Tab moves to the exact City origin")
	await _mouse_click(viewport, city)
	_assert(passive_tree.is_open() and not menu.is_open(), "actual mouse press/release opens City")
	var tree_focus := viewport.gui_get_focus_owner()
	_assert_focus_is_available(tree_focus, passive_tree, "opened City")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(not passive_tree.is_open() and menu.is_open(), "controller B closes City")
	_assert_focus(viewport, city, "City cancel exact CityTree return")

	await _key(viewport, KEY_TAB)
	_assert_focus(viewport, menu_settings, "keyboard Tab skips hidden Developer Quick Start in Player Mode")
	await _key(viewport, KEY_ENTER)
	_assert(settings.is_open(), "keyboard Enter reopens Settings for saved Developer Mode")
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
	var shoulder_steps := 0
	while tabs.get_tab_control(tabs.current_tab) != additional and shoulder_steps < tabs.get_tab_count():
		await _joy_button(viewport, JOY_BUTTON_RIGHT_SHOULDER)
		shoulder_steps += 1
	_assert(tabs.get_tab_control(tabs.current_tab) == additional, "shoulder navigation reaches Additional Settings")
	var mode := additional.get_node("Layout/Mode") as OptionButton
	_assert_focus(viewport, mode, "Additional Settings initial Mode focus")
	await _key(viewport, KEY_ENTER)
	_assert(mode.get_popup().visible, "keyboard Enter opens the real Mode dropdown")
	await _key(viewport, KEY_DOWN)
	await _key(viewport, KEY_ENTER)
	_assert(not mode.get_popup().visible, "keyboard selection closes the real Mode dropdown")
	_assert(mode.selected == PartyForgeSettings.Mode.DEVELOPER_MODE, "real keyboard input selects Developer Mode")
	var apply := additional.get_node("Layout/ApplyAndReturn") as Button
	var tab_guard := 0
	while viewport.gui_get_focus_owner() != apply and tab_guard < 16:
		await _key(viewport, KEY_TAB)
		_assert_focus_is_available(viewport.gui_get_focus_owner(), settings, "Settings Tab navigation")
		tab_guard += 1
	_assert_focus(viewport, apply, "keyboard Tab reaches Apply and Return")
	await _key(viewport, KEY_ENTER)
	_assert(not settings.is_open() and menu.is_open(), "Enter saves Developer Mode and returns to menu")
	_assert(main.saved_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE, "Developer Mode is saved into the composed main state")
	_assert(PartyForgeSettingsStore.new().load_settings().mode == PartyForgeSettings.Mode.DEVELOPER_MODE, "Developer Mode persists to the real settings store")
	_assert(quick_start.visible and not quick_start.disabled, "saved Developer Mode exposes Quick Start")
	_assert_focus(viewport, menu_settings, "Developer settings exact Settings return")
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, -1.0)
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 0.0)
	_assert_focus(viewport, quick_start, "left stick navigates to Developer Quick Start")
	await _joy_button(viewport, JOY_BUTTON_A)
	await _frames(2)
	_assert(main.run_started and main.leader != null, "controller south face launches saved Developer Quick Start")
	_assert(main.party_manager.members.size() == 1 and main.party_manager.members[0].class_definition.id == &"fighter", "Quick Start uses the production Fighter launch")
	_assert(not menu.is_open() and not selector.is_open(), "Quick Start leaves no hidden front-end surface focused")
	var runtime_focus := viewport.gui_get_focus_owner()
	_assert(runtime_focus == null or (runtime_focus.is_visible_in_tree() and runtime_focus.focus_mode != Control.FOCUS_NONE), "Quick Start has no hidden or disabled focus owner")
	_assert(runtime_focus == null or (not menu.is_ancestor_of(runtime_focus) and not selector.is_ancestor_of(runtime_focus)), "Quick Start releases hidden front-end focus")

	await _finish(main)


func _key(viewport: Viewport, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _joy_button(viewport: Viewport, button: JoyButton, device: int = 0) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _joy_motion(viewport: Viewport, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	viewport.push_input(event)
	Input.parse_input_event(event)
	await process_frame


func _mouse_click(viewport: Viewport, target: Button) -> void:
	var position := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = position - viewport.get_mouse_position()
	viewport.push_input(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert_focus(viewport: Viewport, expected: Control, label: String) -> void:
	var actual := viewport.gui_get_focus_owner()
	_assert(actual == expected, "%s focus expected=%s actual=%s" % [label, expected.get_path(), actual.get_path() if actual != null else NodePath()])
	_assert_focus_is_available(actual, null, label)


func _assert_focus_is_available(control: Control, required_ancestor: Node, label: String) -> void:
	_assert(control != null, "%s owns a real focus control" % label)
	if control == null:
		return
	_assert(control.is_inside_tree() and control.is_visible_in_tree(), "%s focus is visible in tree: %s" % [label, control.get_path()])
	_assert(control.focus_mode != Control.FOCUS_NONE, "%s focus remains enabled: %s" % [label, control.get_path()])
	if control is BaseButton:
		_assert(not (control as BaseButton).disabled, "%s focus is not disabled: %s" % [label, control.get_path()])
	if required_ancestor != null:
		_assert(required_ancestor.is_ancestor_of(control), "%s focus belongs to %s: %s" % [label, required_ancestor.get_path(), control.get_path()])


func _on_focus_changed(control: Control) -> void:
	if control == null:
		return
	_assert(control.is_inside_tree() and control.is_visible_in_tree(), "focus change never enters a hidden control: %s" % control.get_path())
	_assert(control.focus_mode != Control.FOCUS_NONE, "focus change never enters a disabled-focus control: %s" % control.get_path())
	if control is BaseButton:
		_assert(not (control as BaseButton).disabled, "focus change never enters a disabled button: %s" % control.get_path())


func _ui_joy_mapping_has_device(action_id: StringName, button: JoyButton, device: int) -> bool:
	return InputMap.action_get_events(action_id).any(func(event: InputEvent) -> bool:
		return event is InputEventJoypadButton \
			and (event as InputEventJoypadButton).button_index == button \
			and event.device == device
	)


func _finish(main: PartyForgeMain) -> void:
	paused = false
	if main != null and is_instance_valid(main):
		main.free()
	ProfileTestSupport.remove_tree(_profile_root)
	_cleanup_settings_fixture()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable navigation profile root was not removed")
	if _failures.is_empty():
		print("MAIN_MENU_NAVIGATION_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("MAIN_MENU_NAVIGATION_FAILURE: %s" % failure)
	print("MAIN_MENU_NAVIGATION_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _cleanup_settings_fixture() -> void:
	for path: String in [PartyForgeSettingsStore.DEFAULT_PATH, "%s.tmp" % PartyForgeSettingsStore.DEFAULT_PATH, "%s.bak" % PartyForgeSettingsStore.DEFAULT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
