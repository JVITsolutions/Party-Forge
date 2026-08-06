extends SceneTree

const PANEL_SCENE := preload("res://scenes/ui/storage/item_tooltip_panel.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var anchor := Button.new()
	anchor.position = Vector2(120.0, 120.0)
	anchor.size = Vector2(78.0, 78.0)
	host.add_child(anchor)
	var panel := PANEL_SCENE.instantiate() as Control
	host.add_child(panel)
	await _wait_for_layout()

	await _exercise_keyboard(viewport, anchor, panel)
	await _exercise_controller(viewport, anchor, panel)
	await _exercise_pin_focus_change(viewport, anchor, panel)

	viewport.free()
	if _failures.is_empty():
		print("ITEM_TOOLTIP_INPUT_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("ITEM_TOOLTIP_INPUT_FAILURE: %s" % failure)
	print("ITEM_TOOLTIP_INPUT_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _exercise_keyboard(viewport: SubViewport, anchor: Control, panel: Control) -> void:
	panel.call("force_dismiss")
	var source := &"keyboard_item"
	_assert(bool(panel.call("show_item", _detail("keyboard"), _comparisons(), anchor, source, true)), "keyboard item opens")
	await _wait_for_layout()

	var alt := _key(KEY_ALT, true)
	viewport.push_input(alt)
	panel.call("release_item", source)
	panel.call("_process", 0.13)
	_assert(panel.visible, "Alt retains a released mouse source")
	_assert(bool(panel.call("comparison_active")), "Alt enables comparison")
	_assert(int(panel.call("card_count")) == 3, "Alt shows every comparison candidate")

	var shift := _key(KEY_SHIFT, true)
	viewport.push_input(shift)
	_assert(bool(panel.call("advanced_active")), "Shift enables advanced affix details")
	_assert(bool(panel.call("comparison_active")) and int(panel.call("card_count")) == 3, "Alt and Shift layers combine")
	await _assert_mouse_wheel_scrolls(viewport, panel)

	viewport.push_input(_key(KEY_SHIFT, false))
	_assert(not bool(panel.call("advanced_active")), "Shift release removes only advanced details")
	_assert(bool(panel.call("comparison_active")) and panel.visible, "Shift release preserves comparison and main card")
	viewport.push_input(_key(KEY_ALT, false))
	await process_frame
	_assert(not bool(panel.call("comparison_active")), "Alt release removes comparison layer")
	_assert(not panel.visible, "Alt release dismisses an inactive unpinned card")


func _exercise_controller(viewport: SubViewport, anchor: Control, panel: Control) -> void:
	panel.call("force_dismiss")
	var source := &"controller_item"
	_assert(bool(panel.call("show_item", _detail("controller"), _comparisons(), anchor, source, true)), "controller item opens")
	viewport.push_input(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, 4))
	_assert(bool(panel.call("comparison_active")), "LT enables comparison")
	viewport.push_input(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 4))
	_assert(bool(panel.call("advanced_active")), "RT enables advanced details")
	_assert(int(panel.call("card_count")) == 3, "LT and RT layers combine")
	await _assert_right_stick_scrolls(viewport, panel)

	viewport.push_input(_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0, 4))
	_assert(not bool(panel.call("advanced_active")), "RT release removes only advanced details")
	_assert(bool(panel.call("comparison_active")) and panel.visible, "RT release preserves comparison and main card")
	viewport.push_input(_axis(JOY_AXIS_TRIGGER_LEFT, 0.0, 4))
	_assert(not bool(panel.call("comparison_active")), "LT release removes comparison")
	_assert(panel.visible, "active controller source remains after modifier release")
	panel.call("release_item", source)
	panel.call("_process", 0.13)
	_assert(not panel.visible, "released controller source dismisses after grace")


