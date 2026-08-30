extends SceneTree

const PANEL_SCENE := preload("res://scenes/ui/level_up_panel.tscn")
const PICKER_SCENE := preload("res://scenes/ui/upgrade_recipient_picker.tscn")
const TARGET_VIEWPORTS := [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var probe := PANEL_SCENE.instantiate() as LevelUpPanel
	var typed_contract := probe.get_node_or_null("Frame/Content/Recipient") != null and probe.has_signal(&"application_requested")
	probe.free()
	if not typed_contract:
		_failures.append("Living Forge typed recipient and confirmation route is not implemented")
		for failure: String in _failures:
			push_error("UPGRADE_RECIPIENT_CONTROLLER_SCROLL_FAILURE: %s" % failure)
		print("UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: FAIL (%d failures, 3 viewports)" % _failures.size())
		quit(1)
		return
	for viewport_size: Vector2i in TARGET_VIEWPORTS:
		await _exercise_viewport(viewport_size)
	await _exercise_stale_rebuild_safety()
	for failure: String in _failures:
		push_error("UPGRADE_RECIPIENT_CONTROLLER_SCROLL_FAILURE: %s" % failure)
	print("UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: %s (%d failures, 3 viewports)" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)


func _exercise_viewport(viewport_size: Vector2i) -> void:
	var mode := "%dx%d" % [viewport_size.x, viewport_size.y]
	root.size = viewport_size
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(24))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for member_id: int in range(2, 25):
		var class_id := &"marksman" if member_id % 2 == 0 else &"fighter"
		_assert(party.recruit(catalog.class_by_id(class_id)), "%s fixture recruits member %d" % [mode, member_id])
		party.members[-1].character_name = "Member %d" % member_id

	var choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"deadeye"))
	var choices: Array[UpgradeChoice] = [
		choice,
		UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
		UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
	]
	var panel := PANEL_SCENE.instantiate() as LevelUpPanel
	root.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.configure_reduced_motion(true)
	panel.show_choices(choices, party)
	await _frames(3)
	await _joy_button(JOY_BUTTON_A)
	await _frames(2)

	var picker := panel.get_node("Frame/Content/Recipient") as UpgradeRecipientPicker
	var scroll := picker.get_node("Content/RecipientsScroll") as ScrollContainer
	var rows := picker.get_node("Content/RecipientsScroll/Rows") as VBoxContainer
	var cancel := picker.get_node("Content/Cancel") as Button
	_assert(picker.visible, "%s controller accept opens the recipient picker" % mode)
	_assert(rows.get_child_count() == 24, "%s picker retains all 24 party rows" % mode)
	_assert((rows.get_node("Member_1") as Button).disabled, "%s ineligible member 1 remains visible and disabled" % mode)
	_assert(root.gui_get_focus_owner() == rows.get_node("Member_2"), "%s initial focus skips to first eligible member 2" % mode)
	var scroll_bar := scroll.get_v_scroll_bar()
	var minimum_scroll := int(scroll_bar.min_value)
	_assert(scroll_bar.max_value > scroll_bar.page, "%s 24-row fixture genuinely overflows" % mode)

	for member_id: int in range(4, 25, 2):
		await _joy_button(JOY_BUTTON_DPAD_DOWN)
		var expected := rows.get_node("Member_%d" % member_id) as Button
		_assert(root.gui_get_focus_owner() == expected, "%s D-pad traverses to eligible member %d in party-row order (actual=%s)" % [mode, member_id, _focus_name()])

	var member_24 := rows.get_node("Member_24") as Button
	_assert(root.gui_get_focus_owner() == member_24, "%s real controller focus reaches member 24" % mode)
	_assert(scroll.scroll_vertical > minimum_scroll, "%s recipient scroll moves beyond its minimum for member 24" % mode)
	_assert(_fully_visible(scroll, member_24), "%s focused member 24 is fully inside the recipient viewport" % mode)

	await _joy_button(JOY_BUTTON_DPAD_DOWN)
	_assert(root.gui_get_focus_owner() == cancel, "%s last eligible recipient navigates down to Back to Offers" % mode)
	await _joy_button(JOY_BUTTON_DPAD_UP)
	_assert(root.gui_get_focus_owner() == member_24, "%s Back to Offers navigates up to the last eligible recipient" % mode)
	_assert(_fully_visible(scroll, member_24), "%s returning from Back keeps member 24 fully visible" % mode)
	for member_id: int in range(22, 1, -2):
		await _key(KEY_UP)
		_assert(root.gui_get_focus_owner() == rows.get_node("Member_%d" % member_id), "%s keyboard Up traverses to eligible member %d" % [mode, member_id])
	_assert(scroll.scroll_vertical <= minimum_scroll + 1, "%s keyboard focus returns recipient scroll to its minimum" % mode)
	for member_id: int in range(4, 25, 2):
		await _key(KEY_DOWN)
		_assert(root.gui_get_focus_owner() == rows.get_node("Member_%d" % member_id), "%s keyboard Down traverses to eligible member %d" % [mode, member_id])
	_assert(root.gui_get_focus_owner() == member_24 and _fully_visible(scroll, member_24), "%s keyboard focus also reaches visible member 24" % mode)
	print("UPGRADE_RECIPIENT_CONTROLLER_SCROLL_VIEWPORT: %s member=24 scroll=%d max=%d page=%d" % [
		mode,
		scroll.scroll_vertical,
		int(scroll_bar.max_value),
		int(scroll_bar.page),
	])

	var selected_member_ids: Array[int] = []
	picker.recipient_selected.connect(func(selected_key: StringName, member_id: int) -> void:
		_assert(selected_key == StringName(choice.key()), "%s recipient emits the stable choice key" % mode)
		selected_member_ids.append(member_id)
	)
	await _joy_button(JOY_BUTTON_A)
	_assert(selected_member_ids == [24], "%s controller south emits stable member_id 24" % mode)
	_assert((panel.get_node("Frame/Content/Confirmation") as Control).visible, "%s controller recipient selection enters the existing confirmation flow" % mode)
	_assert(int(panel.get("_pending_member_id")) == 24, "%s confirmation retains member_id 24" % mode)
	_assert("->" in (panel.get_node("Frame/Content/Confirmation/BodyScroll/Body/Effect") as Label).text, "%s confirmation shows exact recipient preview" % mode)

	panel.free()
	party.free()
	await process_frame


