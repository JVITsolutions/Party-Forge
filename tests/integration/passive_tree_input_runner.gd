extends SceneTree

const TREE_ID := "party-forge-city-v1"

var _failures: Array[String] = []
var _profile_root := ""
var _invalid_path := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/passive_tree_input_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_invalid_path = _profile_root.path_join("invalid-city.pstree.json")
	ProfileTestSupport.remove_tree(_profile_root)

	var viewport := SubViewport.new()
	viewport.disable_3d = false
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := (load("res://scenes/game/main.tscn") as PackedScene).instantiate() as PartyForgeMain
	main.profile_root = _profile_root
	viewport.add_child(main)
	await _frames(3)

	var manager := main.profile_manager
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	var screen := main.get_node("PassiveTreeScreen") as PassiveTreeScreen
	var settings_button := main.get_node("HUD/ClassSelection/Content/Actions/Settings") as Button
	_assert(manager != null and settings != null and screen != null, "composed Main exposes profile, Settings, and passive-tree services")
	if manager == null or settings == null or screen == null:
		await _finish(viewport)
		return

	var created := manager.create_profile("Passive Input Profile", 1000)
	_assert(created.ok(), "profile is created through the composed production manager")
	var profile_id := created.profile.profile_id if created.ok() else ""
	if profile_id.is_empty():
		await _finish(viewport)
		return
	_assert(manager.select_profile(profile_id).is_empty(), "profile can be selected through production manager")
	var profile_mutations := ProfileMutationService.new(ProfileStore.new())
	var prologue := profile_mutations.complete_prologue(profile_id, "input-runner-discover", _profile_root)
	_assert(prologue.ok(), "input profile discovers the City through the production prologue mutation")
	var grant := profile_mutations.grant_passive_points(profile_id, "input-runner-grant", 5, _profile_root)
	_assert(grant.ok(), "input profile receives test points through grant_passive_points")
	var persisted := ProfileStore.new().load_profile(profile_id, _profile_root)
	if persisted.ok():
		var allocations: Array = persisted.profile.tree_allocations.get(TREE_ID, []) as Array
		allocations.append_array(["removed-zeta", "removed-alpha"])
		persisted.profile.tree_allocations[TREE_ID] = allocations
		_assert(ProfileStore.new().save_profile(persisted.profile, _profile_root).is_empty(), "input fixture stores unresolved historical allocation IDs")
	_assert(manager.refresh_profile(profile_id).is_empty(), "composed manager refreshes the mutation results")

	settings.close()
	await _frames(2)
	_assert(viewport.gui_get_focus_owner() == settings_button, "fresh-profile Settings close restores the original caller")
	settings_button.pressed.emit()
	await _frames(2)
	settings.open_additional(settings_button)
	await _frames(2)
	var additional := settings.get_node("Overlay/Frame/Layout/Tabs/Additional Settings") as AdditionalSettingsPage
	var mode := additional.get_node("Layout/Mode") as OptionButton
	var capacity := additional.get_node("Layout/PartyCapacity/Value") as HSlider
	var open_tree := additional.get_node("Layout/OpenCityPassiveTree") as Button
	mode.select(PartyForgeSettings.Mode.DEVELOPER_MODE)
	mode.item_selected.emit(PartyForgeSettings.Mode.DEVELOPER_MODE)
	capacity.value = 9
	_assert(not open_tree.disabled, "Developer draft enables Open City Passive Tree")
	var before_view := manager.active_profile()
	var before_allocations := before_view.tree_allocations.duplicate(true)
	var before_visibility := before_view.tree_visibility_progress.duplicate(true)
	open_tree.pressed.emit()
	await _frames(3)
	_assert(screen.is_open() and not settings.is_open(), "Developer Settings request opens the composed tree screen")
	_assert(manager.active_profile().tree_allocations == before_allocations, "Developer reveal does not persist allocations before an explicit mutation")
	_assert(manager.active_profile().tree_visibility_progress == before_visibility, "Developer reveal does not persist visibility")

	var canvas := screen.get_node("Overlay/Frame/Layout/Body/Canvas") as PassiveTreeCanvas
	_assert(canvas.selected_node_id() == &"city-heart", "tree opens on the allocated City root")
	await _mouse_click(viewport, canvas.node_control(&"city-heart").get_global_rect().get_center())
	_assert(canvas.selected_node_id() == &"city-heart", "mouse click selects a real tree node")

	await _joy_motion(viewport, JOY_AXIS_LEFT_X, 1.0)
	_assert(canvas.selected_node_id() == &"equipment-registry", "device-0 left stick navigates to the linked right node")
	var detail_sections := (screen.get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/DetailSections") as Label).text
	_assert(detail_sections.contains("Cost") and detail_sections.contains("Refund Policy"), "composed selected detail discloses cost and refund policy")
	_assert(detail_sections.contains("Coming Soon") and detail_sections.contains("Developer Preview"), "composed Developer detail discloses future-contract state")
	_assert((screen.get_node("Overlay/Frame/Layout/Unresolved") as Label).text == "Unresolved saved allocations: removed-alpha, removed-zeta", "composed screen discloses sorted unresolved saved allocations")
	await _joy_motion(viewport, JOY_AXIS_LEFT_X, 0.0)

	var pan_before_controller := canvas.pan_value()
	await _joy_motion(viewport, JOY_AXIS_RIGHT_X, 1.0, 4)
	await _joy_motion(viewport, JOY_AXIS_RIGHT_X, 0.0)
	_assert(canvas.pan_value().x > pan_before_controller.x, "device-0 right stick continuously pans the tree")
	var zoom_before_controller := canvas.zoom_value()
	await _joy_motion(viewport, JOY_AXIS_TRIGGER_RIGHT, 1.0, 4)
	await _joy_motion(viewport, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_assert(canvas.zoom_value() > zoom_before_controller, "device-0 right trigger continuously zooms in")

	var blank_point := _canvas_blank_point(canvas)
	var pan_before_middle := canvas.pan_value()
	await _mouse_drag(viewport, blank_point, Vector2(45, 24), MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_MASK_MIDDLE)
	_assert(canvas.pan_value().distance_to(pan_before_middle) > 1.0, "middle-mouse drag pans the real canvas")
	var pan_before_right := canvas.pan_value()
	await _mouse_drag(viewport, blank_point, Vector2(-31, 18), MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MASK_RIGHT)
	_assert(canvas.pan_value().distance_to(pan_before_right) > 1.0, "right-mouse drag pans the real canvas")
	var zoom_before_wheel := canvas.zoom_value()
	await _mouse_wheel(viewport, blank_point, MOUSE_BUTTON_WHEEL_DOWN)
	_assert(canvas.zoom_value() < zoom_before_wheel, "mouse wheel zooms the real canvas")

	await _joy_button(viewport, JOY_BUTTON_A)
	_assert((screen.get_node("Overlay/Confirmation") as Control).visible, "controller south face initiates allocation confirmation")
	var confirm_button := screen.get_node("Overlay/Confirmation/Content/Buttons/ConfirmButton") as Button
	var cancel_button := screen.get_node("Overlay/Confirmation/Content/Buttons/CancelButton") as Button
	_assert(viewport.gui_get_focus_owner() == cancel_button, "modal confirmation starts keyboard focus on Cancel")
	for _index: int in 2:
		await _key(viewport, KEY_TAB)
		_assert(viewport.gui_get_focus_owner() in [confirm_button, cancel_button], "Tab focus remains trapped inside confirmation")
		await _key_with_shift(viewport, KEY_TAB)
		_assert(viewport.gui_get_focus_owner() in [confirm_button, cancel_button], "Shift-Tab focus remains trapped inside confirmation")
		await _joy_button(viewport, JOY_BUTTON_DPAD_LEFT)
		_assert(viewport.gui_get_focus_owner() in [confirm_button, cancel_button], "D-pad focus remains trapped inside confirmation")
		await _key(viewport, KEY_RIGHT)
		_assert(viewport.gui_get_focus_owner() in [confirm_button, cancel_button], "arrow focus remains trapped inside confirmation")
	cancel_button.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert(not (screen.get_node("Overlay/Confirmation") as Control).visible, "ui_accept activates focused Cancel rather than a background or hard-coded confirm action")
	_assert("equipment-registry" not in manager.active_profile().tree_allocations.get(TREE_ID, []), "focused Cancel performs no allocation")
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert((screen.get_node("Overlay/Confirmation") as Control).visible, "controller can reopen allocation confirmation after focused Cancel")
	confirm_button.grab_focus()
	await _joy_button(viewport, JOY_BUTTON_A)
	_assert("equipment-registry" in manager.active_profile().tree_allocations.get(TREE_ID, []), "controller confirmation persists the selected allocation")
	_assert(not (screen.get_node("Overlay/Confirmation") as Control).visible, "successful allocation closes its confirmation")
	await _joy_button(viewport, JOY_BUTTON_X)
	_assert(not (screen.get_node("Overlay/Confirmation") as Control).visible, "permanent node refund request is rejected before confirmation")

	canvas.select_node(&"city-heart")
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, -1.0)
	await _joy_motion(viewport, JOY_AXIS_LEFT_Y, 0.0)
	_assert(canvas.selected_node_id() == &"shared-lessons-1", "device-0 left stick navigates to the linked upper node")
	await _key(viewport, KEY_ENTER)
	_assert((screen.get_node("Overlay/Confirmation") as Control).visible, "keyboard Enter initiates allocation")
	await _key(viewport, KEY_TAB)
	_assert(viewport.gui_get_focus_owner() == confirm_button, "keyboard focus moves from Cancel to Confirm inside the modal")
	await _key(viewport, KEY_ENTER)
	_assert("shared-lessons-1" in manager.active_profile().tree_allocations.get(TREE_ID, []), "keyboard Enter confirms allocation")
	await _joy_button(viewport, JOY_BUTTON_X)
	_assert((screen.get_node("Overlay/Confirmation") as Control).visible, "controller west face initiates an eligible refund")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(screen.is_open() and not (screen.get_node("Overlay/Confirmation") as Control).visible, "controller east face cancels a pending refund without closing the tree")

	await _key(viewport, KEY_ESCAPE)
	_assert(not screen.is_open() and settings.is_open(), "keyboard Escape closes the tree and resumes Settings")
	_assert(viewport.gui_get_focus_owner() == open_tree, "tree close restores focus to Open City Passive Tree")
	_assert(int(capacity.value) == 9, "unsaved Settings draft survives the child tree round trip")
	_assert(settings.current_settings().party_capacity_override != 9, "tree round trip does not apply the unsaved draft")
	await _key(viewport, KEY_ESCAPE)
	_assert(not settings.is_open() and viewport.gui_get_focus_owner() == settings_button, "closing resumed Settings restores its original external caller")

	var original_definition := main.passive_tree_definition
	_assert(_write_invalid_tree_fixture(), "disposable invalid-tree fixture is written outside committed data")
	var invalid := PassiveTreeCatalog.load_path(_invalid_path)
	_assert(not invalid.ok() and invalid.tree == null, "disposable malformed tree fails closed")
	main.passive_tree_definition = invalid.tree
	settings.open_additional(settings_button)
	await _frames(2)
	mode.select(PartyForgeSettings.Mode.DEVELOPER_MODE)
	mode.item_selected.emit(PartyForgeSettings.Mode.DEVELOPER_MODE)
	open_tree.pressed.emit()
	await _frames(3)
	_assert(screen.is_open(), "invalid tree still opens the safe passive-tree screen")
	_assert((screen.get_node("Overlay/Frame/Layout/Status") as Label).text == "City passive tree unavailable", "invalid tree shows the exact unavailable message")
	_assert(manager.active_profile() != null and manager.active_profile().profile_id == profile_id, "invalid tree leaves the active profile usable")
	_assert(main.catalog_valid and not main.run_started, "invalid tree leaves Main and the arena launch catalog usable")
	await _joy_button(viewport, JOY_BUTTON_B)
	_assert(settings.is_open() and viewport.gui_get_focus_owner() == open_tree, "safe unavailable screen returns to usable Settings")
	main.passive_tree_definition = original_definition
	settings.close()

	await _finish(viewport)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _key(viewport: SubViewport, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _key_with_shift(viewport: SubViewport, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.shift_pressed = true
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _joy_button(viewport: SubViewport, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _joy_motion(viewport: SubViewport, axis: JoyAxis, value: float, frame_count: int = 1) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	viewport.push_input(event)
	Input.parse_input_event(event)
	await _frames(frame_count)


func _mouse_click(viewport: SubViewport, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = position - viewport.get_mouse_position()
	viewport.push_input(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	viewport.push_input(event)
	await process_frame
	var release := event.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _mouse_drag(viewport: SubViewport, start: Vector2, relative: Vector2, button: MouseButton, mask: MouseButtonMask) -> void:
	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = start
	pointer_motion.relative = start - viewport.get_mouse_position()
	viewport.push_input(pointer_motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.button_mask = mask
	press.position = start
	press.global_position = start
	press.pressed = true
	viewport.push_input(press)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = start + relative
	motion.global_position = motion.position
	motion.relative = relative
	motion.button_mask = mask
	viewport.push_input(motion)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.position = motion.position
	release.global_position = motion.position
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release)
	await process_frame


func _mouse_wheel(viewport: SubViewport, position: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = true
	viewport.push_input(event)
	await process_frame


func _canvas_blank_point(canvas: PassiveTreeCanvas) -> Vector2:
	var rect := canvas.get_global_rect().grow(-24.0)
	for row: int in range(1, 8):
		for column: int in range(1, 10):
			var candidate := rect.position + Vector2(rect.size.x * float(column) / 10.0, rect.size.y * float(row) / 8.0)
			var blocked := false
			for node_id: StringName in canvas.node_ids():
				var node_control := canvas.node_control(node_id)
				if node_control != null and node_control.get_global_rect().grow(4.0).has_point(candidate):
					blocked = true
					break
			if not blocked:
				return candidate
	return rect.get_center()


func _write_invalid_tree_fixture() -> bool:
	var global_root := ProjectSettings.globalize_path(_profile_root)
	if DirAccess.make_dir_recursive_absolute(global_root) not in [OK, ERR_ALREADY_EXISTS]:
		return false
	var file := FileAccess.open(_invalid_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string('{"format":"passive-skill-tree","formatVersion":1,"treeId":"broken-city"}')
	file.close()
	return true


func _finish(viewport: SubViewport) -> void:
	Input.action_release(&"passive_tree_pan_left")
	Input.action_release(&"passive_tree_pan_right")
	Input.action_release(&"passive_tree_pan_up")
	Input.action_release(&"passive_tree_pan_down")
	Input.action_release(&"passive_tree_zoom_in")
	Input.action_release(&"passive_tree_zoom_out")
	paused = false
	if viewport != null and is_instance_valid(viewport):
		viewport.free()
	ProfileTestSupport.remove_tree(_profile_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable input root was not removed")
	if _failures.is_empty():
		print("PASSIVE_TREE_INPUT_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("PASSIVE_TREE_INPUT_FAILURE: %s" % failure)
	print("PASSIVE_TREE_INPUT_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