func _exercise_pin_focus_change(viewport: SubViewport, anchor: Control, panel: Control) -> void:
	panel.call("force_dismiss")
	var source := &"pinned_item"
	_assert(bool(panel.call("show_item", _detail("pinned"), _comparisons(), anchor, source, true)), "pin item opens")
	viewport.push_input(_button(JOY_BUTTON_Y, true))
	viewport.push_input(_button(JOY_BUTTON_Y, false))
	_assert(bool(panel.call("is_pinned")), "Y or Triangle pins")
	panel.call("release_item", source)
	panel.call("_process", 0.13)
	var other_anchor := Button.new()
	other_anchor.position = Vector2(320.0, 120.0)
	other_anchor.size = Vector2(78.0, 78.0)
	anchor.get_parent().add_child(other_anchor)
	other_anchor.grab_focus()
	var no_comparisons: Array[Dictionary] = []
	_assert(not bool(panel.call("show_item", _detail("other"), no_comparisons, other_anchor, &"other", true)), "focus change cannot replace pinned item")
	viewport.push_input(_button(JOY_BUTTON_Y, true))
	viewport.push_input(_button(JOY_BUTTON_Y, false))
	await process_frame
	_assert(not bool(panel.call("is_pinned")) and not panel.visible, "Y or Triangle unpins original item after focus changes")


func _assert_mouse_wheel_scrolls(viewport: SubViewport, panel: Control) -> void:
	await _wait_for_layout()
	var scroll := panel.get_node("Layout/BodyScroll") as ScrollContainer
	scroll.scroll_vertical = 0
	var position := scroll.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	viewport.push_input(motion)
	var wheel := InputEventMouseButton.new()
	wheel.position = position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewport.push_input(wheel)
	var wheel_release := wheel.duplicate() as InputEventMouseButton
	wheel_release.pressed = false
	viewport.push_input(wheel_release)
	await _wait_for_layout()
	_assert(scroll.scroll_vertical > 0, "mouse wheel scrolls tooltip")


func _assert_right_stick_scrolls(viewport: SubViewport, panel: Control) -> void:
	await _wait_for_layout()
	var scroll := panel.get_node("Layout/BodyScroll") as ScrollContainer
	scroll.scroll_vertical = 0
	viewport.push_input(_axis(JOY_AXIS_RIGHT_Y, 1.0, 0))
	await process_frame
	await process_frame
	_assert(scroll.scroll_vertical > 0, "right stick scrolls tooltip")
	viewport.push_input(_axis(JOY_AXIS_RIGHT_Y, 0.0, 0))


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


func _button(button_index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = pressed
	return event


func _axis(axis: JoyAxis, value: float, device: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _detail(instance_id: String) -> Dictionary:
	var affixes: Array[Dictionary] = []
	for index: int in 28:
		affixes.append({
			"definition_id": "ember_%02d" % index,
			"display_name": "Of Embers %02d" % index,
			"affix_kind": "suffix",
			"tier": 3,
			"rolls": [{
				"stat_id": "fire_damage",
				"stat_name": "Fire Damage",
				"operation": StatModifier.Operation.FLAT,
				"operation_name": "Flat",
				"minimum_roll": 4.0,
				"maximum_roll": 12.0,
				"value": 8.0,
				"roll_fraction": 0.5,
				"effect_text": "+8 Fire Damage",
			}],
		})
	return {
		"instance_id": instance_id,
		"base_definition_id": "windrunner_band",
		"name": instance_id.capitalize(),
		"item_type_id": "ring",
		"rarity_id": "rare",
		"rarity_name": "Rare",
		"item_level": 31,
		"compatible_slot_ids": ["ring_left", "ring_right"],
		"handedness_id": "none",
		"requirement_lines": PackedStringArray(),
		"equip_warning_lines": PackedStringArray(),
		"core_value_lines": PackedStringArray(["12 Armour", "8 Fire Damage"]),
		"affixes": affixes,
	}


func _comparisons() -> Array[Dictionary]:
	return [
		{"slot_id": "ring_left", "item": _detail("left_ring"), "delta_lines": _delta_lines(3.0)},
		{"slot_id": "ring_right", "item": _detail("right_ring"), "delta_lines": _delta_lines(-2.0)},
	]


func _delta_lines(value: float) -> Array[Dictionary]:
	return [{
		"stat_id": "constitution",
		"operation": StatModifier.Operation.FLAT,
		"delta": value,
		"direction": 1 if value > 0.0 else -1,
		"text": "%+.0f Constitution" % value,
	}]
