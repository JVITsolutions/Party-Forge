extends SceneTree

const TREE_ID := "party-forge-city-v1"

var _failures: Array[String] = []
var _profile_root := ""
var _settings_path := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/main_menu_navigation_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_settings_path = "%s/party_forge_settings.cfg" % _profile_root
	ProfileTestSupport.remove_tree(_profile_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_profile_root))
	_cleanup_settings_fixture()
	var player_settings := PartyForgeSettings.new()
	player_settings.mode = PartyForgeSettings.Mode.PLAYER_SIMULATION
	player_settings.use_city_access_snapshot = true
	var fixture_error := PartyForgeSettingsStore.new().save_settings(player_settings, _settings_path)
	_assert(fixture_error.is_empty(), "fixture setup: navigation starts from saved Player Mode with City snapshot presentation enabled")
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
	main.settings_path = _settings_path
	root.add_child(main)
	await _frames(3)

	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var selector := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var passive_tree := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
	var warehouse_screen := main.get_node("WarehouseScreen") as WarehouseScreen
	var warehouse_locked := main.get_node("WarehouseLockedDialog") as Node
	var primary := menu.get_node("PrimaryAction") as Button
	var city := menu.get_node("CityTree") as Button
	var armoury_route := menu.get_node("Armoury") as Button
	var warehouse_route := menu.get_node("Warehouse") as Button
	var city_warehouse_origin := menu.get_node("CityWarehouseHotspot") as Button
	var warehouse_lock_badge := menu.get_node("Warehouse/LockBadge") as Label
	var city_warehouse_lock_badge := menu.get_node("CityWarehouseHotspot/LockBadge") as Label
	var view_city_tree := warehouse_locked.get_node("Overlay/Frame/Layout/Actions/ViewCityTree") as Button
	var warehouse_back := warehouse_locked.get_node("Overlay/Frame/Layout/Actions/Back") as Button
	var quick_start := menu.get_node("DeveloperQuickStart") as Button
	var menu_settings := menu.get_node("Settings") as Button
	var profiles := settings.get_node("Overlay/Frame/Layout/Tabs/Profiles") as ProfilesSettingsPage
	var profile_name := profiles.get_node("Layout/CreateRow/ProfileName") as LineEdit
	var preferred_color := profiles.get_node("Layout/CreateRow/PreferredColor") as OptionButton
	var profile_create := profiles.get_node("Layout/CreateRow/Create") as Button
	var tabs := settings.get_node("Overlay/Frame/Layout/Tabs") as TabContainer

	_assert(main.active_profile() == null and menu.is_open(), "fresh boot opens the real menu without a profile")
	_assert_focus(viewport, primary, "fresh boot PrimaryAction")
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert(settings.is_open() and tabs.get_tab_control(tabs.current_tab) == profiles, "controller south face opens Profiles from first-boot Play")
	_assert_focus(viewport, profile_name, "first-boot Profiles name")
	profile_name.text = "Task 8 Navigation"
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
	_assert_focus(viewport, preferred_color, "D-pad moves from profile name to Preferred Color")
	await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
	_assert_focus(viewport, profile_create, "D-pad moves from Preferred Color to Create")
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
	_assert_focus(viewport, warehouse_route, "device-1 D-pad includes the newly presented locked Warehouse")
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
	_assert_focus(viewport, warehouse_route, "keyboard arrow traverses the newly presented locked Warehouse")
	await _key(viewport, KEY_UP)
	_assert_focus(viewport, primary, "alternate-device flow returns to PrimaryAction")

	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 1.0)
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 0.0)
	_assert_focus(viewport, warehouse_route, "left stick includes the newly presented locked Warehouse")
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
	_assert_focus(viewport, warehouse_route, "keyboard arrow returns through locked Warehouse")
	await _key(viewport, KEY_UP)
	_assert_focus(viewport, primary, "keyboard arrow returns to PrimaryAction")
	await _key(viewport, KEY_SPACE)
	_assert(selector.is_open() and not menu.is_open(), "keyboard Space activates run setup")
	var fighter := selector.selection_focus(&"fighter") as Button
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

	var locked_profile_bytes := ProfileCodec.encode(main.active_profile()).to_utf8_buffer()
	var locked_profile_document := main.active_profile().to_dictionary()
	_assert(warehouse_route.visible and not warehouse_route.disabled and warehouse_lock_badge.visible and warehouse_lock_badge.text == "LOCKED", "Player snapshot activation presents the main-menu Warehouse as visibly locked")
	_assert(city_warehouse_origin.visible and not city_warehouse_origin.disabled and city_warehouse_lock_badge.visible and city_warehouse_lock_badge.text == "LOCKED", "Player snapshot activation presents the City Warehouse hotspot as visibly locked")

	warehouse_route.grab_focus()
	await _frames(1)
	_assert_focus(viewport, warehouse_route, "keyboard locked Warehouse origin")
	await _key(viewport, KEY_ENTER)
	await _frames(2)
	_assert(bool(warehouse_locked.call("is_open")) and menu.is_open() and not warehouse_screen.is_open(), "keyboard activation opens locked guidance without dispatching Warehouse storage")
	_assert_focus(viewport, view_city_tree, "keyboard locked guidance primary action")
	await _key(viewport, KEY_TAB)
	_assert_focus(viewport, warehouse_back, "locked dialog traps keyboard Tab on Back")
	await _key(viewport, KEY_TAB)
	_assert_focus(viewport, view_city_tree, "locked dialog wraps keyboard Tab to View City Tree")
	await _key(viewport, KEY_TAB)
	_assert_focus(viewport, warehouse_back, "locked dialog keeps repeated keyboard traversal inside its actions")
	await _key(viewport, KEY_ENTER)
	_assert(not bool(warehouse_locked.call("is_open")) and menu.is_open(), "keyboard Back closes locked guidance")
	_assert_focus(viewport, warehouse_route, "keyboard Back exact Warehouse origin restore")

	city_warehouse_origin.grab_focus()
	await _frames(1)
	_assert_focus(viewport, city_warehouse_origin, "controller locked City Warehouse origin")
	await _joy_button(viewport, JOY_BUTTON_A)
	await _frames(2)
	_assert(bool(warehouse_locked.call("is_open")) and menu.is_open() and not warehouse_screen.is_open(), "controller activation opens locked guidance without dispatching Warehouse storage")
	_assert_focus(viewport, view_city_tree, "controller locked guidance primary action")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(not bool(warehouse_locked.call("is_open")) and menu.is_open(), "controller B/Circle Back closes locked guidance")
	_assert_focus(viewport, city_warehouse_origin, "controller Back exact City Warehouse origin restore")

	warehouse_route.grab_focus()
	await _frames(1)
	await _key(viewport, KEY_ENTER)
	_assert(bool(warehouse_locked.call("is_open")), "Warehouse guidance reopens for City route reuse")
	_assert_focus(viewport, view_city_tree, "City route CTA starts from deterministic primary focus")
	await _joy_button(viewport, JOY_BUTTON_A)
	await _frames(2)
	_assert(not bool(warehouse_locked.call("is_open")) and passive_tree.is_open() and not menu.is_open(), "View City Tree reuses the existing passive-tree composition")
	_assert(main.get("_city_tree_return_focus") == warehouse_route, "City route retains the exact locked Warehouse return origin")
	_assert_focus_is_available(viewport.gui_get_focus_owner(), passive_tree, "Warehouse-guidance City tree")

	# Fixture-only durable mutation: simulate allocating Stash Access while the
	# existing City tree is open, then let the production close path refresh it.
	var store := ProfileStore.new()
	var stored_before := store.load_profile(profile_id, _profile_root)
	_assert(stored_before.ok(), "stash-allocation fixture reloads the durable locked profile")
	if stored_before.ok():
		var allocated := stored_before.profile
		allocated.permanent_feature_unlocks.append("stash")
		allocated.permanent_feature_unlocks.sort()
		var expected_after := locked_profile_document.duplicate(true)
		expected_after["permanent_feature_unlocks"] = allocated.permanent_feature_unlocks.duplicate()
		_assert(store.save_profile(allocated, _profile_root).is_empty(), "fixture explicitly persists only the simulated stash allocation")
		var stored_after := store.load_profile(profile_id, _profile_root)
		_assert(stored_after.ok() and stored_after.profile.to_dictionary() == expected_after, "durable fixture bytes change only by the explicit stash allocation")
		_assert(ProfileCodec.encode(main.active_profile()).to_utf8_buffer() == locked_profile_bytes, "open City route leaves the composed profile unchanged until close refresh")
	await _joy_button(viewport, JOY_BUTTON_B)
	await _frames(3)
	_assert(not passive_tree.is_open() and menu.is_open(), "controller closes the reused City tree")
	_assert_focus(viewport, warehouse_route, "refreshed City close exact Warehouse origin return")
	_assert(main.active_profile().permanent_feature_unlocks.has("stash"), "City close refreshes the explicit stash allocation into the composed profile")
	_assert(warehouse_route.visible and not warehouse_route.disabled and not warehouse_lock_badge.visible, "refreshed Warehouse origin becomes available without locked decoration")
	_assert(city_warehouse_origin.visible and not city_warehouse_origin.disabled and not city_warehouse_lock_badge.visible, "refreshed City Warehouse origin becomes available without locked decoration")

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
	var mode := additional.get_node("Layout/Scroll/Fields/Mode") as OptionButton
	_assert_focus(viewport, mode, "Additional Settings initial Mode focus")
	await _key(viewport, KEY_ENTER)
	_assert(mode.get_popup().visible, "keyboard Enter opens the real Mode dropdown")
	await _key(viewport, KEY_DOWN)
	await _key(viewport, KEY_ENTER)
	_assert(not mode.get_popup().visible, "keyboard selection closes the real Mode dropdown")
	_assert(mode.selected == PartyForgeSettings.Mode.DEVELOPER_MODE, "real keyboard input selects Developer Mode")
	var apply := additional.get_node("Layout/Actions/ApplyAndReturn") as Button
	var tab_guard := 0
	while viewport.gui_get_focus_owner() != apply and tab_guard < 16:
		await _key(viewport, KEY_TAB)
		_assert_focus_is_available(viewport.gui_get_focus_owner(), settings, "Settings Tab navigation")
		tab_guard += 1
	_assert_focus(viewport, apply, "keyboard Tab reaches Apply and Return")
	await _key(viewport, KEY_ENTER)
	_assert(not settings.is_open() and menu.is_open(), "Enter saves Developer Mode and returns to menu")
	_assert(main.saved_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE, "Developer Mode is saved into the composed main state")
	_assert(PartyForgeSettingsStore.new().load_settings(_settings_path).mode == PartyForgeSettings.Mode.DEVELOPER_MODE, "Developer Mode persists to the disposable settings store")
	_assert(quick_start.visible and not quick_start.disabled, "saved Developer Mode exposes Quick Start")
	_assert_focus(viewport, menu_settings, "Developer settings exact Settings return")
	armoury_route.grab_focus()
	await _frames(1)
	_assert_focus(viewport, armoury_route, "main-menu Armoury route origin")
	await _key(viewport, KEY_ENTER)
	await _frames(2)
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open() and not menu.is_open(), "main-menu Armoury opens through the production route")
	_assert(main.get("_storage_return_focus") == null, "main-menu Armoury leaves Warehouse return state unused")
	main.call("_on_armoury_closed")
	await _frames(2)
	_assert(menu.is_open() and not armoury.is_open(), "main-menu Armoury close returns to menu")
	_assert_focus(viewport, armoury_route, "main-menu Armoury exact origin return")
	_assert(main.get("_lobby_return_context") == PartyForgeMain.LobbyReturnContext.MAIN_MENU and main.get("_lobby_return_focus") == null, "main-menu Armoury consumes enum-backed return state")
	main.set("_lobby_return_context", PartyForgeMain.LobbyReturnContext.DEVELOPER_QUICK_START)
	main.set("_lobby_return_focus", quick_start)
	main.call("_on_armoury_closed")
	await _frames(2)
	_assert_focus(viewport, quick_start, "Developer Quick Start Armoury exact origin return")
	_assert(main.get("_lobby_return_context") == PartyForgeMain.LobbyReturnContext.MAIN_MENU and main.get("_lobby_return_focus") == null, "Developer Quick Start Armoury consumes enum-backed return state")
	await _key(viewport, KEY_DOWN)
	_assert_focus(viewport, menu_settings, "keyboard returns from Quick Start to Settings before stick traversal")
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
	if _settings_path.is_empty():
		return
	for path: String in [_settings_path, "%s.tmp" % _settings_path, "%s.bak" % _settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
