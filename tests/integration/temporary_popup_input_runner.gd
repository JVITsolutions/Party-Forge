extends SceneTree

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
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(host)
	var anchor := Button.new()
	anchor.position = Vector2(80.0, 80.0)
	anchor.size = Vector2(320.0, 240.0)
	host.add_child(anchor)
	var tooltip := (load("res://scenes/ui/upgrade_tooltip_panel.tscn") as PackedScene).instantiate() as UpgradeTooltipPanel
	host.add_child(tooltip)
	await _wait_for_layout()

	var content := _long_content()
	var preheld_alt := InputEventKey.new()
	preheld_alt.keycode = KEY_ALT
	preheld_alt.pressed = true
	viewport.push_input(preheld_alt)
	_assert(not tooltip.visible, "Alt pressed while hidden does not reveal popup")
	_assert(not viewport.is_input_handled(), "Alt pressed while hidden remains unhandled")
	_assert(tooltip.show_content(content, anchor, &"preheld"), "preheld Alt source is accepted")
	tooltip.release_source(&"preheld")
	_assert(tooltip.visible, "Alt pressed before presentation retains popup after source exit")
	var preheld_alt_release := preheld_alt.duplicate() as InputEventKey
	preheld_alt_release.pressed = false
	viewport.push_input(preheld_alt_release)
	await process_frame
	_assert(not tooltip.visible and not tooltip.is_pinned(), "preheld Alt release dismisses inactive unpinned popup")

	tooltip.show_content(content, anchor, &"first")
	await _wait_for_layout()
	var scroll := tooltip.get_node("Content/BodyScroll") as ScrollContainer
	var pin := tooltip.get_node("Content/Header/Pin") as Button

	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.pressed = true
	viewport.push_input(alt)
	tooltip.release_source(&"first")
	_assert(tooltip.visible, "Alt transfer keeps popup visible")

	var motion := InputEventMouseMotion.new()
	motion.position = scroll.get_global_rect().get_center()
	viewport.push_input(motion)
	var wheel := InputEventMouseButton.new()
	wheel.position = motion.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	viewport.push_input(wheel)
	var wheel_release := wheel.duplicate() as InputEventMouseButton
	wheel_release.pressed = false
	viewport.push_input(wheel_release)
	await _wait_for_layout()
	_assert(scroll.scroll_vertical > 0, "mouse wheel scrolls Alt-held popup")

	await _push_mouse_click(viewport, pin)
	_assert(tooltip.is_pinned(), "real mouse click pins popup")
	var alt_release := alt.duplicate() as InputEventKey
	alt_release.pressed = false
	viewport.push_input(alt_release)
	await process_frame
	_assert(tooltip.visible and tooltip.is_pinned(), "mouse pin survives Alt release")
	var pinned_title := (tooltip.get_node("Content/Header/Title") as Label).text
	_assert(not tooltip.show_content({"title": "Replacement"}, anchor, &"second"), "pinned popup rejects replacement")
	_assert((tooltip.get_node("Content/Header/Title") as Label).text == pinned_title, "rejected content stays unchanged")
	await _push_mouse_click(viewport, pin)
	_assert(not tooltip.visible and not tooltip.is_pinned(), "real mouse click unpins and dismisses inactive source")

	var controller_pin := InputEventJoypadButton.new()
	controller_pin.button_index = JOY_BUTTON_Y
	controller_pin.pressed = true
	_assert(tooltip.show_content(content, anchor, &"controller"), "controller source is accepted")
	viewport.push_input(controller_pin)
	await process_frame
	_assert(tooltip.is_pinned(), "Y/Triangle pins active controller popup")
	var controller_release := controller_pin.duplicate() as InputEventJoypadButton
	controller_release.pressed = false
	viewport.push_input(controller_release)
	await process_frame
	scroll.scroll_vertical = 0
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = 1.0
	viewport.push_input(stick)
	await process_frame
	await process_frame
	_assert(scroll.scroll_vertical > 0, "right stick scrolls visible popup")
	stick.axis_value = 0.0
	viewport.push_input(stick)
	var stopped_scroll := scroll.scroll_vertical
	for _frame: int in 4:
		await process_frame
	_assert(scroll.scroll_vertical == stopped_scroll, "neutral right stick stops popup scrolling")
	tooltip.release_source(&"controller")
	viewport.push_input(controller_pin)
	await process_frame
	_assert(not tooltip.visible and not tooltip.is_pinned(), "Y/Triangle unpins and dismisses inactive source")
	viewport.push_input(controller_release)
	await process_frame

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var before := _failures.size()
		viewport.size = viewport_size
		host.size = viewport_size
		anchor.position = Vector2(float(viewport_size.x) * 0.5 - 160.0, 80.0)
		tooltip.force_dismiss()
		await process_frame
		_assert(not tooltip.visible, "cleanup hides popup before %s" % viewport_size)
		_assert(not tooltip.is_pinned(), "cleanup unpins popup before %s" % viewport_size)
		_assert(tooltip.get("_source_id") == &"", "cleanup clears exact source before %s" % viewport_size)
		_assert(tooltip.show_content(content, anchor, &"size_%d" % viewport_size.x), "size source is accepted at %s" % viewport_size)
		await _wait_for_layout()
		var rect := tooltip.get_global_rect()
		var pin_rect := pin.get_global_rect()
		var scrollbar := scroll.get_v_scroll_bar()
		var scrollbar_rect := scrollbar.get_global_rect()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert(rect.position.x >= 16.0 and rect.position.y >= 16.0, "popup starts inside %s" % viewport_size)
		_assert(rect.end.x <= viewport_size.x - 16.0 and rect.end.y <= viewport_size.y - 16.0, "popup ends inside %s" % viewport_size)
		_assert(rect.encloses(pin_rect), "pin remains inside popup at %s" % viewport_size)
		_assert(scrollbar.visible, "long content scrolls at %s" % viewport_size)
		_assert(rect.encloses(scrollbar_rect), "scrollbar remains inside popup at %s" % viewport_size)
		_assert(viewport_rect.encloses(scrollbar_rect), "scrollbar remains inside viewport at %s" % viewport_size)
		if _failures.size() == before:
			print("TEMPORARY_POPUP_INPUT_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	viewport.free()
	if _failures.is_empty():
		print("TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)")
		quit(0)
		return
	for failure: String in _failures:
		push_error("TEMPORARY_POPUP_INPUT_FAILURE: %s" % failure)
	print("TEMPORARY_POPUP_INPUT_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _wait_for_layout() -> void:
	await process_frame
	await process_frame


func _push_mouse_click(viewport: SubViewport, target: Button) -> void:
	var position := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.relative = position - viewport.get_mouse_position()
	viewport.push_input(motion)
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = position
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	viewport.push_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.button_mask = 0
	release.pressed = false
	viewport.push_input(release)
	await process_frame
	await process_frame


func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _long_content() -> Dictionary:
	var effects: Array[String] = []
	var keywords: Array[String] = []
	for index: int in 32:
		effects.append("%d%% increased Area Size from a production-like authored effect." % (index + 1))
	for index: int in 64:
		keywords.append("Keyword %d: A long explanation that requires interactive scrolling." % (index + 1))
	return {
		"title": "Expanding Power",
		"rank_text": "Offered rank 1 / 3",
		"description": "A long authored upgrade used for real popup interaction acceptance.",
		"effect_lines": effects,
		"eligibility_text": "Requires all traits or capabilities: Area",
		"inheritance_text": "",
		"keyword_lines": keywords,
	}
