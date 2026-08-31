extends SceneTree

var _failures: Array[String] = []
var _suite_root := ""
var _focus_failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_suite_root = "user://tests/play_lobby_input/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_suite_root)
	root.size = Vector2i(1920, 1080)
	root.gui_focus_changed.connect(_on_focus_changed)
	await _test_preview_select_start_returns_and_recovery()
	await _test_warning_and_armoury_return()
	for failure: String in _focus_failures:
		_failures.append(failure)
	ProfileTestSupport.remove_tree(_suite_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_suite_root)):
		_failures.append("disposable input suite root was not removed")
	if _failures.is_empty():
		print("PLAY_LOBBY_ACTION_CONSUMERS: PASS")
		print("PLAY_LOBBY_INPUT_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PLAY_LOBBY_INPUT_FAILURE: %s" % failure)
	print("PLAY_LOBBY_INPUT_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _test_preview_select_start_returns_and_recovery() -> void:
	var paths := _fixture_paths("basic")
	var profile_id := _create_completed_profile(paths.profile_root, "Input Qualification", false)
	if profile_id.is_empty():
		return
	var main := await _instantiate_main(paths)
	if main == null:
		return
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	var primary := menu.get_node("PrimaryAction") as Button
	await _mouse_click(primary)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	_assert(lobby.is_open() and not menu.is_open(), "real mouse activates the production Play lobby")
	_assert_focus_available(root.gui_get_focus_owner(), lobby, "opened lobby")
	_assert_action_consumers(main, lobby)

	var fighter := lobby.selection_focus(&"fighter") as Button
	var mage := lobby.selection_focus(&"mage") as Button
	var settings_button := lobby.action_focus(&"settings") as Button
	var armoury_button := lobby.action_focus(&"armoury") as Button
	var start_button := lobby.action_focus(&"start") as Button
	var preview := lobby.find_child("Preview", true, false) as CharacterEquipmentPreview
	var prompt := lobby.get_node("Content/Margin/Layout/Footer/InputPrompt") as ForgeInputPrompt
	var axis_selection := lobby.selected_class_id()
	var axis_actions := _enabled_action_ids(lobby)
	var axis_status := (lobby.get_node("Content/Margin/Layout/Status") as Label).text
	fighter.grab_focus()
	await _joy_axis(JOY_AXIS_LEFT_X, 1.0)
	_assert(lobby.active_prompt_mode() == &"controller", "real joypad-axis motion switches the active lobby prompt")
	_assert_focus(preview, "real joypad-axis motion transfers the focused class to its hero preview")
	_assert(lobby.previewed_class_id() == &"fighter", "preview focus transfer preserves the source class")
	_assert(lobby.selected_class_id() == axis_selection and _enabled_action_ids(lobby) == axis_actions and (lobby.get_node("Content/Margin/Layout/Status") as Label).text == axis_status, "axis navigation preserves selection, action authority, and status")
	var preview_mount := preview.get_node("SubViewport/World/PreviewRoot") as Node3D
	var yaw_before := preview_mount.rotation.y
	await _joy_axis(JOY_AXIS_LEFT_X, 1.0)
	_assert_focus(preview, "controller rotation retains hero-preview focus")
	_assert(not is_equal_approx(preview_mount.rotation.y, yaw_before), "controller direction rotates the previewed model")
	await _joy_axis(JOY_AXIS_LEFT_X, -1.0)
	_assert_focus(preview, "reverse preview rotation does not select a right-column class")
	_assert(lobby.previewed_class_id() == &"fighter", "preview rotation never changes preview identity")
	fighter.grab_focus()
	await process_frame
	for child: Node in lobby.find_child("Grid", true, false).get_children():
		var class_card := child as ForgeClassCard
		if class_card == null:
			continue
		class_card.grab_focus()
		await process_frame
		var source_id := class_card.class_id
		await _key(KEY_RIGHT)
		_assert_focus(preview, "%s keyboard direction transfers to preview" % source_id)
		_assert(lobby.previewed_class_id() == source_id, "%s focus transfer keeps its exact preview identity" % source_id)
		yaw_before = preview_mount.rotation.y
		await _joy_button(JOY_BUTTON_DPAD_RIGHT)
		_assert_focus(preview, "%s controller rotation keeps preview focus" % source_id)
		_assert(not is_equal_approx(preview_mount.rotation.y, yaw_before), "%s controller direction rotates its preview" % source_id)
		_assert(lobby.previewed_class_id() == source_id and lobby.selected_class_id() == axis_selection, "%s preview traversal never selects another class" % source_id)
	fighter.grab_focus()
	await process_frame
	var prompt_focus := root.gui_get_focus_owner()
	await _joy_button(JOY_BUTTON_LEFT_STICK)
	_assert(lobby.active_prompt_mode() == &"controller", "simulated controller switches the active lobby prompt")
	_assert(root.gui_get_focus_owner() == prompt_focus, "prompt-only controller observation does not steal focus")
	_assert(prompt.device_kind == &"controller", "visible lobby prompt presents controller mode")
	await _mouse_motion(mage.get_global_rect().get_center())
	_assert(lobby.active_prompt_mode() == &"keyboard_mouse", "real mouse motion restores keyboard/mouse prompts")
	_assert(lobby.previewed_class_id() == &"mage" and lobby.selected_class_id().is_empty(), "mouse hover previews Mage without selecting or starting")
	_assert(not main.run_started, "preview alone never starts the run")
	await _mouse_click(mage)
	_assert(lobby.selected_class_id() == &"mage" and not main.run_started, "real mouse class activation selects Mage without starting")
	_assert(not start_button.disabled, "selection enables the separate Start Run action")
	await _mouse_motion(fighter.get_global_rect().get_center())
	_assert(lobby.selected_class_id() == &"mage" and lobby.previewed_class_id() == &"fighter", "select-A preview-B remains orthogonal under real mouse input")
	_assert((prompt.get_node("Content/Label") as Label).text.ends_with("Start Run"), "selected lobby prompt contextualizes accept as Start Run")

	await _mouse_click(settings_button)
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	_assert(settings.is_open() and lobby.is_open(), "lobby Settings intent opens the production Settings overlay")
	await _key(KEY_ESCAPE)
	_assert(not settings.is_open() and lobby.is_open(), "real keyboard cancel returns from Settings to the lobby")
	_assert_focus(settings_button, "Settings returns to its exact lobby origin")

	await _mouse_click(armoury_button)
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open() and not lobby.is_open(), "direct lobby Armoury intent opens the production Armoury")
	await _joy_button(JOY_BUTTON_B)
	_assert(not armoury.is_open() and lobby.is_open(), "real controller cancel returns from direct Armoury")
	_assert_focus(armoury_button, "direct Armoury returns to its exact lobby origin")
	_assert(lobby.selected_class_id() == &"mage" and lobby.previewed_class_id() == &"fighter", "direct Armoury round trip preserves selected and previewed identities")

	await _key(KEY_TAB)
	_assert_focus(lobby.action_focus(&"select"), "keyboard Tab advances from Armoury to Select")
	await _key(KEY_TAB)
	_assert_focus(start_button, "keyboard Tab advances from Select to Start")
	var starts: Array[StringName] = []
	lobby.start_requested.connect(func(class_id: StringName) -> void: starts.append(class_id))
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_assert(starts == ([&"mage"] as Array[StringName]), "real keyboard Start emits exact selected Mage once and rejects duplicate activation")
	_assert(main.run_started and main.leader != null, "separate Start action launches the production run")
	_assert(not lobby.is_open(), "successful Start closes the lobby")
	var runtime_focus := root.gui_get_focus_owner()
	_assert(runtime_focus == null or (runtime_focus.is_visible_in_tree() and runtime_focus.focus_mode != Control.FOCUS_NONE), "run start leaves no hidden or disabled focus owner")
	_assert(runtime_focus == null or not lobby.is_ancestor_of(runtime_focus), "run start releases all hidden lobby focus")

	main.free()
	await _frames(3)
	var restarted := await _instantiate_main(paths)
	if restarted != null:
		var restarted_menu := restarted.get_node("MainMenuScreen") as MainMenuScreen
		await _mouse_click(restarted_menu.get_node("PrimaryAction") as Button)
		var recovery := restarted.get_node("RunRecoveryDialog")
		var restarted_lobby := restarted.get_node("HUD/ClassSelection") as ClassSelectionPanel
		_assert(bool(recovery.call("is_open")) and not restarted_lobby.is_open(), "resumable-run recovery takes precedence over the stale direct run-setup route")
		_assert_focus_available(root.gui_get_focus_owner(), recovery, "recovery precedence dialog")
		restarted.free()
		await _frames(2)
	ProfileTestSupport.remove_tree(paths.fixture_root)