func _exercise_stale_rebuild_safety() -> void:
	root.size = Vector2i(1920, 1080)
	var catalog := GameCatalog.load_defaults()
	var choice := UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))
	var picker := PICKER_SCENE.instantiate() as UpgradeRecipientPicker
	root.add_child(picker)
	picker.call(&"show_for", StringName(choice.key()), _recipient_rows(1))
	await _frames(2)
	var old_member_24 := picker.get_node("Content/RecipientsScroll/Rows/Member_24") as Button
	old_member_24.grab_focus()
	picker.call(&"show_for", StringName(choice.key()), _recipient_rows(101))
	var new_first := picker.get_node("Content/RecipientsScroll/Rows/Member_101") as Button
	new_first.grab_focus()
	await _frames(3)
	var scroll := picker.get_node("Content/RecipientsScroll") as ScrollContainer
	_assert(root.gui_get_focus_owner() == new_first, "rebuild keeps focus on the new offer instead of a freed recipient")
	_assert(_fully_visible(scroll, new_first), "stale deferred visibility cannot scroll the new offer away from its first recipient")
	_assert(picker.get_node_or_null("Content/RecipientsScroll/Rows/Member_24") == null, "rebuild removes the stale recipient row")
	picker.free()
	await process_frame


func _recipient_rows(first_member_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for offset: int in 24:
		var member_id := first_member_id + offset
		result.append({
			"member_id": member_id,
			"character_name": "Member %d" % member_id,
			"class_name": "Fighter",
			"role_name": "Frontline",
			"class_rank": 1,
			"health_current": 100.0,
			"health_maximum": 100.0,
			"current_rank": 0,
			"next_rank": 1,
			"preview_lines": ["Fixture preview."],
			"eligible": true,
			"disabled_reason": "",
		})
	return result


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _fully_visible(scroll: ScrollContainer, control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	var viewport_rect := scroll.get_global_rect()
	var control_rect := control.get_global_rect()
	return control_rect.position.y >= viewport_rect.position.y - 1.0 \
		and control_rect.end.y <= viewport_rect.end.y + 1.0


func _focus_name() -> String:
	var focus := root.gui_get_focus_owner()
	return str(focus.get_path()) if focus != null else "<none>"


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