func _test_warning_and_armoury_return() -> void:
	var paths := _fixture_paths("warning")
	var profile_id := _create_completed_profile(paths.profile_root, "Warning Qualification", true)
	if profile_id.is_empty():
		return
	var main := await _instantiate_main(paths)
	if main == null:
		return
	var menu := main.get_node("MainMenuScreen") as MainMenuScreen
	await _mouse_click(menu.get_node("PrimaryAction") as Button)
	var lobby := main.get_node("HUD/ClassSelection") as ClassSelectionPanel
	var mage := lobby.selection_focus(&"mage") as Button
	await _mouse_click(mage)
	_assert(lobby.selected_class_id() == &"mage", "warning fixture selects Mage with real mouse input")
	var start := lobby.action_focus(&"start") as Button
	_assert(not start.disabled, "Needs Attention keeps Start authoritative")
	await _mouse_click(start)
	var warning := main.get_node("LoadoutWarningDialog")
	_assert(bool(warning.call("is_open")) and lobby.compatibility_gate_active(), "Needs Attention Start opens the existing warning flow")
	_assert_focus_available(root.gui_get_focus_owner(), warning, "loadout warning")
	await _mouse_click(warning.get_node("Overlay/Frame/Layout/Actions/ChooseAnother") as Button)
	_assert(not bool(warning.call("is_open")) and lobby.is_open(), "Choose Another returns to the lobby")
	_assert_focus(mage, "warning Choose Another returns to exact selected class")

	await _mouse_click(start)
	_assert(bool(warning.call("is_open")), "warning flow can be reopened after safe cancellation")
	await _mouse_click(warning.get_node("Overlay/Frame/Layout/Actions/Armoury") as Button)
	var armoury := main.get_node("ArmouryScreen") as ArmouryScreen
	_assert(armoury.is_open() and not bool(warning.call("is_open")) and not lobby.is_open(), "warning Armoury intent opens the production Armoury")
	await _joy_button(JOY_BUTTON_B)
	_assert(not armoury.is_open() and lobby.is_open(), "real controller cancel returns from warning Armoury")
	_assert_focus(mage, "warning Armoury returns to the exact selected class")
	_assert(lobby.selected_class_id() == &"mage", "warning Armoury round trip preserves selected class")
	main.free()
	await _frames(2)
	ProfileTestSupport.remove_tree(paths.fixture_root)


func _fixture_paths(label: String) -> Dictionary:
	var fixture_root := _suite_root.path_join("%s-%d" % [label, Time.get_ticks_usec()])
	return {
		"fixture_root": fixture_root,
		"profile_root": fixture_root.path_join("profiles"),
		"settings_path": fixture_root.path_join("settings.cfg"),
	}


func _create_completed_profile(profile_root: String, display_name: String, seed_fighter_item: bool) -> String:
	var manager := ProfileManager.new()
	_assert(manager.bootstrap(profile_root).is_empty(), "%s fixture manager bootstraps" % display_name)
	var created := manager.create_profile(display_name)
	_assert(created.ok(), "%s fixture profile is created" % display_name)
	if not created.ok():
		return ""
	var profile_id := created.profile.profile_id
	var completion := ProfileMutationService.new(ProfileStore.new()).complete_prologue(profile_id, "play-lobby-%s-complete" % profile_id, profile_root)
	_assert(completion.ok(), "%s fixture completes prologue" % display_name)
	var loaded := ProfileStore.new().load_profile(profile_id, profile_root)
	_assert(loaded.ok(), "%s fixture reloads for storage setup" % display_name)
	if not loaded.ok():
		return ""
	var profile := loaded.profile
	for unlock: String in ["bring_in_gear", "equipment_inventory", "stash"]:
		if unlock not in profile.permanent_feature_unlocks:
			profile.permanent_feature_unlocks.append(unlock)
	if seed_fighter_item:
		var item := ItemInstance.new()
		item.instance_id = "item-input-warning-%s" % profile_id
		item.base_definition_id = &"dawn_bulwark_plate"
		item.item_level = 28
		item.rarity_id = &"common"
		item.origin = {"issuer_namespace": "profile:%s" % profile_id, "seed": 90210, "sequence": 0, "source": "play_lobby_input_runner"}
		profile.item_records = ItemRegistry.new([item]).to_dictionary()
		profile.leader_loadout = ItemSlotContainer.create(
			&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile_id,
			EquipmentSlotIndex.capacity(), {EquipmentSlotIndex.index_for(&"body_armour"): item.instance_id},
		).to_dictionary()
		profile.leader_loadout_class_id = "fighter"
	var save_error := ProfileStore.new().save_profile(profile, profile_root)
	_assert(save_error.is_empty(), "%s fixture storage state persists" % display_name)
	return profile_id


func _instantiate_main(paths: Dictionary) -> PartyForgeMain:
	var settings_error := PartyForgeSettingsStore.new().save_settings(PartyForgeSettings.new(), String(paths.settings_path))
	_assert(settings_error.is_empty(), "fixture settings save")
	var main_scene := load("res://scenes/game/main.tscn") as PackedScene
	_assert(main_scene != null, "production Main scene loads")
	if main_scene == null:
		return null
	var main := main_scene.instantiate() as PartyForgeMain
	main.profile_root = String(paths.profile_root)
	main.settings_path = String(paths.settings_path)
	root.add_child(main)
	await _frames(5)
	return main


func _assert_action_consumers(main: PartyForgeMain, lobby: ClassSelectionPanel) -> void:
	_assert(lobby.class_preview_requested.is_connected(Callable(main, "_on_lobby_class_preview_requested")), "class preview intent is consumed by composed Main")
	_assert(lobby.class_selection_requested.is_connected(Callable(main, "_on_lobby_class_selection_requested")), "class selection intent is consumed by composed Main")
	_assert(lobby.start_requested.is_connected(Callable(main, "_on_lobby_start_requested")), "Start intent is consumed by composed Main")
	_assert(lobby.settings_requested.is_connected(Callable(main, "_open_settings")), "Settings intent is consumed by composed Main")
	_assert(lobby.armoury_requested.is_connected(Callable(main, "_on_lobby_armoury_requested")), "Armoury intent is consumed by composed Main")
	_assert(lobby.back_requested.is_connected(Callable(main, "_on_run_setup_back_requested")), "Back intent is consumed by composed Main")
	var action_bar := lobby.get_node("Content/Margin/Layout/Footer/ActionBar") as ForgeActionBar
	_assert(action_bar.action_requested.is_connected(Callable(lobby, "_on_action_requested")), "every enabled footer button enters the lobby action consumer")
	for child: Node in lobby.find_child("Grid", true, false).get_children():
		var card := child as ForgeClassCard
		if card != null and not card.disabled:
			_assert(card.preview_requested.is_connected(Callable(lobby, "_on_class_preview_requested")), "%s preview intent has a consumer" % card.name)
			_assert(card.selection_requested.is_connected(Callable(lobby, "_on_class_selection_requested")), "%s selection intent has a consumer" % card.name)


func _mouse_click(target: Control) -> void:
	var position := target.get_global_rect().get_center()
	await _mouse_motion(position)
	var press := InputEventMouseButton.new()
	press.position = position
	press.global_position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	root.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	root.push_input(release)
	await process_frame


func _mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = position - root.get_mouse_position()
	root.push_input(event)
	await process_frame


func _key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	root.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)
	await process_frame


func _joy_button(button: JoyButton) -> void:
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = button
	press.pressed = true
	root.push_input(press)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release)
	await process_frame


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = axis
	motion.axis_value = value
	root.push_input(motion)
	Input.parse_input_event(motion)
	await process_frame
	var neutral := motion.duplicate() as InputEventJoypadMotion
	neutral.axis_value = 0.0
	root.push_input(neutral)
	Input.parse_input_event(neutral)
	await process_frame


func _enabled_action_ids(lobby: ClassSelectionPanel) -> Array[StringName]:
	var result: Array[StringName] = []
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		var button := lobby.action_focus(action_id) as Button
		if button != null and bool(button.get_meta(&"action_enabled", false)):
			result.append(action_id)
	return result


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert_focus(expected: Control, label: String) -> void:
	var actual := root.gui_get_focus_owner()
	_assert(actual == expected, "%s expected=%s actual=%s" % [label, expected.get_path() if expected != null else NodePath(), actual.get_path() if actual != null else NodePath()])
	_assert_focus_available(actual, null, label)


func _assert_focus_available(control: Control, ancestor: Node, label: String) -> void:
	_assert(control != null, "%s owns a focus control" % label)
	if control == null:
		return
	_assert(control.is_inside_tree() and control.is_visible_in_tree(), "%s focus is visible" % label)
	_assert(control.focus_mode != Control.FOCUS_NONE, "%s focus is enabled" % label)
	if control is BaseButton:
		_assert(not (control as BaseButton).disabled, "%s focus button is actionable" % label)
	if ancestor != null:
		_assert(ancestor.is_ancestor_of(control), "%s focus stays inside expected surface" % label)


func _on_focus_changed(control: Control) -> void:
	if control == null:
		return
	if not control.is_inside_tree() or not control.is_visible_in_tree():
		_focus_failures.append("focus change entered hidden control: %s" % control.get_path())
	if control.focus_mode == Control.FOCUS_NONE:
		_focus_failures.append("focus change entered focus-disabled control: %s" % control.get_path())
	if control is BaseButton and (control as BaseButton).disabled:
		_focus_failures.append("focus change entered disabled button: %s" % control.get_path())


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
